class Build < ActiveRecord::Base
  belongs_to :repository
  belongs_to :request
  belongs_to :commit
  belongs_to :owner, polymorphic: true
  has_many :jobs, as: :source

  serialize :config
end
