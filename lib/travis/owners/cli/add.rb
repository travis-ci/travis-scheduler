# frozen_string_literal: true

module Travis
  module Owners
    module Cli
      class Add < Cl::Cmd
        register 'owners:add'

        purpose 'Add one or more owners to an existing owner group'

        args :owners

        opt '-t', '--to TO', 'An owner in an existing group' do |value|
          opts[:to] = value
        end

        MSGS = {
          target: 'You need to specify which existing owner group to add to. (Pick any owner login on that group. E.g. `owners add joe --to maria`)',
          unknown: 'Unable to find an owner %s.',
          ungrouped: 'Unable to find an existing owner group for the owner %s.',
          grouped: 'The following owners already are in an owner group: %s',
          confirm: 'This will add the following owners to the owner group that %s belongs to: %s. Confirm? [y/n]',
          done: 'Done. These owners have been added to the group.'
        }.freeze

        def run
          validate
          confirm
          add
        end

        private

        def validate
          abort MSGS[:target] unless opts[:to]
          abort MSGS[:unknown] % opts[:to] unless target
          abort MSGS[:ungrouped] % target.login unless uuid
          grouped = owners.select(&:owner_group)
          abort MSGS[:grouped] % grouped.map(&:login).join(', ') if grouped.any?
        end

        def confirm
          puts format(MSGS[:confirm], target.login, owners.map(&:login).join(', '))
          input = STDIN.gets.chomp.downcase
          abort 'Aborting.' unless input == 'y'
        end

        def add
          owners.each { |owner| OwnerGroup.create!(uuid:, owner:) }
          puts MSGS[:done]
        end

        def owners
          @owners_ ||= find_owners(logins)
        end

        def uuid
          target.try(:owner_group).try(:uuid)
        end

        def target
          @target ||= find_owners(opts[:to]).first
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
