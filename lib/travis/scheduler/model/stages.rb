# frozen_string_literal: true

# We have keys with this semantical meaning:
#
#   1.1.1.1 \
#             1.1.2.1         3.1
#   1.1.1.2 /         \     /
#                       2.1
#                     /     \
#   1.2.1.1 - 1.2.2.1         3.2
#
# In other words:
#
#   1.1.1.1   start 1.1.1.1, 1.1.1.2, and 1.2.1.1 in parallel
#   1.1.1.2
#   1.1.2.1   start once 1.1.1.1 and 1.1.1.2 have completed
#   1.2.1.1
#   1.2.2.1   start once 1.2.1.1 has completed
#   2         start once 1.1.2.1 and 1.2.2.1 have completed
#   3.1       start 3.1 and 3.2 once 2 has completed
#   3.2
#
# We transform this into a tree structure like the following, dropping: all
# jobs that are not in a startable state (i.e. `created`).
#
#   1
#     1.1
#       1.1.1
#         1.1.1.1
#         1.1.1.2
#     1.2
#       1.2.1
#         1.2.1.1
#       1.2.2
#         1.2.2.1
#   2
#     2.1
#   3
#     3.1
#     3.2
#
# Then, in order to determine startable jobs we can:
#
# * Select the first branch
# * From this branch select all first branches (1.1.1 and 1.2.1)
# * From these branches select all leafs
#
# This mechanism doesn't seem overly generic, but I cannot come up with any other
# way that would not
#
# * either not select 1.2.1.1 as startable (when all jobs are :created)
# * or not exclude 1.2.2.1 from being startable
#
# If anyone can come up with a more generic mechanism then I'd be extremely
# happy to hear it :)

module Travis
  module Stages
    def self.build(jobs)
      jobs.each_with_object(Stage.new(nil, 0)) do |job, stage|
        job = Job.new(*job.values_at(:id, :state, :stage))
        stage << job unless job.finished? or job.build.canceled?
      end
    end

    class Stage
      attr_reader :parent, :num, :children

      def initialize(parent, num)
        @parent   = parent
        @num      = num.to_i
        @children = []
        parent.children << self if parent
      end

      def <<(job)
        node = job.leaf? ? children : stage(job.nums.shift)
        node << job
      end

      def startable
        if first.is_a?(Stage)
          first.children.map(&:startable).flatten
        else
          children.select(&:startable?).map(&:to_h)
        end
      end

      def root?
        key == '0'
      end

      def key
        [parent && parent.key != '0' ? parent.key : nil, num].compact.join('.')
      end

      def inspect
        indent = ->(child) { child.inspect.split("\n").map { |str| "  #{str}" }.join("\n") }
        "#{root? ? 'Root' : "Stage key=#{key}"}\n#{children.map(&indent).join("\n")}"
      end

      private

      def stage(num)
        stages.detect { |stage| stage.num == num } || Stage.new(self, num.to_i)
      end

      def stages
        children.select { |child| child.is_a?(Stage) }
      end

      def first
        children.first
      end
    end

    class Job < Struct.new(:id, :state, :key)
      def leaf?
        nums.size == 1
      end

      def nums
        @nums ||= key.split('.').map(&:to_i)
      end

      def startable
        startable? ? [self] : []
      end

      def startable?
        state && state.to_sym == :created
      end

      def finished?
        state && state.to_sym == :finished
      end

      def inspect
        "Job key=#{key} state=#{state}"
      end
    end
  end
end
