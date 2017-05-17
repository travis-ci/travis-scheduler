class Organization < ActiveRecord::Base

  def subscription
    subs = Subscription.where(owner_id: id, owner_type: "Organization")
    @subscription ||= subs.where(status: 'subscribed').last || subs.last
  end

  def subscribed?
    subscription.present? and subscription.active?
  end
end
