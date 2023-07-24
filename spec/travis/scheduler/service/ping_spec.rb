# frozen_string_literal: true

describe Travis::Scheduler::Service::Ping do
  let(:now)      { Time.now }
  let(:context)  { Travis::Scheduler.context }
  let(:interval) { context.config[:ping][:interval] }
  let(:service)  { described_class.new(context) }

  let!(:one)     do
    FactoryBot.create(:job, state: :created, owner_id: 1, owner_type: 'User', created_at: now - interval)
  end
  let!(:two) do
    FactoryBot.create(:job, state: :created, owner_id: 1, owner_type: 'User', created_at: now - interval)
  end
  let!(:three) do
    FactoryBot.create(:job, state: :created, owner_id: 2, owner_type: 'User', created_at: now - interval)
  end
  let!(:four)    { FactoryBot.create(:job, state: :created, owner_id: 3, owner_type: 'user', created_at: now) }
  let!(:five)    do
    FactoryBot.create(:job, state: :created, owner_id: 3, owner_type: 'Organization', created_at: now - interval)
  end

  def pings(key, data)
    data = data.merge(src: :ping, at: instance_of(Float))
    service.expects(:async).with(key, has_entries(data)).once
  end

  it do
    service.stubs(:async)
    pings :enqueue_owners, owner_id: 1, owner_type: 'User'
    pings :enqueue_owners, owner_id: 2, owner_type: 'User'
    pings :enqueue_owners, owner_id: 3, owner_type: 'Organization'
    service.run
  end
end
