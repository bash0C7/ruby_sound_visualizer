require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/mock_adapter'
require_relative '../src/ruby/synth_patch/synth_patch'
require_relative '../src/ruby/vj_synth_patch_commands'

class TestVjSynthPatch < Test::Unit::TestCase
  def setup
    SynthPatch::Node.reset_id_counter!
    @adapter = SynthPatch::MockAdapter.new
    @patch = SynthPatch.build(adapter: @adapter) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      carrier = syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod)
      sub     = syn.osc(:sawtooth, freq: 220, name: :sub)
      syn.mix(carrier, sub, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
         .gain(0.35, name: :master_gain)
         .out
    end
    @adapter.reset!
    @pad = VJPad.new(nil, synth_patch: @patch)
  end

  def test_vj_pad_accepts_synth_patch_argument
    pad = VJPad.new(nil, synth_patch: @patch)
    assert_not_nil pad
  end

  def test_vj_pad_without_synth_patch
    pad = VJPad.new(nil)
    result = pad.exec('sp_i')
    assert_equal true, result[:ok]
    assert_match(/not available/, result[:msg])
  end

  def test_sp_i_returns_status
    result = @pad.exec('sp_i')
    assert_equal true, result[:ok]
    assert_match(/adsr=/, result[:msg])
  end

  def test_sp_co_updates_filter_cutoff
    result = @pad.exec('sp_co 3000')
    assert_equal true, result[:ok]
    assert_equal 1, @adapter.calls.length
    call = @adapter.calls[0]
    assert_equal :update_param, call[:method]
    assert_equal :main_filter, call[:node]
    assert_equal :cutoff, call[:param]
    assert_equal 3000.0, call[:value]
  end

  def test_sp_a_sets_attack
    result = @pad.exec('sp_a 0.5')
    assert_equal true, result[:ok]
    assert_equal 0.5, @patch.attack
  end

  def test_sp_d_sets_decay
    @pad.exec('sp_d 0.8')
    assert_equal 0.8, @patch.decay
  end

  def test_sp_s_sets_sustain
    @pad.exec('sp_s 0.7')
    assert_equal 0.7, @patch.sustain
  end

  def test_sp_r_sets_release
    @pad.exec('sp_r 1.2')
    assert_equal 1.2, @patch.release
  end

  def test_sp_gain_updates_master_gain
    @pad.exec('sp_gain 0.5')
    assert_equal 1, @adapter.calls.length
    call = @adapter.calls[0]
    assert_equal :master_gain, call[:node]
    assert_equal :gain, call[:param]
    assert_equal 0.5, call[:value]
  end

  def test_sp_q_updates_filter_q
    @pad.exec('sp_q 2.0')
    call = @adapter.calls[0]
    assert_equal :main_filter, call[:node]
    assert_equal :q, call[:param]
    assert_equal 2.0, call[:value]
  end

  def test_sp_osc_w_updates_carrier_waveform
    result = @pad.exec('sp_osc_w "square"')
    assert_equal true, result[:ok]
    call = @adapter.calls[0]
    assert_equal :carrier, call[:node]
    assert_equal :waveform, call[:param]
    assert_equal 'square', call[:value]
  end

  def test_sp_osc_freq_updates_carrier_frequency
    @pad.exec('sp_osc_freq 880')
    call = @adapter.calls[0]
    assert_equal :carrier, call[:node]
    assert_equal :frequency, call[:param]
    assert_equal 880.0, call[:value]
  end
end
