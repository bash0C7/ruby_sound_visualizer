require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/audio_adapter'
require_relative '../src/ruby/synth_patch/mock_adapter'
require_relative '../src/ruby/synth_patch/node'
require_relative '../src/ruby/synth_patch/osc_node'
require_relative '../src/ruby/synth_patch/fm_op_node'
require_relative '../src/ruby/synth_patch/filter_node'
require_relative '../src/ruby/synth_patch/gain_node'
require_relative '../src/ruby/synth_patch/mixer_node'

class TestSynthPatchNodes < Test::Unit::TestCase
  def setup
    SynthPatch::Node.reset_id_counter!
  end

  # --- OscNode ---

  def test_osc_node_stores_waveform_freq_name
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :carrier)
    assert_equal :sine, node.waveform
    assert_equal 440, node.freq
    assert_equal :carrier, node.name
  end

  def test_osc_node_default_amp
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    assert_equal 1.0, node.amp
  end

  def test_osc_node_custom_amp
    node = SynthPatch::OscNode.new(:sine, freq: 440, amp: 0.5, name: :osc)
    assert_equal 0.5, node.amp
  end

  def test_osc_node_to_spec_h
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :carrier)
    spec = node.to_spec_h
    assert_equal 'carrier', spec[:id]
    assert_equal 'oscillator', spec[:type]
    assert_equal 'sine', spec[:params][:waveform]
    assert_equal 440, spec[:params][:frequency]
  end

  # --- FMOpNode ---

  def test_fm_op_node_stores_attributes
    node = SynthPatch::FMOpNode.new(:sine, freq: 220, amp: 80, name: :mod)
    assert_equal :sine, node.waveform
    assert_equal 220, node.freq
    assert_equal 80, node.amp
    assert_equal :mod, node.name
  end

  def test_fm_op_node_to_spec_h
    node = SynthPatch::FMOpNode.new(:sine, freq: 220, amp: 80, name: :mod)
    spec = node.to_spec_h
    assert_equal 'mod', spec[:id]
    assert_equal 'fm_op', spec[:type]
  end

  # --- FilterNode ---

  def test_filter_node_stores_attributes
    node = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
    assert_equal :lowpass, node.filter_type
    assert_equal 1200, node.cutoff
    assert_equal 0.9, node.q
    assert_equal :main_filter, node.name
  end

  def test_filter_node_default_q
    node = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200, name: :f)
    assert_equal 1.0, node.q
  end

  def test_filter_node_to_spec_h
    node = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200, q: 0.9, name: :f)
    spec = node.to_spec_h
    assert_equal 'f', spec[:id]
    assert_equal 'filter', spec[:type]
    assert_equal 'lowpass', spec[:params][:filter_type]
    assert_equal 1200, spec[:params][:cutoff]
    assert_equal 0.9, spec[:params][:q]
  end

  # --- GainNode ---

  def test_gain_node_stores_gain_value
    node = SynthPatch::GainNode.new(0.35, name: :master_gain)
    assert_equal 0.35, node.gain_value
    assert_equal :master_gain, node.name
  end

  def test_gain_node_to_spec_h
    node = SynthPatch::GainNode.new(0.35, name: :g)
    spec = node.to_spec_h
    assert_equal 'g', spec[:id]
    assert_equal 'gain', spec[:type]
    assert_equal 0.35, spec[:params][:gain]
  end

  # --- MixerNode ---

  def test_mixer_node_stores_inputs
    carrier = SynthPatch::OscNode.new(:sine, freq: 440, name: :carrier)
    sub = SynthPatch::OscNode.new(:sawtooth, freq: 220, name: :sub)
    mixer = SynthPatch::MixerNode.new(carrier, sub, name: :mixer)
    assert_equal 2, mixer.inputs.length
    assert_equal carrier, mixer.inputs[0]
    assert_equal sub, mixer.inputs[1]
  end

  def test_mixer_node_to_spec_h
    carrier = SynthPatch::OscNode.new(:sine, freq: 440, name: :carrier)
    mixer = SynthPatch::MixerNode.new(carrier, name: :mix)
    spec = mixer.to_spec_h
    assert_equal 'mixer', spec[:type]
    assert_equal 1, spec[:params][:input_count]
  end

  # --- Node chain API ---

  def test_filter_creates_chain
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    filter = node.filter(:lowpass, cutoff: 1200, name: :f)
    assert_equal 1, node.chain.length
    assert_kind_of SynthPatch::FilterNode, filter
    assert_equal :f, filter.name
  end

  def test_gain_creates_chain
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    g = node.gain(0.5, name: :g)
    assert_equal 1, node.chain.length
    assert_kind_of SynthPatch::GainNode, g
  end

  def test_out_marks_output
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    assert_equal false, node.output?
    result = node.out
    assert_equal true, node.output?
    assert_equal node, result
  end

  def test_chain_is_chainable
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    g = node.filter(:lowpass, cutoff: 1200, name: :f).gain(0.35, name: :g)
    assert_kind_of SynthPatch::GainNode, g
    assert_equal true, g.out.output?
  end

  def test_fm_returns_self_for_chaining
    carrier = SynthPatch::FMOpNode.new(:sine, freq: 440, name: :carrier)
    mod = SynthPatch::FMOpNode.new(:sine, freq: 220, name: :mod)
    result = carrier.fm(mod)
    assert_equal carrier, result
    assert_equal mod, carrier.fm_modulator
  end

  def test_set_param_raises_before_compile
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    assert_raise(RuntimeError) { node.set_param(:frequency, 880) }
  end

  def test_set_param_calls_adapter_after_compile
    adapter = SynthPatch::MockAdapter.new
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    node.set_compiled!('handle_osc', adapter)
    node.set_param(:frequency, 880)
    assert_equal :update_param, adapter.calls[0][:method]
    assert_equal :osc, adapter.calls[0][:node]
    assert_equal :frequency, adapter.calls[0][:param]
    assert_equal 880, adapter.calls[0][:value]
  end

  def test_auto_name_when_nil
    node = SynthPatch::FilterNode.new(:lowpass, cutoff: 1200)
    assert_not_nil node.name
    assert_match(/\A_n\d+\z/, node.name.to_s)
  end

  # --- to_h ---

  def test_osc_node_to_h
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :carrier)
    h = node.to_h
    assert_equal :carrier, h[:name]
    assert_equal 'OscNode', h[:type]
    assert_equal :sine, h[:waveform]
    assert_equal 440, h[:freq]
  end

  def test_filter_node_to_h_includes_chain
    node = SynthPatch::OscNode.new(:sine, freq: 440, name: :osc)
    node.filter(:lowpass, cutoff: 1200, name: :f).gain(0.35, name: :g).out
    h = node.to_h
    assert_equal 1, h[:chain].length
    assert_equal :f, h[:chain][0][:name]
    assert_equal 1, h[:chain][0][:chain].length
    assert_equal :g, h[:chain][0][:chain][0][:name]
  end
end
