require 'spec_helper'

describe Build do
  describe '#secure_env?' do
    it "returns true if we're not dealing with pull request" do
      build = FactoryGirl.build(:build)
      build.stubs(:pull_request?).returns(false)
      expect(build.secure_env?).to eq(true)
    end

    it 'returns true if pull request is from the same repository' do
      build = FactoryGirl.build(:build)
      build.stubs(:pull_request?).returns(true)
      build.stubs(:same_repo_pull_request?).returns(true)
      expect(build.secure_env?).to eq(true)
    end

    it 'returns false if pull request is not from the same repository' do
      build = FactoryGirl.build(:build)
      build.stubs(:pull_request?).returns(true)
      build.stubs(:same_repo_pull_request?).returns(false)
      expect(build.secure_env?).to eq(false)
    end
  end
end
