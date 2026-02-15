# 3D Programming and Shader Glossary

Glossary of 3D, rendering, and shader terms relevant to this project.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Geometry and Mesh](#geometry-and-mesh)
3. [Materials and Textures](#materials-and-textures)
4. [Lighting and Shading](#lighting-and-shading)
5. [Shaders](#shaders)
6. [Rendering Pipeline](#rendering-pipeline)
7. [Post-Processing](#post-processing)
8. [Color and Color Space](#color-and-color-space)
9. [Animation and Motion](#animation-and-motion)
10. [Performance Terms](#performance-terms)

## Core Concepts

### Scene Graph
A tree of renderable and non-renderable nodes. Parent transforms affect children.

### Coordinate System
Three.js uses a right-handed system: +X right, +Y up, +Z toward viewer.

### World Space / Local Space
- World space: final position in the scene
- Local space: position relative to parent node

### Transform
Position, rotation, and scale of an object.

### Euler Angles
Rotation represented by X/Y/Z angles. Easy to read, can hit gimbal lock.

### Quaternion
Rotation represented with four values (x, y, z, w). Better for stable interpolation.

### Gimbal Lock
Loss of rotational freedom when axes align. Common with Euler angle camera controls.

### Radian
Rotation unit used in Three.js (`Math.PI` based values).

## Geometry and Mesh

### Vertex
A point in 3D space. May include attributes such as color, normal, and UV.

### Triangle / Polygon
GPU primitives are triangles. Complex surfaces are built from many triangles.

### Geometry
Structured vertex/index data. In modern Three.js, typically `BufferGeometry`.

### Mesh
`Geometry + Material` combination for drawable 3D surfaces.

### Wireframe
Render only edges, not filled faces.

### BufferGeometry
Efficient GPU-oriented geometry representation using typed arrays.

### Attribute
Per-vertex array data bound to geometry, such as `position` and `color`.

### Segment Count
Subdivision density in generated geometry. Higher segments improve smoothness but cost more GPU work.

### Torus
Ring-shaped primitive used as the main mesh in this project.

## Materials and Textures

### Material
Defines visual surface behavior: color, transparency, reflectance, emission.

### PBR
Physically based rendering model (`MeshStandardMaterial`) with metalness/roughness.

### Metalness
How metallic the surface appears (`0.0` dielectric, `1.0` metallic).

### Roughness
Micro-surface roughness (`0.0` mirror-like, `1.0` diffuse).

### Emissive / Emissive Intensity
Self-illumination channel. Important for bloom response in this app.

### Opacity and Transparency
`opacity` requires `transparent: true` for blending behavior.

### Texture
Image-based input for material channels (color, normal, emissive, etc.).

## Lighting and Shading

### Ambient Light
Uniform scene-wide light contribution.

### Directional Light
Infinite-distance light with a direction (sun-like behavior).

### Point Light
Light emitted from a position with distance attenuation.

### Diffuse Reflection
Light scattered by surface orientation relative to the light direction.

### Specular Reflection
View-dependent highlight from reflective response.

### Shading
How per-pixel/per-vertex lighting is computed.

## Shaders

### Shader
GPU program stage used to transform geometry and color pixels.

### GLSL
Shader language used in WebGL.

### Vertex Shader
Processes each vertex and outputs clip-space position.

### Fragment Shader
Processes each fragment (pixel candidate) and outputs final color.

### Uniform
Global shader input shared across many vertices/fragments.

### Varying
Interpolated value from vertex shader to fragment shader.

### ShaderMaterial
Three.js material for custom GLSL pipelines.

## Rendering Pipeline

### Pipeline Stages
Typical flow:
1. Vertex fetch and transform
2. Primitive assembly
3. Rasterization
4. Fragment shading
5. Framebuffer write

### Framebuffer
Render target memory. May be on-screen or off-screen.

### Depth Buffer
Per-pixel depth storage used for occlusion.

### Draw Call
Single GPU submission for a renderable object/material state.

## Post-Processing

### Post-Processing
Image-space effects applied after primary scene render.

### EffectComposer
Chains multiple render passes in sequence.

### RenderPass
Initial scene render pass.

### UnrealBloomPass
Glow pass for bright regions.

### OutputPass
Final output and tone-mapping stage.

### Tone Mapping
Maps HDR-like intensity range into displayable output.

## Color and Color Space

### RGB
Additive color space used for direct pixel output.

### HSV/HSL
Perceptual color representations useful for dynamic palette logic.

### Hue
Color angle on a wheel (0-360 degrees).

### Saturation
Color purity/intensity.

### Value / Lightness
Brightness-style channel used for luminance control.

### Clamping
Limiting values into a safe range to prevent clipping or visual blowout.

## Animation and Motion

### Delta Time
Elapsed time between frames, used for frame-rate-independent movement.

### Interpolation (Lerp)
Smooth transition from current value to target value.

### Smoothing
Reducing jitter by low-pass behavior across frames.

### Impulse
Short-lived high-energy spike used for beat-reactive effects.

### Decay
Gradual reduction after an impulse to avoid abrupt drop-offs.

## Performance Terms

### FPS
Frames per second; measured and shown by Ruby-side `FrameCounter`.

### CPU-bound
Performance limited by JavaScript/Ruby processing cost.

### GPU-bound
Performance limited by rendering workload.

### Fill Rate
How many pixels can be shaded per frame.

### Overdraw
Multiple fragments rendered for the same screen pixel.

### Culling
Skipping non-visible geometry to reduce draw cost.

### Batching
Reducing draw calls by grouping compatible geometry/material state.

### Memory Bandwidth
Cost of moving large typed arrays each frame (important for particle updates).
