class Array
  alias_method :orig_triple_eq, '==='.to_sym

  # Overriden to act like include? when comparing a given value to an array,
  # unless the value being compared is itself an array.
  def === (val)
    unless val.is_a?(Array)
      self.include? val
    else
      self.orig_triple_eq(val)
    end
  end

  # Converts an array to an integer via the pack and unpack methods
  def to_i (signed=true,native_endian=false)
    pv = self.pack('C*')
    if signed
      if (native_endian)
        case(size)
        when 1
          pv.unpack('c')[0]
        when (2..3)
          pv.unpack('s')[0]
        when (4..7)
          pv.unpack('l')[0]
        else
          pv.unpack('q')[0]
        end
      else
        case(size)
        when 1
          pv.unpack('c')[0]
        when (2..3)
          pv.unpack('s>')[0]
        when (4..7)
          pv.unpack('l>')[0]
        else
          pv.unpack('q>')[0]
        end
      end
    else
      if native_endian
        case(size)
        when 1
          pv.unpack('C')[0]
        when (2..3)
          pv.unpack('S')[0]
        when (4..7)
          pv.unpack('L')[0]
        else
          pv.unpack('Q')[0]
        end
      else
        case(size)
        when 1
          pv.unpack('C')[0]
        when (2..3)
          pv.unpack('S>')[0]
        when (4..7)
          pv.unpack('L>')[0]
        else
          pv.unpack('Q>')[0]
        end
      end
    end
  end
end

class Fixnum

  # Converts an integer to an array via the pack and unpack methods
  def to_a(size,native_endian=false)
    if native_endian
      (case(size)
      when 1
        [self].pack('C')
      when (2..3)
        [self].pack('S')
      when (4..7)
        [self].pack('L')
      else
        [self].pack('Q')
      end
      ).unpack('C'*size)
    else
      (case(size)
      when 1
        [self].pack('C')
      when (2..3)
        [self].pack('S>')
      when (4..7)
        [self].pack('L>')
      else
        [self].pack('Q>')
      end).unpack('C'*size)
    end
  end
end
