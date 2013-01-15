require 'dyio/input'

module Bowler
  module IO
    module Peripherals

      # Represents a UART peripherial attached to the dyio
      class UART
        # @!attribute [r] receiver
        #   @return [UARTRx] the receiver input associated with this UART
        attr_reader :receiver
        
        # @!attribute [r] transmitter
        #   @return [UARTTx] the transmitter peripheral object associated with this UART
        attr_reader :transmitter

        # Represents a UART receiver channel
        class UARTRx < Input
          # Create a new UART receiver input channel
          # @param [DyIO] dyio the {DyIO} representing the device to which the peripheral is connected
          # @param [Fixnum] channel the dyio channel to which the peripheral is connected
          # @param [true,false] async whether to operate this device in asynchronous mode (NOT CURRENTLY SUPPORTED)
          def initialize(dyio, channel, async=false)
            super(dyio, channel, :usart_rx, async)
          end

          private
          def process_data(data)

          end
        end

        # Represents a UART transmitter channel
        class UARTTx < IO::Channel
          # Create a new UART transmitter channel
          # @param [DyIO] dyio the {DyIO} representing the device to which the peripheral is connected
          # @param [Fixnum] channel the dyio channel to which the peripheral is connected
          def initialize(dyio, channel)
            super(dyio, channel, :usart_tx, false)
          end
        end

        # Create a new UART object representing a UART peripherial connected to the
        # given DyIO at the given input and output channels.
        # @param [DyIO] dyio the {DyIO} representing the device to which the peripheral is connected
        # @param [Fixnum] in_channel the dyio channel to which the UARTRx is connected
        # @param [Fixnum] out_channel the dyio channel to which the UARTTx is connected
        # @param [true,false] async whether to operate this device in asynchronous mode (NOT CURRENTLY SUPPORTED)
        def initialize(dyio, in_channel = 17, out_channel = 16, async = false)
          @receiver = UARTRx.new(dyio, in_channel)
          @transmitter = UARTTx.new(dyio, out_channel)
        end

        # Transmits a sequences of bytes to the peripheral
        # @param [Array<Fixnum>] bytes the bytes to transmit
        def transmit(bytes)
          @transmitter.value = bytes
        end

        # Receives a sequence of bytes from the peripheral
        # @return [String] the bytes returned by the receiver
        def receive
          @transmitter.value
        end
      end
    end
  end
end
