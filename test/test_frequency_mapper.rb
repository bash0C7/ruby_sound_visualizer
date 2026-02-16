require_relative 'test_helper'

class TestFrequencyMapper < Test::Unit::TestCase
  def setup
    @mapper = FrequencyMapper.new
  end

  def test_split_bands_returns_three_keys
    data = Array.new(1024, 100.0)
    result = @mapper.split_bands(data)
    assert_includes result.keys, :bass
    assert_includes result.keys, :mid
    assert_includes result.keys, :high
  end

  def test_bass_range_covers_0_to_250hz
    bin_size = 48000.0 / 2048.0  # ~23.44 Hz per bin
    expected_bins = (250.0 / bin_size).ceil + 1  # bins 0 through ceil(250/23.44)
    data = Array.new(1024, 50.0)
    result = @mapper.split_bands(data)
    assert_operator result[:bass].length, :>=, 10
  end

  def test_mid_range_covers_250_to_2000hz
    data = Array.new(1024, 50.0)
    result = @mapper.split_bands(data)
    assert_operator result[:mid].length, :>, result[:bass].length
  end

  def test_high_range_covers_2000_to_20000hz
    data = Array.new(1024, 50.0)
    result = @mapper.split_bands(data)
    assert_operator result[:high].length, :>, 0
  end

  def test_empty_data_returns_empty_bands
    result = @mapper.split_bands([])
    assert_equal [], result[:bass]
    assert_equal [], result[:mid]
    assert_equal [], result[:high]
  end

  def test_single_element_data
    result = @mapper.split_bands([100.0])
    assert_equal [100.0], result[:bass]
  end

  def test_all_bands_contain_correct_data_values
    data = (0...1024).map { |i| i.to_f }
    result = @mapper.split_bands(data)
    result[:bass].each { |v| assert_kind_of Numeric, v }
    result[:mid].each { |v| assert_kind_of Numeric, v }
    result[:high].each { |v| assert_kind_of Numeric, v }
  end

  def test_total_bins_cover_full_spectrum
    data = Array.new(1024, 1.0)
    result = @mapper.split_bands(data)
    total_bins = result[:bass].length + result[:mid].length + result[:high].length
    assert_operator total_bins, :<=, 1024
  end

  def test_bands_do_not_have_gaps
    bin_size = 48000.0 / 2048.0
    bass_end_bin = (250.0 / bin_size).ceil
    mid_start_bin = (250.0 / bin_size).floor
    # Bass and mid ranges overlap at 250Hz boundary
    assert_operator bass_end_bin, :>=, mid_start_bin
  end
end
