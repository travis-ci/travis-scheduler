describe Travis::Scheduler::Services::Ping do
  let(:now)     { Time.now }
  let!(:one)    { FactoryGirl.create(:job, state: :created, owner_id: 1, owner_type: 'User', created_at: now - 2 * 60) }
  let!(:two)    { FactoryGirl.create(:job, state: :created, owner_id: 1, owner_type: 'User', created_at: now - 2 * 60) }
  let!(:three)  { FactoryGirl.create(:job, state: :created, owner_id: 2, owner_type: 'User', created_at: now - 2 * 60) }
  let!(:four)   { FactoryGirl.create(:job, state: :created, owner_id: 3, owner_type: 'user', created_at: now) }
  let!(:five)   { FactoryGirl.create(:job, state: :created, owner_id: 3, owner_type: 'Organization', created_at: now - 2 * 60) }
  let(:service) { described_class.new(Travis::Scheduler.context) }

  it do
    service.expects(:async).with(:enqueue_owners, owner_id: 1, owner_type: 'User', src: :ping).once
    service.expects(:async).with(:enqueue_owners, owner_id: 2, owner_type: 'User', src: :ping).once
    service.expects(:async).with(:enqueue_owners, owner_id: 3, owner_type: 'Organization', src: :ping).once
    service.run
  end
end
