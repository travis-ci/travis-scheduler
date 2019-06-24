describe Job do
  let(:config) { { rvm: '1.8.7' } }
  let(:job) { FactoryGirl.create(:job, config: config, stage_number: '1.2').reload }

  it 'deserializes config' do
    expect(job.config).to be_a(Hash)
  end

  it 'renders its stage number numeric parts' do
    expect(job.stage_number_parts).to eq [1, 2]
  end
end
