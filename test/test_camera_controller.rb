require_relative 'test_helper'

class TestCameraController < Test::Unit::TestCase
  def setup
    @controller = CameraController.new
  end

  def test_initial_get_data
    data = @controller.get_data
    assert_equal [0, 0, 5], data[:position]
    assert_equal [0, 0, 0], data[:shake]
  end

  def test_update_with_low_bass_decays_shake
    @controller.update(make_analysis(bass: 0.8))
    first_shake = @controller.get_data[:shake].map(&:abs).max

    @controller.update(make_analysis(bass: 0.1))
    second_shake = @controller.get_data[:shake].map(&:abs).max

    assert_operator second_shake, :<, first_shake
  end

  def test_update_with_high_bass_triggers_shake
    @controller.update(make_analysis(bass: 0.8))
    data = @controller.get_data
    shake_magnitude = data[:shake].map(&:abs).max
    assert_operator shake_magnitude, :>, 0.0
  end

  def test_update_with_bass_impulse_triggers_shake
    @controller.update(make_analysis(bass: 0.3, impulse_bass: 0.5))
    data = @controller.get_data
    shake_magnitude = data[:shake].map(&:abs).max
    assert_operator shake_magnitude, :>, 0.0
  end

  def test_shake_decays_over_frames
    @controller.update(make_analysis(bass: 0.9))
    50.times { @controller.update(make_analysis(bass: 0.0)) }
    data = @controller.get_data
    shake_magnitude = data[:shake].map(&:abs).max
    assert_operator shake_magnitude, :<, 0.01
  end

  def test_position_remains_constant
    5.times { @controller.update(make_analysis(bass: 0.8)) }
    assert_equal [0, 0, 5], @controller.get_data[:position]
  end

  def test_shake_z_is_half_intensity_of_xy
    srand(42)
    @controller.update(make_analysis(bass: 0.9, impulse_bass: 0.5))
    shake = @controller.get_data[:shake]
    # z component uses * 0.5 multiplier compared to x,y
    assert_kind_of Float, shake[2]
  end

  private

  def make_analysis(bass: 0.0, impulse_bass: 0.0)
    { bass: bass, impulse: { bass: impulse_bass } }
  end
end

class TestCameraControllerLogging < Test::Unit::TestCase
  def setup
    @controller = CameraController.new
    @log_messages = []
    captured = @log_messages
    mock_console = Object.new
    mock_console.define_singleton_method(:log) { |msg| captured << msg.to_s }
    mock_console.define_singleton_method(:error) { |msg| }
    JS.global['console'] = mock_console
  end

  def teardown
    JS.reset_global!
  end

  def test_logs_on_bass_shake_trigger
    analysis = { bass: 0.9, impulse: { bass: 0.0 } }
    @controller.update(analysis)
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') }
    assert ruby_logs.any? { |m| m.include?('camera.shake.trigger=') },
           "Expected log with camera.shake.trigger, got: #{ruby_logs.inspect}"
  end

  def test_logs_on_impulse_shake_trigger
    analysis = { bass: 0.0, impulse: { bass: 0.8 } }
    @controller.update(analysis)
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') }
    assert ruby_logs.any? { |m| m.include?('camera.shake.trigger=') },
           "Expected log with camera.shake.trigger on impulse, got: #{ruby_logs.inspect}"
  end

  def test_log_includes_shake_intensity
    analysis = { bass: 0.9, impulse: { bass: 0.5 } }
    @controller.update(analysis)
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') }
    assert ruby_logs.any? { |m| m.include?('camera.shake.intensity=') },
           "Expected log with camera.shake.intensity, got: #{ruby_logs.inspect}"
  end

  def test_no_log_when_no_shake
    analysis = { bass: 0.1, impulse: { bass: 0.0 } }
    @controller.update(analysis)
    ruby_logs = @log_messages.select { |m| m.include?('[Ruby]') && m.include?('camera.shake.') }
    assert_empty ruby_logs, 'Expected no shake log when below threshold'
  end
end
