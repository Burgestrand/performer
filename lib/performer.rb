require "performer/version"

# Performer is the main entry point and namespace of the Performer gem.
# It provides methods for synchronously and asynchronously scheduling
# blocks for execution in the performer thread, and a way to shut down
# the performer cleanly.
#
# @note The Performer is thread-safe.
#
# @example usage
#   performer = Performer.new
#   performer.sync { 1 + 1 } # => 2
#   performer.async { 1 + 1 } # => Performer::Task
class Performer
  # All internal errors inherit from Performer::Error.
  class Error < StandardError; end

  # Raised by {Performer#shutdown}.
  class ShutdownError < Error; end

  def initialize
    @queue = Performer::Queue.new
    @running = true
    @thread = Thread.new(&method(:run_loop))

    @current_task = nil
    @shutdown_task = Task.new(lambda do
      @running = false
      nil
    end)
  end

  # If you ever need to forcefully kill the Performer (don't do that),
  # here's the thread you'll need to attack.
  #
  # @return [Thread]
  attr_reader :thread

  # Synchronously schedule a block for execution.
  #
  # If run from inside a task in the same performer, the block is executed
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
      enq(block, nil).value(timeout)
    end
  end

  # Asynchronously schedule a block for execution.
  #
  # @yield block to be executed
  # @return [Performer::Task]
  # @raise [ShutdownError] if shutdown has been requested
  def async(&block)
    enq(block, caller(0))
  end

  # Asynchronously schedule a shutdown, allowing all previously queued tasks to finish.
  #
  # @note No additional tasks will be accepted after shutdown.
  #
  # @return [Performer::Task]
  # @raise [ShutdownError] if performer is already shutdown
  def shutdown
    @queue.close(@shutdown_task) do
      raise ShutdownError, "performer is shut down"
    end

    @shutdown_task
  end

  private

  def enq(block, backtrace)
    task = Task.new(block, backtrace)
    @queue.enq(task) { raise ShutdownError, "performer is shut down" }
  end

  def run_loop
    while @running
      open = @queue.deq { |task| with_task(task, &:call) }

      if not open and @queue.empty?
        @running = false
      end
    end
  ensure
    @queue.close
    until @queue.empty?
      @queue.deq { |task| with_task(task, &:cancel) }
    end
  end

  def with_task(task)
    @current_task = task
    yield task
  rescue Performer::Task::Error
    # Performer calling task does not care if you cancelled
    # task, or if you called task earlier. We skip it.
  ensure
    @current_task = nil
  end
end

require "performer/condition_variable"
require "performer/queue"
require "performer/task"
