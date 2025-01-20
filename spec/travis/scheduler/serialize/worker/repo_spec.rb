# frozen_string_literal: true

describe Travis::Scheduler::Serialize::Worker::Repo do
  subject { described_class.new(repo, config) }

  let(:user)   { FactoryBot.create(:user) }
  let(:org)    { FactoryBot.create(:org) }

  let(:repo)   { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }
  let(:user_repo) { FactoryBot.create(:repository, owner: user) }
  let(:org_repo)  do
    FactoryBot.create(:repository, owner_name: org.login, owner_id: org.id, owner_type: 'Organization')
  end

  let(:authorize_build_url) { "http://localhost:9292/organizations/#{org.id}/plan" }
  let(:config) { { github: {} } }

  let(:unpaid_timeout) { User::DEFAULT_SPONSORED_TIMEOUT }
  let(:paid_timeout)   { User::DEFAULT_SUBSCRIBED_TIMEOUT }

  describe 'api_url' do
    before { config[:github][:api_url] = 'https://api.github.com' }

    it { expect(subject.api_url).to eq 'https://api.github.com/repos/travis-ci/travis-ci' }
  end

  describe '#timeouts' do
    context 'for a user-owned repo' do
      let(:worker) { described_class.new(user_repo, config) }

      context 'unpaid account' do
        let(:authorize_build_url) { "http://localhost:9292/users/#{user.id}/plan" }
        before do
          stub_request(:get, authorize_build_url).to_return(
            body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: 'subscribed',
                                 metered: true)
          )
        end

        it 'returns a hash of timeout values' do
          timeouts = worker.timeouts

          expect(timeouts).to be_a Hash
          expect(timeouts[:hard_limit]).to eq unpaid_timeout
        end
      end

      context 'paid account' do
        let(:authorize_build_url) { "http://localhost:9292/users/#{user.id}/plan" }
        before do
          User.any_instance.stubs(:subscribed?).returns(true)
          stub_request(:get, authorize_build_url).to_return(
            body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: 'subscribed',
                                 metered: true)
          )
        end

        it 'returns a hash of timeout values' do
          timeouts = worker.timeouts

          expect(timeouts).to be_a Hash
          expect(timeouts[:hard_limit]).to eq paid_timeout
        end
      end

      context 'active trial' do
        let(:authorize_build_url) { "http://localhost:9292/users/#{user.id}/plan" }
        before do
          User.any_instance.stubs(:active_trial?).returns(true)
          stub_request(:get, authorize_build_url).to_return(
            body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: 'subscribed',
                                 metered: true)
          )
        end

        it 'returns a hash of timeout values' do
          timeouts = worker.timeouts

          expect(timeouts).to be_a Hash
          expect(timeouts[:hard_limit]).to eq paid_timeout
        end
      end
    end

    context 'for an org-owned repo' do
      let(:worker) { described_class.new(org_repo, config) }

      context 'unpaid account' do

        before do
          stub_request(:get, authorize_build_url).to_return(
            body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: 'subscribed',
                                 metered: true)
          )
        end

        it 'returns a hash of timeout values' do
          timeouts = worker.timeouts

          expect(timeouts).to be_a Hash
          expect(timeouts[:hard_limit]).to eq unpaid_timeout
        end
      end

      context 'paid account' do
        before do
          Organization.any_instance.stubs(:subscribed?).returns(true)
          stub_request(:get, authorize_build_url).to_return(
            body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: 'subscribed',
                                 metered: true)
          )

        end

        it 'returns a hash of timeout values' do
          timeouts = worker.timeouts

          expect(timeouts).to be_a Hash
          expect(timeouts[:hard_limit]).to eq paid_timeout
        end
      end

      context 'active trial' do
        before do
          Organization.any_instance.stubs(:active_trial?).returns(true)
          stub_request(:get, authorize_build_url).to_return(
            body: MultiJson.dump(plan_name: 'free_tier_plan', hybrid: false, free: true, status: 'subscribed',
                                 metered: true)
          )
        end

        it 'returns a hash of timeout values' do
          timeouts = worker.timeouts

          expect(timeouts).to be_a Hash
          expect(timeouts[:hard_limit]).to eq paid_timeout
        end
      end
    end
  end

  describe 'source_url' do
    describe 'default source endpoint' do
      before { config[:github][:source_host] = 'github.com' }

      describe 'on a public repo' do
        before { repo.private = false }

        it { expect(subject.source_url).to eq 'https://github.com/travis-ci/travis-ci.git' }
      end

      describe 'on a private repo' do
        before { repo.private = true }

        it { expect(subject.source_url).to eq 'git@github.com:travis-ci/travis-ci.git' }
      end

      describe 'on a GHE repo' do
        before do
          config[:github][:source_host] = 'local.ghe.com'
          Travis.config.prefer_https = false
        end

        it { expect(subject.source_url).to eq 'git@local.ghe.com:travis-ci/travis-ci.git' }
      end

      context 'when it is an Assembla p4 repo' do
        let(:clone_url) { 'ssl:perforce.assembla.com:1667' }

        before { repo.update(vcs_type: 'AssemblaRepository', server_type: 'perforce', clone_url:) }

        it { expect(subject.source_url).to eq(clone_url) }
      end
    end

    describe 'custom source endpoint' do
      before { config[:github][:source_host] = 'localhost' }

      describe 'on a public repo' do
        before { repo.private = false }

        it { expect(subject.source_url).to eq 'git@localhost:travis-ci/travis-ci.git' }
      end

      describe 'on a private repo' do
        before { repo.private = true }

        it { expect(subject.source_url).to eq 'git@localhost:travis-ci/travis-ci.git' }
      end
    end

    context 'when config prefers HTTPS source_url' do
      before(:all) { @before = Travis.config.prefer_https }
      before { Travis.config.prefer_https = true }
      after(:all) { Travis.config.prefer_https = @before }

      describe 'default source endpoint' do
        before { config[:github][:source_host] = 'github.com' }

        describe 'on a public repo' do
          before { repo.private = false }

          it { expect(subject.source_url).to eq 'https://github.com/travis-ci/travis-ci.git' }
        end

        describe 'on a private repo' do
          before { repo.private = true }

          it { expect(subject.source_url).to eq 'https://github.com/travis-ci/travis-ci.git' }
        end
      end

      describe 'custom source endpoint' do
        before { config[:github][:source_host] = 'localhost' }

        describe 'on a public repo' do
          before { repo.private = false }

          it { expect(subject.source_url).to eq 'https://localhost/travis-ci/travis-ci.git' }
        end

        describe 'on a private repo' do
          before { repo.private = true }

          it { expect(subject.source_url).to eq 'https://localhost/travis-ci/travis-ci.git' }
        end
      end
    end
  end
end
