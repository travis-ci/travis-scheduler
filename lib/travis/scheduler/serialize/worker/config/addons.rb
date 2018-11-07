module Travis
  module Scheduler
    module Serialize
      class Worker
        module Config
          class Addons < Struct.new(:config)
            SAFE = %i(
              apt
              apt_packages
              apt_sources
              browserstack
              chrome
              firefox
              homebrew
              hostname
              hosts
              jwt
              mariadb
              postgresql
              rethinkdb
              snaps
              sonarqube
              ssh_known_hosts
            )

            JWT_AWARE = %i(
              sauce_connect
            )

            JWT_ENV_CHECKS = {
              sauce_connect: {
                'SAUCE_ACCESS_KEY' => {
                  minimum_length: 20
                }
              }
            }

            def apply
              config = compact(filtered)
              config unless config.empty?
            end

            def jwt_sanitize
              # this method would be called once we have filtered the safelisted and jwt_aware addons,
              # and the values have been decrypted we would have something like passed on to this method:
              #
              # {:sauce_connect=>{:username=>"sauce_connect_user"}, :jwt=>"SAUCE_ACCESS_KEY=foo1123456789012345657889"}
              #
              # and we want to drop the values of the :jwt addon that does not meet the criteria
              # set forth by JWT_ENV_CHECKS

              jwt_config = Array(config.delete(:jwt))

              return config if jwt_config.empty?

              config[:jwt] = jwt_config.select do |decrypted_jwt_data|
                return unless decrypted_jwt_data.respond_to?(:split)
                env_var_name, env_var_value = decrypted_jwt_data.split('=', 2)

                JWT_ENV_CHECKS.any? do |addon, criteria|
                  criteria.key?(env_var_name) && criteria[env_var_name][:minimum_length] <= env_var_value.length
                end
              end

              config
            end

            private
            def filtered
              config.map { |key, value| [key, filter(key, value)] }.to_h
            end

            def filter(name, config)
              if safe?(name)
                config
              elsif jwt? && jwt_aware?(name)
                strip_encrypted(config)
              else
                nil
              end
            end

            def strip_encrypted(config)
              case config
              when Hash
                compact(config.map { |key, value| [key, encrypted?(value) ? nil : value] }).to_h
              when Array
                config.map { |config| strip_encrypted(config) }
              else
                config
              end
            end

            def safe?(name)
              SAFE.include?(name.to_sym)
            end

            def jwt?
              config.keys.include?(:jwt)
            end

            def jwt_aware?(name)
              JWT_AWARE.include?(name.to_sym)
            end

            def encrypted?(value)
              value.is_a?(Hash) && value.keys.any? { |key| key == :secure }
            end

            def compact(hash)
              hash.reject { |_, value| value.nil? }
            end
          end
        end
      end
    end
  end
end
