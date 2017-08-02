module Travis
  module Owners
    module Cli
      class Ungroup < Cl::Cmd

        register 'owners:ungroup'

        purpose 'Remove the owner group the given owner belongs to entirely'

        args :owner

        MSGS = {
          count:   'You need to pass exactly 1 owner.',
          missing: 'Cannot find owner(s): %s.',
          grouped: 'The given owner is not in an owner group: %s.',
          confirm: 'This will ungroup all of the following owners: %s. Confirm? [y/n]',
          done:    'Done. These owners are now ungrouped.'
        }

        def run
          validate
          confirm
          ungroup
        end

        private

          def validate
            abort MSGS[:count] if logins.size != 1
            abort MSGS[:missing] % logins.join(', ') unless owner
            abort MSGS[:grouped] % owner.login unless owner.owner_group
          end

          def confirm
            puts MSGS[:confirm] % owners.map(&:login).join(', ')
            input = STDIN.gets.chomp.downcase
            abort 'Aborting.' unless input == 'y'
          end

          def ungroup
            groups.delete_all
            puts MSGS[:done]
          end

          def owners
            groups.map(&:owner)
          end

          def groups
            @groups ||= OwnerGroup.where(uuid: uuid)
          end

          def uuid
            owner.owner_group.uuid
          end

          def owner
            @owner_ ||= find_owners(logins).first
          end

          def logins
            args
          end

          def find_owners(logins)
            User.where(login: logins) + Organization.where(login: logins)
          end
      end
    end
  end
end
