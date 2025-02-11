# frozen_string_literal: true

require 'travis/owners'

module Travis
  module Scheduler
    module Service
      class EnqueueOwners < Struct.new(:context, :data)
        include Helper::With
        include Helper::Runner
        include Helper::Metrics
        include Helper::Memoize
        include Helper::Logging
        include Helper::Locking
        include Helper::Context
        include Registry
        extend Forwardable

        register :service, :enqueue_owners

        MSGS = {
          schedule: 'Evaluating jobs for owner group: %s'
        }.freeze

        def run
          begin
            info format(MSGS[:schedule], owners.to_s)
            Travis::Honeycomb.context.add('owner_group', owners.key)
            puts "Travis::Scheduler::Service::EnqueueOwners#run"
            puts "Owners: #{owners.inspect}"
            puts "collect: #{collect.inspect}"
            collect

            puts "report: #{report.inspect}"
            report

            puts "enqueue: #{enqueue.inspect}"
            enqueue
          rescue => e
            puts "An error occurred inside Travis::Scheduler::Service::EnqueueOwners#run: #{e.message}"
            puts e.backtrace.join("\n")
          end
        end
        with :run, :exclusive

        private

        def collect
          limit.run
        end
        time :collect

        def report
          limit.reports.each { |line| info line }
        end

        def enqueue
          jobs = limit.selected
          jobs = jobs.partition { |job| !job.allow_failure }
          jobs.flatten.each { |job| inline :enqueue_job, job, jid: }
        end
        time :enqueue

        def limit
          Jobs::Select.new(context, owners)
        end
        memoize :limit

        def owners
          @owners ||= Owners.group(data, config.to_h)
        end

        def exclusive(&block)
          super(['scheduler.owners', owners.key].join('-'), config.to_h, retries: 0, &block)
        rescue Owners::ArgumentError => e
          error e.message
        end

        def jid
          data[:jid]
        end

        def src
          data[:src]
        end

        def opts
          super || {}
        end
      end
    end
  end
end
