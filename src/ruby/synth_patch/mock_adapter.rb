require_relative 'audio_adapter'

# SynthPatch::MockAdapter: Test adapter that records all calls.
# Allows tests to verify the correct adapter interface is called.
class SynthPatch
  class MockAdapter < AudioAdapter
    attr_reader :calls, :graph_spec

    def initialize
      @calls = []
      @graph_spec = nil
    end

    def build_graph(json_spec)
      @graph_spec = json_spec
      @calls << { method: :build_graph, spec: json_spec }
    end

    def note_on(freq, duty, adsr_params)
      @calls << { method: :note_on, freq: freq, duty: duty, adsr: adsr_params }
    end

    def note_off
      @calls << { method: :note_off }
    end

    def update_param(node_name, param, value)
      @calls << { method: :update_param, node: node_name, param: param, value: value }
    end

    def reset!
      @calls = []
      @graph_spec = nil
    end
  end
end
