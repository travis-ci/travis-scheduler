require 'active_record'
require 'travis/support/encrypted_column'

class User < ActiveRecord::Base
  serialize :github_oauth_token, Travis::EncryptedColumn.new

  def subscription
    subs = Subscription.where(owner_id: id, owner_type: "User")
    @subscription ||= subs.where(status: 'subscribed').last || subs.last
  end

  def subscribed?
    subscription.present? and subscription.active?
  end
end
