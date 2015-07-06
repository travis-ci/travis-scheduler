class Job
  module Config
    class Decrypt < Struct.new(:config, :decryptor, :options)
      def apply
        [:env, :global_env].each do |key|
          config[key] = process_env(config[key]) if config[key]
        end

        config[:addons] = decryptor.decrypt(config[:addons]) if config[:addons]
        config
      end

      private

        def secure_env?
          !!options[:secure_env]
        end

        def process_env(env)
          env = secure_env? ? decrypt_env(env) : remove_encrypted_env(env)
          env.compact
        end

        def remove_encrypted_env(env)
          env.reject do |var|
            var.is_a?(Hash) && var.has_key?(:secure)
          end
        end

        def decrypt_env(env)
          env.map { |var| decrypt_var(var) }
        end

        def decrypt_var(var)
          decryptor.decrypt(var) do |var|
            var.dup.insert(0, 'SECURE ') unless var.include?('SECURE ')
          end
        rescue
          {}
        end
    end
  end
end
