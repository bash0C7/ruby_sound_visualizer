# Ruby WASM Software Synthesizer - Architecture Plan

## Overview

Browser-based software synthesizer in Ruby (ruby.wasm), using Web Audio API via
the `js` gem adapter. Analog (subtractive) and FM synthesis combined, with a
clean extensible DSL for patching.

---

## 1. Directory Structure

```
src/ruby/synth/
├── audio_context_port.rb      # Abstract interface (module) — the contract
├── web_audio_adapter.rb       # Real Web Audio API adapter (browser only)
├── audio_node.rb              # Base class for all audio nodes
├── oscillator_node.rb         # Analog oscillator (sine/sawtooth/square/triangle)
├── fm_operator.rb             # FM operator with frequency modulation input
├── gain_node.rb               # Gain / VCA node
├── filter_node.rb             # Biquad filter (LPF / HPF / BPF / notch)
├── mixer_node.rb              # N-to-1 mixer (fan-in)
├── reverb_node.rb             # Convolution reverb node
└── synth.rb                   # Synth.build DSL entry point

test/synth/
├── mock_audio_adapter.rb      # Shared mock adapter for all synth tests
├── test_audio_node.rb
├── test_oscillator_node.rb
├── test_fm_operator.rb
├── test_gain_node.rb
├── test_filter_node.rb
├── test_mixer_node.rb
└── test_synth_dsl.rb
```

---

## 2. Layer Responsibilities

### Layer A: Port (interface contract)
- `AudioContextPort` module — required methods every adapter must implement
- `connect(source_raw, dest_raw)`
- `connect_to_param(source_raw, param)`
- `create_oscillator(type:, frequency:)`
- `create_gain(value:)`
- `create_biquad_filter(type:, frequency:, q:)`
- `create_convolver()`
- `destination` (master output raw node)

### Layer B: Adapters
- `WebAudioAdapter` — wraps `JS.global[:AudioContext].new`, all calls go to Web Audio API
- `MockAudioAdapter` — pure Ruby, records all calls, returns `MockNode` objects

### Layer C: Audio Nodes
All nodes inherit from `AudioNode`:
- `raw_node` — the underlying adapter-level node
- `adapter` — the adapter used to create this node
- `connect(target)` — connects this node → target, returns target
- `>>(target)` — alias for connect, allows `a >> b >> c` pipeline
- `connections` — Array of connected targets (for graph introspection)

Convenience methods on `AudioNode` (chainable DSL builders):
- `gain(value)` → creates + connects `GainNode`, returns it
- `lpf(cutoff:, q: 1.0)` → creates + connects `FilterNode(:lowpass)`, returns it
- `hpf(cutoff:, q: 1.0)` → creates + connects `FilterNode(:highpass)`, returns it
- `out` → connects to adapter's destination

### Layer D: Specific Nodes
- `OscillatorNode(type:, frequency:, adapter:)` — starts oscillator
- `FMOperator(type:, frequency:, adapter:)` — oscillator with `fm(modulator)` method
- `GainNode(value:, adapter:)` — gain/amplitude
- `FilterNode(filter_type:, cutoff:, q:, adapter:)` — biquad filter
- `MixerNode(sources:, adapter:)` — connects all sources to internal gain
- `ReverbNode(mix:, adapter:)` — convolution reverb with dry/wet

### Layer E: DSL
`Synth::Builder` — `instance_eval`'d inside `Synth.build { }` block:
- `oscillator(type, freq:)` → `OscillatorNode`
- `sine(freq:)` / `saw(freq:)` / `square(freq:)` / `tri(freq:)` shortcuts
- `operator(type, freq:, amp:)` → `FMOperator`
- `mix(*sources)` → `MixerNode`

`Synth.build(adapter: nil, &block)` — factory, auto-detects adapter via `defined?(JS)`

---

## 3. DSL Usage Examples

```ruby
# === Analog subtractive patch ===
Synth.build do
  saw(freq: 220)
    .gain(0.6)
    .lpf(cutoff: 800, q: 1.4)
    .out
end

# === FM synthesis ===
Synth.build do
  mod     = operator(:sine, freq: 220, amp: 80)
  carrier = operator(:sine, freq: 440).fm(mod)
  carrier.gain(0.4).out
end

# === Combined analog + FM ===
Synth.build do
  mod     = operator(:sine, freq: 110, amp: 60)
  carrier = operator(:sine, freq: 440).fm(mod)
  sub     = saw(freq: 220)
  mix(carrier, sub)
    .lpf(cutoff: 1200, q: 0.9)
    .gain(0.35)
    .out
end
```

---

## 4. Adapter Abstraction (Browser vs Test)

```ruby
# src/ruby/synth/audio_context_port.rb
module AudioContextPort
  def connect(source_raw, dest_raw)       = raise NotImplementedError
  def connect_to_param(source_raw, param) = raise NotImplementedError
  def create_oscillator(type:, frequency:)
    raise NotImplementedError
  end
  def create_gain(value:)                 = raise NotImplementedError
  def create_biquad_filter(type:, frequency:, q:)
    raise NotImplementedError
  end
  def create_convolver                    = raise NotImplementedError
  def destination                         = raise NotImplementedError
end
```

