require 'travis/owners/config'
require 'travis/owners/db'
require 'travis/owners/group'
require 'travis/owners/helper'
require 'travis/owners/record'
require 'travis/owners/subscriptions'

module Travis
  module Owners
    class << self
      def group(owner, config)
        owner = find(owner) if owner.is_a?(Hash)
        Group.new(owners(owner, config), config)
      end

      def find(owner)
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
