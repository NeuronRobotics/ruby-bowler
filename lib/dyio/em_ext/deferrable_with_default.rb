require 'eventmachine'

module Bowler

  # Represents a deferrable object that can have a default
  # callback and errback that run before any callbacks and choose
  # whether to run those callbacks.  Such a default callback should take the deffered
  # arguments (as a standard callback would), as well as a single callback in the form of
  # a block.  Note: the default callback and errback only run if there is at least one callback
  # or errback, respectively.
  class DeferrableWithDefaults
    include EventMachine::Deferrable

    def default_callback(&blk)
      @default_callback = blk
    end

    def default_errback(&blk)
      @default_errback = blk
    end

    alias_method :orig_set_deferred_status, :set_deferred_status
    def set_deferred_status status, *args
      cancel_timeout
      @errbacks ||= nil
      @callbacks ||= nil
      @deferred_status = status
      @deferred_args = args
      case @deferred_status
      when :succeeded
        if @callbacks
          while cb = @callbacks.pop
            @default_callback.call(*@deferred_args, &cb)
          end
        end
        @errbacks.clear if @errbacks
      when :failed
        if @errbacks
          while eb = @errbacks.pop
            @default_errback.call(*@deferred_args, &eb)
          end
        end
        @callbacks.clear if @callbacks
      end
    end
  end
end
