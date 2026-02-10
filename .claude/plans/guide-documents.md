# Plan: Create Guide Documents

## Goal

Create reference guides for development and contribution to this project.

## Documents to Create

### 1. Shader Operations Guide (`.claude/guides/shader-operations.md`)

Content outline:
- Three.js post-processing pipeline overview (EffectComposer, RenderPass, UnrealBloomPass)
- How bloom parameters map to visual effects (strength, radius, threshold)
- BloomController Ruby class and its interaction with JS
- How to add new post-processing passes
- Parameter tuning tips

Source files for reference:
- `src/ruby/bloom_controller.rb` - Ruby bloom logic
- `index.html` Three.js setup section (EffectComposer initialization)

### 2. 3D Basics Guide (`.claude/guides/3d-basics.md`)

Content outline:
- Three.js scene, camera, renderer setup
- Coordinate system and units
- Particle system (BufferGeometry with position/color attributes)
- Torus geometry morphing (scale, rotation)
- Camera control with spherical coordinates
- Layers system for selective bloom

Source files for reference:
- `src/ruby/particle_system.rb`, `src/ruby/geometry_morpher.rb`, `src/ruby/camera_controller.rb`
- `index.html` Three.js initialization section

### 3. VRM Guide (`.claude/guides/vrm-guide.md`)

Content outline:
- VRM file format overview
- @pixiv/three-vrm integration
- Bone structure and VRM_BONE_ORDER mapping
- VRMDancer: audio-reactive dance animation
- VRMMaterialController: emissive material control
- VRM upload flow (loading screen)

Source files for reference:
- `src/ruby/vrm_dancer.rb`, `src/ruby/vrm_material_controller.rb`
- `index.html` VRM loading section

### 4. JavaScript-ruby.wasm Integration Guide (`.claude/guides/js-ruby-interop.md`)

Content outline:
- Data flow overview (JS Audio API -> Ruby analysis -> JS rendering)
- Ruby -> JS calling patterns (method_missing pattern)
- JS -> Ruby callback registration (lambda)
- JSBridge module as the communication layer
- Type conversion gotchas (JS::Object, .to_s, .to_a)
- Consolidation of existing `.claude/RUBY-WASM.md` content

Source files for reference:
- `src/ruby/js_bridge.rb`, `.claude/RUBY-WASM.md`

### 5. ruby.wasm Technical Guide (`.claude/guides/ruby-wasm-technical.md`)

Content outline:
- @ruby/4.0-wasm-wasi architecture
- browser.script.iife.js loading mechanism
- `<script type="text/ruby">` tag processing
- Memory and performance characteristics
- Known bugs and workarounds (JS::Object#call, BasicObject inheritance)
- Debugging techniques

Source files for reference:
- `.claude/RUBY-WASM.md`, `index.html` script loading section

## Approach

- Create each document as standalone markdown
- All content in English (per language policy)
- Fact-based, reference existing code with file paths and line numbers
- Cross-reference between guides where relevant

## File Structure

```
.claude/guides/
  shader-operations.md
  3d-basics.md
  vrm-guide.md
  js-ruby-interop.md
  ruby-wasm-technical.md
```
