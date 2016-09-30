describe Request do
  let(:repo)    { FactoryGirl.create(:repository, owner_name: 'travis-ci', name: 'travis-ci') }
  let(:commit)  { Commit.new(commit: '12345678') }
  let(:request) { Request.new(repository: repo, commit: commit) }

  describe 'same_repo_pull_request?' do
    it 'returns false if the ref is a sha' do
      request.payload = {
        'pull_request' => {
          'base' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } },
          'head' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' },
                      'ref' => 'abc123', 'sha' => 'abc123bde266593ee3a9d32d376430437a6fc392' }
        }
      }

      expect(request.same_repo_pull_request?).to eq(false)
    end

    it 'calls the branch valdiator if it looks like a same repo PR and ref does not look like a sha' do
      request.payload = {
        'pull_request' => {
          'base' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } },
          'head' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' },
                      'ref' => 'foo', 'sha' => 'abc123bde266593ee3a9d32d376430437a6fc392' }
        }
      }

      validator  = stub(valid?: true)
      Travis::Scheduler::BranchValidator.expects(:new).with('foo', request.repository).returns(validator)
      expect(request.same_repo_pull_request?).to eq(true)
    end

    # integration for branch validator
    it 'returns true if the branch exists in the db' do
      Branch.create(repository_id: repo.id, name: 'foo')
      request.payload = {
        'pull_request' => {
          'base' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } },
          'head' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' },
                      'ref' => 'foo', 'sha' => 'abc123bde266593ee3a9d32d376430437a6fc392' }
        }
      }

      expect(request.same_repo_pull_request?).to eq(true)
    end

    it 'returns false if the base and head repos do not match' do
      request.payload = {
        'pull_request' => {
          'base' => { 'repo' => { 'full_name' => 'travis-ci/travis-core' } },
          'head' => { 'repo' => { 'full_name' => 'evilmonkey/travis-core' } }
        }
      }

      expect(request.same_repo_pull_request?).to eq(false)
    end

    it 'returns false if repo data is not available' do
      request.payload = {}

      expect(request.same_repo_pull_request?).to eq(false)
    end
  end
end
