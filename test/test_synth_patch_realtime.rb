require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/mock_adapter'
require_relative '../src/ruby/synth_patch/synth_patch'

class TestSynthPatchRealtime < Test::Unit::TestCase
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
  end

  def test_named_node_access_by_symbol
    assert_not_nil @patch[:carrier]
    assert_not_nil @patch[:main_filter]
    assert_not_nil @patch[:master_gain]
  end

  def test_named_node_returns_correct_type
    assert_kind_of SynthPatch::FMOpNode, @patch[:carrier]
    assert_kind_of SynthPatch::FilterNode, @patch[:main_filter]
    assert_kind_of SynthPatch::GainNode, @patch[:master_gain]
  end

  def test_unknown_node_returns_nil
    assert_nil @patch[:nonexistent]
  end

  def test_set_param_on_carrier_calls_adapter
    @patch[:carrier].set_param(:frequency, 880)
    assert_equal 1, @adapter.calls.length
    call = @adapter.calls[0]
    assert_equal :update_param, call[:method]
    assert_equal :carrier, call[:node]
    assert_equal :frequency, call[:param]
    assert_equal 880, call[:value]
  end

  def test_set_param_on_main_filter_calls_adapter
    @patch[:main_filter].set_param(:cutoff, 2000)
    call = @adapter.calls[0]
    assert_equal :update_param, call[:method]
    assert_equal :main_filter, call[:node]
    assert_equal :cutoff, call[:param]
    assert_equal 2000, call[:value]
  end

  def test_set_param_on_master_gain_calls_adapter
    @patch[:master_gain].set_param(:gain, 0.5)
    call = @adapter.calls[0]
    assert_equal :update_param, call[:method]
    assert_equal :master_gain, call[:node]
    assert_equal :gain, call[:param]
    assert_equal 0.5, call[:value]
  end

  def test_multiple_param_updates_recorded
    @patch[:carrier].set_param(:frequency, 880)
    @patch[:main_filter].set_param(:cutoff, 2000)
    assert_equal 2, @adapter.calls.length
  end
end
