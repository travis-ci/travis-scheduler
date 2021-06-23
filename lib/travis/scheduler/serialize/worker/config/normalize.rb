module Travis
  module Scheduler
    module Serialize
      class Worker
        module Config
          class Normalize
            SAFE_ADDONS = %w(
              apt
              apt_packages
              apt_sources
              browserstack
              chrome
              firefox
              hostname
              hosts
              jwt
              mariadb
              postgresql
              rethinkdb
              snaps
              ssh_known_hosts
            ).freeze

            attr_reader :config, :options

            def initialize(config, options)
              @config  = config ? config.deep_symbolize_keys : {}
              @options = options
            end

            def apply
              normalize_envs
              normalize_deploy if config[:deploy]
              normalize_addons
              filter_addons    if config[:addons] && !full_addons?
              compact(config)
            end

            def jwt_sanitize
              if config && config.fetch(:addons,{}).key?(:jwt)
                config[:addons] = Addons.new(config[:addons]).jwt_sanitize
              end
              config
            end

            def env_sanitize
              [:env, :global_env].each do |key|
                case config[key]
                when Hash
                when Array
                  config[key] = config[key].map do |val|
                    quotize_env(val)
                  end
                else
                  config[key] = quotize_env(config[key]) unless config[key].nil?
                end
              end

              config
            end

            private

              def full_addons?
                !!options[:full_addons]
              end

              def normalize_envs
                [:env, :global_env].each do |key|
                  config[key] = normalize_env(config[key]) if config[key]
                end
              end

              def normalize_envs
                envs = [:env, :global_env].select { |key| config[key] }
                envs.each { |key| config[key] = normalize_env(config[key]) }
              end

              def normalize_env(env)
                [env].flatten.compact
              end

              def normalize_deploy
                config[:addons] ||= {}
                config[:addons][:deploy] = config.delete(:deploy)
              end

              def normalize_addons
                config.delete(:addons) unless config[:addons].is_a?(Hash)
              end

              def filter_addons
                config[:addons] = Addons.new(config[:addons]).apply
              end

              def compact(hash)
                hash.reject { |_, value| value.nil? }
              end

              def quotize_env(val)
                if val.include?('=')
                  var = val.split('=').first
                  value = val.split('=', 2).last
                else
                  var = ''
                  value = val
                end

                if (value[0] == '"' && value[-1] == '"') || (value[0] == "'" && value[-1] == "'")
                  "#{var}#{var.empty? ? '' : '='}#{value}"
                else
                  "#{var}#{var.empty? ? '' : '='}'#{value.gsub("'", "\\\\'")}'"
                end
              end
          end
        end
      end
    end
  end
end
