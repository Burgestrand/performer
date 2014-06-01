describe Puddle do
  let(:puddle) { Puddle.new }

  specify "VERSION" do
    Puddle::VERSION.should_not be_nil
  end

  specify "#thread" do
    puddle.thread.should be_a(Thread)
  end

  describe "errors" do
    specify "standard errors in tasks do not crash the puddle" do
      lambda { puddle.sync { raise "Hell" } }.should raise_error(/Hell/)
      puddle.should be_alive
    end

    specify "non-standard errors in tasks crash the puddle" do
      lambda { puddle.sync { raise Exception, "Hell" } }.should raise_error(/Hell/)
      puddle.should_not be_alive
    end

    xspecify "if the puddle crashes, it brings all queued tasks with it" do
      stopgap = Queue.new

      puddle.async { stopgap.pop }
      puddle.async { raise Exception, "Hell" }
      task = puddle.async { :not_ok }

      stopgap.push :go

      lambda { task.value }.should raise_error(Puddle::CancelledError)
    end
  end

  describe "#sync" do
    specify "with timeout" do
      lambda { puddle.sync(0) { sleep } }.should raise_error(TimeoutError)
    end

    it "executes a task synchronously in another thread" do
      thread = puddle.sync { Thread.current }
      thread.should_not eq(Thread.current)
      thread.should eq(puddle.thread)
    end
  end

  describe "#async" do
    it "executes a task asynchronously in another thread" do
      task = puddle.async { Thread.current }

      thread = task.value
      thread.should_not eq(Thread.current)
      thread.should eq(puddle.thread)
    end
  end

  describe "#terminate" do
    it "allows all existing tasks to finish" do
      stopgap = Queue.new
      waiter = Thread.new(Thread.current) do |thread|
        wait_until_sleep(thread)
        stopgap.push :go
      end

      puddle.async { stopgap.pop }
      task = puddle.async { :done }
      puddle.terminate { :yay }.should eq(:yay)
      task.value.should eq(:done)
    end
  end
end
