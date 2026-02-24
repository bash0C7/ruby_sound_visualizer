require_relative 'test_helper'
require_relative '../src/ruby/synth_patch/audio_adapter'
require_relative '../src/ruby/synth_patch/mock_adapter'

class TestSynthPatchAdapter < Test::Unit::TestCase
  def test_mock_adapter_records_build_graph_call
    adapter = SynthPatch::MockAdapter.new
    adapter.build_graph('{"nodes":[]}')
    assert_equal 1, adapter.calls.length
    assert_equal :build_graph, adapter.calls[0][:method]
    assert_equal '{"nodes":[]}', adapter.calls[0][:spec]
  end

  def test_mock_adapter_stores_graph_spec
    adapter = SynthPatch::MockAdapter.new
    adapter.build_graph('{"nodes":[{"id":"osc"}]}')
    assert_equal '{"nodes":[{"id":"osc"}]}', adapter.graph_spec
  end

  def test_mock_adapter_records_update_param
    adapter = SynthPatch::MockAdapter.new
    adapter.update_param(:carrier, :frequency, 880)
    assert_equal :update_param, adapter.calls[0][:method]
    assert_equal :carrier, adapter.calls[0][:node]
    assert_equal :frequency, adapter.calls[0][:param]
    assert_equal 880, adapter.calls[0][:value]
  end

  def test_mock_adapter_records_note_on
    adapter = SynthPatch::MockAdapter.new
    adapter.note_on(440, 50, { attack: 0.01 })
    assert_equal :note_on, adapter.calls[0][:method]
    assert_equal 440, adapter.calls[0][:freq]
    assert_equal 50, adapter.calls[0][:duty]
  end

  def test_mock_adapter_records_note_off
    adapter = SynthPatch::MockAdapter.new
    adapter.note_off
    assert_equal :note_off, adapter.calls[0][:method]
  end

  def test_mock_adapter_accumulates_multiple_calls
    adapter = SynthPatch::MockAdapter.new
    adapter.note_on(440, 50, {})
    adapter.update_param(:carrier, :frequency, 880)
    adapter.note_off
    assert_equal 3, adapter.calls.length
  end

  def test_mock_adapter_reset_clears_calls
    adapter = SynthPatch::MockAdapter.new
    adapter.note_on(440, 50, {})
    adapter.reset!
    assert_equal 0, adapter.calls.length
    assert_nil adapter.graph_spec
  end

  def test_audio_adapter_raises_not_implemented
    adapter = SynthPatch::AudioAdapter.new
    assert_raise(NotImplementedError) { adapter.build_graph('{}') }
    assert_raise(NotImplementedError) { adapter.note_on(440, 50, {}) }
    assert_raise(NotImplementedError) { adapter.note_off }
    assert_raise(NotImplementedError) { adapter.update_param(:n, :p, 1) }
  end
end
