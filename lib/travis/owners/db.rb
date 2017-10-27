require 'active_record'

module Travis
  module Owners
    class Db < Struct.new(:owner)
      SQL = 'uuid IN (SELECT uuid FROM owner_groups WHERE owner_type = ? AND owner_id = ?)'

      def owners
        attrs.any? ? attrs.map { |(type, id)| find(type, id) } : [owner]
      end

      def uuid
        OwnerGroup.where(owner: owner).pluck(:uuid).first
      end

      private

        def find(type, id)
          Kernel.const_get(type).find(id)
        end

        def attrs
          @attrs ||= OwnerGroup.where(SQL, type, id).pluck(:owner_type, :owner_id)
        end

        def type
          owner.class.name
        end

        def id
          owner.id
        end
    end
  end
end
