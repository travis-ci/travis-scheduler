# frozen_string_literal: true

describe Job do
  let(:config) { { rvm: '1.8.7' } }
  let(:job) { FactoryBot.create(:job, config:).reload }
  let(:stage) { FactoryBot.create(:stage, number: 1) }
  let(:priority) { { high: 5, low: -5, medium: nil } }
  let(:build1)   { FactoryBot.create(:build) }
  let(:build2)   { FactoryBot.create(:build) }
  let(:build3)   { FactoryBot.create(:build) }

  it 'deserializes config' do
    expect(job.config).to be_a(Hash)
  end

  describe 'jobs having all types of priorities' do
    before do
      FactoryBot.create(:job, stage:, state: :created, source: build1)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:low], source: build2)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:low], source: build2)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:high], source: build3)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:high], source: build3)
    end

    describe 'ordering' do
      it {
        expect(stage.jobs.queueable.collect(&:priority)).to eq [priority[:high], priority[:high],
                                                                priority[:medium], priority[:low], priority[:low]]
      }
    end
  end

  describe 'jobs having high and low priorities' do
    before do
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:low], source: build1)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:high], source: build2)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:high], source: build2)
      FactoryBot.create(:job, stage:, state: :created, priority: priority[:low], source: build1)
    end

    describe 'ordering' do
      it {
        expect(stage.jobs.queueable.collect(&:priority)).to eq [priority[:high], priority[:high],
                                                                priority[:low], priority[:low]]
      }
    end
  end

  describe 'jobs not having any priorities' do
    before do
      FactoryBot.create(:job, stage:, state: :created, source: build1)
      FactoryBot.create(:job, stage:, state: :created, source: build2)
      FactoryBot.create(:job, stage:, state: :created, source: build2)
      FactoryBot.create(:job, stage:, state: :created, source: build3)
      FactoryBot.create(:job, stage:, state: :created, source: build1)
    end

    describe 'ordering' do
      it {
        expect(stage.jobs.queueable.collect(&:priority)).to eq [priority[:medium], priority[:medium],
                                                                priority[:medium], priority[:medium], priority[:medium]]
      }
    end
  end

  describe 'multiple builds with same priority' do
    before do
      @stage = FactoryBot.create(:stage, number: 1)
      @build1 = FactoryBot.create(:build)
      @build2 =  FactoryBot.create(:build)
      @build3 =  FactoryBot.create(:build)
      @build4 =  FactoryBot.create(:build)

      @job1 = FactoryBot.create(:job, stage: @stage, state: :created, priority: nil, source: @build1)
      @job2 = FactoryBot.create(:job, stage: @stage, state: :created, priority: nil, source: @build1)
      @job3 = FactoryBot.create(:job, stage: @stage, state: :created, priority: -5, source: @build2)
      @job4 = FactoryBot.create(:job, stage: @stage, state: :created, priority: -5, source: @build2)
      @job5 = FactoryBot.create(:job, stage: @stage, state: :created, priority: 5, source: @build3)
      @job6 = FactoryBot.create(:job, stage: @stage, state: :created, priority: 5, source: @build3)
      @job7 = FactoryBot.create(:job, stage: @stage, state: :created, priority: 5, source: @build4)
      @job8 = FactoryBot.create(:job, stage: @stage, state: :created, priority: 5, source: @build4)
    end

    # builds having same priority will be ordered by job id
    describe 'order jobs by priority and then order by id' do
      it {
        expect(@stage.jobs.queueable.collect(&:id)).to eq [@job5.id, @job6.id, @job7.id, @job8.id,
                                                           @job1.id, @job2.id, @job3.id, @job4.id]
      }
    end
  end
end
