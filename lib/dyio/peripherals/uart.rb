require_relative 'input.rb'

module Bowler
  module IO
    module Peripherals

      # Represents a UART peripherial attached to the dyio
      class UART
        attr_reader :receiver
        attr_reader :transmitter

        # Represents a UART receiver channel
        class UARTRx < Input
          def initialize(dyio, channel, async=false)
            super(dyio, channel, :usart_rx, async)
          end

          private
          def process_data(data)

          end
        end

        # Represents a UART transmitter channel
        class UARTTx < IO::Channel
          def initialize(dyio, channel)
            super(dyio, channel, :usart_tx, false)
          end
        end

        # Create a new UART object representing a UART peripherial connected to the
        # given DyIO at the given input and output channels.
        def initialize(dyio, in_channel = 17, out_channel = 16, async = false)
          @receiver = UARTRx.new(dyio, in_channel)
          @transmitter = UARTTx.new(dyio, out_channel)
        end

        # Transmits a sequences of bytes to the peripheral
        def transmit(bytes)
          @transmitter.value = bytes
        end

        # Receives a sequence of bytes from the peripheral
        def receive
          @transmitter.value
        end
      end
    end
  end
end
