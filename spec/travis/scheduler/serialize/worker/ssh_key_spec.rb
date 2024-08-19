# frozen_string_literal: true

require 'spec_helper'

describe Travis::Scheduler::Serialize::Worker::SshKey do
  let(:repo) { FactoryBot.create :repo, private: true }
  let(:db_job) { FactoryBot.create :job, repository: repo }
  let(:job) { Travis::Scheduler::Serialize::Worker::Job.new(db_job, config) }
  let(:config) do
    { enterprise: false }
  end
  let(:key) { described_class.new(repo, job, config) }

  describe '#data' do
    subject { key.data }

    context 'when private' do
      context 'and non-Github' do
        it {
          expect(subject).to eq(source: :default_repository_key, value: repo.key.private_key, public_key: repo.key.public_key,
                                encoded: false)
        }
      end
    end

    context 'when repo key is nil' do
      before { repo.update_attribute(:key, nil) }

      it { expect(subject).to be_nil }
    end
  end
end
