describe Performer::Task do
  let(:task) { Performer::Task.new(noop) }
  let(:noop) { lambda { :ok } }

  describe "#call" do
    it "raises an error if called after a result is available" do
      task.call

      lambda { task.call }.should raise_error(Performer::Task::InvariantError)
    end

    it "raises an error when called during execution" do
      task = Performer::Task.new(lambda { sleep })
      thread = Thread.new(task, &:call)
      wait_until_sleep(thread)

      lambda { task.call }.should raise_error(Performer::Task::InvariantError)
    end

    it "raises an error if called after task was cancelled" do
      task.cancel

      lambda { task.call }.should raise_error(Performer::Task::InvariantError)
    end

    it "swallows standard errors" do
      error = StandardError.new("Hello!")
      noop.should_receive(:call).and_raise(error)

      task.call.should eql(task)
      lambda { task.value }.should raise_error(error)
    end

    it "re-raises non-standard errors" do
      error = SyntaxError.new("Hello!")
      noop.should_receive(:call).and_raise(error)

      lambda { task.call }.should raise_error(error)
      lambda { task.value }.should raise_error(error)
    end
  end

  describe "#cancel" do
    it "raises an error if called after a result is available" do
      task.call

      lambda { task.cancel }.should raise_error(Performer::Task::InvariantError)
    end

    it "raises an error when called during execution" do
      task = Performer::Task.new(lambda { sleep; :ok })
      thread = Thread.new(task, &:call)
      wait_until_sleep(thread)

      lambda { task.cancel }.should raise_error(Performer::Task::InvariantError)

      thread.wakeup
      task.value.should eq(:ok)
    end

    it "raises an error if called after task was cancelled" do
      task.cancel

      lambda { task.cancel }.should raise_error(Performer::Task::InvariantError)
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

        lambda { task.value }.should raise_error(Performer::Task::CancelledError)
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

        lambda { waiter.value }.should raise_error(Performer::Task::CancelledError)
      end
    end

    it "yields to the given block on timeout" do
      task.value(0) { :what }.should eq(:what)
    end

    it "raises an error on timeout" do
      lambda { task.value(0) }.should raise_error(TimeoutError)
    end
  end
end
