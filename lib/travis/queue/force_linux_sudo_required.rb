module Travis
  class Queue
    class ForceLinuxSudoRequired < Struct.new(:repo, :owner)
      def apply?
        return false if Travis::Features.disabled_for_all?(:force_linux_sudo_required)
        return true if Travis::Features.enabled_for_all?(:force_linux_sudo_required) ||
                       Travis::Features.active?(:force_linux_sudo_required, repo) ||
                       Travis::Features.owner_active?(:force_linux_sudo_required, owner)
        decision = decide_force_linux_sudo_required
        if decision[:chosen?]
          Travis::Scheduler.logger.info(
            "forced sudo: required why=#{decision[:reason]} slug=#{repo.slug}"
          )
          Travis::Features.activate_repository(:force_linux_sudo_required, repo)
        end
        Travis::Features.active?(:force_linux_sudo_required, repo)
      end

      private

        def decide_force_linux_sudo_required
          return { chosen?: true, reason: :first_job } if first_job?
          {
            chosen?: rand <= rollout_force_linux_sudo_required_percentage,
            reason: :random
          }
        end

        def rollout_force_linux_sudo_required_percentage
          Float(
            Travis::Scheduler.config.rollout.force_linux_sudo_required_percentage
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
