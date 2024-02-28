# frozen_string_literal: true

class Trial < ActiveRecord::Base
  belongs_to :owner, polymorphic: true

  ACTIVE = %w[new started].freeze

  def active?
    ACTIVE.include?(status)
  end
end
