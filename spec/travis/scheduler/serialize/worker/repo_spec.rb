describe Travis::Scheduler::Serialize::Worker::Repo do
  let(:repo)   { Repository.new(owner_name: 'travis-ci', name: 'travis-ci') }
  let(:config) { { github: {} } }
  subject      { described_class.new(repo, config) }

  describe 'api_url' do
    before { config[:github][:api_url] = 'https://api.github.com' }
    it { expect(subject.api_url).to eq 'https://api.github.com/repos/travis-ci/travis-ci' }
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

    context "when config prefers HTTPS source_url" do
      before(:all)  { @before = Travis.config.prefer_https }
      before(:each) { Travis.config.prefer_https = true }
      after(:all)   { Travis.config.prefer_https = @before }

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
