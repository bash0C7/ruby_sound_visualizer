# Plan: Performance Tuning

## Goal

Achieve stable 30+ FPS on target hardware through Chrome DevTools profiling and targeted optimization.

**Constraint:** Requires local Chrome MCP connection for profiling and verification.

## Current Architecture Overview

### Per-Frame Execution Flow (Verified from Source)

1. **JS:** `requestAnimationFrame` callback fires (index.html:667)
2. **JS:** `analyser.getByteFrequencyData()` extracts FFT data (2048 bins) (index.html:679)
3. **WASM Boundary:** `window.rubyUpdateVisuals(dataArray, timestamp)` (index.html:680)
4. **Ruby:** `AudioAnalyzer.analyze()` - O(2048) FFT processing (main.rb:50)
5. **Ruby:** `EffectManager.update()` (main.rb:51)
   - **ParticleSystem.update()** - **3000x color calculations** (particle_system.rb:86)
   - GeometryMorpher, BloomController, CameraController updates
6. **WASM Boundary:** 9x JSBridge calls (main.rb:54-78)
   - `update_particles` - **18000 floats** (3000×6: positions + colors)
   - `update_geometry`, `update_bloom`, `update_camera`
   - `update_particle_rotation`
   - `update_vrm` - **called even without VRM**
   - `update_vrm_material` - **called even without VRM** (warns every frame)
7. **JS:** DOM updates (throttled every 15 frames) (index.html:688-709)
8. **JS:** VRM spring bones update (if VRM loaded) (index.html:712)
9. **JS:** `composer.render()` - Three.js rendering + bloom (index.html:715)

### Performance Budget

| Target | Budget |
|--------|--------|
| 30 FPS | 33.3 ms/frame |
| 60 FPS | 16.7 ms/frame |

## Current Status

- **Current FPS:** 23 (measured 2026-02-12)
- **Target FPS:** 30
- **Gap:** +7 FPS needed (~30% improvement)
- **Test Environment:** VRM not loaded (VRM-related bottlenecks not active)

## Critical Bottlenecks (Priority Order, VRM-less scenario)

### 1. Particle Color Calculation (HIGHEST - 3000x/frame)

- **Location:** `particle_system.rb:86` → `color_palette.rb:68-91`
- **Cost:** `ColorPalette.frequency_to_color_at_distance(analysis, normalized_dist)` called **3000x per frame**
- **Each call performs:**
  - HSV calculation from audio analysis
  - `Math.tanh()` soft-clipping
  - Modulo operation for hue wrapping
  - HSV→RGB conversion (case statement + 6 arithmetic ops)
- **Estimated:** ~60,000 operations/frame
- **Impact:** 40-50% of Ruby CPU time

### 2. Wasteful VRM Calls (HIGH - Easy fix)

- **Location:** `main.rb:74-78`
- **Issue:** VRM update functions called **every frame** even when `currentVRM` is null
- **Consequence:** JS-side `updateVRMMaterial` warns every frame (index.html:502-533)
- **Cost:** 2 unnecessary WASM boundary crossings + console warnings
- **Impact:** ~2-3% FPS (low-hanging fruit)

### 3. WASM Boundary Crossing (MEDIUM-HIGH - 9x/frame)

- **Location:** `main.rb:54-78` (JSBridge calls)
- **Cost:** 9 cross-boundary calls per frame
- **Data volume:**
  - `update_particles`: **18,000 floats** (3000×6: positions + colors)
  - `update_geometry`: 4 floats + 1 array
  - Others: minimal
- **Impact:** ~15-20% of frame time

### 4. Audio Analysis (MEDIUM - O(2048))

- **Location:** `audio_analyzer.rb:43-109`
- **Cost:**
  - FFT band splitting: O(2048)
  - Energy calculation: 6x `calculate_energy` (lines 50-53)
  - Smoothing: 6x `lerp` + 4x `exponential_decay`
  - Beat detection: baseline tracking + threshold checks
- **Impact:** ~10-15% of Ruby CPU time

### 5. VRM-Related (INACTIVE in current test)

- VRM Material Traversal (index.html:500-533) - not executed when VRM is null
- VRM Bone Calculation (vrm_dancer.rb) - minimal cost when no VRM loaded

## Optimization Phases

### Phase 1: Low-Risk, High-Impact (Target: 30 FPS)

These changes preserve visual quality while reducing computational cost. Ordered by implementation ease and immediate impact.

#### 1a. Add VRM null check (IMMEDIATE - 5 min)

- **Location:** `main.rb:74-78`
- **Change:** Wrap VRM update calls in `if currentVRM` check
- **Reason:** Eliminates 2 wasteful WASM boundary calls + console warnings
- **Expected Impact:** +0.5-0.7 FPS (~2-3% improvement)
- **Risk:** Zero (no behavior change for VRM-loaded case)
- **Implementation:**
  ```ruby
  # Check if VRM is loaded via JS
  has_vrm = JS.global[:currentVRM].typeof != "undefined" && !JS.global[:currentVRM].nil?

  if has_vrm
    vrm_data = $vrm_dancer.update(scaled_for_vrm)
    JSBridge.update_vrm(vrm_data)

    vrm_material_config = $vrm_material_controller.apply_emissive(scaled_for_vrm[:overall_energy])
    JSBridge.update_vrm_material(vrm_material_config)
  end
  ```

#### 1b. Cache particle colors (HIGH - 30-45 min)

