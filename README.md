# Ruby DyIO API #

## Introduction ##

This library facilitates communication with the [Neuron Robotics] DyIO open source coprocessor (see "http://bowler.io":http://bowler.io).  It is the official Ruby implementation of the
PC side of the Bowler API.

## Requirements ##

This library requires EventMachine, EM::Synchrony, SerialPort, and DBus (see [insert urls here], dbus only required for linux Bluetooth).  Additionally, this library requires Ruby Fiber support
(Ruby 1.9+)

## Installing ##

 * Check out repo
 * cd into repo
 * run `rake build`
 * run `gem install pkg\ruby-dyio-0.0.1.gem`

## Getting Started ##

To start off, first initialize a new DyIO object:

```ruby
require 'dyio'

include Bowler

dyio = DyIO.new('/dev/DyIO0') # Assuming you're on linux, with the DyIO udev files installed
```

The Ruby DyIO libary uses the EventMachine library to provide an event-oriented approach to communicating with the DyIO.  Start the EventMachine reactor as follows:

```ruby
dyio.connect do
  # your code here
end
```

Then, you can set up devices and register callbacks, as such:

```ruby
dyio.connect do
  pot = dyio.get_channel_as_potentiometer 9
  servo = dyio.get_channel_as_servo 10

  pot.on_every_chane do |fraction|
    puts 'Pot is #{fraction}'
    servo.move_to (200*fraction+20).to_i, 500 # move the servo to position 200*fraction+20 (20-220) over the course of 500 ms
  end
end
```

However, often times nested callbacks can be hard to manage. Consider the following example:

```ruby
dyio.connect do
  pot = dyio.get_channel_as_potentiometer 9
  servo = dyio.get_channel_as_servo 10
  button = dyio.get_channel_as_button 11

  button.on_every_change do |pushed|
    if pushed
      pot.on_next_change do |frac|
        servo.move_to (200*frac+20), 500
      end
      dyio.command_to.get_channel_values
    end
  end
end
```

Because of this, all of the methods in the Ruby DyIO library support the EM::Synchrony pattern, which uses Fibers to allow for pseudo-sequential code writing:

```ruby
dyio.connect do
  pot = dyio.get_channel_as_potentiometer 9
  servo = dyio.get_channel_as_servo 10
  button = dyio.get_channel_as_button 11

  button.on_every_change do |pushed|
    if pushed
      val = pot.fraction
      servo.move_to (200*val+20), 500
    end
  end
end
```

Mixing these two style generally produces the most readable code.

## Advanced Topics ##

### EventMachine Primatives ###

All EventMachine primatives are supported.  Note, however, that in order to function properly with the EM::Synchrony functionality used inside the Ruby DyIO library, you should use the EM::Synchrony versions, and not the normal EventMachine versions.  In the event that you have an existing vanilla EventMachine method that you would like to reuse, simply wrap it with a call to EM::Synchrony#sync

### Custom Peripherals ###

Any single-channel custom peripheral should inherit from the `Bowler::IO::Channel` class at minimum.  If your device provides input, you should inherit from the `Bowler::IO::Input` class instead.  Additionally, devices are expected to call the #mode= method in their constructor, so as to configure the DyIO properly before use.  The (private) method #process_data may be overridden to provide event handlers with properly formatted data.  For instance, the Bowler::IO::Peripherals::Button class defines it as such:

```ruby
def process_data(data)
  val = data[:channels][@channel_number].to_i(false)
  @cached_val = if @active_high then (val != 0) else (val == 0) end
  @cached_val
end
```

Arrays can be returned to pass multiple values to the event handlers (the arrays are "expanded" using `*arr` when passed to the event handler blocks).  Finally, the #get_channel_as methods are implemented by searching the Bowler::IO::Peripherals module, so any custom peripherals may be placed there for ease of use.

### Custom Commands ###

Command handling is done in the Bowler::CommandHandler class.  There are two types of relevant methods to implement here: commands and parsers.

#### Commands ####

Now, by default unspecified commands will have their names parsed and acted on automatically (see the documentation for Bowler::CommandHandler#method_missing).  However, to simplify name conversion, etc, you may define your own command methods in Bowler::CommandHandler (or a subclass of it, which you can then specify as the DyIO's command_handler, or as a module, which you can then `include` in Bowler::CommandHandler).  For example, set_channel_value is implemented as such:

```ruby
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
      self.send_command('schv', :post, num, val_bytes)
    end
end 
```

#### Parsers ####

The Bowler::CommandHandler class is also responsible for parsing incoming packets.  Such methods
start with parse, and are called automatically based on the command name to readable name lookup hash Bowler::EVENT_LOOKUP_NAMES, or just used directly if no such entry can be found.  Such a method should take in a single paramter (the results of the #parse_command method), and return a hash with at least a key `:raw_res` whose value is the passed in parameter.  The following is the parse_channel_mode method:

```ruby
def parse_channel_mode(res)
  {:raw_res => res, :mode => CHAN_MODE_NAMES[res[:data][1]], :channel => res[:data][0]}
end
```
