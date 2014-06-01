class Puddle
  # Similar to the stdlib Queue, but with an added method {#drain}.
  class Queue
    class DrainedError < Error; end

    def initialize
      @queue = []
      @queue_mutex = Mutex.new
      @queue_cond = Puddle::ConditionVariable.new
    end

    # Drain the Queue.
    #
    # @return [Array] contents of the queue
    def drain
      @queue_mutex.synchronize do
        queue.tap do
          @queue = nil
          @queue_cond.broadcast
        end
      end
    end

    # Push an object into the queue.
    #
    # @see {#pop}
    # @param obj
    # @raise [DrainedError] if the queue has been drained.
    def enq(obj)
      @queue_mutex.synchronize do
        queue.push(obj)
        @queue_cond.signal
      end

      obj
    end

    # Retrieve an object from the queue, or block until one is available.
    #
    # @see {#push}
    # @return obj
    # @raise [DrainedError] if the queue has been drained.
    def deq
      @queue_mutex.synchronize do
        @queue_cond.wait_until(@queue_mutex) { not queue.empty? }
        queue.shift
      end
    end

    private

    def queue
      @queue or raise DrainedError, "queue is drained"
    end
  end
end
