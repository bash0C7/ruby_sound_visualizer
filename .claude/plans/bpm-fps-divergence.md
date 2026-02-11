# Plan: Fix BPM Estimation Divergence from Measured FPS

## Problem

FPS is clamped to a minimum of 30 in `main.rb` before being passed to `BPMEstimator`, causing systematic BPM overestimation when the actual frame rate is in the 10-29 FPS range.

**Root cause:** `main.rb:90`
```ruby
$bpm_estimator.record_beat(frame_count, fps: [($frame_counter.current_fps), 30].max.to_f)
```

The `[value, 30].max` enforces a floor of 30 FPS. BPMEstimator already has its own low-FPS guard (`fps = 30.0 if fps < 10` at `bpm_estimator.rb:27`), so the external clamping removes valid signal for the 10-29 FPS range.

**Impact example:** At 20 FPS actual, a beat interval of 20 frames = 1.0 second real time, but is calculated as 20/30 = 0.67 seconds, overestimating BPM by ~33%.

## Affected Files

| File | Lines | Role |
|------|-------|------|
| `src/ruby/main.rb` | 90 | FPS clamping before BPMEstimator call |
| `src/ruby/bpm_estimator.rb` | 16-38 | BPM estimation algorithm + internal low-FPS guard |
| `src/ruby/frame_counter.rb` | - | FPS measurement (no changes needed) |
| `src/ruby/config.rb` | 12 | WARMUP_FRAMES = 30 |
| `test/test_bpm_estimator.rb` | - | Test coverage for BPM calculation |

## Implementation Steps

### Step 1: Write failing tests (Red)

Add test cases for the 10-29 FPS range in `test/test_bpm_estimator.rb`:

- `test_bpm_at_15_fps` - Verify correct BPM at 15 FPS (should not be treated as 30 FPS)
- `test_bpm_at_20_fps` - Verify correct BPM at 20 FPS
- `test_bpm_at_25_fps` - Verify correct BPM at 25 FPS
- `test_bpm_at_10_fps` - Boundary: exactly 10 FPS (should use actual value, not 30)

### Step 2: Remove external FPS clamping (Green)

In `main.rb:90`, change:
```ruby
# Before
$bpm_estimator.record_beat(frame_count, fps: [($frame_counter.current_fps), 30].max.to_f)

# After
$bpm_estimator.record_beat(frame_count, fps: $frame_counter.current_fps.to_f)
```

### Step 3: Review BPMEstimator internal guard

Evaluate whether `bpm_estimator.rb:27` (`fps = 30.0 if fps < 10`) is still appropriate, or if a gentler degradation strategy would be better (e.g., clamping to 10 instead of 30 when fps < 10).

### Step 4: Verify edge cases

- FPS = 0 (should not cause division by zero)
- FPS transitions (e.g., sudden drop from 60 to 15 during load)
- Warmup period (first 30 frames, `Config::WARMUP_FRAMES`)

### Step 5: Run full test suite

Ensure all existing BPM tests still pass and new tests pass.

## Verification

- **Local only (Chrome MCP required):** Play music at known BPM, observe estimated BPM at various FPS levels
- **Automated:** Test suite covers the critical 10-29 FPS range

## Risk Assessment

- **Low risk:** Single-line change in `main.rb`, well-tested BPMEstimator
- **Backward compatible:** No API changes
- **Regression concern:** BPM accuracy at very low FPS (< 10) depends on the internal guard
