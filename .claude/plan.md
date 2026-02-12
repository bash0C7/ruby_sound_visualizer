# Implementation Plan: Polish PR#14 for Ruby-First Audio Architecture

## Overview

This plan refactors PR#14's audio input management from JavaScript-first to Ruby-first architecture through disciplined TDD, and fixes a critical bug where tab video overlay disappears in the visualizer screen.

**Current Status:**
- PR#14 branch: `claude/audio-input-enhancement-ZCA6q`
- 235 tests passing
- Mic mute/unmute working via 'm' key
- Tab audio/video capture working via 't' key
- **CRITICAL BUG**: Tab video overlay disappears when entering visualizer screen (audio still works)

**User Requirements:**
1. Mic mute/unmute (startup button, key toggle, command) ✓ implemented
2. Tab audio with mic mixing ✓ implemented
3. Tab video background overlay (black 50% transparency) ← **BROKEN in visualizer screen**
4. JavaScript to minimum, Ruby-first approach ← PRIMARY TASK
5. t-wada style TDD, expand tests ← PRIMARY TASK
6. Chrome verification after implementation

---

## Phase 0: CRITICAL BUG FIX - Video Overlay Disappears

**Goal**: Fix tab video overlay disappearing when entering visualizer screen

**Problem Analysis:**
- Initial screen shows tab video with 50% black overlay ✓
- After selecting VRM/no-VRM, visualizer screen shows black background only ✗
- Tab audio continues working (audio analysis works)
- Video elements exist in DOM but not visible behind Three.js canvas

**Root Cause Identified:**
```javascript
// index.html:433-436
renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false }); // ← alpha: false makes canvas opaque!
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setClearColor(0x000000); // ← black background without transparency
document.body.appendChild(renderer.domElement);
```

The Three.js canvas is **opaque** (`alpha: false`), blocking the video layer (z-index: -2) behind it.

**DOM Structure:**
```
<video id="tabVideo"> (z-index: -2)
<div id="tabOverlay"> (z-index: -1, black 50% overlay)
<canvas> (Three.js renderer, z-index: 0, OPAQUE) ← blocks video!
```

**Solution:**

**Step 0.1: Fix renderer transparency**
```
File: index.html:433-436
Change from:
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setClearColor(0x000000);

Change to:
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setClearColor(0x000000, 0); // Second parameter = alpha channel (0 = fully transparent)
```

**Step 0.2: Verify mix-blend-mode**
```
Current implementation (index.html:358-360):
  if (renderer && renderer.domElement) {
    renderer.domElement.style.mixBlendMode = 'screen';
  }

This should work correctly once alpha: true is enabled.
```

**Step 0.3: Chrome verification**
```
1. Connect to Chrome using tabs_context_mcp
2. Navigate to http://localhost:8000/index.html
3. Click "Capture Tab" button
4. Select a tab to capture (grant permissions)
5. Select VRM or "Start without VRM"
6. VERIFY: Tab video visible behind particles/torus/VRM with 50% black overlay
7. VERIFY: Particles/VRM/torus render on top of video
8. VERIFY: mix-blend-mode: screen makes bright particles more visible
```

**Expected Result:**
- Video plays in background at z-index: -2
- Black 50% overlay at z-index: -1
- Three.js canvas transparent with mix-blend-mode: screen at z-index: 0
- Particles/torus/VRM visible on top

**Files Modified:**
- `index.html` (2 character changes: `false` → `true`, add `, 0` parameter)

**Tests:**
- Manual Chrome verification only (no unit tests for rendering)

**Risk:** Very low - small change, easily reversible

---

## Phase 1: Foundation - AudioInputManager (State Owner)

**Goal**: Create Ruby single source of truth for audio input state

**Current Problem:**
- VJPad commands query `JS.global[:micMuted]` and `JS.global[:tabStream]` directly
- State scattered across JavaScript variables
- No Ruby state layer

**Step 1.1: Red - Write AudioInputManager tests**
```
File: test/test_audio_input_manager.rb (NEW)
Tests to write (11 tests):
- test_initial_state_is_mic_unmuted
- test_mute_mic_changes_state_to_muted
- test_unmute_mic_changes_state_to_unmuted
- test_toggle_mic_from_unmuted_to_muted
- test_toggle_mic_from_muted_to_unmuted
- test_switch_to_tab_capture_sets_source_to_tab
- test_switch_to_mic_sets_source_to_microphone
- test_is_tab_capture_returns_true_when_source_is_tab
- test_is_mic_input_returns_true_when_source_is_mic
- test_get_mic_volume_when_muted_returns_0
- test_get_mic_volume_when_unmuted_returns_1
```

