# frozen_string_literal: true

describe Travis::Owners::Subscriptions do
  subject { described_class.new(owners, plans).max_jobs }

  let!(:travis)  { FactoryBot.create(:org,  login: 'travis') }
  let!(:sinatra) { FactoryBot.create(:org,  login: 'sinatra') }

  let(:plans)    { { five: 5, ten: 10 } }
  let(:limits)   { {} }
  let(:attrs)    { { owner_type: 'Organization', owner_id: travis.id } }
  let(:config)   { { limit: limits, plans: } }
  let(:owners)   { Travis::Owners.group(attrs, config) }

  describe 'a single org with a five jobs plan' do
    before { FactoryBot.create(:subscription, owner: travis, selected_plan: :five) }

    it { is_expected.to eq 5 }
  end

  describe 'with a delegation' do
    let(:limits) { { delegate: { sinatra: 'travis' } } }

    describe 'with a subscription on a delegatee' do
      before { FactoryBot.create(:subscription, owner: sinatra, selected_plan: :five) }

      it { is_expected.to eq 5 }
    end

    describe 'with a subscription on a delegate' do
      before { FactoryBot.create(:subscription, owner: travis, selected_plan: :five) }

      it { is_expected.to eq 5 }
    end

    describe 'with an invalid subscription on a delegatee' do
      before do
        FactoryBot.create(:subscription, owner: travis, selected_plan: :five)
        FactoryBot.create(:subscription, owner: sinatra)
      end

      it { is_expected.to eq 5 }
    end

    describe 'with an invalid subscription on a delegate' do
      before do
        FactoryBot.create(:subscription, owner: travis)
        FactoryBot.create(:subscription, owner: sinatra, selected_plan: :five)
      end

      it { is_expected.to eq 5 }
    end
  end
end
