require_relative 'array_te.rb'

module Bowler
  
  # Represents an error message sent from a physical DyIO
  class BowlerException < RuntimeError
    def initialize(zone, section)
      @zone = zone
      @section = section
    end

    def zone_number
      @zone
    end

    def section_number
      @section
    end

    def zone
      ERR_ZONE_NAME_LOOKUP[@zone] || :unknown
    end

    def section
      if ERR_SECTION_NAME_LOOKUP[@zone]
        ERR_SECTION_NAME_LOOKUP[@zone][@section] || :unknown
      else
        :unknown
      end
    end

    def to_s
      str = "BowlerException (#{zone}, #{section}): "
      str += if ERR_MESSAGE_LOOKUP[@zone]
               ERR_MESSAGE_LOOKUP[@zone][@section] || ERR_MESSAGE_LOOKUP[@zone][:unknown]
             else
               ERR_MESSAGE_LOOKUP[:unknown]
             end
      str + ' -- ' + super
    end
  end
end
