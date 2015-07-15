require 'travis/scheduler/helpers/live'

describe Travis::Scheduler::Helpers::Live::Notifier do
  include Travis::Testing::Stubs

  let(:job) { stub_test(state: :queued) }
  subject   { described_class.new(job) }

  describe 'enqueues a sidekiq job to pusher_tasks' do
    it 'to the pusher-live queue' do
      Sidekiq::Client.expects(:push).with do |hash|
        hash['queue'] == :'pusher-live'
      end
      subject.run
    end

    it 'passing the exepcted pusher payload' do
      Sidekiq::Client.expects(:push).with do |hash|
        hash['args'][3] == {
          id:                 1,
          build_id:           1,
          repository_id:      1,
          repository_slug:    'svenfuchs/minimal',
          repository_private: false,
          number:             '2.1',
          annotation_ids:     [1],
          state:              'queued',
          queue:              'builds.linux',
          log_id:             1,
          commit_id:          1,
          allow_failure:      false,
          commit: {
            id:              1,
            sha:             '62aae5f70ceee39123ef',
            branch:          'master',
            message:         'the commit message',
            compare_url:     'https://github.com/svenfuchs/minimal/compare/master...develop',
            committed_at:    (Time.now.utc - 60 * 60).strftime('%Y-%m-%dT%H:%M:%SZ'),
            committer_email: 'svenfuchs@artweb-design.de',
            committer_name:  'Sven Fuchs',
            author_name:     'Sven Fuchs',
            author_email:    'svenfuchs@artweb-design.de',
            compare_url:     'https://github.com/svenfuchs/minimal/compare/master...develop',
          }
        }
      end
      subject.run
    end

    it 'passing the event' do
      Sidekiq::Client.expects(:push).with do |hash|
        hash['args'][4] == { event: 'job:queued' }
      end
      subject.run
    end
  end
end
