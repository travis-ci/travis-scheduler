# frozen_string_literal: true

class Build < ActiveRecord::Base
  belongs_to :repository
  belongs_to :request
  belongs_to :commit
  belongs_to :owner, polymorphic: true
  has_many :jobs, as: :source

  serialize :config

  def canceled?
    state&.to_sym == :canceled
  end
end
