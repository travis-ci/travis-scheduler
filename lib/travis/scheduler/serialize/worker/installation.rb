# frozen_string_literal: true

class Installation < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
end
