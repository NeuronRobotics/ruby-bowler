require 'dyio'

include Bowler

#bt = Bowler::IO::Bluetooth::DBusBluez.new
#puts 'bt ready'
#dyio = DyIO.new(bt.tty)
dyio = DyIO.new('/dev/DyIO0')
puts 'dyio ready'

dyio.connect do
  puts 'Enter servo channel: '
  servo = Bowler::IO::Peripherals::Servo.new(dyio, 9)
  
  pot = Bowler::IO::Peripherals::Potentiometer.new(dyio, 13)
  pot.async = true

# pm = proc do |frac|
#   puts "I love cheese this much: #{frac*27}"
# end

  pot.on_every_change do |fraction|
    puts "Pot is #{fraction}"
#    servo.move_to (200*fraction+20).to_i, 500
  end

# dyio.handle.every_power_event do |data|
#   puts "power: #{data}"
# end
 
# puts 'ready'
# uart = Bowler::IO::Peripherals::UART.new(dyio)
# uart.transmit([128,132,139,2,0,0]) do |d|

# end

# uart.transmit([128,142,9]) do |d|

# end

# puts uart.receive

# puts 'done!'
end
