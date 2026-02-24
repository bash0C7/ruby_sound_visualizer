require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/mock_adapter'
require_relative '../src/ruby/synth_patch/synth_patch'

class TestSynthPatchNote < Test::Unit::TestCase
  def setup
    SynthPatch::Node.reset_id_counter!
    @adapter = SynthPatch::MockAdapter.new
    @patch = SynthPatch.build(adapter: @adapter) do |syn|
      syn.osc(:sine, freq: 440, name: :osc).out
    end
    @adapter.reset!
  end

  def test_note_on_calls_adapter
    @patch.note_on(440, 50)
    calls = @adapter.calls
    assert_equal 1, calls.length
    assert_equal :note_on, calls[0][:method]
    assert_equal 440, calls[0][:freq]
    assert_equal 50, calls[0][:duty]
  end

  def test_note_on_activates_patch
    assert_equal false, @patch.active?
    @patch.note_on(440, 50)
    assert_equal true, @patch.active?
  end

  def test_note_off_calls_adapter
    @patch.note_on(440, 50)
    @adapter.reset!
    @patch.note_off
    assert_equal 1, @adapter.calls.length
    assert_equal :note_off, @adapter.calls[0][:method]
  end

  def test_note_off_deactivates_patch
    @patch.note_on(440, 50)
    @patch.note_off
    assert_equal false, @patch.active?
  end

  def test_note_off_when_inactive_does_not_call_adapter
    @patch.note_off
    assert_equal 0, @adapter.calls.length
  end

  def test_note_on_zero_freq_triggers_note_off
    @patch.note_on(440, 50)
    @adapter.reset!
    @patch.note_on(0, 50)
    assert_equal false, @patch.active?
  end

  def test_note_on_zero_duty_triggers_note_off
    @patch.note_on(440, 50)
    @adapter.reset!
    @patch.note_on(440, 0)
    assert_equal false, @patch.active?
  end

  def test_note_on_includes_adsr_params
    @patch.note_on(440, 50)
    adsr = @adapter.calls[0][:adsr]
    assert_not_nil adsr
    assert_equal SynthPatch::ADSR_DEFAULTS[:attack], adsr[:attack]
    assert_equal SynthPatch::ADSR_DEFAULTS[:decay], adsr[:decay]
    assert_equal SynthPatch::ADSR_DEFAULTS[:sustain], adsr[:sustain]
    assert_equal SynthPatch::ADSR_DEFAULTS[:release], adsr[:release]
  end

  def test_set_attack_updates_adsr
    @patch.set_attack(0.5)
    assert_equal 0.5, @patch.attack
    @patch.note_on(440, 50)
    assert_equal 0.5, @adapter.calls[0][:adsr][:attack]
  end

  def test_set_decay_updates_adsr
    @patch.set_decay(0.8)
    assert_equal 0.8, @patch.decay
  end

  def test_set_sustain_updates_adsr
    @patch.set_sustain(0.7)
    assert_equal 0.7, @patch.sustain
  end

  def test_set_release_updates_adsr
    @patch.set_release(1.2)
    assert_equal 1.2, @patch.release
  end

  def test_check_timeout_triggers_note_off_after_threshold
    @patch.note_on(440, 50, now_ms: 1000)
    @adapter.reset!
    @patch.check_timeout(current_ms: 1201, threshold_ms: 200)
    assert_equal false, @patch.active?
    assert_equal :note_off, @adapter.calls[0][:method]
  end

  def test_check_timeout_does_not_trigger_before_threshold
    @patch.note_on(440, 50, now_ms: 1000)
    @adapter.reset!
    @patch.check_timeout(current_ms: 1100, threshold_ms: 200)
    assert_equal true, @patch.active?
    assert_equal 0, @adapter.calls.length
  end

  def test_check_timeout_does_nothing_when_inactive
    @patch.check_timeout(current_ms: 9999, threshold_ms: 200)
    assert_equal 0, @adapter.calls.length
  end
end
