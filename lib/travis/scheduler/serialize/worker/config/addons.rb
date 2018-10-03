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
              sonarqube
              ssh_known_hosts
            )

            JWT_AWARE = %i(
              sauce_connect
            )

            JWT_ENV_CHECKS = {
              sauce_connect: {
                'SAUCE_ACCESS_KEY' => 20
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

              config.reject! do |k, v|
                jwt_aware?(k) && config[k].key?(:jwt) && JWT_ENV_CHECKS[k].any? do |env_var, minimum|
                  val = config[k][:jwt]
                  val.gsub(/\A#{env_var}=/, '').length <= minimum
                end
              end

              jwt_config = Array(config.delete(:jwt))

              return config if jwt_config.empty?

              config[:jwt] = jwt_config.select do |decrypted_jwt_data|
                return unless decrypted_jwt_data.respond_to?(:split)
                env_var_name, env_var_value = decrypted_jwt_data.split('=', 2)

                JWT_ENV_CHECKS.any? do |addon, criteria|
                  criteria.key?(env_var_name) && criteria[env_var_name] <= env_var_value.length
                end
              end

              config
            end

            private
            def filtered
              if jwt? && config.keys.any? {|key| jwt_aware?(key)}
                # jwt key is in the wrong place
                if config.key?(:sauce_connect)
                  config[:sauce_connect].merge!({ :jwt => config[:jwt] })
                end
              end
              config.map { |key, value| [key, filter(key, value)] }.to_h
            end

            def filter(name, config)
              if safe?(name) || has_jwt_under?(name)
                config
              else
                nil
              end
            end

            def safe?(name)
              SAFE.include?(name)
            end

            def jwt?
              config.keys.include?(:jwt)
            end

            def jwt_aware?(name)
              JWT_AWARE.include?(name)
            end

            def has_jwt_under?(name)
              jwt_aware?(name) && config[name].respond_to?(:keys) && config[name].keys.include?(:jwt)
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
