describe Request do
  let(:repo)                   { FactoryGirl.build(:repository, owner_name: 'travis-ci', name: 'travis-ci') }
  let(:commit)                 { FactoryGirl.build(:commit, commit: '12345678') }
  let(:pull_request)           { FactoryGirl.build(:pull_request, head_ref: head_ref, head_repo_github_id: head_repo_github_id) }
  let(:request)                { FactoryGirl.build(:request, repository: repo, commit: commit, pull_request: pull_request) }
  let(:head_repo_github_id)    { repo.github_id }
  let(:head_ref)               { 'branch-1' }

  describe 'same_repo_pull_request?' do
    describe 'returns false if the ref is a sha' do
      let(:head_ref) { 'abc123' }
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end

    describe 'returns false if the base and head repos do not match' do
      let(:head_repo_github_id) { repo.github_id + 1000 }
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end

    describe 'returns false if repo data is not available' do
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end
  end
end
