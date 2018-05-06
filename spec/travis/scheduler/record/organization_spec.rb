describe Organization do
  let(:org) { FactoryGirl.create(:org) }

  describe "constants" do
    # It isn't often that we see tests for constants, but these are special.
    #   Changing these values for worker timeout limits impacts our infra teams,
    #   and should only be adjusted after consulting with them.
    #
    it "has correct values for default timeouts" do
      expect(Organization::DEFAULT_SPONSORED_TIMEOUT).to eq 3000
      expect(Organization::DEFAULT_SUBSCRIBED_TIMEOUT).to eq 7200
    end
  end

  describe "#default_worker_timeout" do
    context "subscribed? == true" do
      before do
        org.stubs(:subscribed?).returns(true)
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context "active_trial? == true" do
      before do
        org.stubs(:active_trial?).returns(true)
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context "subscribed? == false && active_trial? == false" do
      before do
        org.stubs(:subscribed?).returns(false)
        org.stubs(:active_trial?).returns(false)
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(org.default_worker_timeout).to eq Organization::DEFAULT_SPONSORED_TIMEOUT
      end
    end
  end
end
