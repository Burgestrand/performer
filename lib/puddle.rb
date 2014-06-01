require "puddle/version"

class Puddle
  class Error < StandardError; end
  class TerminatedError < Error; end

  def initialize
    @queue = Puddle::Queue.new
    @running = true

    @thread = Thread.new(@queue) do |queue|
      begin
        while @running
          begin
            queue.deq.call
          rescue Puddle::Task::Error
            # Ignore. Task could have been cancelled,
            # or executed from somewhere else. Oh well.
          end
        end
      ensure
        queue.drain.each do |task|
          task.cancel rescue nil
        end
      end
    end
  end

  # @return [Thread] the underlying Puddle thread.
  attr_reader :thread

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
      queue.enq Task.new(block)
    else
      raise TerminatedError, "#{self} is terminated"
    end
  end
end

require "puddle/condition_variable"
require "puddle/queue"
require "puddle/task"
