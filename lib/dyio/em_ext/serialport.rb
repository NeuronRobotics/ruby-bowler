require 'em/pure_ruby'
require 'eventmachine'
require 'serialport'

module Bowler 

  # An {EventMachine::StreamObject} that writes as normal, but reads in full bowler packets
  class BowlerSource < EventMachine::StreamObject

    # Open a new Bowler packet source based on the given connection settings
    # @param [Hash] a hash of options for creating the serial connect -- should contain `:path`
    #   as well as any options to be passed to {::SerialPort#new}
    def self.open(conn_hash)
      hsh = {:baud => 115200}.merge conn_hash
      hsh.delete :path
      io = ::SerialPort.new(conn_hash[:path], hsh)
      self.new(io)
    end

    def initialize(io)
      super(io)
    end
  
    # Overriden to read in full bowler packets at a time, based on
    # bowler header information
    # (see EventMachine::StreamObject#eventable_read) 
    def eventable_read
      @last_activity = EventMachine::Reactor.instance.current_loop_time
      begin
        10.times do
          resp = io.read_nonblock(CommandHandler::HEADER_SIZE).bytes.to_a
          target_size = resp[9]
          resp = resp.concat(io.read(target_size).bytes.to_a) 
          EventMachine::event_callback uuid, EventMachine::ConnectionData, resp
        end
      rescue Errno::EAGAIN, Errno::EWOULDBLOCK
        # no-op
      rescue Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError
        @close_scheduled = true
        EventMachine::event_callback uuid, EventMachine::ConnectionUnbound, nil
      end
    end
  end
end

module EventMachine
  class << self

    # Open a new Bowler packet stream
    # @param [Hash] (see Bowler::BowlerSource#open)
    # @param [Bowler::DyIO] the dyio object with which this connection will be associated
    # @param [Class] the event handler class to use with this connection (should be in the form of #{Bowler::EventHandler})
    # @return the resulting "connection" (event handler instance)
    def open_bowler(io_hash, dyio, handler)
      uuid          = BowlerSource.open(io_hash).uuid
      connection    = handler.new uuid, dyio
      @conns[uuid]  = connection
      connection
    end 
  end
end
