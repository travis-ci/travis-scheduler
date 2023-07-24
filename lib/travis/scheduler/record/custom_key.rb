# frozen_string_literal: true

require 'travis/support/encrypted_column'
require 'travis/support/secure_config'

class CustomKey < ActiveRecord::Base
  serialize :private_key, Travis::EncryptedColumn.new
  belongs_to :owner, polymorphic: true
end
