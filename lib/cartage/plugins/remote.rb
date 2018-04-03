# frozen_string_literal: true

require 'tempfile'
require 'micromachine'
require 'cartage/plugin'

# A reliable way to create packages.
class Cartage
  # Connect to a remote machine and build a package remotely. cartage-remote
  # uses Fog::SSH with key-based authentication (not password-based) to connect
  # to a remote server.
  #
  # cartage-remote assumes a relatively stable build server, but does not
  # require one (custom +prebuild+ and +postbuild+ scripts could be used to
  # manage that).
  #
  # == Remote Build Isolation
  #
  # cartage-remote allows for safe builds across multiple projects and branches
  # with path-based isolation. The pattern for the build path is shown below,
  # where the last part of the path is where the code will be cloned to.
  #
  #   ~<remote_user>/cartage/<project-name>/<timestamp>/<project-name>
  #          |          |           |            |           |
  #          v          |           |            |           |
  #     build root      v           |            |           |
  #                  cartage        |            |           |
  #                   path          v            |           |
  #                              project         v           |
  #                               path       isolation       |
  #                                             path         v
  #                                                        build
  #                                                         path
  #
  # So that if I am deploying on a project called +calliope+ and my remote user
  # is +build+, my isolated build path might be:
  #
  #   ~build/cartage/calliope/20160321091432/calliope
  #
  # == Remote Build Steps
  #
  # The steps for a remote build are:
  #
  # 1.  Configure Cartage and save the active Cartage configuration as a
  #     temporary file that will be copied to the remote server.
  # 2.  Configure the Fog::SSH and Fog::SCP adapters with the keys to connect
  #     to the remote system.
  # 3.  Create the +prebuild+ script and run it locally (where the cartage CLI
  #     was run).
  # 4.  Connect to the remote server, put the Cartage configuration file in the
  #     isolation path, and clone the repository. Check the repo out to the
  #     appropriate +release_hashref+.
  # 5.  Create the +build+ script, copy it remotely, and run it from the build
  #     isolation path (+build_path+). This is effectively:
  #       cd "$build_path" && $build_script
  # 6.  Clean up the remote server fromt his build.
  # 7.  Create the +postbuild+ script and run it locally (where the cartage CLI
  #     was run).
  #
  # == Configuration
  #
  # cartage-remote is configured in the +plugins.remote+ section of the Cartage
  # configuration file. It supports two primary keys:
  #
  # +hosts+:: A dictionary of hosts, as described below, that indicate the
  #           remote machine where the build script will be run. The host keys
  #           will be used as the +host+ value.
  # +host+:: The name of the target host to be used. If missing, uses the
  #          +default+ location.
  #
  # For backwards compatibility, a single host may be specified in a +server+
  # key, using the same format as the +host+ values. This host will become the
  # +default+ host unless one is already specified in the +hosts+ dictionary
  # (which is an error).
  #
  # The following keys are optional and may be provided globally in
  # +plugins.remote+, or per host in +plugins.remote.hosts.$name+. If provided,
  # host-level values override the global configuration.
  #
  # +keys+:: The SSH key(s) used to connect to the server. There are two basic
  #          ways that keys can be provided:
  #
  #          * If provided as a string or an array of strings, the value(s)
  #            will be applied as glob patterns to find key files on disk.
  #          * If provided as a dictionary, the values are the ASCII
  #            representations of the private keys.
  #
  #          If keys are not provided, keys will be found on the local machine
  #          using the pattern <tt>~/.ssh/*id_[rd]sa</tt>.
  # +build+:: A multiline YAML string that is copied to the remote machine and
  #           executed as a script there. If not provided, the following script
  #           will be run:
  #
  #             #!/bin/bash
  #             set -e
  #             if [ -f Gemfile ]; then
  #               bundle install --path %{remote_bundle}
  #               bundle exec cartage \
  #                 --config-file %{config_file} \
  #                 --target %{project_path} \
  #                 pack
  #             else
  #               cartage \
  #                 --config-file %{config_file} \
  #                 --target %{project_path} \
  #                 pack
  #             fi
  # +prebuild+:: A multiline YAML string that is run as a script on the local
  #              machine to prepare for running remotely. If not provided, the
  #              following script will be run:
  #
  #                #!/bin/bash
  #                ssh-keyscan -H %{remote_adddress} >> ~/.ssh/known_hosts
  # +postbuild+:: A multiline YAML string that is run as a script on the local
  #               machine to finish the build process locally. There is no
  #               default postbuild script. The script will be passed the stage
  #               (+local_config+, +ssh_config+, +prebuild+, +remote_clone+,
  #               +remote_build+, +cleanup+, or +finished+) and, if the stage
  #               is not +finished+, the error message.
  #
  # === Hosts
  #
  # A host describes the remote server. It may be specified either as a string
  # in the form <tt>[user@]host[:port]</tt> *or* a dictionary with required
  # keys:
  #
  # +user+:: The user to connect to the remote server as. If not provided,
  #          defaults to +$USER+.
  # +address+:: The host address for connecting to the remote server. Also
  #             called +host+.
  # +port+:: The optional port to connect to the remote server on; used if not
  #          using the standard SSH port, 22.
  #
  # Additionally, +keys+, +build+, +prebuild+, and +postbuild+ scripts may be
  # specified to override the global scripts.
  #
  # == Script Substitution
  #
  # The +build+, +prebuild+, and +postbuild+ scripts require information from
  # the Cartage and Cartage::Remote instances. When these scripts are rendered
  # to disk, they will be run through Kernel#sprintf with string substitution
  # parameters (<tt>%{<em>parameter-name</em>}</tt>). All of these values are
  # computed from the local Cartage configuration.
  #
  # +repo_url+:: The repository URL.
  # +name+:: The package name.
  # +release_hashref+:: The release hashref to build.
  # +timestamp+:: The build timestamp.
  # +remote_address+:: The remote build host. Also available as +remote_host+
  #                    for backwards compatability.
  # +remote_port+:: The remote build host SSH port (may be empty).
  # +remote_user+:: The remote build user.
  # +build_root+:: The remote build root, (usually
  #                <tt>~<em>remote_user</em></tt>).
  # +cartage_path+:: <tt><em>build_root</em>/cartage</tt>.
  # +project_path+:: <tt><em>cartage_path</em>/<em>name</em></tt>.
  # +isolation_path+:: <tt><em>project_path</em>/<em>timestamp</em></tt>.
  # +build_path+:: The remote build path (contains the code to package).
  #                <tt><em>isolation_path</em>/<em>name</em></tt>
  # +remote_bundle+:: A place where dependencies for the build can be installed
  #                   locally. <tt><em>isolation_path</em>/deps</tt>. Typically
  #                   used in the +build+ script.
  #                     bundle install --path %{remote_bundle}
  # +dependency_cache+:: The +dependency_cachevendor_cache+ for the remote
  #                      server. Set the same as +project_path+.
  # +config_file+:: The remote filename of the computed Cartage configuration.
  #                 Must be provided to the remote run of +cartage+.
  #                   bundle exec cartage --config-file %{config_file} pack
  # +build_script+:: The full path to the remote build script.
  #                  <tt><em>isolation_path</em>/cartage-build-remote</tt>.
  #
  # == Configuration Example
  #
  #   ---
  #   plugins:
  #     remote:
  #       hosts:
  #         default: build-server
  #       script: |
  #         #! /bin/bash
  #         bundle install --path %{remote_bundle} &&
  #         bundle exec cartage --config-file %{config_file} pack &&
  #         bundle exec cartage --config-file %{config_file} s3 put
  class Remote < Cartage::Plugin
    VERSION = '2.2.beta3' #:nodoc:

    # Build on the remote server.
    def build
      stage.trigger! :local_setup
      stage.trigger! :ssh_setup
      stage.trigger! :run_prebuild
      stage.trigger! :clone_remote
      stage.trigger! :build_remote
      stage.trigger! :clean_remote
      stage.trigger! :complete
    rescue Cartage::CLI::CustomExit
      raise
    rescue => e
      error = e.exception("Remote error in stage #{stage.state}: #{e.message}")
      error.set_backtrace(e.backtrace)
      raise error
    ensure
      if postbuild_script
        cartage.display 'Running postbuild script...'
        system make_tmpscript('postbuild', postbuild_script, subs).path,
          stage.state.to_s, error.to_s
      end

      tmpfiles.each do |tmpfile|
        tmpfile.close
        tmpfile.unlink
      end
      tmpfiles.clear
    end

    # Check that the configuration is correct. If +require_host+ is present, an
    # exception will be thrown if a host is required and not present.
    #
    # The optional +notify+ block parameter is used primarily for testing.
    def check_config(require_host: false, &notify)
      config = cartage.config(for_plugin: :remote)

      puts "#{__method__}: verify_hosts(#{config.hosts.inspect})"
      verify_hosts(config.hosts, &notify)

      if require_host
        name = config.host || 'default'
        fail "No host #{name} present" unless config.hosts.dig(name)
      end

      true
    end

    private

    def initialize(*) #:nodoc:
      super
      @host = @name = @keys = @key_data = nil

      @stage = MicroMachine.new('new').tap { |stage|
        stage.when :local_setup, 'new' => 'local_config'
        stage.when :ssh_setup, 'local_config' => 'ssh_config'
        stage.when :run_prebuild, 'ssh_config' => 'prebuild'
        stage.when :clone_remote, 'prebuild' => 'remote_clone'
        stage.when :build_remote, 'remote_clone' => 'remote_build'
        stage.when :clean_remote, 'remote_build' => 'cleanup'
        stage.when :complete, 'cleanup' => 'finished'
        stage.on(:any) { |event| dispatch(event, stage.state) }
      }
    end

    attr_reader :host
    attr_reader :name
    attr_reader :config
    attr_reader :stage

    attr_reader :build_root
    attr_reader :config_file
    attr_reader :key_data
    attr_reader :keys
    attr_reader :paths
    attr_reader :subs

    def prebuild_script
      unless defined?(@prebuild_script)
        @prebuild_script = host.prebuild || config.prebuild ||
          DEFAULT_PREBUILD_SCRIPT
      end
      @prebuild_script
    end

    def postbuild_script
      unless defined?(@postbuild_script)
        @postbuild_script = host.postbuild || config.postbuild
      end
      @postbuild_script
    end

    def build_script
      unless defined?(@build_script)
        @build_script = host.build || config.build || DEFAULT_BUILD_SCRIPT
      end
      @build_script
    end

    def tmpfiles
      @tmpfiles ||= []
    end

    def local_setup
      @name = config.host || 'default'
      host_config = config.dig(:hosts, name)
      verify_host!(name, host_config)
      @host = Cartage::Remote::Host.new(host_config)

      fail ArgumentError, <<-exception if build_script.nil? || build_script.empty?
