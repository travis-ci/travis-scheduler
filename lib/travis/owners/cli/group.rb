module Travis
  module Owners
    module Cli
      class Group < Struct.new(:args, :opts)
        include Cl::Cmd

        register 'owners:group'

        purpose 'Group owners into a new owner group'

        args :owners

        MSGS = {
          count:   'You need to pass at least 2 owner logins.',
          grouped: 'The following owners already are in an owner group: %s. Please use the `owners add` command.',
          confirm: 'This will group the following owners: %s. Confirm? [y/n]',
          done:    'Done. These owners are now grouped.'
        }

        def run
          validate
          confirm
          create
        end

        private

          def validate
            abort MSGS[:count] if owners.size < 2
            logins = owners.select(&:owner_group).map(&:login)
            abort MSGS[:grouped] % logins.join(', ') if logins.any?
          end

          def confirm
            puts MSGS[:confirm] % owners.map(&:login).join(', ')
            input = STDIN.gets.chomp.downcase
            abort 'Aborting.' unless input == 'y'
          end

          def create
            owners.each { |owner| OwnerGroup.create!(uuid: uuid, owner: owner) }
            puts MSGS[:done]
          end

          def uuid
            @uuid ||= SecureRandom.uuid
          end

          def owners
            @owners ||= User.where(login: args) + Organization.where(login: args)
          end
      end
    end
  end
end
