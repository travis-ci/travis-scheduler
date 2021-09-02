# frozen_string_literal: true

describe Travis::Scheduler::Helper::JobRepository do
  let(:const) do
    Class.new(Struct.new(:job)) do
      include Travis::Scheduler::Helper::JobRepository
    end
  end

  let(:obj) { const.new(job) }
  let(:request) { Request.new }
  let(:build)   { Build.new(request: request) }
  let(:repo)    { FactoryGirl.create(:repository) }
  let(:job)     { Job.new(source: build, config: config, repository: repo) }
  let(:config)  { {} }

  context 'when build is not a pull request' do
    it 'returns job repository' do
      expect(obj.job_repository).to eq(repo)
    end
  end

  context 'when build is a pull request' do
    let(:pull_request) { PullRequest.new }
    let(:request) { Request.new(pull_request: pull_request) }

    before { build.event_type = 'pull_request' }

    context 'within the same repo' do
      before do
        pull_request.base_repo_slug = 'travis-ci/travis-yml'
        pull_request.head_repo_slug = 'travis-ci/travis-yml'
      end

      it 'returns job repository' do
        expect(obj.job_repository).to eq(repo)
      end
    end

    context 'not within the same repo' do
      let(:head_repo) { FactoryGirl.create(:repository, github_id: 234234) }

      context 'and repository is found' do
        before do
          pull_request.base_repo_slug = 'travis-ci/travis-yml'
          pull_request.head_repo_slug = "#{head_repo.owner_name}/#{head_repo.name}"
        end

        it 'returns PR head repository' do
          expect(obj.job_repository).to eq(head_repo)
        end
      end

      context 'and repository is not found' do
        before do
          pull_request.base_repo_slug = 'travis-ci/travis-yml'
          pull_request.head_repo_slug = 'owner/travis-yml'
        end

        it 'returns job repository' do
          expect(obj.job_repository).to eq(repo)
        end
      end
    end
  end
end
