describe Travis::Scheduler::Services::Ping do
  let!(:one)    { FactoryGirl.create(:job, state: :created, owner_id: 1, owner_type: 'User') }
  let!(:two)    { FactoryGirl.create(:job, state: :created, owner_id: 1, owner_type: 'User') }
  let!(:three)  { FactoryGirl.create(:job, state: :created, owner_id: 2, owner_type: 'User') }
  let!(:four)   { FactoryGirl.create(:job, state: :created, owner_id: 3, owner_type: 'Organization') }
  let(:service) { described_class.new(Travis::Scheduler.context) }

  it do
    service.expects(:async).with(:enqueue_owners, owner_id: 1, owner_type: 'User').once
    service.expects(:async).with(:enqueue_owners, owner_id: 2, owner_type: 'User').once
    service.expects(:async).with(:enqueue_owners, owner_id: 3, owner_type: 'Organization').once
    service.run
  end
end
