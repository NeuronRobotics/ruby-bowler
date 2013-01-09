require 'serialport'
require 'em-synchrony'
require 'fiber'
require 'active_support/core_ext/string'
require 'dyio/command_handler'
require 'dyio/serial_io_handler'
require 'dyio/em_ext/serialport'
require 'dyio/em_ext/deferrable_with_default'
require 'dyio/event_handler'

module Bowler

  # Represents a physical DyIO
  # To send commands, use #command_to.
  # To handle events, either use #handle (not reccomended)
  # or the peripheral objects' built-in command handler methods
  # (reccomended)
  class DyIO
    attr_reader :serial_conn
    attr_reader :command_handler

    attr_reader :firmware
    attr_reader :info
    attr_reader :channels
    attr_reader :event_handler

    TIMEOUT = 100

    # Initializes a new DyIO object
    # For bluetooth connections, use the +tty+ method under one of the classes
    # in Bowler::IO::Bluetooth (for example, DBusBluez#tty) to obtain a serial
    # port path
    #
    # == Parameters ==
    # +serialconninfo+::
    #                   either a SerialPort object, a hash to be
    #                   passed to SerialPort#new (with an an additional
    #                   +:path+ key specifying a path), or a string
    #                   representing a path to a serial port on your 
    #                   system.  If a string is used, the baud is assumed
    #                   to be 115200.
    # +hash+::
    #          a hash of extra options.  Currently supported options
    #          are: +:mac_address+ -- a mac address in the formats accepted
    #          by #mac_address=
    def initialize (serialconninfo, opts_hash={})
      conn = serialconninfo
      if (!conn.is_a? SerialPort)
        conn_hash = serialconninfo
        if (serialconninfo.is_a? String) 
          conn_hash = {:path => serialconninfo, :baud => 115200}
        end
        conn = conn_hash
      end

      opts = {:mac_address => :broadcast}.merge opts_hash

      @serial_conn = conn
      self.mac_address = opts[:mac_address]
      @command_handler = CommandHandler.new(self)
      
      @battery_voltage = nil
      @event_handler = EventHandler.new(self)

      # TODO: query and cache capabilities
      # self.query_capabilities
    end

    alias :handle :event_handler

    # returns the last cached battery voltage
    def battery_voltage
      return nil if @battery_voltage.nil?
      @battery_voltage[:voltage]
    end

    # Returns whether or not brownout detection is enabled (currently ALWAYS returns true)
    def brownout_detection?
      true # TODO: implement
    end

    # Gets the state of the given battery bank (passed in as either a 0 or 1, :a or :b, or 'a' or 'b')
    def state_of_battery_bank (ind)
      return nil if @battery_voltage.nil? or ind.nil?
      if (ind.is_a? Fixnum and ind < 2)
        @battery_voltage[:banks][ind]
      elsif (ind.is_a? Symbol and (ind == :a || ind == :b))
        @battery_voltage[:banks][(ind == :a ? 0 : 1)]
      elsif (ind.respond_to?(:to_s) and (ind.to_s == 'a' || ind.to_s == 'b'))
        @battery_voltage[:banks][(ind.to_s == 'a' ? 0 : 1)]
      else
        nil
      end
    end

    # Allows you to call `get_channel_as_peripheralclass`, looking under the Bolwer::IO::Peripherals module
    # (you pass in the channel number -- `get_channel_as_` is the prefix)
    def method_missing(sym, *args)
      raise "Unknown method #{sym.id2name} for #{self.class.to_s}" unless sym.id2name.start_with? 'get_channel_as_'
      dev_name = s.id2name[15..-1].camelcase
      raise "Undefine peripheral #{dev_name}" if !Bowler::IO::Peripherals.const_defined?(dev_name.to_sym) 
      raise "Must specify a channel number" unless args.length > 0
      cl = Bowler::IO::Peripherals.const_get(dev_name.to_sym)
      cl.new(self, *args)
    end

    # Connect to the DyIO, executing the given block in the context of the connected 
    # DyIO (automatically powers on, launches the heartbeat, and resyncs state before calling
    # the block)
    def connect (&blk)
      EventMachine.synchrony do
        launch_event_handler

        # then send power_command
        self.command_to.power_on
        
        # then start the heartbeat
        self.command_to.start_heartbeat(3000)
        launch_heartbeat(3000)

        # then resync
        resync

        blk.call
      end
    end

    # sets up the eventmachine heartbeat
    def launch_heartbeat(interval)
      unless @heartbeat.nil?
        @heartbeat.cancel
      end

      @heartbeat = EM::Synchrony.add_periodic_timer(interval/1000.0) do
        command_to.ping
        puts '[DEBUG] lubdub'
      end
    end

    # Launches the event handler event machine data stream
    def launch_event_handler
      @rw_handler = EventMachine.open_bowler(@serial_conn, self, SerialIOHandler) 
    end

    # Returns the MAC address of the DyIO in the "xx:xx:..." form
    def mac_address
      @mac_address.map {|v| "%02x" % v }.join(':')
    end

    alias :mac_address_string :mac_address

    # Returns a raw array of the bytes in the mac address
    def mac_address_bytes
      @mac_address 
    end

    # Sets the cached MAC address -- the value can be specified as a string in
    # "xx:xx:..." form, an array of bytes, a Fixnum, or :broadcast
    def mac_address=(val)
      old_val = (@mac_address.nil? ? nil : @mac_address.clone)
      if (val == :broadcast) 
        @mac_address = [0,0,0,0,0,0]
      elsif (val.is_a? Fixnum) # we have a raw address in numeric format
        #@mac_address = val.to_s(16).split(/(?=[0-9a-fA-F]{2})(?<=[0-9a-fA-F]{2})/).map {|v| v.to_i(16) }
        @mac_address = val.to_s(16).chars.reduce([""]) do |acc,v|
          if (acc[-1].length < 2)
            acc[-1].concat(v)
            return acc
          else
            acc[-1] = acc[-1].to_i(16)
            acc.push(v)
            return acc
          end
        end
      elsif (val.is_a? Array) # we have an array of either strings or numbers
        if (val[0].is_a? Fixnum)
          @mac_address = val.clone
        else
          @mac_address = val.map {|v| v.to_s.to_i(16)}
        end
      elsif (val == :broadcast)
        @mac_address = [0,0,0,0,0,0]
      else # we have something that we can coerce into a string and then treat like it's in normal mac address form
        @mac_address = val.to_s.split(/:/).map {|v| v.to_i(16) }  
      end

      if (@mac_address.length != 6 or @mac_address.any? {|v| v > 0xFF})
        cv = @mac_address.clone
        @mac_address = old_val
        raise "Invalid MAC address: #{cv.join ':'}" 
      end

      @mac_address
    end

    # Sends the given datagram byte array/String to the DyIO device,
    # dispatching the event as a 'readable_name' event if the type isn't :post
    def send_datagram(datagram, type, readable_name)
      defer = DeferrableWithDefaults.new
      normal_p = proc do |data|
        defer.succeed data
      end

      if (type != :post)
        self.handle.send(('next_'+readable_name.id2name+'_event').to_sym, &normal_p)
      else # TODO: check to see if there are any post methods that don't return :status
        status_p = proc do |success, data|
          if success
            defer.succeed data
          else
            defer.fail data
          end
        end
        self.handle.next_status_event(readable_name, &status_p)
      end
      @rw_handler.send_data(datagram) 

      defer
    end

    alias :command_to :command_handler

    private

    # sets the cached channels' info
    def channels=(v)
      # TODO: fire events about channels updating?
      @channels = v
    end

    # Create a SerialPort connection based on the given connection hash
    # (which is just a ::SerialPort options hash with an extra :path key)
    def create_conn (conn_hash)
      hsh = {:baud => 115200}.merge conn_hash
      hsh.delete :path
      SerialPort.new(conn_hash[:path], hsh)  
    end

    # Resyncs the current state (voltage, firmware, channel modes, and MAC address)
    def resync
      # steps:

      if (@firmware.nil?)
        @battery_voltage = self.command_to.power_on # power commands return voltage
        @battery_voltage.delete :raw_res # don't need to store that
        @firmware = self.command_to.get_firmware_revision[:revisions][:dyio]
      end
      if (@info.nil?)
        @info = self.command_to.get_info[:string]
      end

      resp = self.command_to.get_channel_modes
      self.mac_address = resp[:raw_res][:mac_address]

      if (resp[:channels].size < 24) then raise "Not enough channels: #{resp[:data].size.to_s}!" end

      self.channels = resp[:channels]
      if self.channels.length < 1 then raise "No channels set!" end
    end
  end
end
