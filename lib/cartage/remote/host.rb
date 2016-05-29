# frozen_string_literal: true

##
# The Host which remote commands will be run on.
class Cartage::Remote::Host
  # The user on the remote host.
  attr_reader :user
  # The address of the remote host.
  attr_reader :address
  # The port of the SSH connection to the remote host.
  attr_reader :port

  # The (optional) build script defined as part of this host.
  attr_reader :build
  # The (optional) prebuild script defined as part of this host.
  attr_reader :prebuild
  # The (optional) postbuild script defined as part of this host.
  attr_reader :postbuild

  # The Fog::SSH instance for this server. Must run #configure_ssh before
  # using.
  attr_reader :ssh
  # The Fog::SCP instance for this server. Must run #configure_ssh before
  # using.
  attr_reader :scp

  HOST_RE = /\A(?:(?<user>[^@]+)@)?(?<address>[^@:]+)(?::(?<port>[^:]+))?\z/

  # Initialize the Host from a +host+ object (an OpenStruct from a parsed
  # Cartage configuration) or a +host+ string (<tt>[user@]address[:port]</tt>).
  #
  # If +ssh_config+ is provided, prepare the SSH connections.
  def initialize(host, ssh_config = nil)
    @keys = @key_data = @build = @prebuild = @postbuild = nil

    case host
    when OpenStruct
      @user = host.user
      @address = host.address || host.host
      @port = host.port

      if host.keys.kind_of?(OpenStruct)
        @key_data = host.keys.to_h.values
      else
        @keys = Array(host.keys).flat_map { |key|
          Pathname.glob(Pathname(key).expand_path)
        }
      end
      @build = host.build
      @prebuild = host.prebuild
      @postbuild = host.postbuild
    when HOST_RE
      @user = Regexp.last_match[:user]
      @address = Regexp.last_match[:address]
      @port = Regexp.last_match[:port]
    end

    if address.nil? || address.empty?
      fail ArgumentError, 'Invalid remote host, no address specified.'
    end

    @user = ENV['USER'] if user.nil? || user.empty?

    configure_ssh(ssh_config) if ssh_config
  end

  # Configure the Fog::SSH and Fog::SCP connections using the provided
  # ssh_config.
  def configure_ssh(ssh_config)
    require 'fog'

    if @key_data
      ssh_config[:key_data] = @key_data
      ssh_config[:keys] = nil
    elsif @keys
      ssh_config[:key_data] = nil
      ssh_config[:keys] = @keys
    end

    options = { paranoid: true, port: port }.
      merge(ssh_config).
      delete_if { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }

    @ssh = Fog::SSH.new(address, user, options)
    @scp = Fog::SCP.new(address, user, options)
  end

  # This Host, formatted nicely.
  def to_s
    "#{user}@#{address}:#{port}".gsub(/^@|:$/, '')
  end

  # Convert this Host to a hash format.
  def to_hash
    {
      user: user,
      address: address,
      port: port
    }.delete_if { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
  end
end