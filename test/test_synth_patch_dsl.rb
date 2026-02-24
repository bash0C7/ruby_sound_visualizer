require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/mock_adapter'
require_relative '../src/ruby/synth_patch/synth_patch'
require 'json'

class TestSynthPatchDsl < Test::Unit::TestCase
  def setup
    SynthPatch::Node.reset_id_counter!
  end

  def adapter
    @adapter ||= SynthPatch::MockAdapter.new
  end

  def test_simple_osc_build_calls_build_graph
    SynthPatch.build(adapter: adapter) do |syn|
      syn.osc(:sine, freq: 440, name: :osc).out
    end
    assert_equal 1, adapter.calls.length
    assert_equal :build_graph, adapter.calls[0][:method]
  end

  def test_simple_osc_spec_has_one_node
    SynthPatch.build(adapter: adapter) do |syn|
      syn.osc(:sine, freq: 440, name: :osc).out
    end
    spec = JSON.parse(adapter.graph_spec)
    assert_equal 1, spec['nodes'].length
    assert_equal 'osc', spec['nodes'][0]['id']
    assert_equal 'oscillator', spec['nodes'][0]['type']
  end

  def test_out_node_sets_output_node_in_spec
    SynthPatch.build(adapter: adapter) do |syn|
      syn.osc(:sine, freq: 440, name: :osc).out
    end
    spec = JSON.parse(adapter.graph_spec)
    assert_equal 'osc', spec['output_node']
  end

  def test_chain_builds_connections
    SynthPatch.build(adapter: adapter) do |syn|
      syn.osc(:sine, freq: 440, name: :osc)
         .gain(0.5, name: :g)
         .out
    end
    spec = JSON.parse(adapter.graph_spec)
    assert_equal 2, spec['nodes'].length
    conn = spec['connections'][0]
    assert_equal 'osc', conn['from']
    assert_equal 'g', conn['to']
    assert_equal 'g', spec['output_node']
  end

  def test_fm_connection_in_spec
    SynthPatch.build(adapter: adapter) do |syn|
      mod = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod).out
    end
    spec = JSON.parse(adapter.graph_spec)
    fm_conns = spec['fm_connections']
    assert_equal 1, fm_conns.length
    assert_equal 'mod', fm_conns[0]['mod']
    assert_equal 'carrier', fm_conns[0]['carrier']
  end

  def test_full_dsl_example
    SynthPatch.build(adapter: adapter) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      carrier = syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod)
      sub     = syn.osc(:sawtooth, freq: 220, name: :sub)
      syn.mix(carrier, sub, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
         .gain(0.35, name: :master_gain)
         .out
    end
    spec = JSON.parse(adapter.graph_spec)

    # All 6 nodes present
    node_ids = spec['nodes'].map { |n| n['id'] }
    assert_includes node_ids, 'mod'
    assert_includes node_ids, 'carrier'
    assert_includes node_ids, 'sub'
    assert_includes node_ids, 'mixer'
    assert_includes node_ids, 'main_filter'
    assert_includes node_ids, 'master_gain'

    # FM connection
    assert_equal 1, spec['fm_connections'].length
    assert_equal 'mod', spec['fm_connections'][0]['mod']
    assert_equal 'carrier', spec['fm_connections'][0]['carrier']

    # Output node
    assert_equal 'master_gain', spec['output_node']

    # Mixer inputs: carrier → mixer, sub → mixer
    connections = spec['connections']
    assert connections.any? { |c| c['from'] == 'carrier' && c['to'] == 'mixer' }
    assert connections.any? { |c| c['from'] == 'sub' && c['to'] == 'mixer' }
    # Chain connections
    assert connections.any? { |c| c['from'] == 'mixer' && c['to'] == 'main_filter' }
    assert connections.any? { |c| c['from'] == 'main_filter' && c['to'] == 'master_gain' }
  end

  def test_build_returns_patch_instance
    patch = SynthPatch.build(adapter: adapter) do |syn|
      syn.osc(:sine, freq: 440, name: :osc).out
    end
    assert_kind_of SynthPatch, patch
  end

  def test_node_types_in_spec
    SynthPatch.build(adapter: adapter) do |syn|
      mod     = syn.fm_op(:sine, freq: 220, amp: 80, name: :mod)
      carrier = syn.fm_op(:sine, freq: 440, name: :carrier).fm(mod)
      sub     = syn.osc(:sawtooth, freq: 220, name: :sub)
      syn.mix(carrier, sub, name: :mixer)
         .filter(:lowpass, cutoff: 1200, q: 0.9, name: :main_filter)
         .gain(0.35, name: :master_gain)
         .out
    end
    spec = JSON.parse(adapter.graph_spec)
    types = Hash[spec['nodes'].map { |n| [n['id'], n['type']] }]
    assert_equal 'fm_op', types['mod']
    assert_equal 'fm_op', types['carrier']
    assert_equal 'oscillator', types['sub']
    assert_equal 'mixer', types['mixer']
    assert_equal 'filter', types['main_filter']
    assert_equal 'gain', types['master_gain']
  end
end
