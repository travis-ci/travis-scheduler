class Trial < ActiveRecord::Base
  belongs_to :owner, polymorphic: true

  ACTIVE = %w[new started]

  def active?
    ACTIVE.include?(status)
  end
end
