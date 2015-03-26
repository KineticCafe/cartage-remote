begin
  require 'psych'
rescue LoadError
end
require 'tempfile'
require 'yaml'
require 'erb'
require 'micromachine'
require 'cartage/plugin'

class Cartage
  # Connect to a remote machine and build a package remotely. Cartage::Remote
  # uses Fog::SSH with key-based, not password-based authentication to connect
  # to a remote server.
  #
  # Cartage::Remote assumes a relatively stable build server, but does not
  # require one (custom +prebuild+ and +postbuild+ scripts could be used to
  # manage that).
  #
  # == Remote Build Isolation
  #
  # Cartage::Remote allows for safe builds across multiple projects and
  # branches with path-based isolation. The pattern for the build path is shown
  # below, where the last part of the path is where the code will be cloned to.
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
  #   ~build/cartage/calliope/20150321091432/calliope
  #
  # == Remote Build Steps
  #
  # The steps for a remote build are:
  #
  # 1.  Configure Cartage and save the active Cartage configuration as a
  #     temporary file that will be copied to the remote server.
  # 2.  Configure the Fog::SSH adapters with the keys to connect to the remote
  #     system.
  # 3.  Create the +prebuild+ script and run it locally.
  # 4.  Connect to the remote server, put the Cartage configuration file in the
  #     isolation path, and clone the repository. Check the repo out to the
  #     appropriate +release_hashref+.
  # 5.  Create the +build+ script, copy it remotely, and run it from the build
  #     isolation path (+build_path+). This is effectively:
  #       cd "$build_path" && $build_script
  # 6.  Clean up the remote server
  #
  # == Configuration
  #
  # Cartage::Remote is configured in the +plugins.remote+ section of the
  # Cartage configuration file. The following keys are *required*:
  #
  # +server+:: A server string in the form <tt>[user@]host[:port]</tt> *or* a
  #            dictionary with +user+, +host+, and +port+. In either form, this
  #            will set @remote_user, @remote_host, and @remote_port. If
  #            @remote_user is not provided, it will be set from
  #            <tt>$USER</tt>.
  #
  # The following keys are optional:
  #
  # +keys+:: The SSH key(s) used to connect to the server. There are two basic
  #          ways that keys can be provided:
  #
  #          * If provided as a string or an array of strings, the value(s)
  #            will be applied as glob patterns to find key files on disk.
  #          * If provided as a dictionary, the keys are irrelevant but the
  #            values are the key data.
  #
  #          If keys are not provided, a default pattern of
  #          <tt>~/.ssh/*id_[rd]sa</tt> will be used to find keys on the local
  #          machine.
  # +build+:: A multiline YAML string that is copied to the remote machine and
  #           executed as a script there. If not provided, the following script
  #           will be run:
  #
  #             #!/bin/bash
  #             set -e
  #             if [ -f Gemfile ]; then
  #               bundle install --path %<remote_bundle>s
  #               bundle exec cartage build \
  #                 --config-file %<config_file>s \
  #                 --target %<project_path>s
  #             else
  #               cartage build --config-file %<config_file>s \
  #                 --target %<project_path>s
  #             fi
  # +prebuild+:: A multiline YAML string that is run as a script on the local
  #              machine to prepare for running remotely. If not provided, the
  #              following script will be run:
  #
  #                #!/bin/bash
  #                ssh-keyscan -H %<remote_host>s >> ~/.ssh/known_hosts
  # +postbuild+:: A multiline YAML string that is run as a script on the local
  #               machine to finish the build process locally. If not
  #               provided, nothing will run. The script will be passed the
  #               stage (+config+, +ssh_config+, +prebuild+, +remote_clone+,
  #               +remote_build+, +cleanup+, or +finished+) and, if the stage
  #               is not +finished+, the error message.
  #
  # == Script Substitution
  #
  # The +build+, +prebuild+, and +postbuild+ scripts require information from
  # the Cartage and Cartage::Remote instances. When these scripts are rendered
  # to disk, they will be run through Kernel#sprintf with the following
  # substitution parameters specified as strings
  # (<tt>%<<em>parameter-name</em>>s</tt>). All of these values are computed
  # from the local Cartage configuration.
  #
  # +repo_url+:: The repository URL.
  # +name+:: The package name.
  # +release_hashref+:: The release hashref to build.
  # +timestamp+:: The build timestamp.
  # +remote_host+:: The remote build host.
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
  #                     bundle install --path %<remote_bundle>s
  # +bundle_cache+:: The +bundle_cache+ for the remote server. Set the same as
  #                  +project_path+.
  # +config_file+:: The remote filename of the computed Cartage configuration.
  #                 Must be provided to the remote run of +cartage+.
  #                   bundle exec cartage build --config-file %<config_file>s
  # +build_script+:: The full path to the remote build script.
  #                  <tt><em>isolation_path</em>/cartage-build-remote</tt>.
  #
  # == Configuration Example
  #
  #   ---
  #   plugins:
  #     remote:
  #       server:
  #         host: build-server
  #       script: |
  #         #! /bin/bash
  #         bundle install --path %<remote_bundle>s
  #         bundle exec cartage s3 --config-file %<config_file>s
  #
  class Remote < Cartage::Plugin
    VERSION = '1.1' #:nodoc:

    def initialize(*) #:nodoc:
      super
      @tmpfiles = []
      @fsm = MicroMachine.new(:new).tap do |fsm|
        fsm.when(:local_setup, new: :config)
        fsm.when(:ssh_setup, config: :ssh_config)
        fsm.when(:run_prebuild, ssh_config: :prebuild)
        fsm.when(:clone_remote, prebuild: :remote_clone)
        fsm.when(:build_remote, remote_clone: :remote_build)
        fsm.when(:clean_remote, remote_build: :cleanup)
        fsm.when(:complete, cleanup: :finished)
        fsm.on(:any) { |event| dispatch(event, @fsm.state) }
      end
    end

    # Build on the remote server.
    def build
      @fsm.trigger!(:local_setup)
      @fsm.trigger!(:ssh_setup)
      @fsm.trigger!(:run_prebuild)
      @fsm.trigger!(:clone_remote)
      @fsm.trigger!(:build_remote)
      @fsm.trigger!(:clean_remote)
      @fsm.trigger!(:complete)
    rescue Cartage::StatusError
      raise
    rescue Exception => e
      error = e.exception("Remote error in stage #{@fsm.state}: #{e.message}")
      error.set_backtrace(e.backtrace)
      raise error
    ensure
      if @postbuild
        @cartage.display 'Running postbuild script...'
        system(make_tmpscript('postbuild', @postbuild, @subs).path,
               @fsm.state.to_s, error.to_s)
      end

      @tmpfiles.each { |tmpfile|
        tmpfile.close
        tmpfile.unlink
      }
      @tmpfiles.clear
    end

    private

    def local_setup
      @cartage.display 'Pre-build configuration...'
      @paths = OpenStruct.new(build_root: @build_root)
      @paths.cartage_path = @paths.build_root.join('cartage')
      @paths.project_path = @paths.cartage_path.join(@cartage.name)
      @paths.isolation_path = @paths.project_path.join(@cartage.timestamp)
      @paths.build_path = @paths.isolation_path.join(@cartage.name)
      @paths.remote_bundle = @paths.isolation_path.join('deps')
      @paths.bundle_cache = @paths.project_path
      @paths.config_file = @paths.isolation_path.join('cartage.yml')
      @paths.build_script = @paths.isolation_path.join('cartage-build-remote')

      @config_file = make_config(@paths).path

      @subs = OpenStruct.new(
        @paths.to_h.merge(repo_url:        @cartage.repo_url,
                         name:            @cartage.name,
                         release_hashref: @cartage.release_hashref,
                         timestamp:       @cartage.timestamp,
                         remote_host:     @remote_host,
                         remote_port:     @remote_port,
                         remote_user:     @remote_user)
      )

    end

    def ssh_setup
      require 'fog'
      options = {
        paranoid: true,
        keys:     @keys,
        key_data: @key_data
      }

      options[:port] = @remote_port if @remote_port

      @ssh = Fog::SSH.new(@remote_host, @remote_user, options)
      @scp = Fog::SCP.new(@remote_host, @remote_user, options)
    end

    def run_prebuild
      @cartage.display 'Running prebuild script...'
      system(make_tmpscript('prebuild', @prebuild, @subs).path)
    end

    def clone_remote
      @cartage.display <<-message
