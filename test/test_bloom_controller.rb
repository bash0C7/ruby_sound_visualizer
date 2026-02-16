require_relative 'test_helper'

class TestBloomController < Test::Unit::TestCase
  def setup
    VisualizerPolicy.reset_runtime
    @controller = BloomController.new
  end

  def test_initial_strength
    data = @controller.get_data
    assert_in_delta VisualizerPolicy.bloom_base_strength, data[:strength], 0.001
  end

  def test_initial_threshold
    data = @controller.get_data
    assert_in_delta VisualizerPolicy::BLOOM_BASE_THRESHOLD, data[:threshold], 0.001
  end

  def test_get_data_returns_required_keys
    data = @controller.get_data
    assert_includes data.keys, :strength
    assert_includes data.keys, :threshold
  end

  def test_strength_increases_with_energy
    @controller.update(make_analysis(energy: 0.0))
    low = @controller.get_data[:strength]

    @controller.update(make_analysis(energy: 0.9))
    high = @controller.get_data[:strength]

    assert_operator high, :>, low
  end

  def test_strength_increases_with_impulse
    @controller.update(make_analysis(energy: 0.5))
    base = @controller.get_data[:strength]

    @controller.update(make_analysis(energy: 0.5, impulse_overall: 1.0))
    boosted = @controller.get_data[:strength]

    assert_operator boosted, :>, base
  end

  def test_threshold_decreases_with_energy
    @controller.update(make_analysis(energy: 0.0))
    low_energy_threshold = @controller.get_data[:threshold]

    @controller.update(make_analysis(energy: 0.9))
    high_energy_threshold = @controller.get_data[:threshold]

    assert_operator high_energy_threshold, :<=, low_energy_threshold
  end

  def test_threshold_respects_minimum
    @controller.update(make_analysis(energy: 1.0, impulse_overall: 1.0))
    data = @controller.get_data
    assert_operator data[:threshold], :>=, VisualizerPolicy::BLOOM_MIN_THRESHOLD
  end

  def test_strength_capped_by_policy
    VisualizerPolicy.max_bloom = 2.0
    @controller.update(make_analysis(energy: 1.0, impulse_overall: 1.0))
    data = @controller.get_data
    assert_operator data[:strength], :<=, 2.0
  end

  def test_bloom_flash_boosts_strength
    @controller.update(make_analysis(energy: 0.5))
    base = @controller.get_data[:strength]

    @controller.update(make_analysis(energy: 0.5, bloom_flash: 1.0))
    boosted = @controller.get_data[:strength]

    assert_operator boosted, :>, base
  end

  def test_no_nan_values
    10.times do
      @controller.update(make_analysis(energy: rand, impulse_overall: rand))
    end
    data = @controller.get_data
    assert(!data[:strength].nan?, "strength is NaN")
    assert(!data[:threshold].nan?, "threshold is NaN")
  end

  private

  def make_analysis(energy: 0.0, impulse_overall: 0.0, bloom_flash: 0.0)
    {
      overall_energy: energy,
      impulse: { overall: impulse_overall },
      bloom_flash: bloom_flash
    }
  end
end
