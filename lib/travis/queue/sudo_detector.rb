module Travis
  class Queue
    class SudoDetector < Struct.new(:config)
      EXECUTABLES = %w(
        docker
        ping
        sudo
      )

      STAGES = %i(
        before_install
        install
        before_script
        script
        before_cache
        after_success
        after_failure
        after_script
        before_deploy
      )

      def detect?
        stages.any? do |script|
          commands = script.to_s.sub(/#.*$/,'')
          has_common? commands.split, EXECUTABLES
        end
      end

      private

        def stages
          config.values_at(*STAGES).compact.flatten
        end

        def has_common?(a,b)
          intersection = []
          Array(a).each do |a_el|
            Array(b).each do |b_el|
              if a_el == b_el
                intersection << a_el
              end
            end
          end
          ! intersection.empty?
        end
    end
  end
end
