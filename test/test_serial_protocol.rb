require_relative 'test_helper'

class TestSerialProtocol < Test::Unit::TestCase
  # --- Encoding ---

  def test_encode_produces_valid_frame_format
    frame = SerialProtocol.encode(level: 0.5, bass: 1.0, mid: 0.0, high: 0.75)
    assert frame.start_with?('<')
    assert frame.include?('>')
    assert frame.end_with?("\n")
  end

  def test_encode_scales_float_to_byte
    frame = SerialProtocol.encode(level: 1.0, bass: 0.0, mid: 0.5, high: 0.25)
    assert_match(/L:255/, frame)
    assert_match(/B:0/, frame)
    assert_match(/M:128/, frame)
    assert_match(/H:64/, frame)
  end

  def test_encode_clamps_above_1
    frame = SerialProtocol.encode(level: 2.0, bass: 0.0, mid: 0.0, high: 0.0)
    assert_match(/L:255/, frame)
  end

  def test_encode_clamps_below_0
    frame = SerialProtocol.encode(level: -0.5, bass: 0.0, mid: 0.0, high: 0.0)
    assert_match(/L:0/, frame)
  end

  def test_encode_full_frame_string
    frame = SerialProtocol.encode(level: 0.0, bass: 0.0, mid: 0.0, high: 0.0)
    assert_equal "<L:0,B:0,M:0,H:0>\n", frame
  end

  # --- Decoding ---

  def test_decode_valid_frame
    result = SerialProtocol.decode("<L:255,B:128,M:64,H:0>")
    assert_not_nil result
    assert_in_delta 1.0, result[:level], 0.01
    assert_in_delta 0.502, result[:bass], 0.01
    assert_in_delta 0.251, result[:mid], 0.01
    assert_in_delta 0.0, result[:high], 0.01
  end

  def test_decode_nil_for_nil_input
    assert_nil SerialProtocol.decode(nil)
  end

  def test_decode_nil_for_empty_string
    assert_nil SerialProtocol.decode("")
  end

  def test_decode_nil_for_missing_start_marker
    assert_nil SerialProtocol.decode("L:255,B:128,M:64,H:0>")
  end

  def test_decode_nil_for_missing_end_marker
    assert_nil SerialProtocol.decode("<L:255,B:128,M:64,H:0")
  end

  def test_decode_nil_for_wrong_field_count
    assert_nil SerialProtocol.decode("<L:255,B:128,M:64>")
  end

  def test_decode_nil_for_unknown_key
    assert_nil SerialProtocol.decode("<L:255,B:128,X:64,H:0>")
  end

  def test_decode_nil_for_out_of_range_value
    assert_nil SerialProtocol.decode("<L:256,B:128,M:64,H:0>")
  end

  def test_decode_nil_for_negative_value
    assert_nil SerialProtocol.decode("<L:-1,B:128,M:64,H:0>")
  end

  def test_decode_nil_for_malformed_numeric_value
    assert_nil SerialProtocol.decode("<L:12x,B:128,M:64,H:0>")
    assert_nil SerialProtocol.decode("<L:128,B:abc,M:64,H:0>")
    assert_nil SerialProtocol.decode("<L:12.5,B:128,M:64,H:0>")
  end

  def test_decode_nil_for_extra_colon_in_pair
    assert_nil SerialProtocol.decode("<L:255:99,B:128,M:64,H:0>")
    assert_nil SerialProtocol.decode("<L:255,B:128:1,M:64,H:0>")
  end

  # --- Round-trip ---

  def test_encode_decode_roundtrip
    original = { level: 0.5, bass: 0.75, mid: 0.25, high: 1.0 }
    frame = SerialProtocol.encode(**original)
    decoded = SerialProtocol.decode(frame.strip)
    assert_not_nil decoded
    assert_in_delta original[:level], decoded[:level], 0.01
    assert_in_delta original[:bass], decoded[:bass], 0.01
    assert_in_delta original[:mid], decoded[:mid], 0.01
    assert_in_delta original[:high], decoded[:high], 0.01
  end

  # --- Frame extraction from buffer ---

  def test_extract_frames_single_complete_frame
    buffer = "<L:128,B:64,M:32,H:0>\ngarbage"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_in_delta 0.502, frames[0][:level], 0.01
    assert_equal '', remaining
  end

  def test_extract_frames_multiple_frames
    buffer = "<L:255,B:0,M:0,H:0>\n<L:0,B:255,M:0,H:0>\n"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 2, frames.length
    assert_in_delta 1.0, frames[0][:level], 0.01
    assert_in_delta 1.0, frames[1][:bass], 0.01
  end

  def test_extract_frames_incomplete_frame_preserved
    buffer = "junk<L:128,B:64,M:32,H:0>\n<L:64"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_equal '<L:64', remaining
  end

  def test_extract_frames_empty_buffer
    frames, remaining = SerialProtocol.extract_frames("")
    assert_equal 0, frames.length
    assert_equal '', remaining
  end

  def test_extract_frames_only_garbage
    frames, remaining = SerialProtocol.extract_frames("random garbage text")
    assert_equal 0, frames.length
    assert_equal '', remaining
  end

  def test_extract_frames_skips_invalid_frames
    buffer = "<INVALID>\n<L:128,B:64,M:32,H:0>\n"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_in_delta 0.502, frames[0][:level], 0.01
  end

  # --- Frequency frame encoding ---

  def test_encode_frequency_produces_valid_frame_format
    frame = SerialProtocol.encode_frequency(freq: 440, duty: 50)
    assert frame.start_with?('<')
    assert frame.include?('>')
    assert frame.end_with?("\n")
  end

  def test_encode_frequency_full_frame_string
    frame = SerialProtocol.encode_frequency(freq: 440, duty: 50)
    assert_equal "<F:440,D:50>\n", frame
  end

  def test_encode_frequency_clamps_above_max
    frame = SerialProtocol.encode_frequency(freq: 25000, duty: 150)
    assert_match(/F:20000/, frame)
    assert_match(/D:100/, frame)
  end

  def test_encode_frequency_clamps_below_min
    frame = SerialProtocol.encode_frequency(freq: -100, duty: -10)
    assert_match(/F:0/, frame)
    assert_match(/D:0/, frame)
  end

  def test_encode_frequency_rounds_floats
    frame = SerialProtocol.encode_frequency(freq: 440.7, duty: 50.3)
    assert_match(/F:441/, frame)
    assert_match(/D:50/, frame)
  end

  # --- Frequency frame decoding ---

  def test_decode_frequency_valid_frame
    result = SerialProtocol.decode_frequency("<F:440,D:50>")
    assert_not_nil result
    assert_equal 440, result[:frequency]
    assert_equal 50, result[:duty]
  end

  def test_decode_frequency_boundary_values
    result = SerialProtocol.decode_frequency("<F:0,D:0>")
    assert_not_nil result
    assert_equal 0, result[:frequency]
    assert_equal 0, result[:duty]

    result = SerialProtocol.decode_frequency("<F:20000,D:100>")
    assert_not_nil result
    assert_equal 20000, result[:frequency]
    assert_equal 100, result[:duty]
  end

  def test_decode_frequency_nil_for_nil_input
    assert_nil SerialProtocol.decode_frequency(nil)
  end

  def test_decode_frequency_nil_for_empty_string
    assert_nil SerialProtocol.decode_frequency("")
  end

  def test_decode_frequency_nil_for_missing_markers
    assert_nil SerialProtocol.decode_frequency("F:440,D:50>")
    assert_nil SerialProtocol.decode_frequency("<F:440,D:50")
  end

  def test_decode_frequency_nil_for_wrong_field_count
    assert_nil SerialProtocol.decode_frequency("<F:440>")
    assert_nil SerialProtocol.decode_frequency("<F:440,D:50,X:1>")
  end

  def test_decode_frequency_nil_for_unknown_key
    assert_nil SerialProtocol.decode_frequency("<F:440,X:50>")
  end

  def test_decode_frequency_nil_for_out_of_range
    assert_nil SerialProtocol.decode_frequency("<F:20001,D:50>")
    assert_nil SerialProtocol.decode_frequency("<F:440,D:101>")
  end

  def test_decode_frequency_nil_for_negative_value
    assert_nil SerialProtocol.decode_frequency("<F:-1,D:50>")
  end

  def test_decode_frequency_nil_for_malformed_value
    assert_nil SerialProtocol.decode_frequency("<F:abc,D:50>")
    assert_nil SerialProtocol.decode_frequency("<F:440,D:12.5>")
  end

  def test_decode_frequency_nil_for_extra_colon_in_pair
    assert_nil SerialProtocol.decode_frequency("<F:440:999,D:50>")
    assert_nil SerialProtocol.decode_frequency("<F:440,D:50:1>")
  end

  def test_decode_frequency_nil_for_audio_level_frame
    assert_nil SerialProtocol.decode_frequency("<L:255,B:128,M:64,H:0>")
  end

  # --- Frequency round-trip ---

  def test_encode_decode_frequency_roundtrip
    frame = SerialProtocol.encode_frequency(freq: 880, duty: 75)
    decoded = SerialProtocol.decode_frequency(frame.strip)
    assert_not_nil decoded
    assert_equal 880, decoded[:frequency]
    assert_equal 75, decoded[:duty]
  end

  # --- Mixed frame extraction ---

  def test_extract_frames_frequency_frame
    buffer = "<F:440,D:50>\n"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_equal :frequency, frames[0][:type]
    assert_equal 440, frames[0][:frequency]
    assert_equal 50, frames[0][:duty]
  end

  def test_extract_frames_audio_level_has_type
    buffer = "<L:128,B:64,M:32,H:0>\n"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_equal :audio_level, frames[0][:type]
    assert frames[0].key?(:level)
  end

  def test_extract_frames_mixed_frame_types
    buffer = "<L:128,B:64,M:32,H:0>\n<F:440,D:50>\n<L:255,B:0,M:0,H:0>\n"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 3, frames.length
    assert_equal :audio_level, frames[0][:type]
    assert_equal :frequency, frames[1][:type]
    assert_equal :audio_level, frames[2][:type]
    assert_equal 440, frames[1][:frequency]
  end

  def test_extract_frames_incomplete_frequency_frame_preserved
    buffer = "<F:440,D:50>\n<F:88"
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_equal '<F:88', remaining
  end

  # --- Buffer overflow protection (B-2) ---

  def test_extract_frames_truncates_oversized_buffer
    garbage = "x" * 5000
    valid_frame = "<L:128,B:64,M:32,H:0>"
    buffer = garbage + valid_frame
    frames, _remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 1, frames.length
    assert_in_delta 0.502, frames[0][:level], 0.01
  end

  def test_extract_frames_handles_max_buffer_boundary
    buffer = "x" * (SerialProtocol::MAX_BUFFER_SIZE + 100)
    frames, remaining = SerialProtocol.extract_frames(buffer)
    assert_equal 0, frames.length
    assert_equal '', remaining
  end
end
