require 'travis/scheduler/helpers/deep_dup'

describe Travis::Scheduler::Helpers::DeepDup do
  let(:dup) { described_class.deep_dup(obj) }

  describe 'an array' do
    let(:obj) { [{ bar: 'baz', nil: nil, one: 1, true: true }] }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to_not eq obj.object_id }
  end

  describe 'a hash' do
    let(:obj) { { foo: [{ bar: 'baz', nil: nil, one: 1, true: true }] } }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to_not eq obj.object_id }

    it { expect(dup[:foo].first).to eq obj[:foo].first }
    it { expect(dup[:foo].first.object_id).to_not eq obj[:foo].first.object_id }
  end

  describe 'a string' do
    let(:obj) { 'string' }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to_not eq obj.object_id }
  end

  describe 'nil (cannot be duped)' do
    let(:obj) { nil }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to eq obj.object_id }
  end

  describe 'true (cannot be duped)' do
    let(:obj) { true }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to eq obj.object_id }
  end

  describe 'false (cannot be duped)' do
    let(:obj) { false }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to eq obj.object_id }
  end

  describe 'an integer (cannot be duped)' do
    let(:obj) { 1 }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to eq obj.object_id }
  end

  describe 'a float (cannot be duped)' do
    let(:obj) { 1.2 }

    it { expect(dup).to eq obj }
    it { expect(dup.object_id).to eq obj.object_id }
  end
end

