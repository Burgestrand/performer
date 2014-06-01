describe Puddle::Task do
  let(:task) { Puddle::Task.new(noop) }
  let(:noop) { lambda { :ok } }
  let(:other_thread) { Thread.new {} }

  describe "#call" do
    it "raises an error if not the owner thread" do
      task = Puddle::Task.new(other_thread, noop)
      lambda { task.call }.should raise_error(Puddle::OwnershipError)
    end

    it "raises an error if called twice" do
      task.call
      lambda { task.call }.should raise_error(Puddle::DoubleCallError)
    end

    it "does not raise an error if owner thread is not defined" do
      task.call.should eq(:ok)
    end
  end

  describe "#value" do
    it "retrieves the value if task is done" do
      task.call
      task.value.should eq(:ok)
    end

    it "waits until task is done if task is not done" do
      waiter = Thread.new(task) { |t| t.value }
      wait_until_sleep(waiter)
      task.call
      waiter.value.should eq(:ok)
    end

    it "raises an error if the task was an error" do
      error = RuntimeError.new("Some error")
      noop.should_receive(:call).and_raise(error)
      lambda { task.call }.should raise_error(error)
      lambda { task.value }.should raise_error(error)
    end

    it "yields to the given block on timeout" do
      task.value(0) { :what }.should eq(:what)
    end

    it "raises an error on timeout" do
      lambda { task.value(0) }.should raise_error(TimeoutError)
    end
  end

  describe "query methods" do
    specify "pending" do
      task.should_not be_value
      task.should_not be_error
      task.should_not be_done
    end

    specify "success" do
      noop.should_receive(:call).and_return(:ok)
      task.call

      task.should be_value
      task.should_not be_error
      task.should be_done
    end

    specify "error" do
      noop.should_receive(:call).and_raise
      task.call rescue nil

      task.should_not be_value
      task.should be_error
      task.should be_done
    end
  end

  describe "#to_proc" do
    def yielder
      yield
    end

    it "returns a callable proc" do
      yielder(&task).should eq(:ok)
    end
  end
end
