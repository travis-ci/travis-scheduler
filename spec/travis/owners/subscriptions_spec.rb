describe Travis::Owners::Subscriptions do
  let!(:travis)  { FactoryGirl.create(:org,  login: 'travis') }
  let!(:sinatra) { FactoryGirl.create(:org,  login: 'sinatra') }
  let!(:joe)     { FactoryGirl.create(:user, login: 'joe') }
  let!(:anja)    { FactoryGirl.create(:user, login: 'anja')  }


  let(:plans)    { { five: 5, ten: 10, :"travis-ci-one-free-build"=>1 } }
  let(:limits)   { {} }
  let(:attrs)    { { owner_type: 'Organization', owner_id: travis.id } }
  let(:attrs2)   { { owner_type: 'User', owner_id: joe.id } }
  let(:attrs3)   { { owner_type: 'User', owner_id: anja.id } }

  let(:config)   { { limit: limits, plans: plans } }
  let(:owners)   { Travis::Owners.group(attrs, config) }
  let(:owners2)  { Travis::Owners.group(attrs2, config) }
  let(:owners3)  { Travis::Owners.group(attrs3, config) }

  
  context 'organization' do
    subject { described_class.new(owners, plans).max_jobs }

    describe 'a single org with a five jobs plan' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      it { should eq 5 }
    end

    describe 'with a delegation' do
      let(:limits) { { delegate: { sinatra: 'travis' } } }

      describe 'with a subscription on a delegatee' do
        before { FactoryGirl.create(:subscription, owner: sinatra, selected_plan: :five) }
        it { should eq 5 }
      end

      describe 'with a subscription on a delegate' do
        before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
        it { should eq 5 }
      end

      describe 'with an invalid subscription on a delegatee' do
        before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
        before { FactoryGirl.create(:subscription, owner: sinatra) }
        it { should eq 5 }
      end

      describe 'with an invalid subscription on a delegate' do
        before { FactoryGirl.create(:subscription, owner: travis) }
        before { FactoryGirl.create(:subscription, owner: sinatra, selected_plan: :five) }
        it { should eq 5 }
      end
    end

    context 'user' do
      describe 'a user with a free build plan' do
        before { FactoryGirl.create(:subscription, owner: joe, selected_plan: "travis-ci-one-free-build") }
        subject { described_class.new(owners2, plans).max_jobs }
        it { should eq 1 }
      end

      describe 'a user with a five jobs plan' do
        before { FactoryGirl.create(:subscription, owner: anja, selected_plan: :five) }
        subject { described_class.new(owners3, plans).max_jobs }
        it { should eq 6 }
      end
    end
  end
end
