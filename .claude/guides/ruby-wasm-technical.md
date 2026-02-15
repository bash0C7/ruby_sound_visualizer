# ruby.wasm Technical Guide

Technical notes for running this project on ruby.wasm in the browser.

## Table of Contents

1. [What ruby.wasm Is](#what-rubywasm-is)
2. [Browser Integration](#browser-integration)
3. [Available Features and Constraints](#available-features-and-constraints)
4. [Web Audio Integration](#web-audio-integration)
5. [Performance Characteristics](#performance-characteristics)
6. [Development and Testing](#development-and-testing)
7. [Troubleshooting](#troubleshooting)
8. [References](#references)

## What ruby.wasm Is

ruby.wasm runs CRuby in WebAssembly.

Project runtime package:

```text
@ruby/4.0-wasm-wasi@2.8.1
```

Main components:
- browser runtime script: `browser.script.iife.js`
- Ruby script tags: `type="text/ruby"`
- built-in JS bridge: `require 'js'`

## Browser Integration

### Baseline loading pattern

```html
<script src="https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.8.1/dist/browser.script.iife.js"></script>
<script type="text/ruby" src="src/ruby/main.rb"></script>
```

### Current file order in this project

The app relies on deterministic script order. `main.rb` must be last.

```html
<script type="text/ruby" src="src/ruby/visualizer_policy.rb"></script>
<script type="text/ruby" src="src/ruby/math_helper.rb"></script>
<script type="text/ruby" src="src/ruby/js_bridge.rb"></script>
<script type="text/ruby" src="src/ruby/frequency_mapper.rb"></script>
<script type="text/ruby" src="src/ruby/audio_analyzer.rb"></script>
<script type="text/ruby" src="src/ruby/color_palette.rb"></script>
<script type="text/ruby" src="src/ruby/particle_system.rb"></script>
<script type="text/ruby" src="src/ruby/geometry_morpher.rb"></script>
<script type="text/ruby" src="src/ruby/camera_controller.rb"></script>
<script type="text/ruby" src="src/ruby/bloom_controller.rb"></script>
<script type="text/ruby" src="src/ruby/effect_manager.rb"></script>
<script type="text/ruby" src="src/ruby/effect_dispatcher.rb"></script>
<script type="text/ruby" src="src/ruby/audio_input_manager.rb"></script>
<script type="text/ruby" src="src/ruby/keyboard_handler.rb"></script>
<script type="text/ruby" src="src/ruby/vj_plugin.rb"></script>
<script type="text/ruby" src="src/ruby/vj_pad.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_burst.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_flash.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_shockwave.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_strobe.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_rave.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_serial.rb"></script>
<script type="text/ruby" src="src/ruby/plugins/vj_wordart.rb"></script>
<script type="text/ruby" src="src/ruby/serial_protocol.rb"></script>
<script type="text/ruby" src="src/ruby/serial_manager.rb"></script>
<script type="text/ruby" src="src/ruby/serial_audio_source.rb"></script>
<script type="text/ruby" src="src/ruby/pen_input.rb"></script>
<script type="text/ruby" src="src/ruby/wordart_renderer.rb"></script>
<script type="text/ruby" src="src/ruby/debug_formatter.rb"></script>
<script type="text/ruby" src="src/ruby/bpm_estimator.rb"></script>
<script type="text/ruby" src="src/ruby/frame_counter.rb"></script>
<script type="text/ruby" src="src/ruby/vrm_dancer.rb"></script>
<script type="text/ruby" src="src/ruby/vrm_material_controller.rb"></script>
<script type="text/ruby" src="src/ruby/snapshot_manager.rb"></script>
<script type="text/ruby" src="src/ruby/main.rb"></script>
```

### Coexisting with ES modules

The app uses import maps for Three.js and VRM modules, then publishes module exports to `window` for Ruby to call through JS bridge paths.

## Available Features and Constraints

### Available

- Standard Ruby language features for runtime math/state logic
- `require 'js'` for browser API calls
- Class/module organization split across many Ruby files
- Browser-side callbacks with lambda registration on `JS.global`

### Constrained or unavailable

- Native file-system semantics outside WASI sandbox assumptions
- Ruby network gems as backend replacements (browser sandbox)
- Process/system execution semantics (`system`, `exec`)
- Typical gem-install workflow in browser runtime

### Practical design rule in this repo

Keep browser integration boundaries thin:
- Ruby handles analysis and effect state
- JavaScript handles rendering and platform APIs

## Web Audio Integration

### Runtime path

```text
AudioContext -> AnalyserNode -> Uint8Array frequency data
  -> rubyUpdateVisuals(freq_array, timestamp)
  -> Ruby analysis/effects
  -> JS update functions
```

Current analyser config:
- `fftSize = 2048`
- `smoothingTimeConstant = 0.5`
- `frequencyBinCount = 1024`

### Audio source model

JS manages multiple input sources (feed into AnalyserNode for visualization):
- microphone input
- tab capture
- camera microphone
- serial audio (PWM oscillator from PicoRuby frequency data, also outputs to speakers)

Ruby tracks logical input state through `AudioInputManager` (`:microphone`, `:tab`, `:camera`, `:serial`) and key/VJ commands. Serial audio state is managed by `SerialAudioSource` which receives frequency/duty frames via `SerialProtocol`.

### Suspended context handling

The app tries resume on init and registers a click fallback listener to resume `AudioContext` when required.

## Performance Characteristics

### Typical heavy paths

- Per-frame particle array transfer (`positions`, `colors`)
- Ruby analysis and effect updates in `rubyUpdateVisuals`
- Composer-based post-processing

### Existing mitigations

- Fixed-size frame API boundary (single update call per subsystem)
- Ruby-side precomputation for derived render params
- DOM text refresh throttling
- Perf-view mode that mirrors stream and skips heavy local render path

### Runtime behavior notes

- ruby.wasm startup has non-trivial load/init cost
- cache benefits are significant after first load
- debug-heavy console output can affect frame pacing

## Development and Testing

### Local server

Use project tasks:

```bash
bundle exec rake server:start
bundle exec rake server:status
bundle exec rake server:stop
```

Or manual server:

```bash
bundle exec ruby -run -ehttpd . -p8000
```

### Tests

```bash
bundle exec rake test
```

Test strategy in this repo:
- `test/test_helper.rb` provides JS mocks
- most logic modules are tested as pure Ruby units
- browser-only behavior is covered by integration boundaries and manual browser verification

### Cache control during dev

When needed, append a query suffix to bypass stale browser cache:

```text
http://localhost:8000/index.html?nocache=12345
```

## Troubleshooting

### Blank or broken visuals

- Verify Three.js modules loaded (`window.THREE_READY`)
- Check console for Ruby/JS bridge errors
- Confirm `main.rb` loaded after dependencies

### Ruby callbacks not responding

- Confirm `rubyUpdateVisuals` exists on `window`
- Verify runtime finished initialization before triggering controls
- Inspect `window.logBuffer.getErrors()`

### No audio reaction

- Confirm permission grants
- Verify `AudioContext` state is running
- Verify active source (Mic/Tab/Cam Mic)

### Serial commands not working

- Confirm browser supports Web Serial API
- Connect device first (`sc`)
- Confirm status with `si`

## References

- [ruby.wasm Documentation](https://ruby.github.io/ruby.wasm/)
- [ruby.wasm GitHub](https://github.com/ruby/ruby.wasm)
- [WebAssembly](https://webassembly.org/)
- [WASI](https://wasi.dev/)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [AnalyserNode](https://developer.mozilla.org/en-US/docs/Web/API/AnalyserNode)