Checking out #{@cartage.repo_url} at #{@cartage.release_hashref} remotely...
      message

      ssh %Q(mkdir -p #{@paths.isolation_path})
      @scp.upload(@config_file, user_path(@paths.config_file))
      ssh %Q(git clone #{@cartage.repo_url} #{@paths.build_path})
      ssh <<-command
cd #{@paths.build_path} && git checkout #{@cartage.release_hashref}
      command
    end

    def build_remote
      @cartage.display 'Running build script...'
      script = make_tmpscript('build', @build, @subs).path
      @scp.upload(script, user_path(@paths.build_script))
      ssh %Q(cd #{@paths.build_path} && #{@paths.build_script})
    end

    def clean_remote
      @cartage.display 'Cleaning up after the build...'
      ssh %Q(rm -rf #{@paths.isolation_path})
    end

    def dispatch(event, state)
      send(event) if respond_to?(event, true)
      send(state) if respond_to?(state, true)
    end

    def resolve_config!(remote_config)
      unless remote_config
        raise ArgumentError, 'Cartage remote has no configuration.'
      end

      @remote_user = @remote_host = @remote_port = nil

      case server = remote_config.server
      when OpenStruct
        @remote_user = server.user
        @remote_host = server.host
        @remote_port = server.port
      when %r{\A(?:(?<user>[^@]+)@)?(?<host>[^@:]+)(?::(?<port>[^:]+))?\z}
        @remote_user = $~[:user]
        @remote_host = $~[:host]
        @remote_port = $~[:port]
      end

      @remote_user ||= ENV['USER']

      if @remote_host.nil? or @remote_host.empty?
        raise ArgumentError, 'Cannot connect to remote; no server specified.'
      end

      @remote_server = @remote_host
      @remote_server = "#{@remote_user}@#{@remote_server}" if @remote_user
      @remote_server = "#{@remote_server}:#{@remote_port}" if @remote_port

      @build_root = Pathname(remote_config.build_root || '~')

      @build = remote_config.build
      raise ArgumentError, <<-exception if @build.nil? or @build.empty?
No build script to run on remote #{@remote_server}.
      exception

      @key_data = @keys = nil

      case keys = remote_config.keys
      when OpenStruct
        @key_data = keys.to_h.values
      when Array
        @keys = keys
      when String
        @keys = [ keys ]
      when nil
        @keys = %w(~/.ssh/*id_[rd]sa)
      end

      @keys &&= @keys.map { |key|
        Pathname.glob(Pathname(key).expand_path)
      }.flatten

      @prebuild = remote_config.prebuild || DEFAULT_PREBUILD_SCRIPT
      @postbuild = remote_config.postbuild

      # Force lazy values to be present during execution.
      @cartage.repo_url
      @cartage.root_path
      @cartage.release_hashref
      @cartage.timestamp
      @cartage
    end


    def ssh(*commands)
      results = @ssh.run(commands) do |stdout, stderr|
        $stdout.print stdout unless stdout.nil?
        $stderr.print stderr unless stderr.nil?
      end

      results.each do |result|
        if result.status.nonzero?
          message = <<-msg
Remote error in stage #{@fsm.state}:
  SSH command failed with status (#{result.status}):
    #{result.command}
          msg
          fail Cartage::StatusError.new(result.status, message)
        end
      end
    end

    def make_tmpfile(basename, content = nil)
      Tempfile.new("#{basename}.").tap { |f|
        f.write content || yield
        f.close
        @tmpfiles << f
      }
    end

    def make_tmpscript(basename, content, subs)
      make_tmpfile(basename, content % subs.to_h).tap { |f|
        File.chmod(0700, f.path)
      }
    end

    def make_config(paths)
      make_tmpfile('config.yml') do
        config = Cartage::Config.new(@cartage.config)
        config.name            = @cartage.name
        config.release_hashref = @cartage.release_hashref
        config.timestamp       = @cartage.timestamp
        config.root_path       = paths.build_path.to_s
        config.bundle_cache    = paths.bundle_cache.to_s
        config.to_yaml
      end
    end

    def user_path(path)
      path.to_s.sub(%r{\A~/}, '')
    end

    def self.commands #:nodoc:
      require_relative 'remote/command'
      [ Cartage::Remote::Command ]
    end

    DEFAULT_PREBUILD_SCRIPT = <<-script #:nodoc:
#!/bin/bash

ssh-keyscan -H %<remote_host>s >> ~/.ssh/known_hosts
    script

    DEFAULT_BUILD_SCRIPT = <<-script #:nodoc:
#!/bin/bash

set -e

if [ -f Gemfile ]; then
  bundle install --path %<remote_bundle>s
  bundle exec cartage build --config-file %<config_file>s --target %<project_path>s
else
  cartage build --config-file %<config_file>s --target %<project_path>s
fi
    script
  end
end
