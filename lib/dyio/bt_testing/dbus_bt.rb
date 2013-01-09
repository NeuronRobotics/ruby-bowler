require './bluez_dbus.rb'

bus = Bowler::IO::Bluetooth::DBusBluez.new

loop do
  bus.device 
end
