# Plan: Performance Tuning

## Goal

Achieve stable 30+ FPS on target hardware through Chrome DevTools profiling and targeted optimization.

**Constraint:** Requires local Chrome MCP connection for profiling and verification.

## Current Architecture Overview

### Per-Frame Execution Flow

1. **JS:** `requestAnimationFrame` callback fires
2. **JS:** `analyser.getByteFrequencyData()` extracts FFT data (2048 bins)
3. **JS→Ruby:** `window.rubyUpdateVisuals(dataArray, timestamp)` crosses WASM boundary
4. **Ruby:** Audio analysis → Effect calculations → Data packaging
5. **Ruby→JS:** 9 boundary calls send visual data back (particles, geometry, bloom, camera, VRM, materials)
6. **JS:** DOM updates (throttled every 15 frames)
7. **JS:** VRM spring bones update
8. **JS:** `composer.render()` (Three.js + bloom post-processing)

### Performance Budget

| Target | Budget |
|--------|--------|
| 30 FPS | 33.3 ms/frame |
| 60 FPS | 16.7 ms/frame |

## Critical Bottlenecks (Priority Order)

### 1. Particle Color Calculation (HIGHEST)

- **Location:** `particle_system.rb:86` → `color_palette.rb:67-93`
- **Cost:** `ColorPalette.frequency_to_color_at_distance()` called 3000x per frame
- **Each call:** HSV calculation, `Math.tanh()`, modulo, HSV→RGB conversion
- **Estimated:** ~60,000 operations/frame

### 2. VRM Material Traversal (HIGH)

- **Location:** `index.html:500-533` (`updateVRMMaterial`)
- **Cost:** `scene.traverse()` walks entire VRM scene graph every frame
- **Issue:** `mat.needsUpdate = true` triggers GPU material recompile each frame

### 3. WASM Boundary Crossing (MEDIUM-HIGH)

- **Location:** `main.rb:54-78` (JSBridge calls)
- **Cost:** 9 cross-boundary calls per frame
- **Data volume:** ~9,000+ floats for particles alone (3000 particles x 3 positions + 3 colors)

### 4. VRM Bone Calculation (MEDIUM)

- **Location:** `vrm_dancer.rb:31-200`
- **Cost:** 14 bones x 3 axes = 42 rotation values, ~30+ trig calls per frame

### 5. Audio Analysis (MEDIUM)

- **Location:** `audio_analyzer.rb:43-109`
- **Cost:** O(2048) for FFT band splitting + energy calculation

## Optimization Phases

### Phase 1: Low-Risk, High-Impact

These changes preserve visual quality while reducing computational cost.

#### 1a. Cache particle colors

- Recalculate colors every 3-5 frames instead of every frame
- Store last calculated colors and reuse between recalculations
- **Impact:** ~60-80% reduction in color calculation calls
- **Files:** `particle_system.rb`, `color_palette.rb`

#### 1b. Cache VRM material references

- On VRM load, store direct references to all emissive materials
- Update cached references directly instead of `scene.traverse()` every frame
- Remove per-frame `mat.needsUpdate = true` (only set when value actually changes)
- **Impact:** ~80% reduction in scene traversal cost
- **Files:** `index.html` (updateVRMMaterial function, VRM load handler)

#### 1c. Pre-calculate color lookup table

- Build a lookup table for distance→hue mapping at initialization
- Use table interpolation instead of per-particle HSV calculation
- **Impact:** ~40% reduction per particle computation
- **Files:** `color_palette.rb`

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

## Verification Criteria

- Stable 30+ FPS with microphone input active
- No visual quality regression visible to user
- Beat detection accuracy maintained
- All existing tests pass
