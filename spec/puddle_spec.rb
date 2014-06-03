describe Performer do
  let(:performer) { Performer.new }

  specify "VERSION" do
    Performer::VERSION.should_not be_nil
  end

  describe "errors" do
    specify "standard errors in tasks do not crash the performer" do
      lambda { performer.sync { raise "Hell" } }.should raise_error(/Hell/)
      performer.sync { 1 + 1 }.should eq(2)
    end

    specify "cancelled tasks do not crash the performer" do
      stopgap = Queue.new

      performer.async { stopgap.pop }
      task = performer.async { 1 + 1 }
      task.cancel
      stopgap.push :go

      performer.sync { 1 + 1 }.should eq(2)
    end

    specify "if the performer crashes, it brings all queued tasks with it" do
      stopgap = Queue.new

      performer.async { stopgap.pop }
      performer.async { raise Exception, "Hell" }
      task = performer.async { :not_ok }

      stopgap.push :go

      lambda { task.value }.should raise_error(Performer::Task::CancelledError)
    end

    specify "if the performer crashes, it no longer accepts tasks" do
      lambda { performer.sync { raise Exception, "Hell" } }.should raise_error

      lambda { performer.sync { 1 + 1 } }.should raise_error(Performer::ShutdownError)
      lambda { performer.shutdown }.should raise_error(Performer::ShutdownError)
    end
  end

  describe "#sync" do
    specify "with timeout" do
      lambda { performer.sync(0) { sleep } }.should raise_error(TimeoutError)
    end

    it "yields directly to the task when executed from within the performer" do
      value = performer.sync do
        performer.sync { 1 + 2 }
      end

      value.should eq(3)
    end

    it "executes a task synchronously in another thread" do
      thread = performer.sync { Thread.current }
      thread.should_not eq(Thread.current)
    end
  end

  describe "#async" do
    it "executes a task asynchronously in another thread" do
      task = performer.async { Thread.current }
      thread = task.value
      thread.should_not eq(Thread.current)
    end
  end

  describe "#shutdown" do
    it "performs a clean shutdown, allowing scheduled tasks to finish" do
      stopgap = Queue.new
      waiter = Thread.new(Thread.current) do |thread|
        wait_until_sleep(thread)
        stopgap.push :go
      end

      performer.async { stopgap.pop }
      task = performer.async { :done }
      term = performer.shutdown

      task.value.should eq(:done)
      term.value.should eq(nil)
    end

    it "prevents scheduling additional tasks" do
      performer.shutdown
      lambda { performer.sync { 1 + 1 } }.should raise_error(Performer::ShutdownError)
    end

    it "raises an error if shutdown is already underway" do
      performer.shutdown
      lambda { performer.shutdown }.should raise_error(Performer::ShutdownError)
    end
  end
end
