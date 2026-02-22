require_relative 'test_helper'

class TestOscilloscopeRenderer < Test::Unit::TestCase
  def setup
    @renderer = OscilloscopeRenderer.new
  end

  # --- Initial state ---

  def test_initial_enabled
    assert_equal true, @renderer.enabled?
  end

  def test_initial_buffer_size
    assert_equal 256, @renderer.buffer_size
  end

  def test_initial_waveform_buffer_is_zeros
    assert_equal 256, @renderer.waveform_buffer.length
    assert @renderer.waveform_buffer.all? { |v| v == 0.0 }
  end

  def test_initial_scroll_offset_zero
    assert_in_delta 0.0, @renderer.scroll_offset, 0.001
  end

  def test_initial_intensity_zero
    assert_in_delta 0.0, @renderer.intensity, 0.001
  end

  def test_initial_color
    c = @renderer.color
    assert_equal 3, c.length
    # Default green oscilloscope color
    assert_in_delta 0.0, c[0], 0.01
    assert_in_delta 1.0, c[1], 0.01
    assert_in_delta 0.4, c[2], 0.01
  end

  # --- Enable/Disable ---

  def test_disable
    @renderer.disable
    assert_equal false, @renderer.enabled?
  end

  def test_enable
    @renderer.disable
    @renderer.enable
    assert_equal true, @renderer.enabled?
  end

  # --- Update waveform buffer ---

  def test_update_waveform_stores_samples
    samples = Array.new(256) { |i| Math.sin(i * 0.1) }
    @renderer.update_waveform(samples)
    assert_in_delta samples[0], @renderer.waveform_buffer[0], 0.001
    assert_in_delta samples[127], @renderer.waveform_buffer[127], 0.001
  end

  def test_update_waveform_truncates_if_too_long
    samples = Array.new(512) { |i| i.to_f / 512 }
    @renderer.update_waveform(samples)
    assert_equal 256, @renderer.waveform_buffer.length
  end

  def test_update_waveform_pads_if_too_short
    samples = [0.5, -0.5, 0.3]
    @renderer.update_waveform(samples)
    assert_equal 256, @renderer.waveform_buffer.length
    assert_in_delta 0.5, @renderer.waveform_buffer[0], 0.001
    assert_in_delta -0.5, @renderer.waveform_buffer[1], 0.001
    assert_in_delta 0.3, @renderer.waveform_buffer[2], 0.001
    assert_in_delta 0.0, @renderer.waveform_buffer[3], 0.001
  end

  def test_update_waveform_clamps_values
    samples = Array.new(256) { 2.0 }
    @renderer.update_waveform(samples)
    assert_in_delta 1.0, @renderer.waveform_buffer[0], 0.001
  end

  def test_update_waveform_clamps_negative
    samples = Array.new(256) { -2.0 }
    @renderer.update_waveform(samples)
    assert_in_delta(-1.0, @renderer.waveform_buffer[0], 0.001)
  end

  # --- Scroll (left-to-right flow) ---

  def test_advance_scroll_increases_offset
    @renderer.advance_scroll(16.67)
    assert @renderer.scroll_offset > 0.0
  end

  def test_advance_scroll_with_zero_delta
    @renderer.advance_scroll(0.0)
    assert_in_delta 0.0, @renderer.scroll_offset, 0.001
  end

  def test_scroll_speed_default
    assert_in_delta 2.0, @renderer.scroll_speed, 0.01
  end

  def test_set_scroll_speed
    @renderer.set_scroll_speed(5.0)
    assert_in_delta 5.0, @renderer.scroll_speed, 0.01
  end

  def test_set_scroll_speed_clamps_min
    @renderer.set_scroll_speed(-1.0)
    assert_in_delta 0.1, @renderer.scroll_speed, 0.01
  end

  def test_set_scroll_speed_clamps_max
    @renderer.set_scroll_speed(20.0)
    assert_in_delta 10.0, @renderer.scroll_speed, 0.01
  end

  def test_scroll_wraps_around
    # Advance many frames to exceed width
    100.times { @renderer.advance_scroll(100.0) }
    # Offset should be wrapped within range
    assert @renderer.scroll_offset >= 0.0
    assert @renderer.scroll_offset < @renderer.ribbon_width
  end

  # --- Intensity ---

  def test_set_intensity
    @renderer.set_intensity(0.8)
    assert_in_delta 0.8, @renderer.intensity, 0.001
  end

  def test_set_intensity_clamps_min
    @renderer.set_intensity(-0.5)
    assert_in_delta 0.0, @renderer.intensity, 0.001
  end

  def test_set_intensity_clamps_max
    @renderer.set_intensity(2.0)
    assert_in_delta 1.0, @renderer.intensity, 0.001
  end

  def test_intensity_affects_amplitude
    @renderer.set_intensity(0.5)
    data = @renderer.render_data
    assert_in_delta 0.5, data[:intensity], 0.001
  end

  # --- Color ---

  def test_set_color
    @renderer.set_color(1.0, 0.0, 0.5)
    c = @renderer.color
    assert_in_delta 1.0, c[0], 0.01
    assert_in_delta 0.0, c[1], 0.01
    assert_in_delta 0.5, c[2], 0.01
  end

  def test_set_color_clamps
    @renderer.set_color(2.0, -1.0, 0.5)
    c = @renderer.color
    assert_in_delta 1.0, c[0], 0.01
    assert_in_delta 0.0, c[1], 0.01
    assert_in_delta 0.5, c[2], 0.01
  end

  # --- Ribbon geometry parameters ---

  def test_ribbon_width_default
    assert_in_delta 20.0, @renderer.ribbon_width, 0.1
  end

  def test_ribbon_height_default
    assert_in_delta 3.0, @renderer.ribbon_height, 0.1
  end

  def test_ribbon_z_position_default
    # Should be in front of other objects (closer to camera)
    assert @renderer.z_position > 0
    assert_in_delta 8.0, @renderer.z_position, 0.1
  end

  def test_ribbon_y_position_default
    assert_in_delta(-2.0, @renderer.y_position, 0.1)
  end

  # --- Render data ---

  def test_render_data_structure
    data = @renderer.render_data
    assert_kind_of Hash, data
    assert data.key?(:waveform)
    assert data.key?(:scroll_offset)
    assert data.key?(:intensity)
    assert data.key?(:color)
    assert data.key?(:ribbon_width)
    assert data.key?(:ribbon_height)
    assert data.key?(:z_position)
    assert data.key?(:y_position)
    assert data.key?(:enabled)
  end

  def test_render_data_waveform_is_array
    data = @renderer.render_data
    assert_kind_of Array, data[:waveform]
    assert_equal 256, data[:waveform].length
  end

  def test_render_data_disabled
    @renderer.disable
    data = @renderer.render_data
    assert_equal false, data[:enabled]
  end

  def test_render_data_enabled
    data = @renderer.render_data
    assert_equal true, data[:enabled]
  end

  # --- History ring buffer for 3D ribbon ---

  def test_history_depth_default
    assert_equal 64, @renderer.history_depth
  end

  def test_push_waveform_to_history
    samples = Array.new(256) { |i| Math.sin(i * 0.1) }
    @renderer.update_waveform(samples)
    @renderer.push_to_history
    assert_equal 1, @renderer.history_length
  end

  def test_history_caps_at_depth
    70.times do |i|
      samples = Array.new(256) { |j| Math.sin(j * 0.1 + i) }
      @renderer.update_waveform(samples)
      @renderer.push_to_history
    end
    assert_equal 64, @renderer.history_length
  end

  def test_render_data_includes_history
    samples = Array.new(256) { |i| Math.sin(i * 0.1) }
    @renderer.update_waveform(samples)
    @renderer.push_to_history
    data = @renderer.render_data
    assert data.key?(:history)
    assert_equal 1, data[:history].length
  end

  # --- Status ---

  def test_status_enabled
    result = @renderer.status
    assert_match(/on/, result)
  end

  def test_status_disabled
    @renderer.disable
    result = @renderer.status
    assert_match(/off/, result)
  end

  def test_status_includes_scroll_speed
    result = @renderer.status
    assert_match(/speed/, result)
  end
end
