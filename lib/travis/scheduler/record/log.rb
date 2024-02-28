# frozen_string_literal: true

class Log < ActiveRecord::Base
  belongs_to :job
end
