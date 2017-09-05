module Travis
  class Queue
    class SudoDetector < Struct.new(:config)
      EXECUTABLES = %w(
        docker
        ping
        sudo
      )

      PATTERN = /^[^#]*\b(#{EXECUTABLES.join('|')})\b/

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
        stages.any? { |script| PATTERN =~ script.to_s }
      end

      private

        def stages
          config.values_at(*STAGES).compact.flatten
        end
    end
  end
end
