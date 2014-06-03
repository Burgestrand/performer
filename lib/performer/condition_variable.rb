require "forwardable"

class Performer
  # A custom ConditionVariable.
  #
  # It delegates to ConditionVariable for #wait, #signal and #broadcast,
  # but also provides a reliable {#wait_until}.
  #
  # @api private
  class ConditionVariable
    extend Forwardable

    def initialize
      @condvar = ::ConditionVariable.new
    end

    def_delegators :@condvar, :wait, :signal, :broadcast

    # Wait until a given condition is true, determined by
    # calling the given block.
    #
    # @note This method will honor the timeout, even in the case
    #       of spurious wakeups.
    #
    # @example usage
    #   mutex.synchronize do
    #     condvar.wait_until(mutex, 1) { done? }
    #   end
    #
    # @param [Mutex] mutex
    # @param [Integer, nil] timeout
    # @yield for condition
    def wait_until(mutex, timeout = nil)
      unless block_given?
        raise ArgumentError, "no block given"
      end

      if timeout
        finished = Time.now + timeout
        until yield
          timeout = finished - Time.now
          break unless timeout > 0
          wait(mutex, timeout)
        end
      else
        wait(mutex) until yield
      end

      return self
    end
  end
end
