require 'active_support/concern'

module Support
  module Logger
    extend ActiveSupport::Concern

    included do
      let(:stdout) { StringIO.new }
      let(:log)    { stdout.string }
      let(:logger) { Travis::Logger.new(stdout) }
      before       { Travis::Scheduler.logger = logger }
      before       { Travis::Amqp.logger = logger }
    end
  end
end