No build script to run on remote #{host}.
      exception

      # Force lazy values to be present during execution.
      cartage.send(:realize!)

      cartage.display 'Pre-build configuration...'
      @paths = OpenStruct.new(build_root: build_root)
      paths.cartage_path = paths.build_root.join('cartage')
      paths.project_path = paths.cartage_path.join(cartage.name)
      paths.isolation_path = paths.project_path.join(cartage.timestamp)
      paths.build_path = paths.isolation_path.join(cartage.name)
      paths.remote_bundle = paths.isolation_path.join('deps')
      paths.dependency_cache = paths.project_path
      paths.config_file = paths.isolation_path.join('cartage.yml')
      paths.build_script = paths.isolation_path.join('cartage-build-remote')

      @config_file = make_config(paths).path

      @subs = OpenStruct.new(
        paths.to_h.merge(
          repo_url:        cartage.repo_url,
          name:            cartage.name,
          release_hashref: cartage.release_hashref,
          timestamp:       cartage.timestamp,
          remote_host:     host.address,
          remote_address:  host.address,
          remote_port:     host.port,
          remote_user:     host.user
        )
      )
    end

    def ssh_setup
      host.configure_ssh(keys: keys, key_data: key_data)
    end

    def run_prebuild
      cartage.display 'Running prebuild script...'
      system(make_tmpscript('prebuild', prebuild_script, subs).path)
    end

    def clone_remote
      cartage.display <<-message
