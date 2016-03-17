require 'spec_helper'

describe Job do
  let(:job) { Job.find(FactoryGirl.create(:job).id) }

  it 'deserializes config' do
    expect(job.config).to be_a(Hash)
  end
end
