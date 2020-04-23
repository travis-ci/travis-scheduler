class Commit < ActiveRecord::Base
  has_one :request
  belongs_to :repository
  belongs_to :tag
end
