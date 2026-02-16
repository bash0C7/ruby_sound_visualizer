require_relative 'test_helper'

class TestGeometryMorpher < Test::Unit::TestCase
  def setup
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    @morpher = GeometryMorpher.new
  end

  def test_initial_get_data
    data = @morpher.get_data
    assert_in_delta VisualizerPolicy::GEOMETRY_BASE_SCALE, data[:scale], 0.001
    assert_equal [0, 0, 0], data[:rotation]
    assert_in_delta 0.0, data[:emissive_intensity], 0.001
  end

  def test_get_data_returns_required_keys
    data = @morpher.get_data
    %i[scale rotation emissive_intensity color].each do |key|
      assert_includes data.keys, key
    end
  end

  def test_scale_increases_with_energy
    @morpher.update(make_analysis(energy: 0.0))
    low = @morpher.get_data[:scale]

    morpher2 = GeometryMorpher.new
    morpher2.update(make_analysis(energy: 0.9))
    high = morpher2.get_data[:scale]

    assert_operator high, :>, low
  end

  def test_scale_boosted_by_impulse
    @morpher.update(make_analysis(energy: 0.5))
    base = @morpher.get_data[:scale]

    morpher2 = GeometryMorpher.new
    morpher2.update(make_analysis(energy: 0.5, impulse_overall: 1.0))
    boosted = morpher2.get_data[:scale]

    assert_operator boosted, :>, base
  end

  def test_rotation_accumulates
    @morpher.update(make_analysis(bass: 0.5, mid: 0.5, high: 0.5))
    rot1 = @morpher.get_data[:rotation].dup

    @morpher.update(make_analysis(bass: 0.5, mid: 0.5, high: 0.5))
    rot2 = @morpher.get_data[:rotation]

    3.times { |i| assert_operator rot2[i].abs, :>, rot1[i].abs }
  end

  def test_rotation_increases_with_impulse
    m1 = GeometryMorpher.new
    m1.update(make_analysis(bass: 0.5))
    rot1 = m1.get_data[:rotation]

    m2 = GeometryMorpher.new
    m2.update(make_analysis(bass: 0.5, impulse_bass: 1.0))
    rot2 = m2.get_data[:rotation]

    assert_operator rot2[0].abs, :>, rot1[0].abs
  end

  def test_emissive_increases_with_energy
    @morpher.update(make_analysis(energy: 0.0))
    low = @morpher.get_data[:emissive_intensity]

    morpher2 = GeometryMorpher.new
    morpher2.update(make_analysis(energy: 0.9))
    high = morpher2.get_data[:emissive_intensity]

    assert_operator high, :>, low
  end

  def test_emissive_capped_by_policy
    VisualizerPolicy.max_emissive = 1.0
    @morpher.update(make_analysis(energy: 1.0, impulse_overall: 1.0))
    assert_operator @morpher.get_data[:emissive_intensity], :<=, 1.0
  end

  def test_color_is_rgb_array
    @morpher.update(make_analysis(energy: 0.5, bass: 0.3, mid: 0.3, high: 0.3))
    color = @morpher.get_data[:color]
    assert_instance_of Array, color
    assert_equal 3, color.length
    color.each { |c| assert_kind_of Numeric, c }
  end

  def test_no_nan_after_many_frames
    50.times do
      @morpher.update(make_analysis(energy: rand, bass: rand, mid: rand, high: rand))
    end
    data = @morpher.get_data
    assert(!data[:scale].nan?, "scale is NaN")
    assert(!data[:emissive_intensity].nan?, "emissive is NaN")
    data[:rotation].each { |r| assert(!r.nan?, "rotation contains NaN") }
  end

  private

  def make_analysis(energy: 0.0, bass: 0.0, mid: 0.0, high: 0.0, impulse_overall: 0.0, impulse_bass: 0.0, impulse_mid: 0.0, impulse_high: 0.0)
    {
      overall_energy: energy,
      bass: bass,
      mid: mid,
      high: high,
      impulse: {
        overall: impulse_overall,
        bass: impulse_bass,
        mid: impulse_mid,
        high: impulse_high
      }
    }
  end
end
