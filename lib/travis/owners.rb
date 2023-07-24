require 'travis/owners/config'
require 'travis/owners/db'
require 'travis/owners/group'
require 'travis/owners/helper'
require 'travis/owners/record'
require 'travis/owners/subscriptions'

module Travis
  module Owners
    ArgumentError = Class.new(::ArgumentError)

    class << self
      def group(owner, config, logger = nil)
        owner = find(owner) if owner.is_a?(Hash)
        Group.new(owners(owner, config), config, logger)
      end

      def find(owner)
        raise ArgumentError, 'Invalid owner data: %p' % owner unless owner[:owner_type]

        Kernel.const_get(owner[:owner_type]).find(owner[:owner_id])
      end

      def owners(owner, config)
        owners = Config.new(owner, config).owners
        owners += Db.new(owner).owners if Database.table?('owner_groups')
        owners.uniq
      end
    end
  end
end