**Step 1.2: Green - Implement AudioInputManager**
```
File: src/ruby/audio_input_manager.rb (NEW)
Class responsibilities:
- Track mic mute state (boolean)
- Track audio source (:microphone or :tab)
- Provide query methods (mic_muted?, tab_capture?, mic_volume)
- Provide command methods (mute_mic, unmute_mic, toggle_mic, switch_to_tab, switch_to_mic)
- NO JavaScript calls - pure state management
```

**Step 1.3: Refactor - Integrate into MainController**
```
File: src/ruby/main_controller.rb (MODIFY)
- Add @audio_input_manager = AudioInputManager.new to initialize
- Expose via attr_reader
- Update existing tests if needed
```

**Verification**: Run test suite, expect 246+ tests passing (11 new tests)

---

## Phase 2: Keyboard Handler - Move 'm'/'t' Keys to Ruby

**Goal**: Remove keyboard handling from JavaScript, centralize in Ruby KeyboardHandler

**Current Problem:**
- 'm' and 't' keys handled in JavaScript (index.html)
- KeyboardHandler has no tests for these keys

**Step 2.1: Red - Write keyboard handler tests**
```
File: test/test_keyboard_handler.rb (MODIFY)
Tests to add (5 tests):
- test_m_key_toggles_mic_mute_state_via_audio_input_manager
- test_t_key_switches_to_tab_capture_via_audio_input_manager
- test_m_key_calls_js_set_mic_volume_with_correct_value
- test_t_key_calls_js_capture_tab_with_video_true
- test_multiple_m_key_presses_toggle_mic_state
```

**Step 2.2: Green - Implement 'm'/'t' key handlers**
```
File: src/ruby/keyboard_handler.rb (MODIFY)
Add to handle_key (lines 10-24):
  when 'm'
    @audio_input_manager.toggle_mic
    volume = @audio_input_manager.mic_volume
    JS.global.call(:setMicVolume, volume)
    JSBridge.log "Mic: #{@audio_input_manager.mic_muted? ? 'OFF' : 'ON'}"
  when 't'
    @audio_input_manager.switch_to_tab
    JS.global.call(:captureTab, true)
    JSBridge.log "Tab Capture: #{@audio_input_manager.tab_capture? ? 'ON' : 'OFF'}"

Inject audio_input_manager in initialize:
  def initialize(audio_input_manager)
    @audio_input_manager = audio_input_manager
    ...
  end
```

**Step 2.3: Refactor - Remove JS keyboard listeners**
```
File: index.html (MODIFY)
Search for keyboard event handler with 'm' and 't' cases
Remove these case statements (JS should only dispatch to Ruby)
```

**Step 2.4: Update MainController instantiation**
```
File: src/ruby/main_controller.rb or index.html
Update KeyboardHandler.new to pass audio_input_manager
```

**Verification**: Run test suite, expect 251+ tests passing (5 new tests)

---

## Phase 3: VJPad Commands - Ruby State Before JS Calls

**Goal**: Commands consult Ruby state manager instead of querying JS.global directly

**Current Problem (src/ruby/vj_pad.rb:115-134):**
```ruby
def mic(value = nil)
  muted = JS.global[:micMuted]
  # Queries JavaScript state directly!
end
```

**Step 3.1: Red - Write VJPad command tests**
```
File: test/test_vj_pad.rb (MODIFY)
Enhance existing audio tests (6 new tests):
- test_mic_command_updates_audio_input_manager_state
- test_mic_unmute_command_sets_manager_to_unmuted
- test_mic_mute_command_sets_manager_to_muted
- test_tab_command_updates_audio_input_manager_to_tab_source
- test_status_command_reflects_audio_input_manager_state
- test_mic_command_with_no_args_returns_current_state
```

**Step 3.2: Green - Refactor VJPad commands**
```
File: src/ruby/vj_pad.rb (MODIFY lines 115-134)
Change from:
  def mic(value = nil)
    muted = JS.global[:micMuted]
    is_muted = muted.respond_to?(:typeof) ? muted.typeof.to_s != "undefined" && muted : false
    return is_muted ? "muted" : "on" if value.nil?
    # ...
  end

Change to:
  def mic(value = nil)
    return @main_controller.audio_input_manager.mic_muted? ? "muted" : "on" if value.nil?

    if value.to_i == 0
      @main_controller.audio_input_manager.mute_mic
    else
      @main_controller.audio_input_manager.unmute_mic
    end

    volume = @main_controller.audio_input_manager.mic_volume
    JS.global.call(:setMicVolume, volume)

    @main_controller.audio_input_manager.mic_muted? ? "muted" : "on"
  end
```

