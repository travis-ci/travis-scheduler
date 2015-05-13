Organization.class_eval do
  has_one :subscription, as: :owner

  def subscribed?
    subscription.present? and subscription.active?
  end
end
