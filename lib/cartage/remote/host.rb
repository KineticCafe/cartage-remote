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
  # Whether agent forwarding should be turned on or not. Defaults to +true+.
  attr_reader :forward_agent

  # The (optional) build script defined as part of this host.
  attr_reader :build
  # The (optional) prebuild script defined as part of this host.
  attr_reader :prebuild
  # The (optional) postbuild script defined as part of this host.
  attr_reader :postbuild

  # The (optional) array of SSH private key filenames defined as part of this
  # host.
  attr_reader :keys
  # The (optional) array of SSH private keys defined as part of this host.
  attr_reader :key_data

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
      @forward_agent = host.to_h.fetch(:forward_agent, true)

      if host.keys.kind_of?(OpenStruct)
        @key_data = host.keys.to_h.values
      elsif host.keys
        @keys = Array(host.keys).flat_map { |key|
          Pathname.glob(Pathname(key).expand_path)
        }.uniq
      end

      # If key_data or keys are empty, properly empty them so that they are
      # handled improperly.
      @key_data = nil if @key_data && @key_data.empty?
      @keys = nil if @keys && @keys.empty?

      @build = host.build
      @prebuild = host.prebuild
      @postbuild = host.postbuild
    when HOST_RE
      @user = Regexp.last_match[:user]
      @address = Regexp.last_match[:address]
      @port = Regexp.last_match[:port]
      @forward_agent = true
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
    require 'fog/core'

    if key_data
      ssh_config[:key_data] = key_data
      ssh_config[:keys] = nil
    elsif keys
      ssh_config[:key_data] = nil
      ssh_config[:keys] = keys
    end

    ssh_options = { paranoid: true, port: port, forward_agent: !!forward_agent }.
      merge(ssh_config).
      delete_if { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }

    scp_options = { paranoid: true, port: port }.
      merge(ssh_config).
      delete_if { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }

    @ssh = Fog::SSH.new(address, user, ssh_options)
    @scp = Fog::SCP.new(address, user, scp_options)
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
      port: port,
      forward_agent: forward_agent
    }.delete_if { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
  end

  alias to_h to_hash
end