**Step 3.3: Refactor - Update DebugFormatter**
```
File: src/ruby/debug_formatter.rb (MODIFY)
Change from:
  muted = JS.global[:micMuted]
  mic_status = (muted && muted != false) ? "OFF" : "ON"

  stream = JS.global[:tabStream]
  is_active = stream.respond_to?(:typeof) ? stream.typeof.to_s != "undefined" : !!stream
  tab_status = is_active ? "ON" : "OFF"

Change to:
  mic_status = @main_controller.audio_input_manager.mic_muted? ? "OFF" : "ON"
  tab_status = @main_controller.audio_input_manager.tab_capture? ? "ON" : "OFF"
```

**Verification**: Run test suite, expect 257+ tests passing (6 new tests)

---

## Phase 4: AudioAnalyzer - Comprehensive Test Coverage

**Goal**: Test the 160+ untested lines in AudioAnalyzer

**Current Problem:**
- `src/ruby/audio_analyzer.rb` has NO test file
- Frequency analysis (bass/mid/high) untested
- Beat detection untested

**Step 4.1: Red - Write AudioAnalyzer tests**
```
File: test/test_audio_analyzer.rb (NEW)
Test categories (18+ tests):

Initialization (3 tests):
- test_initialize_with_default_fft_size
- test_initialize_with_custom_fft_size
- test_sets_smoothing_time_constant

Frequency Analysis (6 tests):
- test_get_bass_returns_average_of_first_frequency_bins
- test_get_mid_returns_average_of_middle_frequency_bins
- test_get_high_returns_average_of_high_frequency_bins
- test_frequency_bins_non_overlapping_coverage
- test_normalized_values_between_0_and_1
- test_overall_energy_is_average_of_all_bands

Update Cycle (3 tests):
- test_update_calls_analyzer_get_byte_frequency_data
- test_update_with_nil_analyzer_does_not_crash
- test_frequency_data_stored_in_buffer

Edge Cases (6 tests):
- test_zero_volume_returns_zero_for_all_bands
- test_max_volume_returns_normalized_values
- test_handles_analyzer_disconnect_gracefully
- test_bass_mid_high_sum_represents_full_spectrum
- test_update_before_initialization_safe
- test_repeated_updates_maintain_smoothing
```

**Step 4.2: Green - Fix any discovered issues**
```
File: src/ruby/audio_analyzer.rb (MODIFY if needed)
- Most code should already work
- Add nil checks if tests reveal gaps
- Document frequency bin allocation formula
```

**Step 4.3: Refactor - Improve clarity**
```
- Extract magic numbers to named constants (BASS_BINS, MID_BINS, etc.)
- Add comments explaining FFT size implications
- Verify smoothingTimeConstant value reasoning
```

**Verification**: Run test suite, expect ~275+ tests passing (18+ new tests)

---

## Phase 5: Integration & Edge Cases

**Goal**: Test cross-component interactions and failure modes

**Step 5.1: Red - Write integration tests**
```
File: test/test_integration_audio.rb (NEW)
Integration scenarios (6 tests):
- test_mic_toggle_keyboard_updates_vj_pad_status
- test_tab_capture_keyboard_updates_debug_formatter_display
- test_mic_command_followed_by_keyboard_toggle_consistent_state
- test_switching_tab_to_mic_restores_previous_mic_mute_state
- test_rapid_mic_toggles_maintain_state_consistency
- test_audio_analyzer_continues_during_input_source_changes
```

**Step 5.2: Green - Fix race conditions/inconsistencies**
```
Files to potentially modify:
- src/ruby/audio_input_manager.rb - add state validation
- src/ruby/keyboard_handler.rb - debounce rapid toggles if needed
- index.html - ensure JS calls are synchronous where expected
```

**Step 5.3: Refactor - Error handling**
```
- Add error handling for failed JS calls
- Graceful degradation if Web Audio API unavailable
- Logging for debugging state transitions
```

**Verification**: Run test suite, expect ~281+ tests passing (6 new tests)

---

## Phase 6: Chrome MCP Verification

**Goal**: Verify all functionality in real browser

