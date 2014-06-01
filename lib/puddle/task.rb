require "timeout"

class Puddle
  # A Task is constructed with an owner thread, and a callable object.
  #
  # A Task has the following guarantees:
  # - it is thread-safe
  # - it can only be {#call}ed once
  # - it's {#value} will never change, once set
  class Task
    # Create a new Task, optionally belonging to the given thread.
    #
    # @param [Thread] thread
    # @param [#call] callable
    def initialize(thread = nil, callable)
      @thread = thread
      @callable = callable
      @callable_mutex = Mutex.new

      @value_mutex = Mutex.new
      @value_cond = Puddle::ConditionVariable.new

      @value = nil
      @value_type = nil
    end

    # Call the callable object given to {#initialize}. Arguments and block
    # are passed on to the callable.
    #
    # Once the call finishes, or if it raises an error, the value of the Task
    # will be set and any threads waiting for the value will be woken up.
    #
    # @raise [OwnershipError] if called from the wrong thread
    # @raise [DoubleCallError] if called more than once
    def call(*args, &block)
      if @thread and @thread != Thread.current
        raise OwnershipError, "#{@thread} is not #{Thread.current}"
      end

      callable = @callable_mutex.synchronize do
        @callable.tap { @callable = nil }
      end

      if callable.nil?
        raise DoubleCallError, "I have already been called!"
      end

      begin
        value = callable.call(*args, &block)
        set(:value) { value }
      rescue Exception => ex
        set(:error) { ex }
        raise ex
      end
    end

    # Retrieve the value the task resolved to, or wait if it has not yet finished.
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
      elsif error?
        raise @value
      elsif block_given?
        yield
      else
        raise TimeoutError, "retrieving value timed out after #{timeout}s"
      end
    end

    # @return [Boolean] true if terminated with an error
    def error?
      @value_type == :error
    end

    # @return [Boolean] true if terminated with a value
    def value?
      @value_type == :value
    end

    # @return [Boolean] true if finished executing
    def done?
      value_type = @value_type
      not value_type.nil?
    end

    # @return [#call]
    def to_proc
      method(:call).to_proc
    end

    private

    def set(type)
      @value_mutex.synchronize do
        raise Error, "future is already done; this should never happen!" if done?

        @value_type = type
        @value = yield
        @value_cond.broadcast

        @value
      end
    end
  end
end
