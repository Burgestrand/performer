require "puddle/version"
require "puddle/condition_variable"
require "puddle/task"

class Puddle
  class Error < StandardError; end
  class TerminatedError < Error; end
  class OwnershipError < Error; end
  class DoubleCallError < Error; end
  class CancelledError < Error; end

  def initialize
    @queue = Queue.new
    @running = true

    @loop = Task.new(lambda do |queue|
      while @running
        task = queue.pop
        task.call rescue nil
      end
    end)

    @thread = Thread.new(@queue, &@loop)
  end

  # @return [Thread] the underlying Puddle thread.
  attr_reader :thread

  # @return [Boolean] true if the puddle is accepting work.
  def alive?
    @queue and running?
  end

  # Synchronously schedule a block for execution in the Puddle.
  #
  # If run from inside the Puddle thread, the block will run
  # instantaneously, before any other tasks in the queue.
  #
  # @param [Integer, nil] timeout (see Task#value)
  # @raise [TimeoutError]
  def sync(timeout = nil, &block)
    if Thread.current == @thread
      yield
    else
      schedule(block).value(timeout)
    end
  end

  # Asynchronously schedule a block for execution in the Puddle.
  #
  # @return [Puddle::Task]
  # @raise [TerminatedError] if Puddle has been terminated
  def async(&block)
    schedule(block)
  end

  # Request a fair shutdown of the Puddle. This will allow the Puddle
  # to finish all remaining work in the queue before terminating, but
  # it will not allow additional work to be queued.
  #
  # If a block is given, it will execute inside the Puddle as the final
  # task to ever run in the Puddle.
  #
  # @param [Integer, nil] timeout (see Task#value)
  def terminate(timeout = nil)
    queue, @queue = @queue, nil
    task = schedule(queue, lambda do
      @running = false
      yield if block_given?
    end)
    task.value(timeout)
  end

  private

  def running?
    @running and @thread.alive?
  end

  def schedule(queue = @queue, block)
    if queue and running?
      task = Task.new(@thread, block)
      queue << task
      task
    else
      raise TerminatedError, "#{self} is terminated"
    end
  end
end
