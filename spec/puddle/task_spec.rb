describe Puddle::Task do
  let(:task) { Puddle::Task.new(noop) }
  let(:noop) { lambda { :ok } }

  describe "#call" do
    it "raises an error if called after a result is available" do
      task.call

      lambda { task.call }.should raise_error(Puddle::Task::InvariantError)
    end

    it "raises an error when called during execution" do
      task = Puddle::Task.new(lambda { sleep })
      thread = Thread.new(task, &:call)
      wait_until_sleep(thread)

      lambda { task.call }.should raise_error(Puddle::Task::InvariantError)
    end

    it "raises an error if called after task was cancelled" do
      task.cancel

      lambda { task.call }.should raise_error(Puddle::Task::InvariantError)
    end

    it "returns the result" do
      task.call.should eq(:ok)
    end

    it "re-raises errors" do
      noop.should_receive(:call).and_raise

      lambda { task.call }.should raise_error
    end
  end

  describe "#cancel" do
    it "raises an error if called after a result is available" do
      task.call

      lambda { task.cancel }.should raise_error(Puddle::Task::InvariantError)
    end

    it "raises an error when called during execution" do
      task = Puddle::Task.new(lambda { sleep; :ok })
      thread = Thread.new(task, &:call)
      wait_until_sleep(thread)

      lambda { task.cancel }.should raise_error(Puddle::Task::InvariantError)

      thread.wakeup
      task.value.should eq(:ok)
    end

    it "raises an error if called after task was cancelled" do
      task.cancel

      lambda { task.cancel }.should raise_error(Puddle::Task::InvariantError)
    end
  end

  describe "#value" do
    context "task has a result available" do
      it "returns the value" do
        task.call

        task.value.should eq(:ok)
      end

      it "raises the error if the task is an error" do
        error = RuntimeError.new("Some error")
        noop.should_receive(:call).and_raise(error)
        task.call rescue nil

        lambda { task.value }.should raise_error(error)
      end

      it "raises the error if the task is cancelled" do
        task.cancel

        lambda { task.value }.should raise_error(Puddle::Task::CancelledError)
      end
    end

    context "task receives a result later on" do
      let(:waiter) { Thread.new(task, &:value) }
      before(:each) { wait_until_sleep(waiter) }

      it "is woken up once a value is available" do
        task.call
        waiter.value.should eq(:ok)
      end

      it "is woken up once an error is available" do
        error = RuntimeError.new("Some error")
        noop.should_receive(:call).and_raise(error)
        task.call rescue nil

        lambda { waiter.value }.should raise_error(error)
      end

      it "is woken up once task is cancelled" do
        task.cancel

        lambda { waiter.value }.should raise_error(Puddle::Task::CancelledError)
      end
    end

    it "yields to the given block on timeout" do
      task.value(0) { :what }.should eq(:what)
    end

    it "raises an error on timeout" do
      lambda { task.value(0) }.should raise_error(TimeoutError)
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