```ruby
# src/ruby/synth/web_audio_adapter.rb  (browser only)
require 'js'

class WebAudioAdapter
  include AudioContextPort

  def initialize
    @ctx = JS.global[:AudioContext].new
  end

  def destination
    @ctx[:destination]
  end

  def connect(source_raw, dest_raw)
    source_raw.connect(dest_raw)
  end

  def connect_to_param(source_raw, param)
    source_raw.connect(param)
  end

  def create_oscillator(type:, frequency:)
    node = @ctx.createOscillator
    node[:type] = type.to_s
    node[:frequency][:value] = frequency
    node.start
    node
  end

  def create_gain(value:)
    node = @ctx.createGain
    node[:gain][:value] = value
    node
  end

  def create_biquad_filter(type:, frequency:, q:)
    node = @ctx.createBiquadFilter
    node[:type] = type.to_s
    node[:frequency][:value] = frequency
    node[:Q][:value] = q
    node
  end

  def create_convolver
    @ctx.createConvolver
  end
end
```

```ruby
# test/synth/mock_audio_adapter.rb
class MockRawNode
  attr_reader :type, :params, :connections, :param_connections

  def initialize(node_type, **params)
    @type = node_type
    @params = params
    @connections = []
    @param_connections = []
  end

  def connect_to(other)
    @connections << other
  end

  def connect_param_to(param)
    @param_connections << param
  end
end

class MockAudioAdapter
  include AudioContextPort

  attr_reader :created_nodes, :connections

  def initialize
    @created_nodes = []
    @connections = []
    @destination = MockRawNode.new(:destination)
  end

  def destination
    @destination
  end

  def connect(source_raw, dest_raw)
    @connections << { from: source_raw, to: dest_raw }
    source_raw.connect_to(dest_raw)
  end

  def connect_to_param(source_raw, param)
    @connections << { from: source_raw, to_param: param }
    source_raw.connect_param_to(param)
  end

  def create_oscillator(type:, frequency:)
    node = MockRawNode.new(:oscillator, type: type, frequency: frequency)
    @created_nodes << node
    node
  end

  def create_gain(value:)
    node = MockRawNode.new(:gain, value: value)
    @created_nodes << node
    node
  end

  def create_biquad_filter(type:, frequency:, q:)
    node = MockRawNode.new(:biquad_filter, type: type, frequency: frequency, q: q)
    @created_nodes << node
    node
  end

  def create_convolver
    node = MockRawNode.new(:convolver)
    @created_nodes << node
    node
  end
end
```

---

## 5. TDD Progression (Red → Green → Refactor)

### Sprint 1: MockAudioAdapter contract
- Red: tests for MockAudioAdapter creating nodes and recording connections
- Green: implement MockAudioAdapter
- Refactor: extract MockRawNode to shared file

### Sprint 2: AudioNode base class
- Red: connect returns target, >> works, connections tracked
- Green: implement AudioNode
- Refactor: clean up return value semantics

### Sprint 3: OscillatorNode (analog)
- Red: creates with type/frequency, #gain chains, #lpf chains, #out connects to destination
- Green: implement OscillatorNode + convenience methods on AudioNode
- Refactor: extract chainable helpers to AudioNode

### Sprint 4: GainNode
- Red: creates with value, chains correctly
- Green: implement GainNode
- Refactor: —

### Sprint 5: FilterNode
- Red: creates with filter_type/cutoff/q, lpf/hpf shortcuts
- Green: implement FilterNode
- Refactor: —

### Sprint 6: FMOperator
- Red: #fm connects modulator raw_node → frequency param of carrier
- Green: implement FMOperator (subclass or peer to OscillatorNode)
- Refactor: unify with OscillatorNode where possible

### Sprint 7: MixerNode
- Red: multiple sources all connect to internal gain node
- Green: implement MixerNode
- Refactor: —

### Sprint 8: Synth DSL
- Red: Synth.build block has oscillator/saw/operator/mix methods, auto-uses MockAdapter in non-JS env
- Green: implement Synth + Builder
- Refactor: extract adapter detection to separate method

---

## 6. Testability Strategy

- All test files `require_relative 'mock_audio_adapter'`
- `test_helper.rb` already mocks `JS` — no additional setup needed for synth tests
- Each test explicitly instantiates `MockAudioAdapter` and passes to nodes
- No global state; each test creates fresh nodes and adapter
- `MockAudioAdapter#created_nodes` and `#connections` enable white-box assertions

---

## 7. Extensibility

Adding a new synthesis type (e.g., Wavetable):
1. Create `src/ruby/synth/wavetable_node.rb` inheriting `AudioNode`
2. Add `create_periodic_wave(...)` to `AudioContextPort` and both adapters
3. Add `wavetable(wave:, freq:)` builder method to `Synth::Builder`
4. Write test — no changes to existing nodes needed

Adding a new effect (e.g., Delay):
1. Create `src/ruby/synth/delay_node.rb` inheriting `AudioNode`
2. Add `delay(time:, feedback:)` convenience method on `AudioNode`
3. Write test

---

## 8. Files to Create (Implementation Order)

1. `test/synth/mock_audio_adapter.rb`
2. `src/ruby/synth/audio_context_port.rb`
3. `src/ruby/synth/audio_node.rb`
4. `test/synth/test_audio_node.rb`  ← RED first
5. `src/ruby/synth/gain_node.rb`
6. `src/ruby/synth/filter_node.rb`
7. `src/ruby/synth/oscillator_node.rb`
8. `test/synth/test_oscillator_node.rb`  ← RED first
9. `src/ruby/synth/fm_operator.rb`
10. `test/synth/test_fm_operator.rb`  ← RED first
11. `src/ruby/synth/mixer_node.rb`
12. `test/synth/test_mixer_node.rb`  ← RED first
13. `src/ruby/synth/synth.rb`
14. `test/synth/test_synth_dsl.rb`  ← RED first
15. `src/ruby/synth/web_audio_adapter.rb`  (browser-only, no test)
