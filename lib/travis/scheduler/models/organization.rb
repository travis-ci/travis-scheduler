require 'active_record'

class Organization < ActiveRecord::Base
  # has_many :memberships
  # has_many :users, :through => :memberships
  # has_many :repositories, :as => :owner
  has_one :subscription, as: :owner

  def subscribed?
    subscription.present? and subscription.active?
  end

  # def education?
  #   Travis::Features.owner_active?(:educational_org, self)
  # end
  # alias education education?
end
