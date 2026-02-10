# Plan: Centralize Default Configuration Values

## Goal

Extract all scattered default values and magic numbers into a single shared configuration object, so each class focuses on behavior only.

## Current State

Default values and constants are scattered across multiple files:

### Global variables (`src/ruby/main.rb`)
- `$sensitivity = 1.0` (line 9)
- `$max_brightness = 255` (line 10)
- `$max_lightness = 255` (line 11)

### Class-level constants
- `ParticleSystem::PARTICLE_COUNT = 3000` (particle_system.rb:2)
- `AudioAnalyzer::SAMPLE_RATE = 48000` (audio_analyzer.rb:2)
- `AudioAnalyzer::FFT_SIZE = 2048` (audio_analyzer.rb:3)
- `AudioAnalyzer::HISTORY_SIZE = 43` (audio_analyzer.rb:4)
- `AudioAnalyzer::BASELINE_RATE = 0.02` (audio_analyzer.rb:6)
- `AudioAnalyzer::WARMUP_RATE = 0.15` (audio_analyzer.rb:7)
- `AudioAnalyzer::WARMUP_FRAMES = 30` (audio_analyzer.rb:8)
- `AudioAnalyzer::BEAT_*_DEVIATION` (audio_analyzer.rb:11-13)
- `AudioAnalyzer::BEAT_MIN_*` (audio_analyzer.rb:15-17)
- `AudioAnalyzer::VISUAL_SMOOTHING_FACTOR = 0.70` (audio_analyzer.rb:20)
- `AudioAnalyzer::IMPULSE_DECAY = 0.65` (audio_analyzer.rb:21)
- `AudioAnalyzer::EXPONENTIAL_THRESHOLD = 0.06` (audio_analyzer.rb:22)
- `EffectManager::IMPULSE_DECAY = 0.82` (effect_manager.rb:2)
- `BloomController` base values: `strength=1.5, threshold=0.0` (bloom_controller.rb:3-4)
- `GeometryMorpher` base scale: `1.0` (geometry_morpher.rb:4)

### Hardcoded magic numbers in formulas
- Particle explosion probability: `0.20 + energy * 0.50` (particle_system.rb:35)
- Particle explosion force: `energy * 0.55` (particle_system.rb:37)
- Particle friction: `0.86` (particle_system.rb:98)
- Particle boundary: `10` (particle_system.rb:104)
- Geometry scale multiplier: `2.5` (geometry_morpher.rb:27)
- Various rotation speed multipliers (geometry_morpher.rb:32-34)

### JavaScript-side constants
- `particleCount = 3000` (index.html)
- `bloomPass` initial values (index.html)

## Target Design

### Config module (`src/ruby/config.rb`)

```ruby
module Config
  # Audio Analysis
  SAMPLE_RATE = 48000
  FFT_SIZE = 2048
  HISTORY_SIZE = 43
  BASELINE_RATE = 0.02
  WARMUP_RATE = 0.15
  WARMUP_FRAMES = 30

  # Beat Detection
  BEAT_BASS_DEVIATION = 0.06
  BEAT_MID_DEVIATION = 0.08
  BEAT_HIGH_DEVIATION = 0.08
  BEAT_MIN_BASS = 0.25
  BEAT_MIN_MID = 0.20
  BEAT_MIN_HIGH = 0.20

  # Smoothing
  VISUAL_SMOOTHING_FACTOR = 0.70
  AUDIO_SMOOTHING_FACTOR = 0.55
  IMPULSE_DECAY_AUDIO = 0.65
  IMPULSE_DECAY_EFFECT = 0.82
  EXPONENTIAL_THRESHOLD = 0.06

  # Particles
  PARTICLE_COUNT = 3000
  PARTICLE_EXPLOSION_BASE_PROB = 0.20
  PARTICLE_EXPLOSION_ENERGY_SCALE = 0.50
  PARTICLE_EXPLOSION_FORCE_SCALE = 0.55
  PARTICLE_FRICTION = 0.86
  PARTICLE_BOUNDARY = 10
  PARTICLE_SPAWN_RANGE = 5

  # Geometry
  GEOMETRY_BASE_SCALE = 1.0
  GEOMETRY_SCALE_MULTIPLIER = 2.5
  GEOMETRY_MAX_EMISSIVE = 2.0

  # Bloom
  BLOOM_BASE_STRENGTH = 1.5
  BLOOM_BASE_THRESHOLD = 0.0
  BLOOM_MAX_STRENGTH = 4.5

  # Runtime (mutable, set by URL params / keyboard)
  @@sensitivity = 1.0
  @@max_brightness = 255
  @@max_lightness = 255

  def self.sensitivity; @@sensitivity; end
  def self.sensitivity=(v); @@sensitivity = [v, 0.05].max; end
  def self.max_brightness; @@max_brightness; end
  def self.max_brightness=(v); @@max_brightness = [[v, 0].max, 255].min; end
  def self.max_lightness; @@max_lightness; end
  def self.max_lightness=(v); @@max_lightness = [[v, 0].max, 255].min; end

  # Load from URL parameters
  def self.load_from_url; ... end
end
```

### Migration Strategy

Phase 1 (this task):
- Create `Config` module with all constants
- Each class references `Config::CONSTANT` instead of its own constants
- Remove global variables, use `Config.sensitivity` etc.

Phase 2 (future / combine with brightness-control-layer):
- Add BrightnessPolicy logic into Config or as a submodule

## Changes Required

### 1. New file: `src/ruby/config.rb`
- Define all constants and runtime config accessors
- Add to `index.html` `<script type="text/ruby" src=...>` list (first in load order, requires user approval)

### 2. `src/ruby/audio_analyzer.rb`
- Replace all local constants with `Config::` references

### 3. `src/ruby/particle_system.rb`
- Replace `PARTICLE_COUNT` and magic numbers with `Config::` references

### 4. `src/ruby/geometry_morpher.rb`
- Replace magic numbers with `Config::` references

### 5. `src/ruby/bloom_controller.rb`
- Replace base values with `Config::` references

### 6. `src/ruby/effect_manager.rb`
- Replace `IMPULSE_DECAY` with `Config::IMPULSE_DECAY_EFFECT`

### 7. `src/ruby/main.rb`
- Remove global variables (`$sensitivity`, `$max_brightness`, `$max_lightness`)
- Use `Config.sensitivity`, `Config.max_brightness`, `Config.max_lightness`
- Move URL parameter parsing to `Config.load_from_url`

## TDD Approach

1. Write tests verifying current constant values match expected defaults
2. Create `Config` module
3. Migrate one class at a time, running tests after each
4. Verify all keyboard controls and URL parameters still work

## Estimated Scope

- Files: New `config.rb`, plus 6 existing files modified
- Risk: Medium (many files touched, but changes are mechanical constant replacements)
- Note: Consider implementing together with brightness-control-layer task
