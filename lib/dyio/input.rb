require 'dyio/io_channel'

module Bowler
  module IO
    module Peripherals

      # Represents a generic input device connected to a physical DyIO
      class Input < IO::Channel
        attr_accessor :active_high

        # Create an input object representing an input device of the given type
        # connected to the given DyIO on the given channel, and sets the channel
        # on the physical DyIO accordingly
        def initialize(dyio, channel, type, async=false)
          super(dyio, channel, type, false)
          @async = async
          @callbacks = {:next => [], :all => []}
          @async_handler = nil
          @last_val = (@active_high ? 0 : 1)
        end

        # Adds a new callback that occurs whenever the input value
        # changes and asynchronous mode is enabled
        def on_every_change(&blk)
          self.enable_event_handling = true
          @callbacks[:all].push(blk) 
        end
        alias :on_all_changes :on_every_change

        # Adds a new callback that occurs the next time the input changes
        # and no other one-shot event handlers are present, and asynchronous mode is enabled
        # (i.e. only one one-shot event handler is called for a given event)
        def on_next_change(&blk)
          self.enable_event_handling = true
          @callbacks[:next].push(blk) 
        end
        alias :on_one_change :on_next_change

        # Removes the given event handler from both lists of event handlers
        # (one-shot and every-time)
        def no_more_changes(blk)
          @callbacks[:next].delete(blk)
          @callbacks[:all].delete(blk)

          if @callbacks[:next].empty? and @callbacks[:all].empty?
            enable_event_handling = false
          end
        end


        private

        # dispatches the given event data to each registered every-time
        # event handler and the next one-shot event handler, when present
        def dispatch_events(val, data)
          cb = []
          cb.push(@callbacks[:next].shift) unless @callbacks[:next].empty?
          cb.push(*@callbacks[:all])
          data = process_data data

          cb.each do |handler|
            Fiber.new { handler.call *data }.resume
          end
        end

        # disables or enables event handling (used for optimization cases
        # when no event handlers are enabled or async mode is off
        def enable_event_handling=(v)
          #puts 'enable event handling'
          if v && @async_handler.nil?
            @async_handler = proc do |data|  
              val = data[:channels][@channel_number]
              if (@last_val != val)
                @last_val = val 
                dispatch_events(val, data)
              end
            end
            @dyio.handle.every_channel_values_event(&@async_handler)
          else
            @dyio.handle.no_more_channel_values_events(@async_handler)
            @async_handler = nil
          end
        end

        # This should be overridden in case input objects need to process data
        # before it is passed to event handlers
        def process_data(data)
          data
        end
      end
    end
  end
end
