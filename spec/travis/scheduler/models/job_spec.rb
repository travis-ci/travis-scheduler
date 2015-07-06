require 'spec_helper'

describe Job do
  describe 'decrypted config' do
    it 'handles nil env' do
      job = Job.new(repository: Factory(:repository))
      job.config = { rvm: '1.8.7', env: nil, global_env: nil }

      job.decrypted_config.should == {
        rvm: '1.8.7',
        env: nil,
        global_env: nil
      }
    end

    it 'normalizes env vars which are hashes to strings' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)

      config = { rvm: '1.8.7',
                 env: [{FOO: 'bar', BAR: 'baz'},
                          job.repository.key.secure.encrypt('BAR=barbaz')],
                 global_env: [{FOO: 'foo', BAR: 'bar'},
                          job.repository.key.secure.encrypt('BAZ=baz')]
               }
      job.config = config

      job.decrypted_config.should == {
        rvm: '1.8.7',
        env: ["FOO=bar BAR=baz", "SECURE BAR=barbaz"],
        global_env: ["FOO=foo BAR=bar", "SECURE BAZ=baz"]
      }
    end

    it 'does not change original config' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).at_least_once.returns(true)

      config = {
                 env: [{secure: 'invalid'}],
                 global_env: [{secure: 'invalid'}]
               }
      job.config = config

      job.decrypted_config
      job.config.should == {
        env: [{ secure: 'invalid' }],
        global_env: [{ secure: 'invalid' }]
      }
    end

    it 'leaves regular vars untouched' do
      job = Job.new(repository: Factory(:repository))
      job.expects(:secure_env_enabled?).returns(true).at_least_once
      job.config = { rvm: '1.8.7', env: 'FOO=foo', global_env: 'BAR=bar' }

      job.decrypted_config.should == {
        rvm: '1.8.7',
        env: ['FOO=foo'],
        global_env: ['BAR=bar']
      }
    end

    context 'when secure env is not enabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:secure_env_enabled?).returns(false).at_least_once
        job
      end

      it 'removes secure env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'FOO=foo'],
                   global_env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'BAR=bar']
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          env: ['FOO=foo'],
          global_env: ['BAR=bar']
        }
      end

      it 'removes only secured env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=barbaz'), 'FOO=foo']
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          env: ['FOO=foo']
        }
      end
    end

    context 'when addons are disabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:addons_enabled?).returns(false).at_least_once
        job
      end

      it 'removes addons if it is not a hash' do
        config = { rvm: '1.8.7',
                   addons: []
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7'
        }
      end

      it 'removes addons items which are not whitelisted' do
        config = { rvm: '1.8.7',
                   addons: {
                     sauce_connect: {
                       username: 'johndoe',
                       access_key: job.repository.key.secure.encrypt('foobar')
                     },
                     firefox: '22.0',
                     postgresql: '9.3',
                     hosts: %w(travis.dev),
                     apt_packages: %w(curl git),
                     apt_sources: %w(deadsnakes)
                   }
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          addons: {
            firefox: '22.0',
            postgresql: '9.3',
            hosts: %w(travis.dev),
            apt_packages: %w(curl git),
            apt_sources: %w(deadsnakes)
          }
        }
      end
    end

    context 'when job has secure env enabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:secure_env_enabled?).returns(true).at_least_once
        job
      end

      it 'decrypts env vars' do
        config = { rvm: '1.8.7',
                   env: job.repository.key.secure.encrypt('BAR=barbaz'),
                   global_env: job.repository.key.secure.encrypt('BAR=bazbar')
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          env: ['SECURE BAR=barbaz'],
          global_env: ['SECURE BAR=bazbar']
        }
      end

      it 'decrypts only secure env vars' do
        config = { rvm: '1.8.7',
                   env: [job.repository.key.secure.encrypt('BAR=bar'), 'FOO=foo'],
                   global_env: [job.repository.key.secure.encrypt('BAZ=baz'), 'QUX=qux']
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          env: ['SECURE BAR=bar', 'FOO=foo'],
          global_env: ['SECURE BAZ=baz', 'QUX=qux']
        }
      end
    end

    context 'when job has addons enabled' do
      let :job do
        job = Job.new(repository: Factory(:repository))
        job.expects(:addons_enabled?).returns(true).at_least_once
        job
      end

      it 'decrypts addons config' do
        config = { rvm: '1.8.7',
                   addons: {
                     sauce_connect: {
                       username: 'johndoe',
                       access_key: job.repository.key.secure.encrypt('foobar')
                     }
                   }
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          addons: {
            sauce_connect: {
              username: 'johndoe',
              access_key: 'foobar'
            }
          }
        }
      end

      it 'decrypts deploy addon config' do
        config = { rvm: '1.8.7',
                   deploy: { foo: job.repository.key.secure.encrypt('foobar') }
                 }
        job.config = config

        job.decrypted_config.should == {
          rvm: '1.8.7',
          addons: {
            deploy: { foo: 'foobar' }
          }
        }
      end
    end
  end
end
