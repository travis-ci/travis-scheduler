# frozen_string_literal: true

class Subscription < ActiveRecord::Base
  belongs_to :owner, polymorphic: true

  def active?
    valid_to && valid_to + 24 * 60 * 60 >= Time.now.utc
  end
end
