User.class_eval do
  has_one :subscription, as: :owner

  after_create do
    Travis.logger.info("New user signed up: #{login}") unless Travis.env == 'test'
  end

  def subscribed?
    subscription.present? and subscription.active?
  end

  def email_addresses
    [email]
  end
end
