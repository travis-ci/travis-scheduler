module Travis
  module Scheduler
    module Model
      class Delegates < Struct.new(:login, :config)
        def all
          @all ||= owners_by_logins(logins)
        end

        def logins
          logins = [login, delegate].compact
          logins = logins.concat(delegatees(logins))
          logins = logins.concat(delegators(logins))
          logins.uniq
        end

        private

          def delegate
            config[login.to_sym]
          end

          def delegators(logins)
            config.select { |login, _| logins.include?(login.to_s) }.keys.map(&:to_s)
          end

          def delegatees(logins)
            config.select { |_, login| logins.include?(login.to_s) }.keys.map(&:to_s)
          end

          def owners_by_logins(logins)
            [User.where(login: logins).all, Organization.where(login: logins).all].flatten
          end

          def config
            super[:limit][:delegate]
          end
      end
    end
  end
end
