require 'active_record'

module Travis
  module Database
    class << self
      def connect(config, logger = nil)
        ActiveRecord::Base.establish_connection(config.to_h)
        ActiveRecord.default_timezone = :utc
        ActiveRecord::Base.logger = logger
      end

      def table?(_name)
        ActiveRecord::Base.connection.tables.include?('owner_groups')
      end
    end
  end
end
