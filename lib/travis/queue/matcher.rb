module Travis
  class Queue
    class Matcher < Struct.new(:job, :config, :logger)
      KEYS = %i(slug owner os language sudo dist group osx_image percentage
        addons services)

      MSGS = {
        unknown_matchers: 'unknown matchers used for queue %s: %s (repo=%s)"'
      }

      def matches?(attrs)
        check_unknown_matchers(attrs.keys)
        matchers_for(attrs).all? { |key, value| value === attrs[key] }
      end

      private

        def matchers_for(attrs)
          (KEYS & attrs.keys).map { |key| [key, send(key)] }.to_h
        end

        def slug
          repo.slug
        end

        def owner
          repo.owner_name
        end

        def os
          job.config[:os]
        end

        def language
          Array(job.config[:language]).flatten.compact.first
        end

        def sudo
          Sudo.new(repo, job.config, config).value
        end

        def dist
          job.config[:dist]
        end

        def group
          job.config[:group]
        end

        def osx_image
          job.config[:osx_image]
        end

        def percentage
          ->(percent) { rand(100) < percent }
        end

        def addons
          ->(addons) { Array(job.config[:addons] && job.config[:addons].keys.map(&:to_s) & addons).any? }
        end

        def services
          ->(services) { (Array(job.config[:services]) & services).any? }
        end

        def repo
          job.repository
        end

        def check_unknown_matchers(used)
          unknown = used - KEYS
          logger.warn MSGS[:unknown_matchers] % [used.join(', '), unknown, repo.slug] if logger && unknown.any?
        end
    end
  end
end
