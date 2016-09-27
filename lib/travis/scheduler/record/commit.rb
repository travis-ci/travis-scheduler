class Commit < ActiveRecord::Base
  has_one :request
  belongs_to :repository
end
