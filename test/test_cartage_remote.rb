# frozen_string_literal: true

require 'minitest_config'

describe 'Cartage::Remote' do
  let(:string_host) {
    'suser@saddress:sport'
  }
  let(:hash_host) {
    {
      user: 'huser',
      address: 'haddress',
      host: 'hhost',
      port: 'hport'
    }
  }

  let(:remote_config) {
    {
      hosts: {
        default: hash_host
      }
    }
  }
  let(:config_hash) {
    {
      root_path: '/a/b/c',
      name: 'test',
      timestamp: 'value',
      plugins: {
        remote: remote_config
      }
    }
  }
  let(:config) { Cartage::Config.new(config_hash) }
  let(:cartage) { Cartage.new(config) }
  let(:subject) { cartage.remote }

  def self.it_verifies_configuration(focus: false, &block)
    self.focus if focus
    it 'fails if there is no host with the given name' do
      remote_config[:host] = 'foo'
      ex = assert_raises RuntimeError do
        instance_exec(&block)
      end
      assert_equal 'No host foo present', ex.message
    end

    self.focus if focus
    it 'fails if there are no hosts present' do
      remote_config[:hosts] = {}

      ex = assert_raises ArgumentError do
        instance_exec(&block)
      end
      assert_equal 'No hosts present', ex.message
    end

    self.focus if focus
    it 'warns if a host is missing some configuration' do
      remote_config[:hosts][:foo] = {}

      error = <<-EOS
Host foo invalid: No host address present
      EOS

      assert_output nil, error do
        instance_exec(&block)
      end
    end
  end

  describe '#resolve_plugin_config!' do
    it 'errors with implicit and explicit hosts' do
      ex = assert_raises ArgumentError do
        remote_config[:server] = 'something'
        cartage
      end

      assert_match(/implicit and explicit/, ex.message)
    end

    it 'requires host address' do
      remote_config.delete(:hosts)
      remote_config[:server] = {}

      ex = assert_raises ArgumentError do
        cartage
      end

      assert_match(/no address/, ex.message)
    end

    it 'converts the implicit default into explicit' do
      remote_config.delete(:hosts)
      remote_config[:server] = hash_host

      assert_equal remote_config[:hosts], cartage.config(for_plugin: :remote).
        dig(:hosts).to_hash
    end
  end
end