Checking out #{cartage.repo_url} at #{cartage.release_hashref} remotely...
      message

      ssh "mkdir -p #{paths.isolation_path}"
      host.scp.upload(config_file, user_path(paths.config_file))
      ssh "git clone #{cartage.repo_url} #{paths.build_path}"
      ssh <<-command
cd #{paths.build_path} && git checkout #{cartage.release_hashref}
      command
    end

    def build_remote
      cartage.display 'Running build script...'
      script = make_tmpscript('build', build_script, subs).path
      host.scp.upload(script, user_path(paths.build_script))
      ssh "cd #{paths.build_path} && #{paths.build_script}"
    end

    def clean_remote
      cartage.display 'Cleaning up after the build...'
      ssh "rm -rf #{paths.isolation_path}"
    end

    def dispatch(event, state)
      send(event) if respond_to?(event, true)
      send(state) if respond_to?(state, true)
    end

    def resolve_plugin_config!(remote_config)
      @config = remote_config
      if config.dig(:server)
        if config.dig(:hosts, :default)
          fail ArgumentError,
            'Cannot configure both an implicit and explicit default host.'
        end

        config.hosts ||= OpenStruct.new
        default = Cartage::Remote::Host.new(config.server).to_hash
        config.hosts.default = OpenStruct.new(default)
        config.host ||= 'default'

        config.delete_field(:server)
      end

      if config.keys.kind_of?(OpenStruct)
        @key_data = config.keys.to_h.values
      else
        @keys = Array(config.keys || '~/.ssh/*id_[rd]sa').flat_map { |key|
          Pathname.glob(Pathname(key).expand_path)
        }.uniq
      end

      @build_root = Pathname(config.build_root || '~')
      @postbuild_script = config.postbuild
    end

    def ssh(*commands)
      results = host.ssh.run(commands) do |stdout, stderr|
        $stdout.print stdout unless stdout.nil?
        $stderr.print stderr unless stderr.nil?
      end

      results.each do |result|
        next if result.status.zero?

        message = <<-msg
