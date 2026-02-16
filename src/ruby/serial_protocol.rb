module SerialProtocol
  START_MARKER = '<'
  END_MARKER = '>'
  TERMINATOR = "\n"
  MAX_VALUE = 255
  MIN_VALUE = 0
  FREQ_MAX = 20000
  FREQ_MIN = 0
  DUTY_MAX = 100
  DUTY_MIN = 0
  MAX_BUFFER_SIZE = 4096

  FRAME_SPECS = {
    audio_level: {
      fields: {
        'L' => { key: :level, range: MIN_VALUE..MAX_VALUE, convert: :byte_to_float },
        'B' => { key: :bass,  range: MIN_VALUE..MAX_VALUE, convert: :byte_to_float },
        'M' => { key: :mid,   range: MIN_VALUE..MAX_VALUE, convert: :byte_to_float },
        'H' => { key: :high,  range: MIN_VALUE..MAX_VALUE, convert: :byte_to_float },
      },
      count: 4
    },
    frequency: {
      fields: {
        'F' => { key: :frequency, range: FREQ_MIN..FREQ_MAX },
        'D' => { key: :duty,      range: DUTY_MIN..DUTY_MAX },
      },
      count: 2
    }
  }.freeze

  def self.encode(level:, bass:, mid:, high:)
    l = scale_to_byte(level)
    b = scale_to_byte(bass)
    m = scale_to_byte(mid)
    h = scale_to_byte(high)
    "#{START_MARKER}L:#{l},B:#{b},M:#{m},H:#{h}#{END_MARKER}#{TERMINATOR}"
  end

  def self.decode(frame)
    parse_frame(frame, FRAME_SPECS[:audio_level])
  end

  def self.encode_frequency(freq:, duty:)
    f = [[freq.to_f.round, FREQ_MIN].max, FREQ_MAX].min
    d = [[duty.to_f.round, DUTY_MIN].max, DUTY_MAX].min
    "#{START_MARKER}F:#{f},D:#{d}#{END_MARKER}#{TERMINATOR}"
  end

  def self.decode_frequency(frame)
    parse_frame(frame, FRAME_SPECS[:frequency])
  end

  def self.extract_frames(buffer)
    remaining = buffer.dup
    frames = []

    while (start_idx = remaining.index(START_MARKER))
      end_idx = remaining.index(END_MARKER, start_idx)
      break unless end_idx

      frame_str = remaining[start_idx..end_idx]
      decoded = decode_any(frame_str)
      frames << decoded if decoded

      remaining = remaining[(end_idx + 1)..]
    end

    if remaining && remaining.index(START_MARKER)
      remaining = remaining[remaining.index(START_MARKER)..]
    else
      remaining = ''
    end

    remaining = remaining[-MAX_BUFFER_SIZE..] if remaining.length > MAX_BUFFER_SIZE

    [frames, remaining]
  end

  def self.decode_any(frame)
    audio = decode(frame)
    return audio.merge(type: :audio_level) if audio

    freq = decode_frequency(frame)
    return freq.merge(type: :frequency) if freq

    nil
  end

  def self.parse_frame(frame, spec)
    return nil unless frame.is_a?(String)
    stripped = frame.strip
    return nil unless stripped.start_with?(START_MARKER) && stripped.end_with?(END_MARKER)

    body = stripped[1..-2]
    pairs = body.split(',')
    return nil unless pairs.length == spec[:count]

    values = {}
    pairs.each do |pair|
      parts = pair.split(':')
      return nil unless parts.length == 2
      key, val = parts
      return nil unless val.match?(/\A\d+\z/)

      field_def = spec[:fields][key]
      return nil unless field_def

      int_val = val.to_i
      return nil unless field_def[:range].include?(int_val)

      values[field_def[:key]] = field_def[:convert] ? send(field_def[:convert], int_val) : int_val
    end

    return nil unless values.length == spec[:count]
    values
  end

  def self.scale_to_byte(float_val)
    val = (float_val.to_f * MAX_VALUE).round
    [[val, MIN_VALUE].max, MAX_VALUE].min
  end

  def self.byte_to_float(byte_val)
    byte_val.to_f / MAX_VALUE
  end

  private_class_method :scale_to_byte, :byte_to_float, :decode_any, :parse_frame
end
