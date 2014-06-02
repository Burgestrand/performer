describe Puddle do
  let(:puddle) { Puddle.new }

  specify "VERSION" do
    Puddle::VERSION.should_not be_nil
  end

  describe "errors" do
    specify "standard errors in tasks do not crash the puddle" do
      lambda { puddle.sync { raise "Hell" } }.should raise_error(/Hell/)
      puddle.sync { 1 + 1 }.should eq(2)
    end

    specify "cancelled tasks do not crash the puddle" do
      stopgap = Queue.new

      puddle.async { stopgap.pop }
      task = puddle.async { 1 + 1 }
      task.cancel
      stopgap.push :go

      puddle.sync { 1 + 1 }.should eq(2)
    end

    specify "if the puddle crashes, it brings all queued tasks with it" do
      stopgap = Queue.new

      puddle.async { stopgap.pop }
      puddle.async { raise Exception, "Hell" }
      task = puddle.async { :not_ok }

      stopgap.push :go

      lambda { task.value }.should raise_error(Puddle::Task::CancelledError)
    end

    specify "if the puddle crashes, it no longer accepts tasks" do
      lambda { puddle.sync { raise Exception, "Hell" } }.should raise_error

      lambda { puddle.sync { 1 + 1 } }.should raise_error(Puddle::ShutdownError)
    end
  end

  describe "#sync" do
    specify "with timeout" do
      lambda { puddle.sync(0) { sleep } }.should raise_error(TimeoutError)
    end

    it "yields directly to the task when executed from within the puddle" do
      value = puddle.sync do
        puddle.sync { 1 + 2 }
      end

      value.should eq(3)
    end

    it "executes a task synchronously in another thread" do
      thread = puddle.sync { Thread.current }
      thread.should_not eq(Thread.current)
    end
  end

  describe "#async" do
    it "executes a task asynchronously in another thread" do
      task = puddle.async { Thread.current }
      thread = task.value
      thread.should_not eq(Thread.current)
    end
  end

  describe "#shutdown" do
    it "allows all existing tasks to finish" do
      stopgap = Queue.new
      waiter = Thread.new(Thread.current) do |thread|
        wait_until_sleep(thread)
        stopgap.push :go
      end

      puddle.async { stopgap.pop }
      task = puddle.async { :done }
      term = puddle.shutdown { :yay }

      task.value.should eq(:done)
      term.value.should eq(:yay)
    end

    it "prevents scheduling additional tasks" do
      puddle.shutdown { :yay }
      lambda { puddle.sync { 1 + 1 } }.should raise_error(Puddle::ShutdownError)
    end
  end
end
