# frozen_string_literal: true

require 'minitest_config'

describe 'Cartage::Remote::Host' do
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
  let(:host) { Cartage::Remote::Host.new(config.plugins.remote.hosts.default) }
  let(:ssh) { host.ssh }

  describe '#initialize' do
    it 'parses a string host correctly' do
      host = Cartage::Remote::Host.new(string_host)
      assert_equal 'suser', host.user
      assert_equal 'saddress', host.address
      assert_equal 'sport', host.port
      assert_nil host.build
      assert_nil host.prebuild
      assert_nil host.postbuild
      assert_nil host.keys
      assert_nil host.key_data
    end

    describe 'with a config/OpenStruct host' do
      it 'parses correctly' do
        assert_equal 'huser', host.user
        assert_equal 'haddress', host.address
        assert_equal 'hport', host.port
        assert_nil host.build
        assert_nil host.prebuild
        assert_nil host.postbuild
        assert_nil host.keys
        assert_nil host.key_data
      end

      it 'parses host script overrides correctly' do
        hash_host.update(
          build: 'hbuild',
          prebuild: 'hprebuild',
          postbuild: 'hpostbuild'
        )

        assert_equal 'hbuild', host.build
        assert_equal 'hprebuild', host.prebuild
        assert_equal 'hpostbuild', host.postbuild
      end

      it 'parses host keys overrides correctly' do
        hash_host.update(keys: '~/.ssh/id_rsa')

        stub Pathname, :glob, %w(/home/user/.ssh/id_rsa) do
          assert_equal %w(/home/user/.ssh/id_rsa), host.keys
          assert_nil host.key_data
        end
      end

      it 'parses host keys overrides correctly (removing duplicates)' do
        hash_host.update(keys: %w(~/.ssh/id_rsa) * 2)

        stub Pathname, :glob, %w(/home/user/.ssh/id_rsa) do
          assert_equal %w(/home/user/.ssh/id_rsa), host.keys
          assert_nil host.key_data
        end
      end

      it 'parses empty host keys overrides correctly (back to nil)' do
        hash_host.update(keys: [])

        stub Pathname, :glob, %w(/home/user/.ssh/id_rsa) do
          assert_nil host.keys
          assert_nil host.key_data
        end
      end

      it 'parses host key_data overrides correctly' do
        hash_host.update(
          keys: {
            custom: 'Host ASCII-Armored Private Key'
          }
        )

        assert_nil host.keys
        assert_equal [ 'Host ASCII-Armored Private Key' ], host.key_data
      end

      it 'parses empty host key_data overrides correctly (back to nil)' do
        hash_host.update(keys: {})

        assert_nil host.keys
        assert_nil host.key_data
      end
    end
  end

  describe '#configure_ssh' do
    def assert_ssh_value(expected, name)
      assert_equal expected, ssh.instance_variable_get(:"@#{name}")
    end

    def assert_ssh_option(expected, name)
      assert_equal expected, ssh.instance_variable_get(:@options)[name]
    end

    it 'configures SSH properly' do
      host.configure_ssh({})
      assert_ssh_value 'haddress', :address
      assert_ssh_value 'huser', :username
      assert_ssh_option 'hport', :port
      assert_ssh_option true, :paranoid
    end

    it 'uses the provided key_data if there is no host override' do
      host.configure_ssh(key_data: [ 'Global ASCII-Armored Private Key' ])
      assert_ssh_option [ 'Global ASCII-Armored Private Key' ], :key_data
    end

    it 'uses the provided keys if there is no host override' do
      host.configure_ssh(keys: %w(path/to/a/key/file))
      assert_ssh_option %w(path/to/a/key/file), :keys
    end

    it 'uses the host keys if present' do
      hash_host.update(keys: '~/.ssh/id_rsa')

      stub Pathname, :glob, %w(/home/user/.ssh/id_rsa) do
        host.configure_ssh(keys: [ 'path/to/a/key/file' ])
      end

      assert_ssh_option %w(/home/user/.ssh/id_rsa), :keys
    end

    it 'uses the provided keys if host keys is empty' do
      hash_host.update(keys: [])
      host.configure_ssh(keys: %w(path/to/a/key/file))
      assert_ssh_option %w(path/to/a/key/file), :keys
    end

    it 'uses the provided key_data if host key_data is empty' do
      hash_host.update(keys: {})
      host.configure_ssh(key_data: [ 'Global ASCII-Armored Private Key' ])
      assert_ssh_option [ 'Global ASCII-Armored Private Key' ], :key_data
    end
  end
end
