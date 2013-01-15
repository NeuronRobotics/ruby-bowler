require 'dyio/input'

module Bowler
  module IO
    module Peripherals

      # Represents a potentiometer input or other analog input
      #
      class Potentiometer < Input
        # @!attribute [rw] min_val
        #   @return [Fixnum] the raw value from the dyio to be treated as the minimum value
        #   @see #fraction
        attr_accessor :min_val

        # @!attribute [rw] max_val
        #   @return [Fixnum] the raw value from the dyio to be treated as the maximum value
        #   @see #fraction
        attr_accessor :max_val

        # Creates an input object representing a potentiometer
        # @param [DyIO] dyio the {Bowler::DyIO} object to which this potentiometer is connected
        # @param [Fixnum] channel the channel number on the dyio to which this potentiometer is connected
        # @param [Fixnum] min the value for {#min_val}
        # @param [Fixnum] max the value for {#max_val}
        def initialize(dyio, channel, min=0, max=1023, async=false)
          super(dyio, channel, :analog_in, async)
          @cached_val = nil
          @min_val = min
          @max_val = max
        end

        # Get the value of the potentiometer as a decimal value
        # between 0.0 and 1.0, based on {#min_val} and {#max_val}
        # @return [Float] a value between 0.0 and 1.0
        # @param refresh [true,false] if `true`, actually query the dyio for a value (if `false`, return the cached value)
        def fraction(refresh=true)
          if refresh or @cached_val.nil?
            @cached_val = self.raw_value(true)
          end
          (@cached_val - @min_val)/(@max_val - @min_val).to_f
        end

        # Return the value of the potentiometer as a floating point
        # number between 0.0 and 100.0,
        # @param (see #fraction)
        # @return [Float] a value between 0.0 and 100.0
        # @see #fraction #fraction -- This method is equivalent to `fraction*100`
        def percent(refresh=true)
          (self.fraction(refresh)*100)
        end

        # Gets the raw value of the input (without adjustment from the dyio)
        # @param (see #fraction)
        # @return [Fixnum] a value between 0 and 1023
        def raw_value(refresh)
          if (refresh or @cached_val.nil?)
            @cached_val = self.value
          end
          @cached_val
        end

        private

        # First calculates the fractional value from the given input data,
        # and then passes that and the raw value to the event handlers
        # @return [[Float,Fixnum]] the fractional value and the raw value
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
