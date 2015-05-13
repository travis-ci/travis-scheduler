class Subscription < ActiveRecord::Base
  def active?
    cc_token? and valid_to.present? and valid_to >= Time.now.utc
  end
end
