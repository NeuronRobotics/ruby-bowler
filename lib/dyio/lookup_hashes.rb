module Bowler
  class CommandHandler
    # A hash to convert raw channel mode codes to human readable symbol names
    CHAN_MODE_NAMES =
    {
      0x00 => :no_change,
      0x01 => :off,
      0x02 => :digital_in,
      0x03 => :digital_out,
      0x04 => :analog_in,
      0x05 => :analog_out,
      0x06 => :pwm_out,
      0x07 => :servo_out,
      0x08 => :usart_tx,
      0x09 => :usart_rx,
      0x0A => :spi_mosi,
      0x0B => :spi_miso,
      0x0C => :spi_clock,
      0x0D => :spi_select,
      0x0E => :count_in_int,
      0x0F => :count_in_dir,
      0x10 => :count_in_home,
      0x11 => :count_out_int,
      0x12 => :count_out_dir,
      0x13 => :count_in_home,
      0x14 => :dc_motor_vel,
      0x15 => :dc_motor_dir,
      0x16 => :ppm_in
    }

    # A hash to convert human readable symbols for channel modes to raw channel mode codes
    CHAN_MODE_VALS = CHAN_MODE_NAMES.invert
  end
  
  # A hash to convert special dyio event names to human readable symbols
  EVENT_LOOKUP_NAMES =
  {
    '_png' => :ping,
    '_pwr' => :power,
    'gacv' => :channel_values,
    'gchv' => :channel_value,
    'gacm' => :channel_modes,
    'gchm' => :channel_mode,
    'schv' => :set_channel_value,
    'schm' => :set_channel_mode,
    '_err' => :error,
    '_rdy' => :ready,
    '_rev' => :firmware_revision
  }

  # A hash to convert human readable symbol event names to dyio event codes
  EVENT_LOOKUP_RPCS = EVENT_LOOKUP_NAMES.invert

  class BowlerException

    # A hash to convert error zone codes to human readable symbols
    ERR_ZONE_NAME_LOOKUP =
    {
      0 => :comm_stack,
      85 => :coprocessor,
      1 => :get_parser,
      2 => :post_parser,
      3 => :config,
      6 => :config
    }

    # a hash to convert zone numbers and error codes to human readable symbols
    ERR_SECTION_NAME_LOOKUP =
    {
      0 =>
      {
        0x7f => :invalid_method,
        0 => :non_synchronous,
        1 => :undefined_get,
        2 => :undefined_post,
        3 => :undefined_critical
      },
      85 => 
      {
        1 => :not_responding,
        2 => :not_responding
      },
      1 => { 0 => :invalid_channel },
      2 => 
      {
        0 => :value_not_set,
        1 => :mode_not_set,
        2 => :input_value_not_set
      },
      3 =>
      {
        0 => :channel_not_config,
        1 => :pid_not_config,
        3 => :invalid_name_string
      },
      6 =>
      {
        0 => :channel_not_config,
        1 => :pid_not_config,
        3 => :invalid_name_string
      }
    }

    # A hash to convert an error zone symbol and a error type symbol into a String error message
    ERR_MESSAGE_LOOKUP =
    {
      :unknown => "Unknown error",
      :comm_stack =>
      {
        :unknown => "Unknown communications stack error",
        :invalid_method => "Invalid method",
        :non_synchronous => "Packet not sent synchronously",
        :undefined_get => "Undefined GET RPC",
        :undefined_post => 'Undefined POST RPC',
        :undefined_critical => 'Undefined CRITICAL RPC'
      },
      :coprocessor => 
      {
        :unknown => 'Unknown co-processor error',
        :not_responding => 'Co-processor not responding',
      },
      :get_parser =>
      {
        :unknown => 'Unknown GET parser error',
        :invalid_channel => 'Error with GET parser, most likely the channel mode does not have GET functionality'
      },
      :post_parser => 
      {
        :unknown => 'Unknown error in POST processor',
        :value_not_set => 'Failed to set the value of the channel',
        :mode_not_set => 'Failed to set the mode of the channel',
        :input_value_not_set => 'Failed to set the value of the input channel'
      },
      :config =>
      {
        :unknown => 'Unknown CRITICAL parser error',
        :channel_not_config => 'Failed to configure channel',
        :pid_not_config => 'Failed to configure PID channel',
        :invalid_name_string => 'Invalid name string (either too short or too long)'
      },
    }
  end
end

