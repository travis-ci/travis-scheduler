require 'metriks'

module Travis
  module Scheduler
    module Helper
      module Metrics
        module ClassMethods
          def meter(method, opts = {})
            prepend Module.new {
              define_method(method) do |*args, &block|
                meter(opts[:key] || method) do
                  super(*args, &block)
                end
              end
            }
          end
        end

        def self.included(base)
          base.extend(ClassMethods)
        end

        def meter(key, &block)
          metrics.time(metrics_key(key), &block)
        end

        def gauge(key, value)
          metrics.gauge(metrics_key(key), value)
        end

        private

          def metrics_key(key = nil)
            parts = ['sync', metrics_namespace, self.class.registry_key]
            parts << key if key && key != :run # TODO include :run, and fix librato?
            parts.join('.').gsub(/[\?!]/, '')
          end

          def metrics_namespace
            self.class.registry_const.name.split('::').last.downcase.to_sym
          end

          def metrics
            GithubSync.metrics
          end
      end
    end
  end
end
