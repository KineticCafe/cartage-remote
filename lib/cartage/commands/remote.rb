# frozen_string_literal: true

Cartage::CLI.extend do
  desc 'Build packages on remote servers'
  long_desc <<-'DESC'
Resolve Cartage configuration locally, then execute a build script on the
configured remote server based on the resolved configuration.
  DESC
  command 'remote' do |remote|
    remote.desc 'The name of the remote server to use'
    remote.long_desc <<-'DESC'
The name of the defined remote server in the Cartage configuration file. If the
server does not exist in the configuration, an error will be reported.
    DESC
    remote.flag %i(H host), arg_name: :HOST, default_value: :default

    remote.desc 'Check plugin configuration'
    remote.long_desc <<-'DESC'
Verifies the configuration of the cartage-remote section of the Cartage
configuration file.
    DESC
    remote.command 'check-config' do |check|
      check.hide!
      check.action do |_global, _options, _args|
        cartage.remote.check_config
      end
    end

    remote.default_desc 'Run a build script remotely'
    remote.action do |_global, options, _args|
      options[:host] = nil if options[:host] == :default
      config = cartage.config(for_plugin: :remote)
      server = (options[:host] || config.host || :default).to_sym

      unless config.dig(:hosts, server)
        message = if options[:host] || config.host
                    "Host '#{server}' does not exist."
                  else
                    'Default host does not exist.'
                  end
        fail ArgumentError, message
      end

      config.server = server
      cartage.remote.build
    end
  end
end
