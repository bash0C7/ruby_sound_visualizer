require_relative 'test_helper'

class TestVRMModeDetection < Test::Unit::TestCase
  # Test the regex used for VRM mode detection in ruby-main.
  # The pattern should match ?vrm, &vrm, ?vrm=1, &vrm=1
  # but NOT substrings like ?maxBrightness=vrm123

  PATTERN = /[?&]vrm(?:=|&|$)/

  def test_matches_vrm_only_param
    assert_match PATTERN, "?vrm"
  end

  def test_matches_vrm_with_value
    assert_match PATTERN, "?vrm=1"
  end

  def test_matches_vrm_as_second_param
    assert_match PATTERN, "?sensitivity=1.0&vrm"
  end

  def test_matches_vrm_with_value_and_other_params
    assert_match PATTERN, "?vrm=1&sensitivity=1.5"
  end

  def test_does_not_match_vrm_substring_in_value
    refute_match PATTERN, "?maxBrightness=vrm123"
  end

  def test_does_not_match_vrm_as_part_of_param_name
    refute_match PATTERN, "?vrmExtra=1"
  end

  def test_matches_vrm_between_params
    assert_match PATTERN, "?foo=1&vrm&bar=2"
  end

  def test_matches_vrm_with_equals_between_params
    assert_match PATTERN, "?foo=1&vrm=true&bar=2"
  end
end
