require 'active_record'
require 'travis/support/encrypted_column'

class User < ActiveRecord::Base
  has_one :subscription, as: :owner
  serialize :github_oauth_token, Travis::EncryptedColumn.new

  def subscribed?
    subscription.present? and subscription.active?
  end
end
