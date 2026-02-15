# 3D Basics Guide

Core Three.js concepts used in this project, with implementation notes tied to the current codebase.

## Table of Contents

1. [Scene Graph](#scene-graph)
2. [Camera](#camera)
3. [Geometry and Mesh](#geometry-and-mesh)
4. [Particle System](#particle-system)
5. [Lighting](#lighting)
6. [Animation Loop](#animation-loop)
7. [Coordinate System and Transform](#coordinate-system-and-transform)
8. [Performance Optimization](#performance-optimization)
9. [References](#references)

## Scene Graph

Three.js uses a tree structure rooted at `Scene`.

Current runtime layout:

```text
Scene
  |- PerspectiveCamera
  |- Points (particle system)
  |- Mesh (wireframe torus)
  |- VRM scene (optional, loaded at runtime)
  |- DirectionalLight + AmbientLight (added only when VRM is loaded)
```

Project notes:
- `camera.layers.enableAll()` is used.
- `BLOOM_LAYER` exists, but explicit layer assignment for torus/particles is currently disabled.
- Rendering is done through `EffectComposer` rather than direct `renderer.render(...)`.

## Camera

### Perspective Camera

The app uses:

```javascript
camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000)
```

### Spherical Orbit Control

Camera orbit uses spherical coordinates around `cameraTarget`:

```text
x = radius * cos(phi) * sin(theta)
y = radius * sin(phi)
z = radius * cos(phi) * cos(theta)
```

This is applied in `updateCameraPosition()`.

### Keyboard Controls

- Orbit: `d` / `f` (left/right), `e` / `c` (up/down)
- Position offset: `a` / `s` / `w` / `x` / `q` / `z`

`phi` is clamped near +/-90 degrees to avoid gimbal lock behavior.

### Control Panel Camera Sliders

The control panel exposes:
- `camera_radius`
- `camera_theta`
- `camera_phi`

Those sliders update the same spherical camera state and are included in URL snapshots.

## Geometry and Mesh

### Torus Mesh

The main mesh is a wireframe torus:

```javascript
new THREE.TorusGeometry(1, 0.4, 12, 16)
```

Material highlights:
- `MeshStandardMaterial`
- `wireframe: true`
- `transparent: true`
- `emissive: 0xffffff`
- runtime `color` and `emissiveIntensity` updates from Ruby

Ruby-side geometry data is produced by `GeometryMorpher` and applied through `window.updateGeometry(...)`.

## Particle System

### Data Layout

Particles are represented as a `THREE.Points` object with:
- `position` attribute (`Float32Array`)
- `color` attribute (`Float32Array`)

Count is fixed to 3000 (aligned with `VisualizerPolicy::PARTICLE_COUNT`).

### Material

`PointsMaterial` configuration:
- `vertexColors: true`
- `transparent: true`
- `opacity` updated at runtime
- `blending: THREE.AdditiveBlending`

### Runtime Updates

Ruby computes particle state in `ParticleSystem`, then JS applies it via:
- `window.updateParticles(positions, colors, avgSize, avgOpacity)`

Both attributes set `needsUpdate = true` every frame.

## Lighting

### Base Scene

Particles and wireframe torus do not require scene lights to remain visible.

### VRM Lighting

When a VRM is loaded, the app adds:
- `DirectionalLight`
- `AmbientLight`

This is done at load time so VRM materials remain visible without forcing lighting cost when no VRM exists.

## Animation Loop

### Main Render Loop

`animate()` performs:
1. Delta time update (`window._animDeltaTime`)
2. FFT pull from `AnalyserNode`
3. Ruby callback `window.rubyUpdateVisuals(Array.from(dataArray), now)`
4. Periodic DOM text updates (every ~15 frames)
5. `currentVRM.update(deltaTime)` for spring bones
6. `composer.render()` (normal mode only)

### Perf View Behavior

In perf view (`?perf=1`), the loop uses `setTimeout(..., 16)` instead of `requestAnimationFrame` to avoid background-tab throttling behavior.

## Coordinate System and Transform

Three.js uses a right-handed coordinate system:
- +X: right
- +Y: up
- +Z: toward the viewer

Transform operations used in the app:
- `mesh.position.set(...)`
- `mesh.rotation.set(...)`
- `mesh.scale.set(...)`

Rotation values are in radians.

## Performance Optimization

Current performance strategy in this project:
- Keep particle count moderate (3000)
- Keep torus segment count low (`12`, `16`)
- Run heavy visual math in Ruby once per frame, then push compact outputs to JS
- Throttle non-critical DOM updates (debug text)
- Skip full 3D render work in perf-view mirror mode

Practical tips:
- Close unnecessary tabs during live use
- Keep browser hardware acceleration enabled
- Avoid keeping heavy DevTools panels open during performance runs

## References

- [Three.js Documentation](https://threejs.org/docs/)
- [PerspectiveCamera](https://threejs.org/docs/#api/en/cameras/PerspectiveCamera)
- [Points](https://threejs.org/docs/#api/en/objects/Points)
- [BufferGeometry](https://threejs.org/docs/#api/en/core/BufferGeometry)
- [EffectComposer](https://threejs.org/docs/#examples/en/postprocessing/EffectComposer)
