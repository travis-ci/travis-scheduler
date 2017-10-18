describe Travis::Stages do
  let(:jobs) { keys.map { |stage| { state: :created, stage: stage } } }
  let(:root) { described_class.build(jobs) }

  include Support::Stages

  describe 'scenario 1' do
    # 1.1 \
    # 1.2 - 2.1 - 3.1 - 4.1 - 5.1 - 6.1 - 7.1 - 8.1 - 9.1 - 10.1
    # 1.3 /

    let(:keys)  { ['9.1', '1.1', '1.2', '1.3', '2.1', '3.1', '4.1', '5.1', '6.1', '7.1', '8.1', '10.1'] }

    describe 'structure' do
      let :structure do
        <<-str.gsub(/ {10}/, '').chomp
          Root
            Stage key=9
              Job key=9.1 state=created
            Stage key=1
              Job key=1.1 state=created
              Job key=1.2 state=created
              Job key=1.3 state=created
            Stage key=2
              Job key=2.1 state=created
            Stage key=3
              Job key=3.1 state=created
            Stage key=4
              Job key=4.1 state=created
            Stage key=5
              Job key=5.1 state=created
            Stage key=6
              Job key=6.1 state=created
            Stage key=7
              Job key=7.1 state=created
            Stage key=8
              Job key=8.1 state=created
            Stage key=10
              Job key=10.1 state=created
        str
      end

      it { expect(root.inspect).to eq structure }
    end

    describe 'flow' do
      context do
        it { expect(startable).to eq ['1.1', '1.2', '1.3'] }
      end

      context do
        before { start '1.1', '1.2', '1.3' }
        it { expect(startable).to eq [] }
      end

      context do
        before { finish '1.1' }
        before { start '1.2', '1.3' }
        it { expect(startable).to eq [] }
      end

      context do
        before { finish '1.1', '1.3' }
        before { start '1.2' }
        it { expect(startable).to eq [] }
      end

      context do
        before { finish '1.1', '1.2', '1.3' }
        it { expect(startable).to eq ['2.1'] }
      end

      context do
        before { finish '1.1', '1.2', '1.3' }
        before { start '2.1' }
        it { expect(startable).to eq [] }
      end

      context do
        before { finish '1.1', '1.2', '1.3', '2.1' }
        it { expect(startable).to eq ['3.1'] }
      end
    end
  end
end
