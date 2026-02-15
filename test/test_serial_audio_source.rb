require_relative 'test_helper'

class TestSerialAudioSource < Test::Unit::TestCase
  def setup
    @source = SerialAudioSource.new
  end

  # --- Initial state ---

  def test_initial_state_inactive
    assert_equal false, @source.active?
  end

  def test_initial_frequency_440
    assert_equal 440, @source.frequency
  end

  def test_initial_duty_50
    assert_equal 50, @source.duty
  end

  def test_initial_volume
    assert_in_delta 0.3, @source.volume, 0.01
  end

  # --- Start/Stop ---

  def test_start_activates
    @source.start
    assert_equal true, @source.active?
  end

  def test_stop_deactivates
    @source.start
    @source.stop
    assert_equal false, @source.active?
  end

  def test_start_sets_pending_update
    @source.start
    assert_equal true, @source.pending_update?
  end

  def test_stop_sets_pending_update
    @source.start
    @source.consume_update
    @source.stop
    assert_equal true, @source.pending_update?
  end

  # --- Update frequency/duty ---

  def test_update_changes_frequency_and_duty
    @source.start
    @source.update(880, 75)
    assert_equal 880, @source.frequency
    assert_equal 75, @source.duty
  end

  def test_update_clamps_frequency_max
    @source.start
    @source.update(25000, 50)
    assert_equal 20000, @source.frequency
  end

  def test_update_clamps_frequency_min
    @source.start
    @source.update(-100, 50)
    assert_equal 0, @source.frequency
  end

  def test_update_clamps_duty_max
    @source.start
    @source.update(440, 150)
    assert_equal 100, @source.duty
  end

  def test_update_clamps_duty_min
    @source.start
    @source.update(440, -10)
    assert_equal 0, @source.duty
  end

  def test_update_ignored_when_inactive
    @source.update(880, 75)
    assert_equal 440, @source.frequency
    assert_equal 50, @source.duty
  end

  def test_update_sets_pending
    @source.start
    @source.consume_update
    @source.update(880, 75)
    assert_equal true, @source.pending_update?
  end

  # --- Pending update tracking ---

  def test_consume_update_clears_pending
    @source.start
    @source.consume_update
    assert_equal false, @source.pending_update?
  end

  def test_consume_update_returns_state
    @source.start
    @source.update(880, 75)
    data = @source.consume_update
    assert_equal 880, data[:frequency]
    assert_equal 75, data[:duty]
    assert_equal true, data[:active]
    assert_in_delta 0.3, data[:volume], 0.01
  end

  def test_consume_update_after_stop_returns_inactive
    @source.start
    @source.stop
    data = @source.consume_update
    assert_equal false, data[:active]
  end

  # --- Volume control ---

  def test_set_volume
    @source.set_volume(0.8)
    assert_in_delta 0.8, @source.volume, 0.01
  end

  def test_set_volume_clamps_above_1
    @source.set_volume(1.5)
    assert_in_delta 1.0, @source.volume, 0.01
  end

  def test_set_volume_clamps_below_0
    @source.set_volume(-0.5)
    assert_in_delta 0.0, @source.volume, 0.01
  end

  def test_set_volume_sets_pending
    @source.consume_update if @source.pending_update?
    @source.set_volume(0.5)
    assert_equal true, @source.pending_update?
  end

  # --- Status ---

  def test_status_when_inactive
    result = @source.status
    assert_match(/off/, result)
    assert_match(/440/, result)
    assert_match(/50/, result)
  end

  def test_status_when_active
    @source.start
    @source.update(880, 75)
    result = @source.status
    assert_match(/on/, result)
    assert_match(/880/, result)
    assert_match(/75/, result)
  end
end
