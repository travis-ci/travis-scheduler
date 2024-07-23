# frozen_string_literal: true

module Travis
  module Scheduler
    module Serialize
      class Worker
        module Config
          class Decrypt < Struct.new(:config, :decryptor, :options)
            def apply
              %i[env global_env].each do |key|
                config[key] = process_env(config[key]) if config[key]
              end

              force_vault_to_be_secure!(config)
              config[:vault] = decryptor.decrypt(config[:vault]) if config[:vault]
              config[:addons] = decryptor.decrypt(config[:addons]) if config[:addons]
              config
            end

            private

            def force_vault_to_be_secure!(config)
              config[:vault].delete(:token) if config.dig(:vault, :token).is_a?(String)
            end

            def secure_env?
              !!options[:secure_env]
            end

            def process_env(env)
              env = secure_env? ? decrypt_env(env) : to_vars(remove_encrypted_env(env))
              env.compact
            end

            def remove_encrypted_env(env)
              env.reject do |var|
                var.is_a?(Hash) && var.key?(:secure)
              end
            end

            def decrypt_env(vars)
              case vars
              when Array
                vars.map { |var| decrypt_env(var) }.flatten
              when Hash
                vars.key?(:secure) ? decrypt_var(vars) : decrypt_hash(vars)
              when String
                decrypt_var(vars)
              end
            end

            def decrypt_hash(vars)
              vars.map do |key, value|
                secure = false
                value = decryptor.decrypt(value) { |value| secure = value } if decrypt?(value)
                var = "#{key}=#{value}"
                secure ? "SECURE #{var}" : var
              end
            end

            def decrypt_var(var)
              decryptor.decrypt(var) do |var|
                var.dup.insert(0, 'SECURE ') unless var.include?('SECURE ')
              end
            rescue StandardError
              {}
            end

            def decrypt?(value)
              value.is_a?(Hash) || value.is_a?(String)
            end

            def to_vars(env)
              case env
              when Array
                env.map { |var| to_vars(var) }.flatten
              when Hash
                env.map { |key, value| [key, value].join('=') }
              when String
                env
              end
            end
          end
        end
      end
    end
  end
end
