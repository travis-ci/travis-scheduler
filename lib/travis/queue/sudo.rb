require 'travis/queue/linux_sudo_required'

module Travis
  class Queue
    class Sudo < Struct.new(:repo, :job_config, :config)
      def value
        return 'required' if sudo_used?
        return specified if specified?
        return 'required' if linux_sudo_required?
        default_value
      end

      private

        def default_value
          Travis::Scheduler.config.sudo.default
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

        def linux_sudo_required?
          LinuxSudoRequired.new(repo, repo.owner).apply?
        end
    end
  end
end
