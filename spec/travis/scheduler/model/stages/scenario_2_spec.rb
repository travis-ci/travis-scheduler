# frozen_string_literal: true

describe Travis::Stages do
  let(:jobs) { keys.map { |stage| { state: :created, stage: } } }
  let(:root) { described_class.build(jobs) }

  include Support::Stages

  describe 'scenario 2' do
    # 1.1.1.1 \
    #           1.1.2.1         3.1
    # 1.1.1.2 /         \     /
    #                     2.1
    #                   /     \
    # 1.2.1.1 - 1.2.2.1         3.2

    let(:keys) { ['1.1.1.1', '1.1.1.2', '1.1.2.1', '1.2.1.1', '1.2.2.1', '2.1', '3.1', '3.2'] }

    describe 'structure' do
      let :structure do
        <<-STR.gsub(/ {10}/, '').chomp
          Root
            Stage key=1
              Stage key=1.1
                Stage key=1.1.1
                  Job key=1.1.1.1 state=created
                  Job key=1.1.1.2 state=created
                Stage key=1.1.2
                  Job key=1.1.2.1 state=created
              Stage key=1.2
                Stage key=1.2.1
                  Job key=1.2.1.1 state=created
                Stage key=1.2.2
                  Job key=1.2.2.1 state=created
            Stage key=2
              Job key=2.1 state=created
            Stage key=3
              Job key=3.1 state=created
              Job key=3.2 state=created
        STR
      end

      it { expect(root.inspect).to eq structure }
    end

    describe 'flow' do
      context do
        it { expect(startable).to eq ['1.1.1.1', '1.1.1.2', '1.2.1.1'] }
      end

      context do
        before { start '1.1.1.1', '1.1.1.2', '1.2.1.1' }

        it { expect(startable).to eq [] }
      end

      context do
        before do
          finish '1.1.1.1'
          start '1.1.1.2', '1.2.1.1'
        end

        it { expect(startable).to eq [] }
      end

      context do
        before do
          finish '1.1.1.1', '1.1.1.2'
          start '1.2.1.1'
        end

        it { expect(startable).to eq ['1.1.2.1'] }
      end

      context do
        before { finish '1.1.1.1', '1.1.1.2', '1.2.1.1' }

        it { expect(startable).to eq ['1.1.2.1', '1.2.2.1'] }
      end

      context do
        before { finish '1.1.1.1', '1.1.1.2', '1.1.2.1', '1.2.1.1', '1.2.2.1' }

        it { expect(startable).to eq ['2.1'] }
      end

      context do
        before { finish '1.1.1.1', '1.1.1.2', '1.1.2.1', '1.2.1.1', '1.2.2.1', '2.1' }

        it { expect(startable).to eq ['3.1', '3.2'] }
      end

      context do
        before do
          finish '1.1.1.1', '1.1.1.2', '1.1.2.1', '1.2.1.1', '1.2.2.1', '2.1', '3.1'
          start '3.2'
        end

        it { expect(startable).to eq [] }
      end

      context do
        before do
          finish '1.1.1.1', '1.1.1.2', '1.1.2.1', '1.2.1.1', '1.2.2.1', '2.1', '3.2'
          start '3.1'
        end

        it { expect(startable).to eq [] }
      end

      context do
        before { finish '1.1.1.1', '1.1.1.2', '1.1.2.1', '1.2.1.1', '1.2.2.1', '2.1', '3.1', '3.2' }

        it { expect(startable).to eq [] }
      end
    end
  end
end
