require 'active_record'
require 'travis/scheduler/models/subscription'
require 'travis/scheduler/encrypted_column'

class User < ActiveRecord::Base
  has_one :subscription, as: :owner
  serialize :github_oauth_token, Travis::Scheduler::EncryptedColumn.new

  def subscribed?
    subscription.present? and subscription.active?
  end
end
