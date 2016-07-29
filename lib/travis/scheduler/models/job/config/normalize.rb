class Job
  module Config
    class Normalize
      WHITELISTED_ADDONS = %w(
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
          [env].flatten.map do |line|
            if line.is_a?(Hash) && !line.has_key?(:secure)
              line.map { |k, v| "#{k}=#{v}" }.join(' ')
            else
              line
            end
          end
        end

        def normalize_deploy
          config[:addons] ||= {}
          config[:addons][:deploy] = config.delete(:deploy)
        end

        def normalize_addons
          config.delete(:addons) unless config[:addons].is_a?(Hash)
        end

        def filter_addons
          config[:addons].keep_if { |key, _| WHITELISTED_ADDONS.include? key.to_s }
          config.delete(:addons) if config[:addons].empty?
        end
    end
  end
end
