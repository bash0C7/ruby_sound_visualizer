# SerialProtocol: Stateless ASCII frame format for serial communication.
# Frame format: "<L:NNN,B:NNN,M:NNN,H:NNN>\n"
# - Start marker: '<'
# - End marker: '>'
# - Newline terminator: "\n"
# - Values: 0-255 integer (scaled from 0.0-1.0 float)
# - Fields: L=level(overall), B=bass, M=mid, H=high
# Robust to mid-stream disconnects: each frame is self-contained.
module SerialProtocol
  START_MARKER = '<'
  END_MARKER = '>'
  TERMINATOR = "\n"
  MAX_VALUE = 255
  MIN_VALUE = 0

  # Encode audio analysis data into a serial frame string.
  # @param level [Float] overall energy 0.0-1.0
  # @param bass [Float] bass energy 0.0-1.0
  # @param mid [Float] mid energy 0.0-1.0
  # @param high [Float] high energy 0.0-1.0
  # @return [String] encoded frame
  def self.encode(level:, bass:, mid:, high:)
    l = scale_to_byte(level)
    b = scale_to_byte(bass)
    m = scale_to_byte(mid)
    h = scale_to_byte(high)
    "#{START_MARKER}L:#{l},B:#{b},M:#{m},H:#{h}#{END_MARKER}#{TERMINATOR}"
  end

  # Decode a serial frame string into a hash of float values.
  # @param frame [String] raw frame string
  # @return [Hash, nil] decoded values or nil if invalid
  def self.decode(frame)
    return nil unless frame.is_a?(String)
    stripped = frame.strip
    return nil unless stripped.start_with?(START_MARKER) && stripped.end_with?(END_MARKER)

    body = stripped[1..-2]
    pairs = body.split(',')
    return nil unless pairs.length == 4

    values = {}
    pairs.each do |pair|
      key, val = pair.split(':')
      return nil unless key && val
      int_val = val.to_i
      return nil if int_val < MIN_VALUE || int_val > MAX_VALUE
      case key
      when 'L' then values[:level] = byte_to_float(int_val)
      when 'B' then values[:bass] = byte_to_float(int_val)
      when 'M' then values[:mid] = byte_to_float(int_val)
      when 'H' then values[:high] = byte_to_float(int_val)
      else return nil
      end
    end

    return nil unless values.key?(:level) && values.key?(:bass) && values.key?(:mid) && values.key?(:high)
    values
  end

  # Extract complete frames from a receive buffer string.
  # Returns array of decoded hashes and remaining unparsed buffer.
  # @param buffer [String] accumulated receive buffer
  # @return [Array<Hash>, String] array of decoded frames and remaining buffer
  def self.extract_frames(buffer)
    frames = []
    remaining = buffer.dup

    while (start_idx = remaining.index(START_MARKER))
      end_idx = remaining.index(END_MARKER, start_idx)
      break unless end_idx

      frame_str = remaining[start_idx..end_idx]
      decoded = decode(frame_str)
      frames << decoded if decoded

      remaining = remaining[(end_idx + 1)..]
    end

    # Keep only from the last unmatched start marker
    if remaining && remaining.index(START_MARKER)
      remaining = remaining[remaining.index(START_MARKER)..]
    else
      remaining = ''
    end

    [frames, remaining]
  end

  def self.scale_to_byte(float_val)
    val = (float_val.to_f * MAX_VALUE).round
    [[val, MIN_VALUE].max, MAX_VALUE].min
  end

  def self.byte_to_float(byte_val)
    byte_val.to_f / MAX_VALUE
  end

  private_class_method :scale_to_byte, :byte_to_float
end
