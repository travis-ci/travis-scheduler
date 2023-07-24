module Travis
  module Owners
    module Cli
      class List < Cl::Cmd
        register 'owners:list'

        purpose 'List all existing owner groups'

        MSGS = {
          list: 'Known owner groups:',
          none: 'None'
        }

        def run
          puts MSGS[:list]
          puts groups.any? ? groups.map { |group| format_group(group) } : MSGS[:none]
        end

        private

        def format_group(group)
          group.map { |owner| format_owner(owner) }.join(', ')
        end

        def format_owner(owner)
          "#{owner.login} (#{owner.is_a?(User) ? 'user' : 'org'})"
        end

        def groups
          @groups ||= uuids.map do |uuid|
            OwnerGroup.where(uuid:).map(&:owner)
          end
        end

        def uuids
          OwnerGroup.pluck(:uuid).uniq
        end
      end
    end
  end
end
