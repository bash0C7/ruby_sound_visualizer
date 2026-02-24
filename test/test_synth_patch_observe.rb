require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/mock_adapter'
require_relative '../src/ruby/synth_patch/synth_patch'

class TestSynthPatchObserve < Test::Unit::TestCase
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
  end

  def test_status_returns_string
    result = @patch.status
    assert_kind_of String, result
  end

  def test_status_includes_node_names
    result = @patch.status
    assert_match(/carrier/, result)
    assert_match(/main_filter/, result)
    assert_match(/master_gain/, result)
  end

  def test_status_includes_adsr
    result = @patch.status
    assert_match(/adsr=/, result)
  end

  def test_status_includes_active_state
    result = @patch.status
    assert_match(/active=false/, result)

    @patch.note_on(440, 50)
    result = @patch.status
    assert_match(/active=true/, result)
  end

  def test_to_h_returns_hash
    h = @patch.to_h
    assert_kind_of Hash, h
  end

  def test_to_h_has_nodes_key
    h = @patch.to_h
    assert h.key?(:nodes)
    assert_kind_of Array, h[:nodes]
  end

  def test_to_h_nodes_include_all_named_nodes
    h = @patch.to_h
    names = h[:nodes].map { |n| n[:name] }
    assert_includes names, :mod
    assert_includes names, :carrier
    assert_includes names, :sub
    assert_includes names, :mixer
    assert_includes names, :main_filter
    assert_includes names, :master_gain
  end

  def test_to_h_has_adsr
    h = @patch.to_h
    assert h.key?(:adsr)
    assert_equal SynthPatch::ADSR_DEFAULTS[:attack], h[:adsr][:attack]
    assert_equal SynthPatch::ADSR_DEFAULTS[:release], h[:adsr][:release]
  end

  def test_to_h_has_active_state
    h = @patch.to_h
    assert h.key?(:active)
    assert_equal false, h[:active]

    @patch.note_on(440, 50)
    h = @patch.to_h
    assert_equal true, h[:active]
  end

  def test_to_h_nodes_include_type
    h = @patch.to_h
    carrier_h = h[:nodes].find { |n| n[:name] == :carrier }
    assert_not_nil carrier_h
    assert_equal 'FMOpNode', carrier_h[:type]
  end

  def test_to_h_nodes_include_params
    h = @patch.to_h
    carrier_h = h[:nodes].find { |n| n[:name] == :carrier }
    assert_not_nil carrier_h
    assert_equal 440, carrier_h[:freq]
  end
end
