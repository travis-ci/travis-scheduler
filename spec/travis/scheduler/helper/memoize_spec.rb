describe Travis::Scheduler::Helper::Memoize do
  let :const do
    Class.new(Struct.new(:dep)) do
      include Travis::Scheduler::Helper::Memoize
      memoize def foo = dep.call
    end
  end

  let(:dep) { stub('dep') }
  let(:obj) { const.new(dep) }

  [true, false, nil].each do |val|
    it "calls the implementation only once (returning #{val}" do
      dep.expects(:call).returns(val).once
      3.times { expect(obj.foo).to eq val }
    end
  end
end
