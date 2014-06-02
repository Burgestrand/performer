describe Puddle::Queue do
  let(:queue) { Puddle::Queue.new }
  let(:failer) { lambda { raise "This should not happen" } }

  def dequeue(q)
    yielded = false
    yielded_value = nil

    open = q.deq do |value|
      yielded_value = value
      yielded = true
    end

    if yielded
      [open, yielded_value]
    else
      [open]
    end
  end

  it "maintains FIFO order" do
    queue.enq(1, &failer)
    queue.enq(2, &failer)

    dequeue(queue).should eq([true, 1])
    dequeue(queue).should eq([true, 2])
  end

  describe "#enq" do
    it "raises an error if not given an error handling block" do
      lambda { queue.enq(1) }.should raise_error(ArgumentError, "no block given")
    end

    it "enqueues an object" do
      queue.should be_empty
      queue.enq(1) { raise "enq failed" }
      queue.should_not be_empty
    end

    it "yields if equeueing failed" do
      queue.close

      error = RuntimeError.new("Enqueue failed!")
      lambda { queue.enq(1) { raise error } }.should raise_error(error)
      queue.should be_empty
    end
  end

  describe "#deq" do
    it "raises an error if not given an error handling block" do
      lambda { queue.deq }.should raise_error(ArgumentError, "no block given")
    end

    context "empty, open" do
      let(:waiter) do
        Thread.new(queue) { |q| dequeue(q) }
      end

      before { wait_until_sleep(waiter) }

      specify "is awoken when an object is added" do
        queue.enq(1) { raise "enq failed" }

        waiter.value.should eq([true, 1])
        queue.should be_empty
      end

      specify "is awoken when closed without an object" do
        queue.close

        waiter.value.should eq([false])
        queue.should be_empty
      end

      specify "is awoken when closed with an object" do
        queue.close(:thingy) { raise "close failed" }

        waiter.value.should eq([false, :thingy])
        queue.should be_empty
      end
    end

    specify "not empty, open" do
      queue.enq(1) { raise "enq failed" }

      dequeue(queue).should eq([true, 1])
      queue.should be_empty
    end

    context "not empty, not open" do
      before do
        queue.enq(1) { raise "enq failed" }
      end

      specify "when closed without an object" do
        queue.close

        dequeue(queue).should eq([false, 1])
        queue.should be_empty
      end

      specify "when closed with an object" do
        queue.close(:thingy) { raise "close failed" }

        dequeue(queue).should eq([false, 1])
        queue.should_not be_empty
      end
    end

    specify "empty, not open" do
      queue.close
      dequeue(queue).should eq([false])
    end
  end

  describe "#close" do
    it "can be closed multiple times without argument" do
      queue.close # no errors
      queue.close # no errors
    end

    it "yields if closed with an argument that cannot be pushed" do
      lambda { |b| queue.close(:thingy, &b) }.should_not yield_control
      lambda { |b| queue.close(:thingy, &b) }.should yield_control
    end

    it "returns the object queued" do
      queue.close(:thingy) { raise "close failed" }.should eq(:thingy)
    end

    it "returns nil if not closed with an object" do
      queue.close.should eq(nil)
    end
  end
end
