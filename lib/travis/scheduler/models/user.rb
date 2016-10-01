require 'active_record'
require 'travis/scheduler/models/subscription'
require 'travis/scheduler/encrypted_column'

class User < ActiveRecord::Base
  has_one :subscription, as: :owner
  has_many :permissions
  serialize :github_oauth_token, Travis::Scheduler::EncryptedColumn.new

  def subscribed?
    subscription.present? and subscription.active?
  end

  class << self
    def with_permissions(permissions)
      where(:permissions => permissions).includes(:permissions)
    end

    def with_github_token
      where("github_oauth_token IS NOT NULL and github_oauth_token != ''")
    end
  end
end
