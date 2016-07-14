require 'spec_helper'

describe Travis::Scheduler::BranchValidator do
  #let(:repo)    { FactoryGirl.create(:repository, owner_name: 'travis-ci', name: 'travis-ci') }
  #let(:commit)  { Commit.new(commit: '12345678') }
  #let(:request) { Request.new(repository: repo, commit: commit) }

  describe '#valid_branch_name?' do
    it 'validates the name' do
      expect(described_class.new('foo', nil).valid_branch_name?).to be_truthy
      expect(described_class.new('foo/bar/baz', nil).valid_branch_name?).to be_truthy
      expect(described_class.new('foo-bar.baz/1.0.1', nil).valid_branch_name?).to be_truthy
      expect(described_class.new('1.2.3', nil).valid_branch_name?).to be_truthy
      expect(described_class.new('a/b-c/d', nil).valid_branch_name?).to be_truthy

      expect(described_class.new('a/.b', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo.lock', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo.', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo^', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('', nil).valid_branch_name?).to be_falsey
      expect(described_class.new(nil, nil).valid_branch_name?).to be_falsey
      expect(described_class.new('/foo', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo//bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo@bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo^bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo[bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo*bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo?bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo:bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo~bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new('foo\bar', nil).valid_branch_name?).to be_falsey
      expect(described_class.new("foo\040bar", nil).valid_branch_name?).to be_falsey
      expect(described_class.new("foo\177bar", nil).valid_branch_name?).to be_falsey
    end
  end

  describe 'branch_exists_in_the_db?' do
    it 'returns ture if a branch with a given name and repository id exists in the database' do
      Branch.create(name: 'foo', repository_id: 10)

      repository = stub(id: 10)
      expect(described_class.new('foo', repository).branch_exists_in_the_db?).to be_truthy
    end

    it 'returns ture if a branch with a given name and repository id does not exist in the database' do
      Branch.create(name: 'foo', repository_id: 11)

      repository = stub(id: 10)
      expect(described_class.new('foo', repository).branch_exists_in_the_db?).to be_falsey
    end
  end

  describe 'branch_exists_on_github?' do
    it 'tries to fetch branch from github using credentials of recently updated user' do
      repository = FactoryGirl.create(:repository, name: 'travis-scheduler', owner_name: 'travis-ci', private: true)
      user1 = FactoryGirl.create(:user, updated_at: Time.now, github_oauth_token: 'token-1')
      user2 = FactoryGirl.create(:user, updated_at: Time.now - 3600, github_oauth_token: 'token-2')
      repository.users << user1
      repository.users << user2

      GH.expects(:with).with(token: 'token-1').yields
      GH.expects(:[]).with('/repos/travis-ci/travis-scheduler/branches/foo').returns({})

      expect(described_class.new('foo', repository).branch_exists_on_github?).to be_truthy
    end

    it 'tries to fetch branch from github using credentials of next users if the first user\'s token is invalid' do
      repository = FactoryGirl.create(:repository, name: 'travis-scheduler', owner_name: 'travis-ci', private: true)
      user1 = FactoryGirl.create(:user, updated_at: Time.now, github_oauth_token: 'token-1')
      user2 = FactoryGirl.create(:user, updated_at: Time.now - 3600, github_oauth_token: 'token-2')
      repository.users << user1
      repository.users << user2

      GH.expects(:with).with(token: 'token-1').raises(GH::TokenInvalid)
      GH.expects(:with).with(token: 'token-2').yields
      GH.expects(:[]).with('/repos/travis-ci/travis-scheduler/branches/foo').returns({})

      expect(described_class.new('foo', repository).branch_exists_on_github?).to be_truthy
    end

    it "returns false if all of the users' tokens are invalid" do
      repository = FactoryGirl.create(:repository, name: 'travis-scheduler', owner_name: 'travis-ci', private: true)
      user1 = FactoryGirl.create(:user, updated_at: Time.now, github_oauth_token: 'token-1')
      user2 = FactoryGirl.create(:user, updated_at: Time.now - 3600, github_oauth_token: 'token-2')
      repository.users << user1
      repository.users << user2

      GH.expects(:with).with(token: 'token-1').raises(GH::TokenInvalid)
      GH.expects(:with).with(token: 'token-2').raises(GH::TokenInvalid)

      expect(described_class.new('foo', repository).branch_exists_on_github?).to be_falsey
    end

    it 'returns false if the branch does not exist on github' do
      repository = FactoryGirl.create(:repository, name: 'travis-scheduler', owner_name: 'travis-ci', private: true)

      user1 = FactoryGirl.create(:user, updated_at: Time.now, github_oauth_token: 'token-1')
      user2 = FactoryGirl.create(:user, updated_at: Time.now - 3600, github_oauth_token: 'token-2')
      repository.users << user1
      repository.users << user2

      GH.expects(:with).with(token: 'token-1').raises(GH::TokenInvalid)
      GH.expects(:with).with(token: 'token-2').yields
      GH.expects(:[]).with('/repos/travis-ci/travis-scheduler/branches/foo').raises(GH::Error.new(nil, nil, response_status: 404))

      expect(described_class.new('foo', repository).branch_exists_on_github?).to be_falsey
    end

    it "tries next users even if we get 404 or 403 (because user's permissions could be revoked)" do
      repository = FactoryGirl.create(:repository, name: 'travis-scheduler', owner_name: 'travis-ci', private: true)

      user1 = FactoryGirl.create(:user, updated_at: Time.now, github_oauth_token: 'token-1')
      user2 = FactoryGirl.create(:user, updated_at: Time.now - 100, github_oauth_token: 'token-2')
      user3 = FactoryGirl.create(:user, updated_at: Time.now - 200, github_oauth_token: 'token-3')
      repository.users << user1
      repository.users << user2
      repository.users << user3

      GH.expects(:with).with(token: 'token-1').yields
      GH.expects(:with).with(token: 'token-2').yields
      GH.expects(:with).with(token: 'token-3').yields
      sequence = sequence('sequence')
      GH.expects(:[]).with('/repos/travis-ci/travis-scheduler/branches/foo').raises(GH::Error.new(nil, nil, response_status: 404)).in_sequence(sequence)
      GH.expects(:[]).with('/repos/travis-ci/travis-scheduler/branches/foo').raises(GH::Error.new(nil, nil, response_status: 403)).in_sequence(sequence)
      GH.expects(:[]).with('/repos/travis-ci/travis-scheduler/branches/foo').returns({}).in_sequence(sequence)

      expect(described_class.new('foo', repository).branch_exists_on_github?).to be_truthy
    end

    it "raises an error if it's a non 403 or 404 error" do
      repository = FactoryGirl.create(:repository, name: 'travis-scheduler', owner_name: 'travis-ci', private: true)

      user1 = FactoryGirl.create(:user, updated_at: Time.now, github_oauth_token: 'token-1')
      repository.users << user1

      GH.expects(:with).with(token: 'token-1').yields
      GH.expects(:[]).times(3).with('/repos/travis-ci/travis-scheduler/branches/foo').raises(GH::Error.new(nil, nil, response_status: 401))

      expect {
        described_class.new('foo', repository).branch_exists_on_github?
      }.to raise_error(GH::Error)
    end
  end
end
