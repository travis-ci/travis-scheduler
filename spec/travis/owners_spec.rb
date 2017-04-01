describe Travis::Owners do
  let!(:anja)   { FactoryGirl.create(:user, login: 'anja')  }
  let!(:carla)  { FactoryGirl.create(:user, login: 'carla') }
  let!(:joe)    { FactoryGirl.create(:user, login: 'joe') }
  let!(:travis) { FactoryGirl.create(:org, login: 'travis') }
  let!(:rails)  { FactoryGirl.create(:org, login: 'sinatra') }

  let(:plans)   { { five: 5, ten: 10 } }
  let(:config)  { { limit: respond_to?(:limits) ? limits : {}, plans: plans } }
  let(:owners)  { described_class.group(anja, config) }

  shared_examples_for 'max_jobs' do
    describe 'with no subscription' do
      it { expect(owners.max_jobs).to eq 0 }
    end

    describe 'with a subscription on the delegatee' do
      before { FactoryGirl.create(:subscription, owner: anja, selected_plan: :ten) }
      it { expect(owners.max_jobs).to eq 10 }
    end

    describe 'with a subscription on the delegate' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :ten) }
      it { expect(owners.max_jobs).to eq 10 }
    end

    describe 'with a subscription on both the delegatee and delegate' do
      before { FactoryGirl.create(:subscription, owner: anja, selected_plan: :ten) }
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      it { expect(owners.max_jobs).to eq 15 }
    end
  end

  shared_examples_for 'subscribed_owners' do
    describe 'with no subscription' do
      it { expect(owners.subscribed_owners).to eq [] }
    end

    describe 'with a subscription on the delegatee' do
      before { FactoryGirl.create(:subscription, owner: anja, selected_plan: :ten) }
      it { expect(owners.subscribed_owners).to eq %w(anja) }
    end

    describe 'with a subscription on the delegate' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :ten) }
      it { expect(owners.subscribed_owners).to eq %w(travis) }
    end

    describe 'with a subscription on both the delegatee and delegate' do
      before { FactoryGirl.create(:subscription, owner: anja, selected_plan: :ten) }
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      it { expect(owners.subscribed_owners).to eq %w(anja travis) }
    end
  end

  describe 'using the db' do
    env DB_OWNER_GROUPS: 'true'

    describe 'given no owner group' do
      it { expect(owners.logins).to eq %w(anja) }
      it { expect(owners.key).to eq 'anja' }
    end

    describe 'given an owner group' do
      let(:uuid) { SecureRandom.uuid }

      before { OwnerGroup.create(uuid: uuid, owner_type: 'User', owner_id: anja.id) }
      before { OwnerGroup.create(uuid: uuid, owner_type: 'User', owner_id: carla.id) }
      before { OwnerGroup.create(uuid: uuid, owner_type: 'Organization', owner_id: travis.id) }

      it { expect(owners.logins).to eq %w(anja carla travis) }
      it { expect(owners.key).to eq 'anja:carla:travis' }

      include_examples 'max_jobs'
      include_examples 'subscribed_owners'
    end
  end

  describe 'using config' do
    describe 'given no owner group' do
      let(:limits) { {} }
      it { expect(owners.logins).to eq %w(anja) }
    end

    describe 'given an owner group' do
      let(:limits) { { delegate: { anja: 'travis', carla: 'travis' } } }

      it { expect(owners.logins).to eq %w(anja carla travis) }
      it { expect(owners.key).to eq 'anja:carla:travis' }

      include_examples 'max_jobs'
      include_examples 'subscribed_owners'
    end
  end

  describe '==' do
    describe 'for an owner in the same group' do
      let(:other) { described_class.group(anja, config) }
      it { expect(owners == other).to eq true }
    end

    describe 'for an owner in another group' do
      let(:other) { described_class.group(carla, config) }
      it { expect(owners == other).to eq false }
    end
  end
end
