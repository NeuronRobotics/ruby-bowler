require 'dyio/input'

module Bowler
  module IO
    module Periperals
      class IRobotCreate < UART
        attr_reader :mode

        def initialize(dyio, mode = :full, in_channel = 17, out_channel = 16)
          super(dyio, in_channel, out_channel)
          self.mode = mode
          @byte_queue = []
          @stream_paused = false
          @stream_enabled = false
        end

        def mode_codes 
          case @mode
          when :safe
            [128, 131]
          when :full
            [128, 132]
          when :passive
            [128]
          else
            [128]
          end
        end

        def mode=(m)
          self.reset
          @mode = m
        end

        def reset
          @started = false
        end

        def start!
          @started = true
          @method_queue.push *mode_codes
        end

        def queue_command(command_bytes)
          self.start! unless @started
          self.transmit command_bytes
        end

        def run_demo(demo_num)
          raise "Demo number must be between 0 and 9" if (demo < 0 or demo > 10)
          self.queue_command([136, demo_num])
        end

        def abort_demo
          self.queue_command([136,-1])
        end

        def flush_queue
          self.transmit @byte_queue
          @byte_queue = []
        end

        def method_missing(name, *args, &block)
          name_str = name.id2name
          raise "Method not a iRobot Create Command!" unless name_str.end_with? '!'
          raise "Method not a iRobot Create Command!" unless self.respond_to? (name_str[0..-2].to_sym)
          self.send(name_str[0..-2], *args, &block)
          self.flush_queue
        end

        def drive(speed, turn_radius)
          # sequence: 137, vel high, vel low, rad high, rad low 
          self.queue_commnad([137])
          self.queue_command(speed.to_a 2)
          self.queue_command(turn_radius.to_a 2)
        end

        def drive_direct(right_vel, left_vel)
          # sequence: 145, right vel high, right vel low, left vel high, left vel low
          self.queue_command([145])
          self.queue_command(speed.to_a 2)
          self.queue_command(speed.to_a 2)
        end

        def set_leds(advance, play, power_color, power_intensity)
          # sequence 139, LED Bits (7, 6, 5, 4, advance, 2, play, 0), power color, power intensity
          color_bits = 0
          if advance
            color_bits = color_bits | 0b00001000
          end
          if play
            color_bits = color_bits | 0b00000010
          end
          self.queue_command([139, color_bits, power_color, power_intensity])
        end

        def set_digital_outputs(first, second, third)
          # 147, output bits (0 = low, 1 = high)
          output_byte = 0
          if third then output_byte = output_byte | 0b00000100 end
          if second then output_byte = output_byte | 0b00000010 end
          if first then output_byte = output_byte | 0b00000001 end

          self.queue_command([147, output_byte])
        end
        
        def set_pwm_low_side_drivers(duty_cycle1, duty_cycle2, duty_cycle3)
          # 144, low side 2, low side 1, low side 0
          self.queue_command([144, duty_cycle3, duty_cycle2, duty_cycle1])
        end

        def set_low_side_drivers(first, second, third)
          # 138, driver_bits

          output_byte = 0
          if third then output_byte = output_byte | 0b00000100 end
          if second then output_byte = output_byte | 0b00000010 end
          if first then output_byte = output_byte | 0b00000001 end

          self.queue_command([138, output_byte])
        end
        
        def send_ir(byte)
          # 151, byte
          self.queue_command([151, byte])
        end

        def send_ir_bytes(bytes)
          self.queue_command([151])
          self.queue_command(bytes)
        end

        def program_song(id, notes)
          # 140, song number, song length, note 1 num, note 1 duration, ...
          self.queue_command(id, notes.length, notes.map {|note, length| [lookup_note(note), length]}.flatten)
        end

        def sing(song_number)
          # 141, song_number
          self.queue_command([141, song_number])
        end

        def query_sensors(*query_type, stream=false)
          # [SINGLE SENSOR PACKET] 142, packet id
          # [LIST OF SENSOR PACKETS] 149, num packets, packet id 1, ...
          # [STREAM] 148, num packets, packet id 1, ...
          packets = query_type.map { |sym| PACKET_TYPE_TO_NUM[sym] }
          unless stream
            if packets.length == 1
              self.queue_command([142])
            else
              self.queue_command([149, packets.length])
            end

            self.queue_command(packets)
            @stream_enabled = true
          else
            self.queue_command([148, packets.length])
            self.queue_command(packets)
          end
          # TODO: parse sensor data
        end

        def receive_packets
          res = []
          packets = self.receive 

          while packets.length > 0
            packet = packets.shift
            if packet == 19
              num_bytes = packets.shift
              while packets.length < num_bytes do packets += self.receive end
              packet_info = packets.shift(num_bytes) 
              checksum = packets.shift
              # TODO: do something with checksum
              res += parse_stream_response(packets)
            else
              # TODO: complete this part
            end
          end

          res
        end

        def pause_stream
          # 150, 0 for pause
          self.queue_command([150, 0]) unless @stream_paused or !@stream_enabled
          @stream_paused = true
        end

        def resume_stream
          # 150, 1 for resume
          self.queue_command([150, 1]) if @stream_paused and @stream_enabled
          @stream_paused = false
        end

        PACKET_TYPE_TO_NUM =
        {
          :bumper => 7,
          :wheel_drops => 7,
          :wall_sensor => 8,
          :left_cliff => 9,
          :front_left_cliff => 10,
          :front_right_cliff => 11,
          :right_cliff => 12,
          :virtual_wall_sensor => 13,
          :low_side_driver => 14,
          :wheel_overcurrent => 14,
          :infrared => 17,
          :play_button => 18,
          :advance_button => 18,
          :buttons => 18,
          :distance_accumulator => 19,
          :angle_accumulator => 20,
          :charging_state => 21,
          :voltage => 22,
          :current => 23,
          :battery_temp => 24,
          :battery_charge => 25,
          :battery_capacity => 26,
          :wall_signal => 27,
          :left_cliff_signal => 28,
          :front_left_cliff_signal => 29,
          :front_right_cliff_signal => 30,
          :right_cliff_signal => 31,
          :cargo_bay_digital_in => 32,
          :cargo_bay_analog_in => 33,
          :charging_sources => 34,
          :mode => 35,
          :selected_song => 36,
          :song_is_playing => 37,
          :num_stream_packets => 38,
          :requested_velocity => 39,
          :requested_radius => 40,
          :requested_right_velocity => 41,
          :requested_left_velocity => 42
        }

        # TODO: implement packet groups
        PACKET_NUM_TO_TYPE = PACKET_TYPE_TO_NUM.invert

        NUM_PACKETS_NEEDED =
        {
          :wheel_drops => 1,
          :wall_sensor => 1,
          :left_cliff => 1,
          :front_left_cliff => 1,
          :front_right_cliff => 1,
          :right_cliff => 1,
          :virtual_wall_sensor => 1,
          :wheel_overcurrent => 1,
          :infrared => 1,
          :play_button => 1,
          :advance_button => 1,
          :buttons => 1,
          :distance_accumulator => 2,
          :angle_accumulator => 2,
          :charging_state => 1,
          :voltage => 2,
          :current => 2,
          :battery_temp => 1,
          :battery_charge => 2,
          :battery_capacity => 2,
          :wall_signal => 2,
          :left_cliff_signal => 2,
          :front_left_cliff_signal => 2,
          :front_right_cliff_signal => 2,
          :right_cliff_signal => 2,
          :cargo_bay_digital_in => 1,
          :cargo_bay_analog_in => 2,
          :charging_sources => 1,
          :mode => 1,
          :selected_song => 1,
          :song_is_playing => 1,
          :num_stream_packets => 1,
          :requested_velocity => 2,
          :requested_radius => 2,
          :requested_right_velocity => 2,
          :requested_left_velocity => 2
        }



        # TODO: implement scripting support

        private
        def parse_stream_response(packets)
          res = []
          while packets.length > 0
            type = packets.shift
            data = packets.shift(NUM_PACKETS_NEEDED[PACKET_NUM_TO_TYPE[type]])
            res << PacketParser.parse_data(packets.shift, data)
          end
          res
        end

        def lookup_note(note_name)
          return note_name if note_name.is_a? Fixnum
          nn = note_name.downcase
          note_num = case nn[0]
                     when 'g'
                       0
                     when 'a'
                       2
                     when 'b'
                       4
                     when 'c'
                       5
                     when 'd'
                       7
                     when 'e'
                       9
                     when 'f'
                       10
                     else
                       raise "Unknown note #{nn[0].upcase}!"
                     end
          note_num += 31
          if nn[1] == '#'
            note_num += 1
          else
            note_num += nn[1].to_i*13 if nn[1] != '#'
            note_num += 1 if (nn.length > 2 && nn[2] == '#')
          end

          note_num
        end
      end
    end
  end
end
