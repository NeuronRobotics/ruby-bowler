require 'dbus'
require 'fiber'

module Bowler
  module IO
    
    # Contains helper classes to assist with bluetooth connects
    module Bluetooth

      # handles connecting to BlueZ via DBus, and obtaining a tty object from
      # BlueZ
      class DBusBluez

        # Creates an object that coordinates with BlueZ to connect to the
        # Bluetooth device at the given device name (and optionally with the
        # given BlueZ adapter path)
        def initialize (dev_name="NR_DyIO0001", adapter_path=nil)
          @@bus ||= DBus::SystemBus.instance
          @@rootservice ||= @@bus.service 'org.bluez'
          @@rootobj ||= @@rootservice.object '/'
          @@rootobj.introspect
          @@manager ||= @@rootobj['org.bluez.Manager']

          if (adapter_path.nil?)
            @hci = default_adapter
          else
            @hci = make_adapter adapter_path
          end
          
          @adapter = @hci['org.bluez.Adapter']
          @dev_id = dev_name
        end

        # Obtains a tty connection to the bluetooth device. 
        def tty
          unless (@connection.nil?) then return @connection end
          
          @serial ||= self.device['org.bluez.Serial']
          devpattern = "spp" # TODO: figure out how to get a device string
          @connection = @serial.Connect(devpattern)[0]
        end

        # Returns the DBus bluetooth device object
        def device
          unless (@device.nil?) then return @device end

          addr = self.device_address
          dev_path = nil
          begin
            dev_path = @adapter.FindDevice(addr)[0]
          rescue DBus::Error => e
            dev_path = @adapter.CreateDevice(addr)[0]
          end
          if (dev_path.nil?) then raise "Error: Could not get or create a device for the address #{addr}" end
          puts addr
          puts dev_path
          @device ||= @@rootservice.object dev_path
          @device.introspect
          @device['org.bluez.Device'].DiscoverServices ''
          @device
        end
        
        # Attempts to retrieve the DBus BlueZ device address
        def device_address
          # TODO: look at which device is needed

          main_fiber = Fiber.current

          # TO discover: wire to devicefound in Adapter under hci, then startdiscovery, get event, stop discovery, use new addr to createdevice in adapter, use to get serial conn
          @adapter.on_signal('DeviceFound') do |addr, attrs|
            if attrs['Name'] == @dev_id
              @adapter.StopDiscovery
              Fiber.yield addr
            end
          end

          rf = Fiber.new do
            main_loop = DBus::Main.new
            main_loop << @@bus

            @adapter.StartDiscovery

            main_loop.run
          end

          rf.resume # return result of the fiber (i.e. the address)
        end

        # Converts a given device id into a DyIO bluetooth
        # device name
        def self.device_name_by_id (id)
          base = "NR_DyIO"
          if (id.is_a? Numeric)
            base + ("%03i" % id)
          else
            base + id.to_s
          end
        end

        private
        
        # Gets the default adapter DBus object
        def default_adapter
          make_adapter @@manager.DefaultAdapter[0]
        end

        # makes a DBus adapter object from the given path
        def make_adapter(path)
          adapter = @@rootservice.object path
          adapter.introspect
          adapter
        end
      end
    end
  end
end