**Step 6.1: Use /debug-browser skill**
```
Execute: Skill(skill: "debug-browser")
Manual test scenarios:
1. Load http://localhost:8000/index.html
2. Verify initial mic input (audio analysis working)
3. Press 'm', verify mute indicator (console log)
4. Press 'm' again, verify unmute
5. Type `mic mute` in VJ Pad, verify command works
6. Press 't', verify tab capture permission prompt
7. Grant permissions, select a tab to capture
8. VERIFY: Tab video visible with 50% black overlay
9. VERIFY: Particles/torus/VRM render on top of video
10. Type `status` in VJ Pad, verify correct state display
11. Check console for Ruby/JS errors (should be none)
```

**Step 6.2: Performance verification**
```
- Verify 60fps animation during audio analysis
- Check memory usage stable over 5 minutes
- Verify no memory leaks on repeated tab capture
- Test with high/low audio input levels
- Test rapid 'm' key presses (debouncing)
```

---

## Risk Mitigation

**Risks and Mitigations:**

1. **Risk**: Breaking existing 235 tests
   - **Mitigation**: Run full suite after each phase, fix immediately

2. **Risk**: Phase 0 fix breaks rendering
   - **Mitigation**: `alpha: true` is safe, widely used for transparent overlays

3. **Risk**: JS/Ruby interop issues with new AudioInputManager
   - **Mitigation**: Phase 1 is pure Ruby state (no JS calls), test in isolation

4. **Risk**: Keyboard events not reaching Ruby
   - **Mitigation**: Phase 2 tests verify before removing JS listeners

5. **Risk**: Tab capture async promises breaking Ruby flow
   - **Mitigation**: Keep captureDisplayMedia in JS, Ruby only triggers

6. **Risk**: State synchronization between Ruby and JS
   - **Mitigation**: AudioInputManager is single source of truth, JS reads from Ruby

---

## File Modification Summary

### Phase 0 (Bug Fix)
- `index.html` - Fix renderer transparency (2 characters)

### Phase 1-5 (Refactoring)
**New Files (4):**
1. `src/ruby/audio_input_manager.rb` - State manager class
2. `test/test_audio_input_manager.rb` - Manager tests (11 tests)
3. `test/test_audio_analyzer.rb` - Analyzer tests (18+ tests)
4. `test/test_integration_audio.rb` - Integration tests (6 tests)

**Modified Files (6):**
1. `src/ruby/main_controller.rb` - Add audio_input_manager initialization
2. `src/ruby/keyboard_handler.rb` - Add 'm'/'t' key handlers
3. `src/ruby/vj_pad.rb` - Refactor mic/tab commands to use manager
4. `src/ruby/debug_formatter.rb` - Read from Ruby state not JS
5. `test/test_keyboard_handler.rb` - Add 'm'/'t' tests (5 tests)
6. `test/test_vj_pad.rb` - Enhance audio command tests (6 tests)

**Minimal JS Changes:**
1. `index.html` - Phase 0: alpha fix (2 chars), Phase 2: Remove 'm'/'t' listeners

---

## Success Criteria

**Merge Readiness Checklist:**

- [ ] **Phase 0: Tab video overlay visible in visualizer screen** (CRITICAL)
- [ ] All 281+ tests passing (46+ new tests, 235 existing)
- [ ] AudioAnalyzer has >90% test coverage
- [ ] Audio input state owned by Ruby, not JS
- [ ] Keyboard 'm'/'t' handled in Ruby KeyboardHandler
- [ ] VJPad commands consult AudioInputManager before JS calls
- [ ] Chrome MCP verification confirms all features work
- [ ] No console errors in browser
- [ ] No performance regression (60fps maintained)
- [ ] Code follows existing patterns (burst/flash command style)

**Test Coverage Growth:**
- Before: 235 tests, AudioAnalyzer 0% coverage, video overlay broken
- After: 281+ tests, AudioAnalyzer >90% coverage, video overlay working

---

## Implementation Order

1. **Phase 0 first** (CRITICAL BUG) - fixes user's immediate problem
2. **Phase 1-5** (refactoring) - improves architecture
3. **Phase 6** (verification) - confirms everything works

**Estimated Time:**
- Phase 0: 15 min (small change + Chrome verification)
- Phase 1: 45 min (AudioInputManager TDD)
- Phase 2: 60 min (Keyboard handler refactoring)
- Phase 3: 45 min (VJPad commands refactoring)
- Phase 4: 90 min (AudioAnalyzer comprehensive tests)
- Phase 5: 45 min (Integration tests)
- Phase 6: 30 min (Final Chrome verification)

**Total**: ~5.5 hours of focused TDD implementation
