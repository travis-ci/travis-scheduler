describe Travis::Owners::Subscriptions do
  let!(:travis)  { FactoryBot.create(:org,  login: 'travis') }
  let!(:sinatra) { FactoryBot.create(:org,  login: 'sinatra') }

  let(:plans)    { { five: 5, ten: 10 } }
  let(:limits)   { {} }
  let(:attrs)    { { owner_type: 'Organization', owner_id: travis.id } }
  let(:config)   { { limit: limits, plans: } }
  let(:owners)   { Travis::Owners.group(attrs, config) }

  subject { described_class.new(owners, plans).max_jobs }

  describe 'a single org with a five jobs plan' do
    before { FactoryBot.create(:subscription, owner: travis, selected_plan: :five) }
    it { should eq 5 }
  end

  describe 'with a delegation' do
    let(:limits) { { delegate: { sinatra: 'travis' } } }

    describe 'with a subscription on a delegatee' do
      before { FactoryBot.create(:subscription, owner: sinatra, selected_plan: :five) }
      it { should eq 5 }
    end

    describe 'with a subscription on a delegate' do
      before { FactoryBot.create(:subscription, owner: travis, selected_plan: :five) }
      it { should eq 5 }
    end

    describe 'with an invalid subscription on a delegatee' do
      before { FactoryBot.create(:subscription, owner: travis, selected_plan: :five) }
      before { FactoryBot.create(:subscription, owner: sinatra) }
      it { should eq 5 }
    end

    describe 'with an invalid subscription on a delegate' do
      before { FactoryBot.create(:subscription, owner: travis) }
      before { FactoryBot.create(:subscription, owner: sinatra, selected_plan: :five) }
      it { should eq 5 }
    end
  end
end
