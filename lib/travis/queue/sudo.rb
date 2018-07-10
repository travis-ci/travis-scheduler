require 'travis/queue/force_linux_sudo_required'
require 'travis/queue/force_precise_sudo_required'

module Travis
  class Queue
    class Sudo < Struct.new(:repo, :job_config, :config)
      def value
        return 'required' if force_linux_sudo_required?
        return 'required' if force_precise_sudo_required?
        return 'required' if sudo_used?
        return specified if specified?
        default
      end

      private

        def default
          return false if repo_created_after_cutoff?
          'required'
        end

        def specified
          {
            nil => false,
            true => 'required',
          }.fetch(job_config[:sudo], job_config[:sudo])
        end

        def specified?
          job_config.key?(:sudo)
        end

        def sudo_used?
          SudoDetector.new(job_config).detect?
        end

        def repo_created_after_cutoff?
          repo.created_at > docker_default_cutoff
        end

        def docker_default_cutoff
          date = config[:docker_default_queue_cutoff]
          date ? Time.parse(date) : Time.now.utc
        end

        def force_linux_sudo_required?
          ForceLinuxSudoRequired.new(repo.owner).apply?
        end

        def force_precise_sudo_required?
          ForcePreciseSudoRequired.new(repo, job_config[:dist]).apply?
        end
    end
  end
end
