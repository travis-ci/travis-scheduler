module Travis
  module Owners
    class Config < Struct.new(:owner, :config)
      def owners
        [owner, users, orgs].flatten.uniq
      end

      private

      def users
        User.where(login: logins).all
      end

      def orgs
        Organization.where(login: logins).all
      end

      def logins
        logins = [delegate].compact
        logins = logins.concat(delegatees(login, *logins))
        logins = logins.concat(delegators(login, *logins))
        logins.uniq.compact
      end

      def login
        owner.login
      end

      def delegate
        config[login.try(:to_sym)]
      end

      def delegatees(*logins)
        config.select { |_, login| logins.include?(login.to_s) }.keys.map(&:to_s)
      end

      def delegators(*logins)
        config.select { |login, _| logins.include?(login.to_s) }.keys.map(&:to_s)
      end

      def config
        super && super[:limit] && super[:limit][:delegate] || {}
      end
    end
  end
end
