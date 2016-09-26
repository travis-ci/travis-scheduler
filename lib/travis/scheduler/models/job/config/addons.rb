class Job
  module Config
    class Addons < Struct.new(:config)
      SAFE = %i(
        apt
        apt_packages
        apt_sources
        browserstack
        firefox
        hostname
        hosts
        jwt
        mariadb
        postgresql
        rethinkdb
        ssh_known_hosts
      )

      JWT_AWARE = %i(
        sauce_connect
      )

      def apply
        config = compact(filtered)
        config unless config.empty?
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
