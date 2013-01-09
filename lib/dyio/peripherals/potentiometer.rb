require 'dyio/input'

module Bowler
  module IO
    module Peripherals

      # Represents a potentiometer input
      class Potentiometer < Input
        attr_accessor :min_val
        attr_accessor :max_val

        # Creates an input object representing a potentiometer connected
        # to the given DyIO on the given channel, using the given min and
        # max values to scale values returned by #percent and #fraction
        # (also sets the channel on the physical DyIO accordingly)
        def initialize(dyio, channel, min=0, max=1023, async=false)
          super(dyio, channel, :analog_in, async)
          @cached_val = nil
          @min_val = min
          @max_val = max
        end

        # Return the value of the potentiometer as a decimal
        # floating point number between 0.0 and 1.0, refreshing the
        # value by querying the dyio by default (although the cached value
        # can be returned by passing in false)
        def fraction(refresh=true)
          if refresh or @cached_val.nil?
            @cached_val = self.raw_value(true)
          end
          (@cached_val - @min_val)/(@max_val - @min_val).to_f
        end

        # Return the value of the potentiometer as a floating point
        # number between 0.0 and 100.0, refreshing the number by querying
        # the dyio as specified (same as `fraction(refresh)*100`)
        def percent(refresh=true)
          (self.fraction(refresh)*100)
        end

        # Returns the raw channel value returned by the dyio,
        # refreshing the cached value as specified
        def raw_value(refresh)
          if (refresh or @cached_val.nil?)
            @cached_val = self.value
          end
          @cached_val
        end

        private

        # first calculates the fractional value from the given input data,
        # and then passes that and the raw value to the event handlers
        def process_data(data)
          val = data[:channels][@channel_number].to_i(false)
          @cached_val = val
          fraction_val = (@cached_val - @min_val)/(@max_val - @min_val).to_f
          [fraction_val, @cached_val]
        end
      end
    end
  end
end
