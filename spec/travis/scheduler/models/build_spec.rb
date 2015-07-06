require 'spec_helper'

describe Build do
  describe '#secure_env_enabled?' do
    it 'returns true if we\'re not dealing with pull request' do
      build = Factory.build(:build)
      build.stubs(:pull_request?).returns(false)
      build.secure_env_enabled?.should be_true
    end

    it 'returns true if pull request is from the same repository' do
      build = Factory.build(:build)
      build.stubs(:pull_request?).returns(true)
      build.stubs(:same_repo_pull_request?).returns(true)
      build.secure_env_enabled?.should be_true
    end

    it 'returns false if pull request is not from the same repository' do
      build = Factory.build(:build)
      build.stubs(:pull_request?).returns(true)
      build.stubs(:same_repo_pull_request?).returns(false)
      build.secure_env_enabled?.should be_false
    end
  end
end
