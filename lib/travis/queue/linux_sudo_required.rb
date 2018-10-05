module Travis
  class Queue
    class LinuxSudoRequired < Struct.new(:repo, :owner)
      def apply?
        return false if Travis::Features.disabled_for_all?(:linux_sudo_required)
        return true if Travis::Features.enabled_for_all?(:linux_sudo_required)

        decision = decide_linux_sudo_required
        if decision[:chosen?]
          Travis::Scheduler.logger.info(
            "selected sudo: required why=#{decision[:reason]} slug=#{repo.slug}"
          )
          Travis::Features.activate_repository(:linux_sudo_required, repo) if decision[:set_active?]
        end
        
        decision[:chosen?]
      end

      private

        def decide_linux_sudo_required
          return { chosen?: true, reason: :repo_active, set_active?: false } if Travis::Features.active?(:linux_sudo_required, repo)
          return { chosen?: true, reason: :owner_active, set_active?: false } if Travis::Features.owner_active?(:linux_sudo_required, owner)
          return { chosen?: true, reason: :first_job , set_active?: true } if first_job?
          {
            chosen?: rand <= rollout_linux_sudo_required_percentage,
            reason: :random,
            set_active?: true
          }
        end

        def rollout_linux_sudo_required_percentage
          Float(
            Travis::Scheduler.config.rollout.linux_sudo_required_percentage
          )
        end

        def first_job?
          return @first_job if defined?(@first_job)
          @first_job = begin
            first_job_id.nil?
          rescue => e
            Travis::Scheduler.logger.warn(
              "failed to fetch first job for repository=#{repo.slug}"
            )
            false
          end
        end

        def first_job_id
          Job.where(
            owner_id: repo.owner.id,
            owner_type: repo.owner.class.name,
            state: 'passed',
            repository_id: repo.id
          ).select(:id).limit(1).first
        end
    end
  end
end
