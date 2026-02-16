# Ruby WASM Sound Visualizer - Project Tasks

Project task list for tracking progress.

## Notes

- All tasks implemented with t-wada style TDD (800 tests, 100% pass)
- Ruby-first implementation: all logic in Ruby, minimal JS for browser API glue
- Chrome MCP browser testing deferred to local sessions
- Global variables eliminated: VisualizerApp container class replaces 15 `$` globals

## Code Quality & Refactoring Tasks

### [A-1] DONE: Split rubyUpdateVisuals lambda in main.rb

- Replaced 126-line monolithic lambda with VisualizerApp#update_visuals (10-line orchestrator)
- Extracted 11 private methods: dispatch_vj_actions, analyze_audio, update_effects,
  update_vrm, scale_analysis_for_vrm, update_serial, update_pen_input, update_wordart,
  update_frame_tracking, update_debug_display, update_audio_log

### [A-2] DONE: Split VJPad mega-class

- Extracted VJSerialCommands module (118 lines): 13 serial/serial_audio commands
- VJPad reduced from 436 to 211 lines

### [A-3] DONE: DRY up VJPad command methods

- Created PARAM_COMMANDS hash (14 entries) + define_method loop
- Replaced 14 manually written getter/setter methods

### [A-4] DONE: Remove global variables

- Created VisualizerApp container class encapsulating all 15 instance variables
- Injected wordart_renderer/pen_input into VJPad constructor
- Replaced $frame_count global with JSBridge.frame_count module accessor

### [A-5] DONE: Auto-generate VisualizerPolicy getters/setters

- Created RUNTIME_PARAMS hash (17 entries) with default, type, min, max
- Auto-generates getters, clamped setters, reset_runtime via metaprogramming
- 334 to 202 lines (-40%)

### [A-6] DONE: Consolidate AudioInputManager/DebugFormatter duplicate logic

- Simplified DebugFormatter with safe navigation operator (&.)
- Removed JS.global fallback from VJPad mic/tab commands

### [A-7] DONE: Unify SerialProtocol encode/decode common logic

- Created FRAME_SPECS table driving shared parse_frame() method
- Added MAX_BUFFER_SIZE = 4096 buffer overflow guard
- 162 to 127 lines

### [A-8] DONE: Replace WordartRenderer manual JSON serializer

- Fixed incomplete escape handling (newlines, tabs, carriage returns)
- Extracted escape_json() helper with block-form gsub

### [A-9] DONE: Unify ColorPalette singleton pattern

- Replaced 10 manual class-level delegation methods with CLASS_DELEGATIONS hash
- 164 to 123 lines

### [A-10] DONE: Group VRMDancer bone rotation calculations

- Extracted private methods: update_phases, update_face, build_rotations,
  build_torso, build_arms, build_legs, apply_smoothing
- Extracted constants: ROTATION_AMPLIFY, SMOOTHING_FACTOR
- Removed all Japanese comments

## Potential Bug Risks

### [B-1] DONE: VJPad mic/tab fallback behavior inconsistency

- Removed JS.global fallback; returns "unavailable" when no AudioInputManager
- Simplified to consistent behavior

### [B-2] DONE: SerialProtocol buffer overflow risk

- Added MAX_BUFFER_SIZE = 4096 guard
- Added boundary tests for buffer overflow

### [B-3] DONE: WordartRenderer incomplete escape handling

- Fixed newline, tab, carriage return escaping in hash_to_json
- Added 4 escape tests

### [B-4] INVESTIGATED: ParticleSystem random seed dependency

- Particle type assignment is deterministic (idx % 3), not random
- Each type's explosion check uses independent rand() calls
- No actual bug; particle type selection is statistically independent

### [B-5] INVESTIGATED: VJPad exec() instance_eval security concern

- In browser WASM sandbox, attack surface is inherently limited
- Ruby WASM cannot access filesystem, network, or OS resources
- Added exception behavior tests (C-11) documenting error handling

## Test Coverage & Exploratory Testing Tasks

### [C-1] DONE: Create JSBridge unit tests

- 20 tests covering all 8 public methods with edge cases

### [C-2] DONE: Create CameraController tests

- 7 tests: shake trigger, decay, initialization

### [C-3] DONE: Create FrequencyMapper tests

- 10 tests: band splitting, boundaries, edge cases

### [C-4] DONE: Create ParticleSystem tests

- 11 tests: initialization, update, boundary handling

### [C-5] DONE: Create BloomController tests

- 11 tests: intensity curves, threshold, capping

### [C-6] DONE: Create GeometryMorpher tests

- 11 tests: scale, rotation, emissive, color

### [C-7] DONE: Fix VRMDancer delta_time parameter test discrepancy

- Removed stale comment; update method already accepts delta_time

### [C-8] DONE: Add AudioAnalyzer NaN/Infinity handling tests

- Added finite? guard in calculate_energy and find_dominant_frequency
- 4 tests: NaN, Infinity, all-zeros, single-element array

### [C-9] DONE: Add FrameCounter time-skip scenario tests

- 4 tests: backwards timestamp, negative FPS, large gap, zero timestamp

### [C-10] DONE: Expand BPMEstimator FPS variation scenario tests

- 3 tests: variable FPS, FPS jitter, FPS zero clamp

### [C-11] DONE: Improve VJPad exec() exception behavior tests

- 5 tests: RuntimeError, NameError, TypeError, ZeroDivisionError, NoMethodError

### [C-12] DONE: Improve MockJSObject completeness

- Added configurable typeof parameter to MockJSObject constructor
- Added JS.eval stub for API completeness
- Verified method_missing covers JS::Object#call pattern

### [C-13] DONE: Introduce parameterized tests to reduce repetition

- VJPad: data-driven PARAM_COMMANDS getter/setter tests (28 tests from 14-entry hash)
- VisualizerPolicy: data-driven MUTABLE_KEYS, reset, and set_by_key/get_by_key roundtrip tests
- Removed 19 repetitive manual tests replaced by data-driven equivalents
