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
              hostname
              hosts
              mariadb
              postgresql
              rethinkdb
              sonarqube
              ssh_known_hosts
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
