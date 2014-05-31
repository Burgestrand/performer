require "puddle/version"
require "puddle/condition_variable"
require "puddle/task"

class Puddle
  class Error < StandardError; end
  class TerminatedError < Error; end
  class OwnershipError < Error; end
  class DoubleCallError < Error; end

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

  # Synchronously schedule a block for execution in the Puddle.
  #
  # If run from inside the Puddle thread, the block will run
  # instantaneously, before any other tasks in the queue.
  #
  # @param [Integer, nil] timeout (see Task#value)
  def sync(timeout = nil, &block)
    schedule(block).value(timeout)
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

  def schedule(queue = @queue, block)
    if queue and @running and @thread.alive?
      task = Task.new(@thread, block)
      queue << task
      task
    else
      raise TerminatedError, "#{self} is terminated"
    end
  end
end
