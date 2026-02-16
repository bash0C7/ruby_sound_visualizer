require_relative 'test_helper'

class TestParticleSystem < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    srand(42)
    @system = ParticleSystem.new
  end

  def test_initialize_creates_particles
    data = @system.get_data
    assert_equal VisualizerPolicy::PARTICLE_COUNT * 3, data[:positions].length
    assert_equal VisualizerPolicy::PARTICLE_COUNT * 3, data[:colors].length
  end

  def test_get_data_returns_required_keys
    data = @system.get_data
    assert_includes data.keys, :positions
    assert_includes data.keys, :colors
    assert_includes data.keys, :avg_size
    assert_includes data.keys, :avg_opacity
  end

  def test_initial_avg_size_positive
    data = @system.get_data
    assert_operator data[:avg_size], :>, 0.0
  end

  def test_initial_avg_opacity_positive
    data = @system.get_data
    assert_operator data[:avg_opacity], :>, 0.0
    assert_operator data[:avg_opacity], :<=, 1.0
  end

  def test_update_with_silent_input
    @system.update(make_analysis(energy: 0.0))
    data = @system.get_data
    assert_equal VisualizerPolicy::PARTICLE_COUNT * 3, data[:positions].length
  end

  def test_update_with_high_energy
    srand(42)
    @system.update(make_analysis(energy: 0.9, bass: 0.8, mid: 0.7, high: 0.6))
    data = @system.get_data
    assert_equal VisualizerPolicy::PARTICLE_COUNT * 3, data[:positions].length
  end

  def test_particles_move_after_update
    initial = @system.get_data[:positions].dup
    srand(42)
    @system.update(make_analysis(energy: 0.9, bass: 0.8))
    after = @system.get_data[:positions]
    changed = initial.zip(after).count { |a, b| a != b }
    assert_operator changed, :>, 0
  end

  def test_no_nan_after_100_frames
    100.times do
      @system.update(make_analysis(energy: rand, bass: rand, mid: rand, high: rand))
    end
    data = @system.get_data
    data[:positions].each { |v| assert(!v.nan?, "position contains NaN") }
    data[:colors].each { |v| assert(!v.nan?, "color contains NaN") }
  end

  def test_particles_respect_boundary
    50.times { @system.update(make_analysis(energy: 1.0, bass: 1.0, mid: 1.0, high: 1.0)) }
    data = @system.get_data
    data[:positions].each_slice(3) do |x, y, z|
      assert_operator x.abs, :<=, VisualizerPolicy::PARTICLE_BOUNDARY + VisualizerPolicy::PARTICLE_SPAWN_RANGE
      assert_operator y.abs, :<=, VisualizerPolicy::PARTICLE_BOUNDARY + VisualizerPolicy::PARTICLE_SPAWN_RANGE
      assert_operator z.abs, :<=, VisualizerPolicy::PARTICLE_BOUNDARY + VisualizerPolicy::PARTICLE_SPAWN_RANGE
    end
  end

  def test_impulse_increases_explosion_probability
    srand(42)
    system1 = ParticleSystem.new
    system1.update(make_analysis(energy: 0.5, bass: 0.5))
    data1 = system1.get_data

    srand(42)
    system2 = ParticleSystem.new
    system2.update(make_analysis(energy: 0.5, bass: 0.5, impulse_overall: 1.0))
    data2 = system2.get_data

    # With impulse, particles should move more (different positions)
    diff = data1[:positions].zip(data2[:positions]).count { |a, b| a != b }
    assert_operator diff, :>, 0
  end

  def test_color_cache_updates_periodically
    @system.update(make_analysis(energy: 0.5, bass: 0.3))
    colors1 = @system.get_data[:colors].dup

    ColorPalette.set_hue_mode(1)
    # First frame after mode change may use cached colors
    @system.update(make_analysis(energy: 0.5, bass: 0.3))
    @system.update(make_analysis(energy: 0.5, bass: 0.3))
    @system.update(make_analysis(energy: 0.5, bass: 0.3))
    colors2 = @system.get_data[:colors]

    changed = colors1.zip(colors2).count { |a, b| a != b }
    assert_operator changed, :>, 0
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
