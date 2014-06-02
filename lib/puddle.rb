require "puddle/version"

class Puddle
  class Error < StandardError; end
  class ShutdownError < Error; end

  def initialize
    @queue = Puddle::Queue.new
    @running = true
    @thread = Thread.new(&method(:run_loop))
  end

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
      async(&block).value(timeout)
    end
  end

  # Asynchronously schedule a block for execution.
  #
  # @yield block to be executed
  # @return [Puddle::Task]
  # @raise [ShutdownError] if shutdown has been requested
  def async(&block)
    task = Task.new(block)
    @queue.enq(task) { raise ShutdownError, "puddle is shutdown" }
  end

  # Asynchronously schedule a shutdown, allowing all previously queued tasks to finish.
  #
  # @note No additional tasks will be accepted after shutdown.
  #
  # @return [Puddle::Task]
  def shutdown
    task = Task.new(lambda do
      @running = false
      yield if block_given?
    end)

    @queue.close(task) { raise ShutdownError, "puddle is shutdown" }
  end

  private

  def run_loop
    while @running
      open = @queue.deq do |task|
        begin
          task.call
        rescue Puddle::Task::Error
          # No op. Allows cancelling scheduled tasks.
        end
      end

      if not open and @queue.empty?
        @running = false
      end
    end
  ensure
    @queue.close
    until @queue.empty?
      @queue.deq do |task|
        begin
          task.cancel
        rescue Puddle::Task::Error
          # Shutting down. Don't care.
        end
      end
    end
  end
end

require "puddle/condition_variable"
require "puddle/queue"
require "puddle/task"
