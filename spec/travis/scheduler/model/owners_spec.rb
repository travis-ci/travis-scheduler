describe Travis::Scheduler::Model::Owners do
  let!(:travis)  { FactoryGirl.create(:org,  login: 'travis') }
  let!(:sinatra) { FactoryGirl.create(:org,  login: 'sinatra') }
  let!(:sven)    { FactoryGirl.create(:user, login: 'sven') }
  let!(:carla)   { FactoryGirl.create(:user, login: 'carla') }
  let!(:other)   { FactoryGirl.create(:user, login: 'other') }

  let(:limits)   { { delegate: { sven: 'travis', carla: 'travis' } } }
  let(:plans)    { { five: 5, ten: 10 } }
  let(:attrs)    { { owner_type: 'User', owner_id: carla.id } }
  let(:config)   { { limit: limits, plans: plans } }
  let(:owners)   { described_class.new(attrs, config) }

  describe 'all' do
    subject { owners.all.map(&:login) }
    it { should eq %w(carla sven travis) }
  end

  describe 'logins' do
    subject { owners.logins }
    it { should eq %w(carla sven travis) }
  end

  describe 'key' do
    subject { owners.key }
    it { should eq 'carla:sven:travis' }
  end

  describe 'max_jobs' do
    subject { owners.max_jobs }

    describe 'with no subscription' do
      it { should eq 0 }
    end

    describe 'with a subscription on the delegatee' do
      before { FactoryGirl.create(:subscription, owner: carla, selected_plan: :ten) }
      it { should eq 10 }
    end

    describe 'with a subscription on the delegate' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :ten) }
      it { should eq 10 }
    end

    describe 'with a subscription on both the delegatee and delegate' do
      before { FactoryGirl.create(:subscription, owner: carla, selected_plan: :ten) }
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      it { should eq 15 }
    end
  end

  describe 'subscribed_owners' do
    subject { owners.subscribed_owners }

    describe 'with no subscription' do
      it { should eq [] }
    end

    describe 'with a subscription on the delegatee' do
      before { FactoryGirl.create(:subscription, owner: carla, selected_plan: :ten) }
      it { should eq %w(carla) }
    end

    describe 'with a subscription on the delegate' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :ten) }
      it { should eq %w(travis) }
    end

    describe 'with a subscription on both the delegatee and delegate' do
      before { FactoryGirl.create(:subscription, owner: carla, selected_plan: :ten) }
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      it { should eq %w(carla travis) }
    end
  end

  describe '==' do
    subject { owners == other_owners }

    describe 'for an owner in the same group' do
      let(:other_owners) { described_class.new({ owner_type: 'User', owner_id: sven.id }, config) }
      it { should eq true }
    end

    describe 'for an owner in another group' do
      let(:other_owners) { described_class.new({ owner_type: 'User', owner_id: other.id }, config) }
      it { should eq false }
    end
  end
end
