class Organization < ActiveRecord::Base
  has_one :trial, as: :owner

  # These default timeouts, for Users and Organzations, are for limiting workers
  #   from living forever, and should not be adjusted without checking with
  #   builders on the infrastructure or reliability teams. Changing them will
  #   impact our resource usage as well as our ability to rollout new workers.
  #
  # Note: timeout values are in seconds
  #
  DEFAULT_SUBSCRIBED_TIMEOUT = 120 * 60
  DEFAULT_SPONSORED_TIMEOUT  = 50 * 60

  def subscription
    subs = Subscription.where(owner_id: id, owner_type: 'Organization')
    @subscription ||= subs.where(status: 'subscribed').last || subs.last
  end

  def subscribed?
    subscription.present? && subscription.active?
  end

  def educational?
    !!Travis::Features.owner_active?(:educational_org, self)
  end

  def paid?
    subscribed? || active_trial? || paid_new_plan?
  end

  def active_trial?
    redis.get("trial:#{login}").to_i > 0
  end

  def paid_new_plan?
    redis_key = "organization:#{id}:plan"
    plan = if redis.exists?(redis_key)
             JSON.parse(redis.get(redis_key))
           else
             billing_client.get_plan(self).to_h
           end
    return false if plan[:error] || plan['plan_name'].nil?

    plan['hybrid'] || !plan['plan_name'].include?('free')
  end

  def default_worker_timeout
    # When the user is a paid user ("subscribed") or has an active trial, they
    #   are granted a different default timeout on their jobs.
    #
    # Note that currently (27/4/18) we are NOT providing timeouts different from
    #   those enforced by workers themselves, but we plan to sometime in the
    #   following weeks/months.
    #
    if paid? || educational?
      Travis.logger.info "Default Timeout: DEFAULT_SUBSCRIBED_TIMEOUT for owner=#{id}"
      DEFAULT_SUBSCRIBED_TIMEOUT
    else
      Travis.logger.info "Default Timeout: DEFAULT_SPONSORED_TIMEOUT for owner=#{id}"
      DEFAULT_SPONSORED_TIMEOUT
    end
  end

  def preferences
    super || {}
  end

  def keep_netrc?
    preferences.key?('keep_netrc') ? preferences['keep_netrc'] : true
  end

  def uid
    "org:#{id}"
  end

  private

  def redis
    Travis::Scheduler.context.redis
  end

  def billing_client
    @billing_client ||= Travis::Scheduler::Billing::Client.new(context)
  end

  def context
    Travis::Scheduler.context
  end
end
