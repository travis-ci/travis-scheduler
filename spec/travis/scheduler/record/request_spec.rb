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
