module Travis
  class Queue
    class ForceLinuxSudoRequired < Struct.new(:owner)
      def apply?
        Travis::Features.enabled_for_all?(:linux_sudo_required) ||
          Travis::Features.owner_active?(:linux_sudo_required, owner)
      end
    end
  end
end
