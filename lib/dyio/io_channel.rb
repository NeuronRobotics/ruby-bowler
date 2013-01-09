require_relative 'utils/array_te.rb'

module Bowler
  module IO

    # Represents a physical channel on a DyIO (either input or output)
    class Channel
      attr_reader :channel_number
      attr_reader :mode
      attr_accessor :duration
      attr_reader :dyio

      # Create a Channel object representing the given channel number
      # on the given dyio with the given mode (setting the mode accordingly),
      # and potentially locking the channel
      def initialize(dyio, channel, mode, lock)
        @dyio = dyio
        @channel_number = channel
        @locked = lock
        @async = false
        self.mode = mode

        #resync
      end

      # Gets the channel mode, potentially querying the dyio
      # to refresh the cached value
      def mode(refresh=false)
        resync if refresh
        @mode
      end

      # Checks to see if the current channel mode supports asynchronous mode
      def has_async?
        [:analog_in, :count_in_int, :count_out_int, :digital_in].include? @mode
      end

      # Checks to see if the current channel is locked
      def locked?
        return @locked
      end

      # Unlocks the current channel
      def unlock
        @locked = false
      end

      # Locks the current channel
      def lock
        @locked = true
      end

      # Toggles the lock state of the current channel
      def toggle_lock
        @locked = !@locked 
      end

      # Queries the dyio to get the current channel value, returning the value unless
      # the channel is a stream channel, in which case 0 is returned
      def value
        res = @dyio.command_to.get_channel_value @channel_number
        
        if self.stream_channel?
          0
        else
          if [:count_in_dir, :count_in_int, :count_out_dir, :count_out_int].include? self.mode
            res[:raw_val].to_i(true)
          else
            res[:raw_val].to_i(false)
          end
        end
      end

      # Sets the channel value to the given value, command the dyio to move the value to the given value,
      # using the given cached duration if applicable
      def value=(v)
        if [:count_in_int, :count_in_dir, :count_in_home, :count_out_in, :count_out_dir, :count_out_home].include? self.mode
          @dyio.command_to.set_channel_value @channel_number, v, :time => @duration, :time_size => 4, :val_size => 4
        elsif self.mode == :servo_out
          @dyio.command_to.set_channel_value @channel_number, v, :time => @duration, :time_size => 2, :val_size => 1
        else
          @dyio.command_to.set_channel_value @channel_number, v, :val_size => 1
        end
      end

      # Enables or disables async mode for this channel
      def async=(v)
        @async = v
        self.mode = self.mode # (send mode)
      end

      # Gets whether this channel is currently in async mode (does not query DyIO)
      def async?
        @async
      end

      # Gets whether this channel is currently in async mode (does not query DyIO)
      def async
        @async
      end

      # Commands the DyIO to set the channel to the given mode (if the mode is appropriate -- it raises an exception otherwise)
      # and resyncs
      def mode=(v)
        if is_mode_appropriate? v
          @dyio.command_to.set_channel_mode @channel_number, v, @async
          resync
        else
          raise "Mode #{v.to_s} is not an appropriate mode for channel #{@channel_number}!"
        end
        # TODO: implement multiple attempts?
      end

      # Checks if this is a stream channel (currently ALWAYS returns false)
      def stream_channel?
        false # TODO: implement this
      end

      private

      # resynchronizes the cached channel mode
      def resync 
        res = @dyio.command_to.get_channel_mode(@channel_number) 
        self.cached_mode = res[:mode]
      end

      # sets the cached mode without sending a command to the DyIO or resyncing
      def cached_mode=(mode)
        @mode = mode 
      end

      # UGLY, UGLY, UGLY!
      # This HUGE method checks if a given channel mode is appropriate for a given channel.  Really, the 
      # DyIO should be able to tell us this, but it doesn't (TODO: email someone about this)
      def is_mode_appropriate?(mode)
        return true if [:digital_in, :digital_out].include? mode

        if (@dyio.brownout_detection?)
          puts "#{mode.to_s} + #{@channel_number} + #{@dyio.state_of_battery_bank :a}"
          return true if mode == :servo_out and (@channel_number < 12 and @dyio.state_of_battery_bank(:a) != :regulated)
          return true if mode == :servo_out and (@channel_number > 11 and @dyio.state_of_battery_bank(:b) != :regulated)
        else
          return true if mode == :servo_out
        end

        return true if (@channel_number == 0 and mode == :spi_clock)
        return true if (@channel_number == 1 and mode == :spi_miso)
        return true if (@channel_number == 2 and mode == :spi_mosi)

        case @channel_number
          when (0..3)
            return true if [:count_in_home, :count_out_home].include? mode
          when [16,18,20,22]
            return true if [:count_in_dir, :count_out_dir].include? mode
          when [17,19,21,23]
            return true if [:count_in_int, :count_out_int].include? mode
          when (8..15)
            return true if mode == :analog_in
        end

        case @channel_number
          when (4..7)
            return true if [:pwm_out, :dc_motor_vel].include? mode
          when (8..1)
            return true if mode == :dc_motor_dir
        end

        return true if @channel_number == 16 and mode == :usart_tx
        return true if @channel_number == 17 and mode == :usart_rx

        return true if @channel_number == 23 and mode == :ppm_in

        return false
      end

    end
  end
end
