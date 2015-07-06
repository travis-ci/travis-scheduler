require 'active_record'
require 'travis/scheduler/models/subscription'

class User < ActiveRecord::Base
  has_one :subscription, as: :owner

  def subscribed?
    subscription.present? and subscription.active?
  end
end
