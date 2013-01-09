require_relative 'io_channel.rb'

module Bowler
  module IO
    module Peripherals

      # Represents a servo hooked in to one of the dyio ports
      class Servo < IO::Channel

        # Creates a new servo based on the given DyIO object and channel number,
        # and sets the dyio's channel state accordingly
        def initialize(dyio, channel)
          super(dyio, channel, :servo_out, false)
        end

        # Moves the servo to the given position over the given peroid of time (in milliseconds), or
        # "immediately" (1 ms) if no time is given
        def move_to(pos, duration=1)
          self.duration = duration
          self.value = pos
        end

        # Override the DyIO power limitations for this servo channel
        def override_power=(v)
          @dyio.command_to.set_override_power v
        end
      end
    end
  end
end
