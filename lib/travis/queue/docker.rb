require 'travis/queue/force_precise_sudo_required'

module Travis
  class Queue
    class Docker < Struct.new(:repo, :job, :config)
      def apply?
        return 'required' if force_precise_sudo_required?
        return specified if specified?
        default
      end

      private

        def default
          not sudo_used? and repo_created_after_cuttoff?
        end

        def specified?
          job.key?(:sudo)
        end

        def specified
          not job[:sudo]
        end

        def sudo_used?
          Sudo.new(job).detect?
        end

        def repo_created_after_cuttoff?
          repo.created_at > docker_default_cutoff
        end

        def docker_default_cutoff
          date = config[:docker_default_queue_cutoff]
          date ? Time.parse(date) : Time.now.utc
        end

        def owner
          repo.owner
        end

        def force_precise_sudo_required?
          ForcePreciseSudoRequired.new(repo, job[:dist]).apply?
        end
    end
  end
end
