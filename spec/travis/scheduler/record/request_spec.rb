describe Request do
  let(:repo)                   { FactoryBot.build(:repository, owner_name: 'travis-ci', name: 'travis-ci') }
  let(:commit)                 { FactoryBot.build(:commit, commit: '12345678') }
  let(:pull_request)           { FactoryBot.build(:pull_request, head_ref: head_ref, head_repo_github_id: head_repo_github_id) }
  let(:request)                { FactoryBot.build(:request, repository: repo, commit: commit, head_commit: head_commit, pull_request: pull_request) }
  let(:head_repo_github_id)    { repo.github_id }
  let(:head_ref)               { }
  let(:head_commit)            { }

  describe 'same_repo_pull_request?' do
    describe 'returns true if base and head repos match and head ref equals head sha' do
      let(:head_ref) { 'branch-1' }
      let(:head_commit) { commit.commit }
      it { expect(request.same_repo_pull_request?).to eq(true) }
    end

    describe 'returns false if head commit is nil' do
      let(:head_ref) { 'branch-1' }
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end

    describe 'returns false if head ref is nil' do
      let(:head_commit) { commit.commit }
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end

    describe 'returns false if the base and head repos do not match' do
      let(:head_repo_github_id) { repo.github_id + 1000 }
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end

    describe 'returns false if repo data is not available' do
      it { expect(request.same_repo_pull_request?).to eq(false) }
    end

    describe '#head_repo_vcs_id' do
      subject { request.send(:head_repo_vcs_id) }

      context 'when pull request does not exist' do
        let(:pull_request) { nil }

        it { is_expected.to be_nil }
      end

      context 'when pull request exists' do
        let(:head_repo_github_id) { 123 }
        let(:head_repo_vcs_id) { 'bitbucket123' }
        let(:pull_request) do
          FactoryBot.build(
            :pull_request, head_ref: head_ref, head_repo_github_id: head_repo_github_id,
            head_repo_github_id: head_repo_github_id, head_repo_vcs_id: head_repo_vcs_id
          )
        end

        context 'when repo is a github repository' do
          it { is_expected.to eq(head_repo_github_id.to_s) }
        end

        context 'when repo is not a github repository' do
          let(:repo) do
            FactoryBot.build(:repository, owner_name: 'travis-ci', name: 'travis-ci', vcs_type: 'BitbucketRepository')
          end

          it { is_expected.to eq(head_repo_vcs_id) }
        end
      end
    end
  end
end
