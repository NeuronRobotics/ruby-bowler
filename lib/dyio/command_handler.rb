require 'dyio/lookup_hashes'

module Bowler
  BOWLER_VERSION = 3

  # Handles sending commands to the dyio, validating Bowler packets,
  # and parsing Bowler packets into ruby data structures.
  # All parsed packets have a :raw_res key containing the raw packet metadata and data with minimal processing
  # (see #parse_command for the format of this data) 
  class CommandHandler
    HEADER_SIZE = 11

    def initialize(dyio_obj)
      @dyio = dyio_obj
    end

    # sets the given channel number to the given value
    # Options include :val_size to specify a target value size
    # and :time to specify a duration
    def set_channel_value(num, val, opts_hsh)
      res = nil
      val_bytes = unless (val.is_a? Array)
                    val.to_a(opts_hsh[:val_size])
                  else
                    val
                  end
      unless opts_hsh[:time].nil?
        time_bytes = opts_hsh[:time].to_a(opts_hsh[:time_size])
        self.send_command('schv', :post, num, val_bytes, time_bytes)
      else
        #puts 'I like cereal'
        self.send_command('schv', :post, num, val_bytes)
      end
      
    end

    # Sets the given channel number to the given mode
    def set_channel_mode(num, mode, async=false)
      self.send_command('schm', :post, num, CHAN_MODE_VALS[mode], (async ? 1 : 0))
    end

    # Parse an error packet into a BowlerException (and raise it)
    def parse_error_command(res)
      zone = res[:data][0]
      section = res[:data][1]
      
      raise BowlerException.new(zone,section), "Error RPC received"
    end

    # Parses a channel mode packet into `{:mode => mode, :channel => channel_number}`
    def parse_channel_mode(res)
      {:raw_res => res, :mode => CHAN_MODE_NAMES[res[:data][1]], :channel => res[:data][0]}
    end

    # Parses a raw channel value packet, but doesn't do much, since the channel
    # value's interpretation is largely dependent on the device connected
    def parse_channel_value(res)
      {:raw_res => res, :channel_num => res[:data][0], :raw_val => res[:data][1..-1]} # note: can only be interpreted based on which channel mode is set, so metadata parsed in channel class
    end

    # Parses a firmware revision packet into `{:revisions => {:dyio => [x,y,z], :bootloader => [x,y,z]}}`
    def parse_firmware_revision(res)
      rv = {:raw_res => res, :revisions => {}}
      #(0..res[:data].length/3 - 1).each do |ind|
      #  rv[:revisions].push res[:data][ind*3..(ind*3+2)]
      #end
      rv[:revisions][:dyio] = res[:data][0..2]
      rv[:revisions][:bootloader] = res[:data][3..5]
      rv
    end

    # Parses a channel modes packet into `{:channels => [{:mode => mode, :editable => boolean}]}`
    def parse_channel_modes(res)
      rv = {:raw_res => res, :channels => []}

      res[:data].each_with_index do |chan,ind|
        cm = CHAN_MODE_NAMES[chan] || nil
        editable = true
        if (cm.nil?)
          cm = :digital_in
          editable = false
          self.set_channel_mode(ind, cm, false)
        end
        rv[:channels].push({:mode => cm, :editable => editable})
      end

      rv
    end

    # Parses a channel values packet into `{:channels => [[channelvalue],[channelvalue],...]}` (see #parse_channel_value)
    def parse_channel_values(res)
      rv = {:raw_res => res}

      rv[:channels] = res[:data].reduce([[]]) do |acc,elem|
        if acc[-1].length < 4
          acc[-1].push(elem)
        else
          acc.push([elem])
        end
        acc
      end
      rv
    end

    # Sends a power on command
    def power
      # TODO: handle disableBrownoutProtected
      self.send_command('_pwr', :get)
    end

    # Parses a power packet into `{:voltage => voltage (in what units?), :banks => [:regulated or :unpowered or :powered, same types]}`
    def parse_power(res)
      rv =
      {
        :raw_res => res,
        :voltage => ((res[:data][2] << 8) | res[:data][3])/1000.0,
        :banks => []

      }
      rv[:banks][0] = case (res[:data][0])
                      when 1
                        :regulated
                      when 0
                        if (rv[:voltage] < 5.0)
                          :unpowered
                        else
                          :powered
                        end
                      else
                        :powered
                      end
      rv[:banks][1] = case (res[:data][1])
                      when 1
                        :regulated
                      when 0
                        if (rv[:voltage] < 5.0)
                          :unpowered
                        else
                          :powered
                        end
                      else
                        :powered
                      end
      rv
    end

    alias :power_on :power

    # Sends a command to start the heartbeat with the given frequency
    def start_heartbeat(hb)
      res = self.send_command('safe', :post, 1, hb & 0x00FF, hb & 0xFF00) # expects a 16-bit integer (2 bytes), the 1 is for 'true'
      rv = {:raw_res => res}
    end

    # Sends a command to retrieve the DyIO's info string, or to set the info string if a string is speficied
    def get_info(name=nil)
      # TODO: make get_info and set_info
      res = if name.nil?
        self.send_command('info', :get) 
      else
        self.send_command('info', :critical, name) # takes up to 16 bytes?
      end
    end

    # Parses an info packet into `{:string => string}`
    def parse_get_info(res)
      # note: does not return any formatted data
      {:raw_res => res, :string => res[:data]}
    end
    

    # Parses a bowler packet into `{:revision => number, :mac_address => bytes, :namespace_id => number, :full_transaction_id => number, :direction => :upstream or :downstream,
    # :given_size => number, :given_crc => number, :rpc => string, :data => bytes, :method => :status or :get or :post or :critical or :async or [:other, number], :calculated_crc => number,
    # :calculated_size => number}` (NOTE: does not actually compare the calculated size and crc with the given size and crc)
    def parse_command(datagram)
      return nil if datagram.nil? or datagram.length < HEADER_SIZE
      res =
      {
        :revision => datagram[0],
        :mac_address => datagram[1..6],
        # method is 7 and is filled in below
        :namespace_id => datagram[8] & 0x7F,
        :full_transaction_id => datagram[8],
        :direction => (datagram[8] < 0 ? :upstream : :downstream),
        :given_size => datagram[9],
        :given_crc => datagram[10],
        :rpc => datagram[HEADER_SIZE..HEADER_SIZE+3].pack('C*'),
        :data => datagram[HEADER_SIZE+4..-1]
      }
      res[:method] = case datagram[7]
                     when 0x00
                       :status
                     when 0x10
                       :get
                     when 0x20
                       :post
                     when 0x30
                       :critical
                     when 0x40
                       :async
                     else
                       [:other, datagram[7]]
                     end
      res[:calculated_size] = (res[:data].nil? ? res[:rpc].length : res[:data].length+res[:rpc].length)
      res[:calculated_crc] = datagram[0..HEADER_SIZE-2].reduce(0) {|acc,v| acc + v} & 0x000000FF

      # error checking should be done in a different method
      res
    end
    
    # Builds a datagram byte array/String from the given rpc name, type symbol, and arguments.
    # Any argument which responds to #bytes is converted that way, any Fixnum is converted as
    # `[number]`, if the value responds to #to_a it is converted as such, and finally any other
    # value is converted using #to_s and String#bytes.
    def build_datagram(name, type, *args)
      raise 'RPC name cannot be nil' if name.nil?
      datagram = []
      # datagram fmt:
      datagram.push(BOWLER_VERSION) # revision
      datagram.push(*(@dyio.mac_address_bytes)) # mac address (from @dyio)
      datagram.push( 
        case (type) # method (type) id
        when :status
          0x00
        when :get
          0x10
        when :post
          0x20
        when :critical
          0x30
        when :async
          0x40
        else
          raise "Unrecognized type #{type.to_s}"
        end
      )
      datagram.push(0) # transaction id (currently 0, TODO: pass in this value)

      arg_size = args.reduce(0) do |acc, v|
        if (v.is_a? Fixnum)
          acc + 1
        else
          acc + v.length
        end
      end
      datagram.push(name.length + arg_size) # (command and data) length

      datagram.push(datagram.reduce(0) {|acc,v| acc + v} & 0x000000FF) # (datagram so far) CRC
      datagram.push(*(name.bytes))

      arg_bytes = args.reduce([]) do |acc, v|
        if (v.respond_to? (:bytes))
          acc.concat(v.bytes)
        elsif (v.is_a? Fixnum)
          acc.concat([v])
        elsif (v.respond_to? :to_a)
          acc.concat(v.to_a)
        else
          acc.concat(v.to_s.bytes.to_a)
        end
      end
      datagram.push(*arg_bytes)

      datagram
    end

    # Sends a command with the given name, type symbol, and arguments, and calls the given block
    # when the dyio returns a response (for synchronous commands)
    def send_command(name, type, *args, &blk)
      #puts "processing #{name}"
      dg = build_datagram(name,type,*args)
      defer = @dyio.send_datagram(dg, type, EVENT_LOOKUP_NAMES[name] || name.to_sym)

      pm = proc {|rv, &blk| blk.call(rv) unless blk.nil?}

      defer.default_callback(&pm)
      defer.default_errback(&pm)

      unless blk.nil? or type == :async
        defer
      else
        EM::Synchrony.sync defer
      end
      #@dyio.handle.send(('next_'+name+'_event').to_sym, &pm)
    end

    # Validate a Bowler packet (currently just checks to see if it is nil)
    def validate_result(rv)
      raise 'Null response' if rv.nil?
    end

    # Allows you to call methods as `command_to.get_something` -- commands can be
    # (get|post|critical|status|async|set)_commandname (set translates to post, and sticks set back on the 
    # beginning of the command name), or just commandname, in which case
    # a type of post is assumed unless the first argument to the method is a type symbol.  Currently, namespaces are ignored
    # and the command namespace is set to 0
    def method_missing(sym, *args)
      raise "Unknown method #{sym.id2name}" if sym.id2name.start_with? 'parse'
      parts = sym.id2name.match /^(.+?)_(.+)_(.+?)_(.+?)$/ # [action]_[commandname]_from_[namespace]
      if (parts.nil?)
        parts = sym.id2name.split('_', 2)
      end

      if (parts.nil? || !([:status,:get,:post,:critical,:async, :set].include? parts[0].to_sym))
        # handle undefined commands
        if ([:status, :get, :post, :critical, :async].include? args[0])
          command = EVENT_LOOKUP_RPCS[sym] || sym.to_s
          self.send_command(command, *args)
        else
          # assume post
          command = EVENT_LOOKUP_RPCS[sym] || sym.to_s
          self.send_command(command, :post, *args)
        end
      else
        method = parts[0].to_sym
        name = parts[1].to_sym
        if (method == :set)
          method = :post
          name = ('set_'+name.to_s).to_sym
        end
        command = EVENT_LOOKUP_RPCS[name] || name.to_s
        namespace = 0 #ignore namespace lookup for now: namespace = if (parts.length > 2) then parts[3] else 0 end
        self.send_command(command, method, *args)
      end
    end
  end
end
