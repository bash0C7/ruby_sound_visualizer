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
end
