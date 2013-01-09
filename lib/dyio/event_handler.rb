require_relative 'utils/array_te.rb'

module Bowler

  # Handles events received from and event stream,
  # dispatching them to the appropriate low-level event handlers
  class EventHandler
    attr_accessor :dyio

    def initialize(dyio)
      @dyio = dyio
      @run_once = {:status => {}}
      @run_always = {:status => {}}
    end
    
    # Handles an incoming event, first validating the result with
    # the command handler, then attempting to parse the data via the command handler's #parse_eventname
    # method (if present), then handing it off to low-level event handlers
    def incoming_event(data)
      event_name = EVENT_LOOKUP_NAMES[data[:rpc]] || data[:rpc].to_sym

      #puts "Incoming event: #{event_name} -- #{data.inspect}"
      #puts "Incoming event: #{event_name}"
      #puts "Run once: #{@run_once}"
      #puts "Run always: #{@run_always}"
      #puts "\n\n"

      dyio.command_handler.validate_result(data)

      data = if dyio.command_handler.respond_to?(('parse_'+event_name.id2name).to_sym)
              dyio.command_handler.send(('parse_'+event_name.id2name).to_sym, data)
            else
              {:raw_res => data}
            end

      handlers = []
      handlers.push((@run_once[event_name]).shift) unless @run_once[event_name].nil? or @run_once[event_name].empty?
      handlers.push(*(@run_always[event_name] || []))

      #puts "#{data.keys}"

      if (data[:raw_res][:method] == :status)
        status_handlers = []
        # TODO: deal with status rpc cb code if available
        #status_handlers.push((@run_once[:status][data[:rpc].to_sym]).shift) unless @run_once[:status][data[:rpc].to_sym].nil? or @run_once[:status][data[:rpc].to_sym].empty?
        #status_handlers.push(*(@run_always[:status][data[:rpc].to_sym] || []))
        status_handlers.push((@run_once[:status][:all]).shift) unless @run_once[:status][:all].nil? or @run_once[:status][:all].empty?
        status_handlers.push(*(@run_always[:status][:all] || []))

        #puts "called status handlers #{status_handlers}"

        was_success = (data[:raw_res][:rpc] != '_err')
        status_handlers.each do |handler|
          Fiber.new { handler.call was_success, data }.resume
        end
      end
      
      handlers.each do |handler|
        Fiber.new { handler.call data }.resume
      end
    end

    # Register a run-one event handler for status events (see [insert class here])
    # for more details on the meaning of event handlers
    def next_status_event(name, &blk)
      # TODO: deal with status rpc cb code if available
      name = :all
      @run_once[:status][name] ||= [] 
      @run_once[:status][name].push(blk)
    end

    alias :one_status_event :next_status_event

    # Register an every-time event handler
    def every_status_event(name, &blk)
      # TODO: deal with status rpc cb code if available
      name = :all
      @run_always[:status][name] ||= [] 
      @run_always[:status][name].push(blk)
    end

    alias :all_status_events :every_status_event

    # Remove an event handler
    def no_more_status_events(name, &blk)
      # TODO: deal with status rpc cb code if available
      name = :all
      @run_always[:status][name].delete(args[0] || blk) if @run_always[:status][name]
      @run_once[:status][name].delete(args[0] || blk) if @run_once[:status][name]
    end

    # This allows the class to accept methods like
    # `next_eventname_event`, `next_eventname_events`, and so one (preficies are `next_`, `one_`, `all_`, `every_`, and `no_more_`)
    def method_missing(sym, *args, &blk)
      meth_breakdown = sym.id2name.split('_', 2)
      raise "method #{sym.id2name} not in correct format!" if meth_breakdown.size < 2
      if (meth_breakdown[1].end_with? '_event') then meth_breakdown[1] = meth_breakdown[1][0..-7] end
      if (meth_breakdown[1].end_with? '_events') then meth_breakdown[1] = meth_breakdown[1][0..-8] end
      raise "#{sym.id2name} is not a method of #{self.class.to_s}" unless ['next', 'one', 'every', 'all', 'no_more'].include? meth_breakdown[0]

      case meth_breakdown[0]
      when ['next','one']
        @run_once[meth_breakdown[1].to_sym] ||= []
        @run_once[meth_breakdown[1].to_sym].push (blk)
      when ['all', 'every']
        @run_always[meth_breakdown[1].to_sym] ||= []
        @run_always[meth_breakdown[1].to_sym].push (blk)
      when 'no_more'
        @run_always[meth_breakdown[2].to_sym].delete(args[0] || blk) if @run_always[meth_breakdown[2].to_sym]
        @run_once[meth_breakdown[2].to_sym].delete(args[0] || blk) if @run_once[meth_breakdown[2].to_sym]
      else
        raise "Unknown type: #{meth_breakdown[0]}"
      end
    end
  end
end
