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
      port: 'hport',
      forward_agent: true
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
  let(:hashify) { config.method(:hashify) }

  it 'fails if there is no host with the given name' do
    remote_config[:host] = 'foo'
    ex = assert_raises RuntimeError do
      cartage.remote.check_config(require_host: true)
    end
    assert_equal 'No host foo present', ex.message
  end

  it 'fails if there are no hosts present' do
    remote_config[:hosts] = {}

    ex = assert_raises ArgumentError do
      cartage.remote.check_config(require_host: true)
    end
    assert_equal 'No hosts present', ex.message
  end

  it 'warns if a host is missing some configuration' do
    remote_config[:hosts][:foo] = {}
    messages = []
    cartage.remote.check_config(require_host: true, &->message { messages << message })
    assert_equal ['Host foo invalid: No host address present'], messages
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
      expected = hashify.(remote_config.delete(:hosts))
      remote_config[:server] = hash_host

      actual = hashify.(cartage.config(for_plugin: :remote).dig(:hosts))

      assert_equal expected, actual
    end

    it 'sets forward_agent to true if missing' do
      expected = hashify.(remote_config.dig(:hosts, :default))
      remote_config.dig(:hosts, :default).delete(:forward_agent)
      actual = hashify.(cartage.config(for_plugin: :remote).dig(:hosts, :default))
      assert_equal expected, actual
    end

    it 'keeps forward_agent as false if specified' do
      hash_host[:forward_agent] = false
      expected = hashify.(remote_config.dig(:hosts, :default))
      actual = hashify.(cartage.config(for_plugin: :remote).dig(:hosts, :default))
      assert_equal expected, actual
    end
  end
end
