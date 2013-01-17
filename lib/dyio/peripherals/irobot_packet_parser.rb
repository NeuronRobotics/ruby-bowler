module Bowler
  module IO
    module Periperals
      class IRobotCreate
        class PacketParser
          class << self
            def parse_data(packet_id, data)
              packet_type = PACKET_NUM_TO_TYPE[packet_id].id2name
              if (respond_to? "parse_#{packet_type}_packet".to_sym)
                send("parse_#{packet_type}_packet".to_sym, *data)
              else
                data > 0
              end
            end

            # also bumper
            def parse_wheel_drops_packet(data)
              caster = data & 0b00010000
              drop_left = data & 0b00001000
              drop_right = data & 0b00000100
              bump_left = data & 0b00000010
              bump_right = data & 0b00000001
              {:wheeldrop => {:caster => caster > 0, :left => drop_left > 0, :right => drop_right > 0}, :bumper => {:left => bump_left > 0, :right => bump_right > 0}}
            end

            def parse_wheel_overcurrent_packet(data)
              left_wheel = data & 0b00010000
              right_wheel = data & 0b00001000
              ld2 = data & 0b00000100
              ld0 = data & 0b00000010
              ld1 = data & 0b00000001
              {:wheel_overcurrent => {:left => left_wheel > 0, :right => right_wheel > 0}, :low_side_drivers => [ld0 > 0, ld1 > 0, ld2 > 0]}
            end

            def parse_infrared_packet(data)
              if (data == 255)
                nil
              else
                data.ord
              end
            end

            def parse_buttons_packet(data)
              advance = 0b00000100 & data
              play = 0b00000001 & data
              {:advance => advance > 0, :play => play > 0}
            end

            def parse_distance_accumulator_packet(high, low)
              [high,low].to_i
            end

            def parse_angle_accumulator_packet(high, low)
              [high,low].to_i
            end

            def parse_charging_state_packet(data)
              case data
              when 0
                :not_charging
              when 1
                :reconditioning_charging
              when 2
                :full_charging
              when 3
                :trickle_charging
              when 4
                :waiting
              when 5
                :fault
              end
            end

            unsigned_data :voltage
            signed_data :current
            signed_data :battery_temp
            unsigned_data :battery_charge, :battery_capacity
            unsigned_data :wall_signal, :left_clift_signal, :right_clift_signal, :front_left_clift_signal, :front_right_clift_signal
            
            def parse_cargo_bay_digital_in(data)
              dev_detect = 0b00010000 & data
              di3 = 0b00001000 & data
              di2 = 0b00000100 & data
              di1 = 0b00000010 & data
              di0 = 0b00000001 & data
              {:device_detect => dev_detect, :inputs => [di0 > 0, di1 > 0, di2 > 0, di3 > 0]}
            end

            unsiqned_data :cargo_bay_analog_signal_in

            def parse_charging_sources_packet(data)
              {:home_base => data & 0b00000010, :internal => data & 0b00000001}
            end

            def parse_mode_packet(data)
              case data
              when 0
                :off
              when 1
                :passive
              when 2
                :safe
              when 3
                :full
              end
            end

            unsigned_data :selected_song
            unsigned_data :num_stream_packets
            signed_data :requested_velocity, :requested_radius, :requested_right_velocity, :requested_left_velocity

            class << self
              private
              def signed_data(*names)
                names.each do |name|
                  send :define_method, "parse_#{name.id2name}_packet".to_sym do |*data|
                    data.to_i 
                  end
                end
              end

              def unsigned_data(*names)
                names.each do |name|
                  send :define_method, "parse_#{name.id2name}_packet".to_sym do |*data|
                    data.to_i(false)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
