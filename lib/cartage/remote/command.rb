require 'cartage/command'

class Cartage::Remote::Command < Cartage::Command #:nodoc:
  def initialize(cartage)
    super(cartage, 'remote')
    takes_commands(false)
    short_desc('Build a release package and upload to cloud storage.')

    @cartage = cartage
    @remote = cartage.remote

    Cartage.common_build_options(options, cartage)
  end

  def perform(*)
    @remote.build
  end

  def with_plugins
    %w(remote)
  end
end
