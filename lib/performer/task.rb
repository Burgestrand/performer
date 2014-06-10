require "timeout"

class Performer
  # A task is constructed with a callable object (like a proc), and provides ways to:
  #
  # - call the contained object, once and only once
  # - retrieve the value from the execution of the callable, and wait if execution is not finished
  # - cancel a task, and as such wake up all waiting for the task value
  #
  # Furthermore, the Task public API is thread-safe, and a resolved task will never change value.
  #
  # @example constructing a task
  #   task = Task.new(lambda { 1 + 1 })
  #   worker = Thread.new(task, &:call)
  #   task.value # => 2
  class Task
    # Used for the internal task state machine.
    #
    # @api private
    Transitions = {
      idle: { executing: true, cancelled: true },
      executing: { error: true, value: true },
    }

    # Allows easy capturing of all task-specific errors.
    class Error < Performer::Error; end

    # Raised in {Task#value} if the task was cancelled.
    class CancelledError < Error; end

    # Raised from {Task#call} or {Task#cancel} on invariant errors.
    class InvariantError < Error; end

    # Create a new Task from a callable object.
    #
    # @param [#call] callable
    # @param [Array<String>] backtrace
    def initialize(callable, backtrace = nil)
      @callable = callable
      @backtrace = backtrace

      @value_mutex = Mutex.new
      @value_cond = Performer::ConditionVariable.new

      @value = nil
      @value_type = :idle
    end

    # Execute the task. Arguments and block are passed on to the callable.
    #
    # @note A task can only be called once.
    # @note A task can not be called after it has been cancelled.
    # @note A task swallows standard errors during execution, but all other errors are propagated.
    #
    # When execution finishes, all waiting for {#value} will be woken up with the result.
    #
    # @return [Task] self
    def call(*args, &block)
      set(:executing) { nil }

      begin
        value = @callable.call(*args, &block)
      rescue Exception => ex
        slice_length = caller.length + 1
        ex.backtrace.slice!(-slice_length, slice_length)
        ex.backtrace[0] << " (task failed: #{ex.message} (#{ex.class}))" if @backtrace

        set(:error) { ex }
        raise ex unless ex.is_a?(StandardError)
      else
        set(:value) { value }
      end

      self
    end

    # Cancel the task. All waiting for {#value} will be woken up with a {CancelledError}.
    #
    # @note This cannot be done while the task is executing.
    # @note This cannot be done if the task has finished executing.
    #
    # @param [String] message for the cancellation error
    def cancel(message = "task was cancelled")
      backtrace = caller(0)
      backtrace[0] << " (Task#cancel: #{message})"

      set(:cancelled) do
        error = CancelledError.new(message)
        error.set_backtrace(backtrace)
        error
      end
    end

    # Retrieve the value of the task. If the task is not finished, this will block.
    #
    # @example waiting with a timeout and a block
    #   task.value(1) { raise MyOwnError, "Timed out after 1s" }
    #
    # @param [Integer, nil] timeout how long to wait for value before timing out, nil if wait forever
    # @yield if block given, yields instead of raising an error on timeout
    # @raise [TimeoutError] if waiting timeout was reached, and no block was given
    def value(timeout = nil)
      unless done?
        @value_mutex.synchronize do
          @value_cond.wait_until(@value_mutex, timeout) { done? }
        end
      end

      if value?
        return @value
      elsif error? or cancelled?
        raise prepare_backtrace(@value)
      elsif block_given?
        yield
      else
        raise TimeoutError, "retrieving value timed out after #{timeout}s"
      end
    end

    private

    def error?
      @value_type == :error
    end

    def value?
      @value_type == :value
    end

    def cancelled?
      @value_type == :cancelled
    end

    def done?
      value? or error? or cancelled?
    end

    def prepare_backtrace(error)
      error = error.dup

      value_backtrace = caller(1)

      if @backtrace
        error.backtrace.unshift(*value_backtrace)
        error.backtrace.concat(@backtrace)
      else
        error.backtrace.concat(value_backtrace)
      end

      error
    end

    # @param [Symbol] type
    # @yield to set the value
    def set(type)
      @value_mutex.synchronize do
        unless Transitions.fetch(@value_type, {}).has_key?(type)
          raise InvariantError, "transition from #{@value_type} to #{type} is not allowed"
        end

        @value_type = type
        @value = yield
        @value_cond.broadcast if done?

        @value
      end
    end
  end
end
