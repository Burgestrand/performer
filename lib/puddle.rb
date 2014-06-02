require "puddle/version"

class Puddle
  class Error < StandardError; end
  class ShutdownError < Error; end

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
          begin
            task.cancel
          rescue Puddle::Task::Error
            # Ignore it. We're exiting anyway.
          end
        end
      end
    end
  end

  # @return [Thread] the underlying Puddle thread.
  attr_reader :thread

  # Synchronously schedule a block for execution.
  #
  # If run from inside a task in the same puddle, the block is executed
  # immediately. You can avoid this behavior by using {#async} instead.
  #
  # @param [Integer, nil] timeout (see Task#value)
  # @yield block to be executed
  # @return whatever the block returned
  # @raise [TimeoutError] if waiting for the task to finish timed out
  # @raise [ShutdownError] if shutdown has been requested
  def sync(timeout = nil, &block)
    if Thread.current == @thread
      yield
    else
      schedule(block).value(timeout)
    end
  end

  # Asynchronously schedule a block for execution.
  #
  # @yield block to be executed
  # @return [Puddle::Task]
  # @raise [ShutdownError] if shutdown has been requested
  def async(&block)
    schedule(block)
  end

  # Asynchronously schedule a shutdown, allowing all previously queued tasks to finish.
  #
  # @note No additional tasks will be accepted during shutdown.
  #
  # @return [Puddle::Task]
  def shutdown
    queue, @queue = @queue, nil
    schedule(queue, lambda do
      @running = false
      yield if block_given?
    end)
  end

  private

  def schedule(queue = @queue, block)
    if queue
      begin
        queue.enq Task.new(block)
      rescue Puddle::Queue::DrainedError
        raise ShutdownError, "puddle is shutdown"
      end
    else
      raise ShutdownError, "puddle is shutdown"
    end
  end
end

require "puddle/condition_variable"
require "puddle/queue"
require "puddle/task"
