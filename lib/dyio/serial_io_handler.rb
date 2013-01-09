require 'eventmachine'

module Bowler

  # An EventMachine::Connection representing a connection to
  # a physical DyIO
  class SerialIOHandler < EventMachine::Connection
    attr_accessor :dyio

    def initialize(dyio, *args)
      self.dyio = dyio
      super(*args)
    end

    def receive_data(data)
      structured_data = dyio.command_to.parse_command data
      dyio.handle.incoming_event(structured_data)
    end

    # Expects the data in array form, which then gets packed as 'C*'
    # before sending
    def send_data(data)
      str_data = data.pack('C*')
      super(str_data)
    end
  end
end
