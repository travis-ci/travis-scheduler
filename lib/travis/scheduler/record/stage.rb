class Stage < ActiveRecord::Base
  belongs_to :build
  has_many :jobs
end
