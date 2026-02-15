# Shader Operations Guide

Post-processing and material behavior used by the current visualizer pipeline.

## Table of Contents

1. [Post-Processing Basics](#post-processing-basics)
2. [UnrealBloomPass](#unrealbloompass)
3. [Materials and Emissive](#materials-and-emissive)
4. [Blending Modes](#blending-modes)
5. [Soft-Clipping Strategy](#soft-clipping-strategy)
6. [References](#references)

## Post-Processing Basics

The project renders through `EffectComposer`.

Current pass chain:

```text
RenderPass -> UnrealBloomPass -> OutputPass
```

Why this matters:
- `RenderPass` draws the scene
- `UnrealBloomPass` adds glow on bright regions
- `OutputPass` finalizes tone-mapped output

`OutputPass` is part of the active pipeline and should remain in the chain.

## UnrealBloomPass

### Runtime setup

```javascript
bloomPass = new UnrealBloomPass(
  new THREE.Vector2(window.innerWidth, window.innerHeight),
  1.5,
  0.4,
  0.0
)
```

### Dynamic updates from Ruby

Ruby `BloomController` computes:
- `strength`
- `threshold`

Then JS applies:

```javascript
window.updateBloom(strength, threshold)
```

### Current Ruby-side bloom formula

```ruby
@strength = VisualizerPolicy.bloom_base_strength + Math.tanh(energy * VisualizerPolicy.bloom_energy_scale) * 2.5
@strength += Math.tanh(imp_overall) * VisualizerPolicy.bloom_impulse_scale
@strength += bloom_flash * 2.0 if bloom_flash > 0.01
@strength = VisualizerPolicy.cap_bloom(@strength)

@threshold = 0.15 - Math.tanh(energy) * 0.15
@threshold -= 0.04 * imp_overall
@threshold = [@threshold, VisualizerPolicy::BLOOM_MIN_THRESHOLD].max
```

Notes:
- `cap_bloom` is controlled by runtime `max_bloom` (default `4.5`)
- threshold floor is controlled by `BLOOM_MIN_THRESHOLD`

## Materials and Emissive

### Torus material

Uses `MeshStandardMaterial` with:
- runtime base color updates
- runtime `emissiveIntensity` updates
- white emissive color for neutral glow behavior

### VRM material behavior

`updateVRMMaterial` traverses VRM meshes and updates `emissiveIntensity` per material.

Design choice:
- keep original material color setup
- only modulate intensity in runtime

### Emissive role in bloom

Bloom reacts to bright output; emissive intensity is a direct control lever for what blooms.

## Blending Modes

Particles use additive blending:

```javascript
blending: THREE.AdditiveBlending
```

Effect:
- overlapping particles accumulate brightness
- works naturally with glow-heavy visual style

Other blend modes exist (`Normal`, `Subtractive`, `Multiply`) but are not the current default path.

## Soft-Clipping Strategy

To avoid hard whiteout and abrupt clipping, effect curves use smooth saturation.

Primary tools:
- `Math.tanh(...)` for smooth nonlinear compression
- explicit runtime caps from `VisualizerPolicy`

Typical pattern:

```text
output = base + tanh(input * gain) * range
```

Benefits:
- responsive at low-to-mid levels
- stable at high-energy spikes
- fewer harsh transitions than hard clamp-only shaping

## References

- [EffectComposer](https://threejs.org/docs/#examples/en/postprocessing/EffectComposer)
- [UnrealBloomPass Example](https://threejs.org/examples/#webgl_postprocessing_unreal_bloom)
- [MeshStandardMaterial](https://threejs.org/docs/#api/en/materials/MeshStandardMaterial)
- [PointsMaterial](https://threejs.org/docs/#api/en/materials/PointsMaterial)
- [Material Blending Constants](https://threejs.org/docs/#api/en/constants/Materials)
