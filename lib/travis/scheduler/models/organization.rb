require 'active_record'

class Organization < ActiveRecord::Base
  has_one :subscription, as: :owner

  def subscribed?
    subscription.present? and subscription.active?
  end
end
