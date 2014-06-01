describe Puddle::Queue do
  let(:queue) { Puddle::Queue.new }

  it "maintains FIFO order" do
    queue.enq(1)
    queue.enq(2)

    queue.deq.should eq(1)
    queue.deq.should eq(2)
  end

  describe "#enq" do
    it "raises an error if the queue has been drained" do
      queue.drain

      lambda { queue.enq(1) }.should raise_error(Puddle::Queue::DrainedError)
    end
  end

  describe "#deq" do
    it "raises an error if the queue has been drained" do
      queue.drain

      lambda { queue.deq }.should raise_error(Puddle::Queue::DrainedError)
    end

    it "raises an error if the queue is drained while waiting" do
      waiter = Thread.new(queue) { |q| q.deq }
      wait_until_sleep(waiter)

      queue.drain
      lambda { waiter.value }.should raise_error(Puddle::Queue::DrainedError)
    end

    it "blocks until an item is available for pop" do
      waiter = Thread.new(queue) { |q| q.deq }
      wait_until_sleep(waiter)

      queue.enq(1)
      waiter.value.should eq(1)
    end
  end

  describe "#drain" do
    it "raises an error if queue has already been drained" do
      queue.drain

      lambda { queue.drain }.should raise_error(Puddle::Queue::DrainedError)
    end

    it "returns the contents of the queue at the moment of drain" do
      queue.enq(1)
      queue.enq(2)
      queue.enq(3)
      queue.deq

      queue.drain.should eq([2, 3])
    end
  end
end
