require_relative 'input.rb'

module Bowler
  module IO
    module Peripherals

      # An input object representing a simple binary input (such as a button, or other binary digital input)
      class Button < Input
        attr_accessor :active_high

        # Creates an input object representing a button or other binary digital input device connected
        # to the given DyIO on the given channel, assuming >0 -> on, 0 -> off unless inverted is set to
        # true.
        def initialize(dyio, channel, inverted=false, async=false)
          super(dyio, channel, :digital_in, async)
          @cached_val = nil
          @active_high = !inverted
          @last_val = (@active_high ? 0 : 1)
        end

        def on? (refresh=true)
          if refresh or @cached_val.nil?
            @cached_val = if @active_high then (self.value != 0) else (self.value == 0) end
          end

          @cached_val
        end

        private

        # Converts the raw data to a boolean value
        def process_data(data)
          val = data[:channels][@channel_number].to_i(false)
          @cached_val = if @active_high then (val != 0) else (val == 0) end
          @cached_val
        end
      end
    end
  end
end
