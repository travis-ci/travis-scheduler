# frozen_string_literal: true

describe Travis::Scheduler::Serialize::Worker::Commit do
  subject { described_class.new(commit) }

  let(:request) { Request.new }
  let(:commit)  { Commit.new(request:) }

  describe 'pull_request?' do
    describe 'with a :push event' do
      before { request.event_type = 'push' }

      it { expect(subject.pull_request?).to be false }
    end

    describe 'with a :pull_request event' do
      before { request.event_type = 'pull_request' }

      it { expect(subject.pull_request?).to be true }
    end
  end

  describe 'tag' do
    describe 'with a tag ref' do
      before { commit.ref = 'refs/tags/foo' }

      it { expect(subject.tag).to eq 'foo' }
    end

    describe 'with any other ref' do
      before { commit.ref = 'refs/heads/foo' }

      it { expect(subject.tag).to be nil }
    end
  end

  describe 'range' do
    describe 'with a :push event' do
      before { request.event_type = 'push' }

      describe 'with a valid compare_url' do
        before { commit.compare_url = 'https://github.com/svenfuchs/minimal/compare/0cd9ff...62aaef' }

        it { expect(subject.range).to eq '0cd9ff...62aaef' }
      end

      describe 'with an invalid compare_url' do
        before { commit.compare_url = 'https://github.com/rails/rails/compare/ffaab2c4ffee.....60790e852a4f' }

        it { expect(subject.range).to eq(nil) }
      end

      describe 'without a compare_url' do
        before { commit.compare_url = nil }

        it { expect(subject.range).to eq(nil) }
      end
    end

    describe 'with a :pull_request event' do
      before do
        request.event_type = 'pull_request'
        request.assign_attributes(base_commit: '0cd9ff', head_commit: '62aaef')
      end

      it { expect(subject.range).to eq '0cd9ff...62aaef' }
    end
  end
end
