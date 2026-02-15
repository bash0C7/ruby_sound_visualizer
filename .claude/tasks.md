# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

## Notes

- All tasks implemented with t-wada style TDD (115 new tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions

## Code Quality & Refactoring Tasks

### [A-1] HIGH: Split rubyUpdateVisuals lambda in main.rb

- **File**: `src/ruby/main.rb` lines 114-240
- **Problem**: 126-line main loop mixes 7 responsibilities: VJPad consumption, audio analysis, VRM updates, serial processing, pen input, WordArt, and debug display
- **Improvement**: Extract each update responsibility into a dedicated class (e.g., EffectUpdateManager)

### [A-2] HIGH: Split VJPad mega-class (436 lines)

- **File**: `src/ruby/vj_pad.rb`
- **Problem**: Color control, parameter control, audio input, serial, pen, and WordArt control all in one class
- **Improvement**: Apply facade pattern and split into individual controllers

### [A-3] HIGH: DRY up VJPad command methods

- **File**: `src/ruby/vj_pad.rb` lines 47-174
- **Problem**: 30+ command methods repeat identical patterns (getter/setter same structure)
- **Improvement**: Use PARAM_COMMANDS constant + define_method for metaprogramming

### [A-4] HIGH: Remove global variables

- **File**: `src/ruby/main.rb` lines 3-17
- **Problem**: 15 `$` global variables cause test difficulty and state leakage
- **Improvement**: Manage via VisualizerApplication container class

### [A-5] MEDIUM: Auto-generate VisualizerPolicy getters/setters

- **File**: `src/ruby/visualizer_policy.rb` lines 70-167
- **Problem**: 45 manually defined methods with repetitive patterns
- **Improvement**: Use MUTABLE_KEYS constant + define_singleton_method for dynamic generation

### [A-6] MEDIUM: Consolidate AudioInputManager/DebugFormatter duplicate logic

- **File**: `src/ruby/vj_pad.rb` lines 178-204, `src/ruby/debug_formatter.rb` lines 34-48, `src/ruby/keyboard_handler.rb` lines 79-98
- **Problem**: @audio_input_manager existence check and fallback processing repeated in 3 places
- **Improvement**: Extract AudioInputHelper helper method

### [A-7] MEDIUM: Unify SerialProtocol encode/decode common logic

- **File**: `src/ruby/serial_protocol.rb`
- **Problem**: decode (lines 32-65) and decode_frequency (lines 80-110) share similar patterns
- **Improvement**: Extract common parser method

### [A-8] MEDIUM: Replace WordartRenderer manual JSON serializer

- **File**: `src/ruby/wordart_renderer.rb` lines 294-311
- **Problem**: Handwritten JSON serializer is hard to maintain and has incomplete escape handling
- **Improvement**: Use JSON.generate (verify availability in ruby.wasm first)

### [A-9] LOW: Unify ColorPalette singleton pattern

- **File**: `src/ruby/color_palette.rb` lines 104-140
- **Problem**: Instance-based and class-method-based approaches are mixed
- **Improvement**: Standardize to either full singleton or full instance pattern

### [A-10] LOW: Group VRMDancer bone rotation calculations

- **File**: `src/ruby/vrm_dancer.rb` lines 75-179
- **Problem**: 13 rotation groups with similar structure (4-6 lines each) are hard to read
- **Improvement**: Extract per-bone calculation methods

## Potential Bug Risks

### [B-1] VJPad mic/tab fallback branch behavior inconsistency

- **File**: `src/ruby/vj_pad.rb` line 191
- **Problem**: Behavior may differ when `@audio_input_manager` is nil vs false
- **Investigation**: Verify whether `JS.global.respond_to?(:setMicMute)` always returns true due to ruby.wasm limitations

### [B-2] SerialProtocol buffer overflow risk

- **File**: `src/ruby/serial_protocol.rb` lines 132-137
- **Problem**: Incomplete frame retention logic in extract_frames is complex and may cause buffer overflow
- **Investigation**: Add boundary testing with large/malformed input frames

### [B-3] WordartRenderer incomplete escape handling

- **File**: `src/ruby/wordart_renderer.rb` line 302
- **Problem**: Multiple backslash escaping is incomplete
- **Investigation**: Test with strings containing backslashes, quotes, and control characters

### [B-4] ParticleSystem random seed dependency

- **File**: `src/ruby/particle_system.rb`
- **Problem**: Multiple particle types share the same random seed; third particle always depends on previous probability check result
- **Investigation**: Verify particle type selection is statistically independent

### [B-5] VJPad exec() instance_eval security concern

- **File**: `src/ruby/vj_pad.rb`
- **Problem**: instance_eval directly evaluates input, allowing arbitrary code execution from user input
- **Investigation**: Assess actual attack surface in browser WASM context; consider allowlist approach

## Test Coverage & Exploratory Testing Tasks

### [C-1] HIGH: Create JSBridge unit tests (completely untested)

- **File**: `src/ruby/js_bridge.rb` (122 lines)
- **Problem**: update_particles, update_geometry, update_bloom, update_camera, update_vrm, update_vrm_material, log, error are all untested
- **Direction**: Design tests with mocked JS dependencies

### [C-2] HIGH: Create CameraController tests (untested)

- **File**: `src/ruby/camera_controller.rb` (31 lines)
- **Problem**: shake behavior (uses random) and decay effect are unverified
- **Direction**: Test with fixed random seed; verify decay rate calculation

### [C-3] HIGH: Create FrequencyMapper tests (untested)

- **File**: `src/ruby/frequency_mapper.rb` (38 lines)
- **Problem**: BASS_RANGE, MID_RANGE, HIGH_RANGE boundary calculations are unverified
- **Direction**: Test each range boundary and overlap behavior

### [C-4] HIGH: Create ParticleSystem tests (untested)

- **File**: `src/ruby/particle_system.rb`
- **Problem**: Particle explosion logic, physics simulation, and boundary handling are unverified
- **Direction**: Test particle lifecycle, velocity/position updates, boundary conditions

### [C-5] HIGH: Create BloomController tests (untested)

- **File**: `src/ruby/bloom_controller.rb`
- **Problem**: Bloom intensity calculation and threshold processing are unverified
- **Direction**: Test intensity curves, threshold clamping, and decay behavior

### [C-6] HIGH: Create GeometryMorpher tests (untested)

- **File**: `src/ruby/geometry_morpher.rb`
- **Problem**: Geometry deformation calculations are unverified
- **Direction**: Test morph targets, interpolation correctness, edge cases

### [C-7] MEDIUM: Fix VRMDancer delta_time parameter test discrepancy

- **File**: `test/test_vrm_dancer.rb` lines 32-38
- **Problem**: Comment states "This test will FAIL until we refactor..." indicating implementation and tests are out of sync
- **Direction**: Either update implementation to accept delta_time or update test to match current API

### [C-8] MEDIUM: Add AudioAnalyzer NaN/Infinity handling tests

- **File**: `src/ruby/audio_analyzer.rb`
- **Problem**: Behavior when FFT data contains abnormal values (NaN, Infinity) is untested
- **Direction**: Test with edge-case FFT arrays; verify graceful degradation

### [C-9] MEDIUM: Add FrameCounter time-skip scenario tests

- **File**: `test/test_frame_counter.rb`
- **Problem**: No test for time going backwards (frame skip handling in real environment unverified)
- **Direction**: Test with non-monotonic timestamps; verify no negative delta_time propagation

### [C-10] MEDIUM: Expand BPMEstimator FPS variation scenario tests

- **File**: `test/test_bpm_estimator.rb`
- **Problem**: Only fixed FPS values (30, 60, 15, 20) tested; realistic variation not covered
- **Direction**: Add tests with variable FPS sequences simulating real browser behavior

### [C-11] MEDIUM: Improve VJPad exec() exception behavior tests

- **File**: `test/test_vj_pad.rb` lines 289-291
- **Problem**: Syntax error catch behavior only partially covered
- **Direction**: Test runtime errors, nil dereference, and stack overflow scenarios in exec()

### [C-12] LOW: Improve MockJSObject completeness

- **File**: `test/test_helper.rb` lines 11-34
- **Problem**: May not support JS.Object#call; risk of divergence from production implementation
- **Direction**: Audit MockJSObject against js-2.8.1 API; add missing method stubs

### [C-13] LOW: Introduce parameterized tests to reduce repetition

- **File**: `test/test_vj_pad.rb`, `test/test_visualizer_policy.rb`
- **Problem**: getter/setter tests and clamping tests repeated 30+ times
- **Direction**: Use data-driven test patterns (e.g., array of [method, value, expected] tuples)
