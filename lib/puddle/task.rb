require "timeout"

class Puddle
  # A Task is constructed with an owner thread, and a callable object.
  #
  # A Task has the following guarantees:
  # - it is thread-safe
  # - it can only be {#call}ed once
  # - it's {#value} will never change, once set
  class Task
    Transitions = {
      idle: { executing: true, cancelled: true },
      executing: { error: true, value: true },
    }

    class CancelledError < Error; end
    class TransitionError < Error; end

    # Create a new Task from a callable object.
    #
    # @param [#call] callable
    def initialize(callable)
      @callable = callable

      @value_mutex = Mutex.new
      @value_cond = Puddle::ConditionVariable.new

      @value = nil
      @value_type = :idle
    end

    # Call the callable object given to {#initialize}. Arguments and block
    # are passed on to the callable.
    #
    # Once the call finishes, or if it raises an error, the value of the Task
    # will be set and any threads waiting for the value will be woken up.
    def call(*args, &block)
      set(:executing) { nil }

      begin
        value = @callable.call(*args, &block)
        set(:value) { value }
      rescue Exception => ex
        set(:error) { ex }
        raise ex
      end
    end

    # Cancel the task.
    #
    # This cannot be done while the task is executing, or after task has a result.
    #
    # @param [String] message will be stored for retrival within {#value}
    def cancel(message = "task was cancelled")
      set(:cancelled) { CancelledError.new(message) }
    end

    # Retrieve the value the task resolved to, or wait if it has not yet finished.
    #
    # If the Task resulted in an error, that error will be raised.
    #
    # @param [Integer, nil] timeout how long to wait for value before timing out
    # @yield if block given, yields instead of raising an error on timeout
    # @raise [TimeoutError] if waiting timeout was reached
    def value(timeout = nil)
      unless done?
        @value_mutex.synchronize do
          @value_cond.wait_until(@value_mutex, timeout) { done? }
        end
      end

      if value?
        return @value
      elsif error? or cancelled?
        raise @value
      elsif block_given?
        yield
      else
        raise TimeoutError, "retrieving value timed out after #{timeout}s"
      end
    end

    # @return [Proc]
    def to_proc
      method(:call).to_proc
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

    # @param [Symbol] type
    # @yield to set the value
    def set(type)
      @value_mutex.synchronize do
        unless Transitions.fetch(@value_type, {}).has_key?(type)
          raise TransitionError, "transition from #{@value_type} to #{type} is not allowed"
        end

        @value_type = type
        @value = yield
        @value_cond.broadcast if done?

        @value
      end
    end
  end
end
