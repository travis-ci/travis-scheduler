describe Job do
  let(:config) { { rvm: '1.8.7' } }
  let(:job) { FactoryGirl.create(:job, config: config).reload }
  let(:stage) { FactoryGirl.create(:stage, number: 1) }
  let(:priority) { { high: 5, low: -5, medium: nil } }

  it 'deserializes config' do
    expect(job.config).to be_a(Hash)
  end

  describe 'jobs having all types of priorities' do
    before { FactoryGirl.create(:job, stage: stage, state: :created) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:low]) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:high]) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:low]) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:high]) }

    describe 'ordering' do
      it { expect(stage.jobs.queueable.collect(&:priority)).to eq [priority[:high], priority[:high], priority[:medium], priority[:low], priority[:low]] }
    end
  end

  describe 'jobs having high and low priorities' do
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:low]) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:high]) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:low]) }
    before { FactoryGirl.create(:job, stage: stage, state: :created, priority: priority[:high]) }

    describe 'ordering' do
      it { expect(stage.jobs.queueable.collect(&:priority)).to eq [priority[:high], priority[:high], priority[:low], priority[:low]] }
    end
  end

  describe 'jobs not having any priorities' do
    before { FactoryGirl.create(:job, stage: stage, state: :created) }
    before { FactoryGirl.create(:job, stage: stage, state: :created) }
    before { FactoryGirl.create(:job, stage: stage, state: :created) }
    before { FactoryGirl.create(:job, stage: stage, state: :created) }
    before { FactoryGirl.create(:job, stage: stage, state: :created) }

    describe 'ordering' do
      it { expect(stage.jobs.queueable.collect(&:priority)).to eq [priority[:medium], priority[:medium], priority[:medium], priority[:medium], priority[:medium]] }
    end
  end
end
