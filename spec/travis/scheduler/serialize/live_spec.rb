# frozen_string_literal: true

require 'travis/scheduler/serialize/live'

describe Travis::Scheduler::Serialize::Live do
  subject      { described_class.new(job).data }

  let(:job)    { FactoryBot.create(:job, state: :queued) }
  let(:commit) { job.commit }
  let(:build)  { job.source }
  let(:repo)   { job.repository }

  it 'data' do
    expect(subject).to eq(
      id: job.id,
      build_id: build.id,
      repository_id: repo.id,
      repository_slug: 'svenfuchs/gem-release',
      repository_private: false,
      number: '2.1',
      state: 'queued',
      queue: 'builds.gce',
      commit_id: commit.id,
      allow_failure: false,
      updated_at: job.updated_at.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'),
      commit: {
        id: commit.id,
        sha: '62aaef',
        branch: 'master',
        message: 'message',
        committed_at: '2016-01-01T12:00:00Z',
        committer_email: 'me@svenfuchs.com',
        committer_name: 'Sven Fuchs',
        author_name: 'Sven Fuchs',
        author_email: 'me@svenfuchs.com',
        compare_url: 'https://github.com/svenfuchs/minimal/compare/0cd9ff...62aaef'
      }
    )
  end
end
