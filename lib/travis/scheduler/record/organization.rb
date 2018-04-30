class Organization < ActiveRecord::Base

  def subscription
    subs = Subscription.where(owner_id: id, owner_type: "Organization")
    @subscription ||= subs.where(status: 'subscribed').last || subs.last
  end

  def subscribed?
    subscription.present? && subscription.active?
  end

  def active_trial?
    redis.get("trial:#{login}").to_i > 0
  end

  def default_worker_timeout
    # When the organization is a paid account ("subscribed") or has an active
    #   trial, they are granted a different default timeout on their jobs.
    #
    # Note that currently (27/4/18) we are NOT providing different timeouts, but
    #   we plan to sometime in the following weeks/months.
    #
    if subscribed? || active_trial?
      120 * 60 # timeouts are in seconds
    else
      60 * 60
    end
  end

  private

  def redis
    Travis::Scheduler.context.redis
  end
end
