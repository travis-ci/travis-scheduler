require 'travis/conditions'

module Travis
  module Scheduler
    class Condition
      attr_reader :cond, :job, :conf, :data

      def initialize(cond, job)
        @cond = cond.is_a?(Array) || cond.is_a?(Hash) || cond.nil? ? cond : cond.to_s
        @conf = job.config
        @data = Data.new(job, conf).to_h
      end

      def applies?
        return true if cond.nil?
        version = conf[:conditions].to_s == 'v0' ? :v0 : :v1
        Travis::Conditions.eval(cond, data, version: version)
      rescue Travis::Conditions::Error, ArgumentError, RegexpError, TypeError => e
        Gatekeeper.logger.error "Unable to process condition: #{cond.inspect}. (#{e.message})"
        # the old implentation returned `true` on parse errors, unfortunately
        return true if version == :v0
        raise BadCondition, e.message
      end

      def to_s
        "IF #{cond}"
      end

      class Data < Struct.new(:job, :conf)
        def to_h
          {
            type: event,
            repo: repo.slug,
            head_repo: head_repo,
            os: os,
            dist: dist,
            group: group,
            sudo: sudo.to_s, # this can be a boolean once we're on v1
            language: language,
            sender: sender,
            fork: fork?.to_s,
            branch: branch,
            head_branch: head_branch,
            tag: tag,
            commit_message: commit_message,
            env: env
          }
        end

        def repo
          job.repository
        end

        def request
          job.source.request
        end

        def event
          request.event_type.to_s
        end

        def head_repo
          pull_request&.head_repo_slug
        end

        def os
          conf[:os]
        end

        def dist
          conf[:dist]
        end

        def group
          conf[:group]
        end

        def sudo
          conf[:sudo]
        end

        def language
          conf[:language]
        end

        def commit_message
          commit&.message
        end

        def fork?
          pull_request ? repo.slug != pull_request.head_repo_slug : repo.fork?
        end

        def branch
          commit.branch
        end

        def head_branch
          pull_request&.head_ref
        end

        def tag
          commit.tag && commit.tag.name
        end

        def sender
          request.sender&.login
        end

        def pull_request
          request.pull_request
        end

        def commit
          job.commit
        end

        def env
          env = conf[:env] || {}
          env = env[:global] if global?(env)
          env = to_strings(env)
          env = settings_env + global_env + env
          env.compact.flatten
        end

        def global_env
          Array(to_strings(conf[:global_env]))
        end

        def settings_env
          repo.settings.env_vars.map { |v| "#{v.name}=#{v.value.decrypt}" }
        end

        def to_strings(env)
          return Array(env) unless env.is_a?(Hash)
          env.map { |key, value| [key, value].join('=') }
        end

        def global?(env)
          env.is_a?(Hash) && [Hash, Array].include?(env[:global].class)
        end

        def conf
          @conf ||= super || {}
        end

        def compact(hash)
          hash.reject { |_, value| value.nil? }.to_h
        end
      end
    end
  end
end
