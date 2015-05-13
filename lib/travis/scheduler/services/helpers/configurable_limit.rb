require 'travis/scheduler/services/helpers/limit'
require 'travis/scheduler/models/subscription'

module Travis
  module Scheduler
    module Services
      module Helpers
        # An extension of the default limit strategy that allows for a few
        # extra things to consider when scheduling builds:
        #
        #   * Allow delegation of an account to determine the number of runnable
        #     jobs based on another account. Relevant for organizations that have
        #     multiple GitHub accounts but only want to have one subscription.
        #
        #     In the configuration, this can be set by using delegates:
        #
        #       delegate:
        #         roidrage: travis-ci
        #
        #     In this case, the build scheduling looks at the travis-ci account to
        #     determine the runnable jobs for the account roidrage.
        #
        #     The scheduler looks at all the running jobs for both accounts to
        #     determine the number of runnable job, and one subscription can have
        #     multiple delegatees.
        #
        #   * Look at an account's subscription to determine the maximum number
        #     of builds, using a default when there's no subscription or if the
        #     account is on a trial. The default should be 1 but is configurable.
        #
        # The priority of determining the build limit is based on
        #
        #   1. a direct limit specified in the configuration
        #   2. a delegate in the configuration
        #   3. the account's subscription
        #   4. the default
        #
        class ConfigurableLimit < Limit
          attr_reader :delegate, :delegatees

          def initialize(owner, jobs)
            super(owner, jobs)

            unless Travis.config.plans.present?
              Travis.logger.warn "No plans present in the config, all builds will default to #{config[:default]} concurrent jobs"
            end

            if login = config[:delegate] && config[:delegate][owner.login.to_sym]
              @delegate = find_account(login)
              @delegatees = config[:delegate].select { |delegatee, delegate| delegate == login }.map { |delegatee, delegate| find_account(delegatee) }.compact
              Travis.logger.info("Delegating #{owner.login} to #{login}")
            end
          end

          def find_account(login)
            User.find_by_login(login) || Organization.find_by_login(login)
          end

          def running
            @running ||= if delegatees
              jobs = number_of_running_delegatees_jobs
              Travis.logger.info("Delegate #{delegate.login} has #{jobs} total running jobs")
              jobs
            else
              super
            end
          end

          def max_jobs
            config[:by_owner][owner.login] ||
              max_jobs_from_container_account ||
              max_jobs_based_on_plan(owner) ||
              config[:default]
          end

          def max_jobs_based_on_plan(owner)
            if subscribed?(owner) && owner.subscription.selected_plan
              Travis.config.plans[owner.subscription.selected_plan]
            end
          end

          def max_jobs_based_on_plan(owner)
            return unless subscribed?(owner)
            plan = owner.subscription.selected_plan
            plan && Travis.config.plans.present? && Travis.config.plans[plan]
          end

          def subscribed?(owner)
            owner.subscribed? || (owner.subscription.try(:valid_to).to_i + 24.hours.to_i) > Time.now.to_i
          end

          def max_jobs_from_container_account
            if delegate
              config[:by_owner][delegate.login] || max_jobs_based_on_plan(delegate)
            end
          end

          def number_of_running_delegatees_jobs
            (delegatees + Array(delegate)).map do |account|
              Job.owned_by(account).running.count
            end.sum
          end
        end
      end
    end
  end
end
