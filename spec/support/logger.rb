# frozen_string_literal: true

require 'active_support/concern'

module Support
  module Logger
    extend ActiveSupport::Concern

    included do
      let(:stdout) { StringIO.new }
      let(:log)    { stdout.string }
      let(:logger) { Travis::Logger.new(stdout, logger: { level: :debug }) }
      before       { Travis::Scheduler.context.logger = logger }
      before       { Travis::Amqp.logger = logger }
    end
  end
end
