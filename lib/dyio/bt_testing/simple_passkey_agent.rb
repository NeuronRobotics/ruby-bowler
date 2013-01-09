require 'dbus'

module Bowler
  module IO
    module Bluetooth

      # Handles passkey authentication for BlueZ, since
      # passkey authentication is forked off into another "key handler"
      # NOTE: you can use your own passkey agent -- this is just a nice helper which
      # is not fully working ATM.  We reccomend you use the BlueZ python tools simple agent
      # if you do not already have one (many desktop environments provide them)
      class SimpleBluezPasskeyAgent < DBus:Object
        attr_accessor :passkeys
        
        # Create a passkey agent that returns a passkey based on
        # the device requesting it 
        def initialize(passkey_hash={})
          @passkeys = passkey_hash
        end

        # Runs the passkey agent
        def run
          session_bus = DBus.session_bus
          sys_bus = DBus::SystemBus.instance
          #service = bus.request_service
          # TODO: finish
        end

        dbus_interface 'org.bluez.Agent' do

          dbus_method :Release, "" do
            #mainloop.quit
          end

          dbus_method :Authorize, "in device:o, in uuid:s" do |device, uuid|
            unless self.passkeys[device].nil?
              return
            else
              raise DBus.error('org.bluez.Error.Rejected'), "Rejected unknown device"
            end
          end

          dbus_method :RequestPinCode, "in device:o out pin:s" do |device|
            return [self.passkeys[device]]
          end

          dbus_method :RequestPasskey, "in device:o, out passkey:u" do |device|
            return [self.passkeys[device]] # TODO: in order for this to work, we need to return a UInt32
          end

          dbus_method :DisplayPasskey, "in device:o, in passkey:u" do |device, passkey|
            puts "DisplayPasskey: #{device}, #{passkey}"
          end

          dbus_method :RequestConfirmation, "in device:o, in passkey:u" do |device, passkey|
            unless self.passkeys[device].nil?
              return
            else
              raise DBus.error('org.bluez.Error.Rejected'), "Rejected unknown device"
            end
          end

          dbus_method :ConfirmModeChange, "in mode:s" do |mode|
            unless self.passkeys[device].nil?
              return
            else
              raise DBus.error('org.bluez.Error.Rejected'), "Rejected unknown device"
            end
          end

          dbus_method :Cancel, "", do
            # puts 'Cancel'
          end
        end
      end
    end
  end
end

