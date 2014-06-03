class Performer
  # Similar to the stdlib Queue, but with a thread-safe way of closing it down.
  class Queue
    def initialize
      @queue = []
      @queue_mutex = Mutex.new
      @queue_cond = Performer::ConditionVariable.new
      @undefined = {}
      @open = true
    end

    # Push an object into the queue, or yield if not possible.
    #
    # @example pushing an item onto the queue
    #   queue.enq(obj) do
    #     raise "Unable to push #{obj} into queue!"
    #   end
    #
    # @yield if obj could not be pushed onto the queue
    # @param obj
    # @return obj
    # @raise [ArgumentError] if no block given
    def enq(obj)
      unless block_given?
        raise ArgumentError, "no block given"
      end

      pushed = false
      @queue_mutex.synchronize do
        pushed = try_push(obj)
        @queue_cond.signal
      end
      yield if not pushed

      obj
    end

    # Retrieve an object from the queue, or block until one is available.
    #
    # The behaviour is as follows:
    # - empty, open: block until queue is either not empty, or open
    # - not empty, open: yield an item off the queue, return true
    # - not empty, not open: yield an item off the queue, return false
    # - empty, not open: return false
    #
    # @example
    #   open = queue.deq do |obj|
    #     # do something with obj
    #   end
    #
    # @yield [obj] an item retrieved from the queue, if available
    # @return [Boolean] true if queue is open, false if open
    # @raise [ArgumentError] if no block given
    def deq
      unless block_given?
        raise ArgumentError, "no block given"
      end

      obj, was_open = @queue_mutex.synchronize do
        while empty? and open?
          @queue_cond.wait(@queue_mutex)
        end

        obj = if empty?
          undefined
        else
          queue.shift
        end

        [obj, open?]
      end

      yield obj unless undefined.equal?(obj)
      was_open
    end

    # Close the queue, optionally pushing an item onto the queue right before close.
    #
    # @example close and enqueue
    #   queue.close(object) do
    #     raise "Queue is was already closed!"
    #   end
    #
    # @example close without enqueue
    #   queue.close # => no need for block, since no argument
    #
    # @yield if obj could not be pushed onto the queue
    # @param [Object, nil] obj
    # @return [Object, nil] obj
    # @raise [ArgumentError] if obj given, but no block given
    def close(obj = undefined)
      if undefined.equal?(obj)
        @queue_mutex.synchronize do
          @open = false
          @queue_cond.broadcast
        end

        nil
      elsif not block_given?
        raise ArgumentError, "no block given"
      else
        pushed = false
        @queue_mutex.synchronize do
          pushed = try_push(obj)
          @open = false
          @queue_cond.broadcast
        end
        yield if not pushed

        obj
      end
    end

    # @return [Boolean] true if queue is empty
    def empty?
      queue.empty?
    end

    private

    attr_reader :undefined
    attr_reader :queue

    def try_push(obj)
      if open?
        queue.push(obj)
        true
      else
        false
      end
    end

    def open?
      @open
    end
  end
end
