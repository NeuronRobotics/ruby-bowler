require 'dyio/input'

module Bowler
  module IO
    module Peripherals

      # An input object representing a simple binary input (such as a button, or other binary digital input)
      class Button < Input
        # @!attribute [rw] active_high
        #   @return [true,false] whether or not to treat the input as enabled when the value is high (1)
        attr_accessor :active_high

        # Creates an input object representing a button or other binary digital input device connected
        # @param [DyIO] dyio the {DyIO} representing the device to which the peripheral is connected
        # @param [Fixnum] channel the dyio channel to which the peripheral is connected
        # @param [true,false] inverted the opposite of {#active_high}
        # @param [true,false] async whether to operate this device in asynchronous mode
        def initialize(dyio, channel, inverted=false, async=false)
          super(dyio, channel, :digital_in, async)
          @cached_val = nil
          @active_high = !inverted
          @last_val = (@active_high ? 0 : 1)
        end

        # Gets whether the input is "enabled" (e.g. pushed down for a button)
        # @param (see Bowler::IO::Peripherals::Potentiometer#raw_value)
        # @return [true,false] whether or not the input is active
        def on? (refresh=true)
          if refresh or @cached_val.nil?
            @cached_val = if @active_high then (self.value != 0) else (self.value == 0) end
          end

          @cached_val
        end

        private

        # Converts the raw data to a boolean value
        # @return [true,false] whether or not the input is active
        def process_data(data)
          val = data[:channels][@channel_number].to_i(false)
          @cached_val = if @active_high then (val != 0) else (val == 0) end
          @cached_val
        end
      end
    end
  end
end