Remote error in stage #{stage.state}:
  SSH command failed with status (#{result.status}):
        #{result.command}
        msg
        fail Cartage::CLI::CustomExit.new(message, result.status)
      end
    end

    def make_tmpfile(basename, content = nil)
      Tempfile.new("#{basename}.").tap { |f|
        f.write content || yield
        f.close
        tmpfiles << f
      }
    end

    def make_tmpscript(basename, content, subs)
      make_tmpfile(basename, content % subs.to_h).tap { |f|
        File.chmod(0700, f.path)
      }
    end

    def make_config(paths)
      make_tmpfile('config.yml') do
        config = Cartage::Config.new(cartage.config)
        config.name = cartage.name
        config.root_path = paths.build_path.to_s
        config.timestamp = cartage.timestamp
        config.release_hashref = cartage.release_hashref
        config.compression = cartage.compression.to_s
        config.disable_dependency_cache = cartage.disable_dependency_cache
        config.dependency_cache_path = paths.dependency_cache.to_s
        config.to_yaml
      end
    end

    def user_path(path)
      path.to_s.sub(%r{\A~/}, '')
    end

    def verify_hosts(hosts, &notify)
      fail ArgumentError, 'No hosts present' if hosts.nil? || hosts.to_h.empty?

      hosts.each_pair do |name, host|
        puts "#{__method__}: verify_host(#{name.inspect}, #{host.inspect})"
        verify_host(name, host, &notify)
      end
    end

    def verify_host(name, host, &notify)
      notify ||= ->(message) { warn message }

      address =
        case host
        when OpenStruct
          host.dig(:address) || host.dig(:host)
        when String
          Cartage::Remote::Host::HOST_RE.match(host)[:address]
        end

      puts "#{__method__}: address=#{address.inspect}"

      notify.("Host #{name} invalid: No host address present") unless address
    end

    def verify_host!(name, host)
      verify_host(name, host) { |message| fail ArgumentError, message }
    end

    DEFAULT_PREBUILD_SCRIPT = <<-script #:nodoc:
#!/bin/bash

ssh-keyscan -H %{remote_address} >> ~/.ssh/known_hosts
    script

    DEFAULT_BUILD_SCRIPT = <<-script #:nodoc:
#!/bin/bash

set -e

if [ -f Gemfile ]; then
  bundle install --path %{remote_bundle}
  bundle exec cartage --config-file %{config_file} --target %{project_path} pack
else
  cartage --config-file %{config_file} --target %{project_path} pack
fi
    script
  end
end

require 'cartage/remote/host'
