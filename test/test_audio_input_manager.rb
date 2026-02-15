require_relative 'test_helper'

class TestAudioInputManager < Test::Unit::TestCase
  def setup
    @manager = AudioInputManager.new
  end

  # === Initial state tests ===

  def test_initial_state_is_mic_unmuted
    assert_equal false, @manager.mic_muted?
  end

  def test_initial_source_is_microphone
    assert_equal :microphone, @manager.source
  end

  # === Mic mute/unmute tests ===

  def test_mute_mic_changes_state_to_muted
    @manager.mute_mic
    assert_equal true, @manager.mic_muted?
  end

  def test_unmute_mic_changes_state_to_unmuted
    @manager.mute_mic
    @manager.unmute_mic
    assert_equal false, @manager.mic_muted?
  end

  def test_toggle_mic_from_unmuted_to_muted
    initial_state = @manager.mic_muted?
    assert_equal false, initial_state

    @manager.toggle_mic
    assert_equal true, @manager.mic_muted?
  end

  def test_toggle_mic_from_muted_to_unmuted
    @manager.mute_mic
    assert_equal true, @manager.mic_muted?

    @manager.toggle_mic
    assert_equal false, @manager.mic_muted?
  end

  # === Source switching tests ===

  def test_switch_to_tab_capture_sets_source_to_tab
    @manager.switch_to_tab
    assert_equal :tab, @manager.source
  end

  def test_switch_to_mic_sets_source_to_microphone
    @manager.switch_to_tab
    @manager.switch_to_mic
    assert_equal :microphone, @manager.source
  end

  def test_switch_to_camera_sets_source_to_camera
    @manager.switch_to_camera
    assert_equal :camera, @manager.source
  end

  def test_switch_to_mic_from_camera_sets_source_to_microphone
    @manager.switch_to_camera
    @manager.switch_to_mic
    assert_equal :microphone, @manager.source
  end

  def test_switch_to_tab_from_camera_sets_source_to_tab
    @manager.switch_to_camera
    @manager.switch_to_tab
    assert_equal :tab, @manager.source
  end

  # === Query methods tests ===

  def test_is_tab_capture_returns_true_when_source_is_tab
    @manager.switch_to_tab
    assert_equal true, @manager.tab_capture?
  end

  def test_is_tab_capture_returns_false_when_source_is_mic
    assert_equal false, @manager.tab_capture?
  end

  def test_is_tab_capture_returns_false_when_source_is_camera
    @manager.switch_to_camera
    assert_equal false, @manager.tab_capture?
  end

  def test_is_mic_input_returns_true_when_source_is_mic
    assert_equal true, @manager.mic_input?
  end

  def test_is_mic_input_returns_false_when_source_is_tab
    @manager.switch_to_tab
    assert_equal false, @manager.mic_input?
  end

  def test_is_mic_input_returns_false_when_source_is_camera
    @manager.switch_to_camera
    assert_equal false, @manager.mic_input?
  end

  def test_camera_input_returns_true_when_source_is_camera
    @manager.switch_to_camera
    assert_equal true, @manager.camera_input?
  end

  def test_camera_input_returns_false_when_source_is_mic
    assert_equal false, @manager.camera_input?
  end

  def test_camera_input_returns_false_when_source_is_tab
    @manager.switch_to_tab
    assert_equal false, @manager.camera_input?
  end

  # === Serial source tests ===

  def test_switch_to_serial_sets_source_to_serial
    @manager.switch_to_serial
    assert_equal :serial, @manager.source
  end

  def test_serial_input_returns_true_when_source_is_serial
    @manager.switch_to_serial
    assert_equal true, @manager.serial_input?
  end

  def test_serial_input_returns_false_when_source_is_mic
    assert_equal false, @manager.serial_input?
  end

  def test_switch_to_mic_from_serial
    @manager.switch_to_serial
    @manager.switch_to_mic
    assert_equal :microphone, @manager.source
  end

  def test_mic_input_returns_false_when_source_is_serial
    @manager.switch_to_serial
    assert_equal false, @manager.mic_input?
  end

  def test_tab_capture_returns_false_when_source_is_serial
    @manager.switch_to_serial
    assert_equal false, @manager.tab_capture?
  end

  def test_camera_input_returns_false_when_source_is_serial
    @manager.switch_to_serial
    assert_equal false, @manager.camera_input?
  end

  # === Volume calculation tests ===

  def test_get_mic_volume_when_muted_returns_0
    @manager.mute_mic
    assert_equal 0, @manager.mic_volume
  end

  def test_get_mic_volume_when_unmuted_returns_1
    assert_equal 1, @manager.mic_volume
  end

  def test_get_mic_volume_after_unmute_returns_1
    @manager.mute_mic
    @manager.unmute_mic
    assert_equal 1, @manager.mic_volume
  end
end