- **Location:** `particle_system.rb`
- **Change:** Recalculate colors every 3-5 frames instead of every frame
- **Mechanism:**
  - Add `@color_cache_counter` and `@color_cache_interval = 3`
  - Store last calculated colors in particle data
  - Reuse cached colors between recalculations
- **Expected Impact:** +3.5-4.5 FPS (~15-20% improvement)
  - Reduces 3000 color calculations/frame to 600-1000
- **Risk:** Low (minimal visual difference at 23 FPS)
- **Visual Trade-off:** Color changes lag by 1-2 frames (imperceptible at current FPS)

#### 1c. Pre-calculate color lookup table (MEDIUM - 45-60 min)

- **Location:** `color_palette.rb`
- **Change:** Build distance→hue LUT at initialization, interpolate at runtime
- **Mechanism:**
  - Create 256-entry LUT for distance [0.0, 1.0] → hue offset
  - Replace `frequency_to_color_at_distance` HSV calculation with table lookup
  - Use linear interpolation for sub-index precision
- **Expected Impact:** +2.3-3.0 FPS (~10-13% improvement)
- **Risk:** Low (slight color banding possible, mitigated by interpolation)
- **Combined with 1b:** Expected total +5.8-7.5 FPS

#### 1d. Batch WASM boundary calls (OPTIONAL - if Phase 1a-c insufficient)

- **Location:** `main.rb:54-78`, `js_bridge.rb`, `index.html`
- **Change:** Combine 9 JSBridge calls into 1-2 packed calls
- **Expected Impact:** +1.0-1.5 FPS (~4-6% improvement)
- **Risk:** Medium (requires refactoring both Ruby and JS sides)
- **Decision:** Only pursue if 1a-c don't reach 30 FPS

### Phase 2: Medium-Risk (Profile-Guided)

These require profiling data to validate the trade-offs.

#### 2a. Reduce FFT size to 1024

- Trade frequency resolution (46.8 Hz/bin vs 23.4 Hz/bin) for analysis speed
- **Impact:** 50% audio analysis cost reduction
- **Risk:** May affect beat detection accuracy
- **Files:** `config.rb`, `index.html` (analyser.fftSize)

#### 2b. Reduce particle count

- Test with 2000-2500 particles, compensate with larger particle size
- **Impact:** ~17-33% Ruby CPU reduction
- **Risk:** Less dense particle field
- **Files:** `config.rb`, `index.html` (particleCount)

#### 2c. Batch WASM boundary calls

- Combine multiple JSBridge calls into a single call with a packed data object
- **Impact:** Reduces 9 boundary crossings to 1-2
- **Risk:** Requires refactoring both Ruby and JS sides
- **Files:** `main.rb`, `js_bridge.rb`, `index.html`

### Phase 3: High-Risk, Major Refactoring

Only pursue if Phase 1-2 are insufficient.

#### 3a. Move color calculation to JavaScript

- Compute particle colors in JS using the same algorithm
- Reduces WASM boundary data transfer
- **Files:** `particle_system.rb`, `color_palette.rb`, `index.html`

#### 3b. Use WebWorker for audio analysis

- Offload AudioAnalyzer to a background thread
- **Risk:** Threading complexity, shared memory management

## Profiling Methodology

### Step 1: Baseline measurement

- Connect Chrome DevTools via Chrome MCP
- Record 30-second performance trace with audio input
- Document: FPS, CPU usage (Ruby vs JS breakdown), GPU usage, memory

### Step 2: Identify actual bottlenecks

- Use Performance tab flame chart to identify hot functions
- Compare Ruby WASM execution time vs JS rendering time
- Measure WASM boundary crossing overhead

### Step 3: Apply Phase 1 optimizations

- Implement one optimization at a time
- Re-profile after each change
- Document FPS improvement per optimization

### Step 4: Evaluate Phase 2 necessity

- If 30 FPS achieved, stop
- If not, proceed with profile-guided Phase 2 optimizations

## Key Configuration Values

| Parameter | Current | Location | Performance Impact |
|-----------|---------|----------|-------------------|
| `PARTICLE_COUNT` | 3000 | `config.rb:30`, `index.html:293` | Per-frame Ruby CPU |
| `FFT_SIZE` | 2048 | `config.rb:7` | Audio analysis cost |
| `HISTORY_SIZE` | 43 | `config.rb:8` | Memory + beat detection |
| Torus segments | 12x16 | `index.html:323` | GPU vertex count |
| Bloom resolution | window size | `index.html:281` | GPU post-processing |
| DOM update interval | 15 frames | `index.html:688` | DOM thrashing |

## Implementation Strategy

### Phase 1 Execution Order

1. **1a: VRM null check** (5 min) - Quick win, test immediately
2. **Test:** Verify FPS +0.5-0.7, confirm no JS warnings
3. **1b: Particle color caching** (30-45 min) - Main optimization
4. **Test:** Verify FPS +3.5-4.5, check color transitions are smooth
5. **1c: Color lookup table** (45-60 min) - Secondary optimization
6. **Test:** Verify FPS +2.3-3.0, check for color banding
7. **Final verification:** Stable 30+ FPS, visual quality check

### Verification Criteria

- **Primary Goal:** Stable 30+ FPS with microphone input active
- **Visual Quality:** No perceptible degradation in color transitions or effects
- **Beat Detection:** Accuracy maintained (BPM estimation stable)
- **Functional:** All existing keyboard controls work
- **Code Quality:** No new warnings in console

### Rollback Plan

- Each optimization is independent and can be reverted individually
- Git commit after each successful optimization
- If visual regression occurs, reduce cache interval (1b) or LUT resolution (1c)
