# frozen_string_literal: true

describe Repository do
  describe 'settings' do
    let(:repo) { FactoryBot.create(:repository) }

    it 'adds repository_id to collection records' do
      env_var = repo.settings.env_vars.create(name: 'FOO')
      expect(env_var.repository_id).to eq(repo.id)
      repo.settings.save

      expect(repo.reload.settings.env_vars.first.repository_id).to eq(repo.id)
    end

    describe 'share_ssh_keys_with_forks setting' do
      subject { repo.settings.share_ssh_keys_with_forks? }

      let(:created_at) { Date.parse('2021-09-01') }

      before { repo.update(created_at:) }

      context 'when repo is old' do
        it { is_expected.to be true }
      end

      context 'when repo is new' do
        let(:created_at) { Date.parse('2021-11-01') }

        it { is_expected.to be false }
      end
    end

    it 'allows to set nil for settings' do
      repo.settings = nil
      settings = Repository::Settings.new
      settings.additional_attributes = { repository_id: repo.id }
      expect(repo.settings.to_hash).to eq(settings.to_hash)
    end

    it 'allows to set settings as JSON string' do
      repo.settings = '{"maximum_number_of_builds": 44}'
      settings = Repository::Settings.new(maximum_number_of_builds: 44)
      settings.additional_attributes = { repository_id: repo.id }
      expect(repo.settings.to_hash).to eq(settings.to_hash)
    end

    it 'allows to set settings as a Hash' do
      repo.settings = { maximum_number_of_builds: 44 }
      settings = Repository::Settings.new(maximum_number_of_builds: 44)
      settings.additional_attributes = { repository_id: repo.id }
      expect(repo.settings.to_hash).to eq(settings.to_hash)
    end
  end

  describe '#github?' do
    subject { repo.github? }

    context 'when repo is a github repository (default)' do
      let(:repo) { FactoryBot.create(:repository) }

      it { is_expected.to be true }
    end

    context 'when repo is not a github repository' do
      let(:repo) { FactoryBot.create(:repository, vcs_type: 'BitbucketRepository') }

      it { is_expected.to be false }
    end
  end
end
