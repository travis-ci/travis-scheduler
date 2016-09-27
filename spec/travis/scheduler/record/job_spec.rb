describe Job do
  let(:config) { { rvm: '1.8.7' } }
  let(:job) { FactoryGirl.create(:job, config: config).reload }

  it 'deserializes config' do
    expect(job.config).to be_a(Hash)
  end
end
