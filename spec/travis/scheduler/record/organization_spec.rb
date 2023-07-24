describe Organization do
  let(:org) { FactoryBot.create(:org) }
  let(:authorize_build_url) { "http://localhost:9292/organizations/#{org.id}/plan" }

  describe 'constants' do
    # It isn't often that we see tests for constants, but these are special.
    #   Changing these values for worker timeout limits impacts our infra teams,
    #   and should only be adjusted after consulting with them.
    #
    it 'has correct values for default timeouts' do
      expect(Organization::DEFAULT_SPONSORED_TIMEOUT).to eq 3000
      expect(Organization::DEFAULT_SUBSCRIBED_TIMEOUT).to eq 7200
    end
  end

  describe '#educational?' do
    context 'education = true' do
      before do
        Travis::Features.stubs(:owner_active?).returns(true)
      end

      it 'returns true' do
        expect(org.educational?).to be_truthy
      end
    end

    context 'education = false' do
      before do
        Travis::Features.stubs(:owner_active?).returns(false)
      end

      it 'returns true' do
        expect(org.educational?).to be_falsey
      end
    end

    context 'education = nil' do
      before do
        Travis::Features.stubs(:owner_active?).returns(nil)
      end

      it 'returns true' do
        expect(org.educational?).to be_falsey
      end
    end
  end

  describe '#default_worker_timeout' do
    context 'subscribed? == true' do
      before do
        org.stubs(:subscribed?).returns(true)
      end

      it 'returns the DEFAULT_SUBSCRIBED_TIMEOUT' do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context 'active_trial? == true' do
      before do
        org.stubs(:active_trial?).returns(true)
      end

      it 'returns the DEFAULT_SUBSCRIBED_TIMEOUT' do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context 'subscribed? == true' do
      before do
        org.stubs(:educational?).returns(true)
        stub_request(:get, authorize_build_url).to_return(
          body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: nil, metered: true)
        )
      end

      it 'returns the DEFAULT_SUBSCRIBED_TIMEOUT' do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context 'paid_new_plan? == true' do
      before do
        org.stubs(:paid_new_plan?).returns(true)
        stub_request(:get, authorize_build_url).to_return(
          body: MultiJson.dump(plan_name: 'two_concurrent_plan', hybrid: true, free: false, status: 'subscribed',
                               metered: false)
        )
      end

      it 'returns the DEFAULT_SUBSCRIBED_TIMEOUT' do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context '#subscribed?, #active_trial?, #educational? == false' do
      before do
        org.stubs(:subscribed?).returns(false)
        org.stubs(:active_trial?).returns(false)
        org.stubs(:educational?).returns(false)
        stub_request(:get, authorize_build_url).to_return(
          body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: nil, metered: true)
        )
      end

      it 'returns the DEFAULT_SUBSCRIBED_TIMEOUT' do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SPONSORED_TIMEOUT
      end
    end
  end
end
