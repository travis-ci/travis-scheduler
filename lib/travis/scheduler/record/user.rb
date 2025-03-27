# frozen_string_literal: true

require 'active_record'
require 'travis/support/encrypted_column'

class User < ActiveRecord::Base
  has_one :trial, as: :owner

  serialize :github_oauth_token, Travis::EncryptedColumn.new

  # These default timeouts, for Users and Organzations, are for limiting workers
  #   from living forever, and should not be adjusted without checking with
  #   builders on the infrastructure or reliability teams. Changing them will
  #   impact our resource usage as well as our ability to rollout new workers.
  #
  # Note: timeout values are in seconds
  #
  DEFAULT_SUBSCRIBED_TIMEOUT = 120 * 60
  DEFAULT_SPONSORED_TIMEOUT  = 50 * 60
  DEFAULT_TRIAL_TIMEOUT = 30 * 60

  def subscription
    subs = Subscription.where(owner_id: id, owner_type: 'User')
    @subscription ||= subs.where(status: 'subscribed').last || subs.last
  end

  def subscribed?
    subscription.present? && subscription.active?
  end

  def active_trial?
    redis.get("trial:#{login}").to_i > 0
  end

  def educational?
    !!education
  end

  def paid?
    subscribed? || active_trial? || paid_new_plan?
  end

  def paid_new_plan?
    redis_key = "user:#{self.id}:plan"
    plan = if redis.exists?(redis_key)
             JSON.parse(redis.get(redis_key))
           else
             billing_plan
           end
    return false if plan[:error] || plan['plan_name'].nil?

    plan['hybrid'] || !plan['plan_name'].include?('free')
  end

  def v2trial?
    !billing_plan['current_trial'].nil?
  end

  def trial_timeout
    @trial_timeout ||= (billing_plan['current_trial'].nil? || !billing_plan['current_trial'].include?('build_timeout')) ? DEFAULT_TRIAL_TIMEOUT : billing_plan['current_trial']['build_timeout']
  end

  def enterprise?
    !!context.config[:enterprise]
  end

  def default_worker_timeout
    # When the user is a paid user ("subscribed") or has an active trial, they
    #   are granted a different default timeout on their jobs.
    #
    # Note that currently (27/4/18) we are NOT providing timeouts different from
    #   those enforced by workers themselves, but we plan to sometime in the
    #   following weeks/months.
    #
    if enterprise? || educational?
        Travis.logger.info "Default Timeout: DEFAULT_SUBSCRIBED_TIMEOUT for owner=#{id}"
        DEFAULT_SUBSCRIBED_TIMEOUT
    elsif paid?
      if v2trial?
        Travis.logger.info "Default Timeout: TRIAL_TIMEOUT #{trial_timeout} for owner=#{id}"
        trial_timeout
      else
        Travis.logger.info "Default Timeout: DEFAULT_SUBSCRIBED_TIMEOUT for owner=#{id}"
        DEFAULT_SUBSCRIBED_TIMEOUT
      end
    else
      Travis.logger.info "Default Timeout: DEFAULT_SPONSORED_TIMEOUT for owner=#{id}"
      DEFAULT_SPONSORED_TIMEOUT
    end
  end

  def billing_plan
    @billing_plan ||= billing_client.get_plan(self)&.to_h
  end


  def preferences
    super || {}
  end

  def keep_netrc?
    preferences.key?('keep_netrc') ? preferences['keep_netrc'] : !(ENV['DELETE_NETRC'] == "true") 
  end

  def uid
    "user:#{id}"
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
