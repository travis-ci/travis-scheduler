# frozen_string_literal: true

class AccountEnvVars < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
end
