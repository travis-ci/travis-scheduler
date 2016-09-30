describe Repository do
  describe 'settings' do
    let(:repo) { FactoryGirl.create(:repository) }

    it 'adds repository_id to collection records' do
      env_var = repo.settings.env_vars.create(name: 'FOO')
      expect(env_var.repository_id).to eq(repo.id)
      repo.settings.save

      expect(repo.reload.settings.env_vars.first.repository_id).to eq(repo.id)
    end

    it "allows to set nil for settings" do
      repo.settings = nil
      expect(repo.settings.to_hash).to eq(Repository::Settings.new.to_hash)
    end

    it "allows to set settings as JSON string" do
      repo.settings = '{"maximum_number_of_builds": 44}'
      expect(repo.settings.to_hash).to eq(Repository::Settings.new(maximum_number_of_builds: 44).to_hash)
    end

    it "allows to set settings as a Hash" do
      repo.settings = { maximum_number_of_builds: 44}
      expect(repo.settings.to_hash).to eq(Repository::Settings.new(maximum_number_of_builds: 44).to_hash)
    end
  end
end
