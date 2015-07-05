require 'active_record'

class User < ActiveRecord::Base
  has_one :subscription, as: :owner

  def subscribed?
    subscription.present? and subscription.active?
  end
end
