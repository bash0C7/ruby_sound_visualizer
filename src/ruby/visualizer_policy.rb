# Centralized policy module for visualizer behavior, constraints, and configuration.
# Includes audio analysis constants, rendering policies (brightness/lightness caps),
# and runtime-mutable settings. Replaces the former Config module with broader scope.
module VisualizerPolicy
  # Audio Analysis
  SAMPLE_RATE = 48000
  FFT_SIZE = 2048
  HISTORY_SIZE = 43  # ~2 seconds of history (assuming ~21fps)

  BASELINE_RATE = 0.02       # Baseline tracking speed (slow = moving average)
  WARMUP_RATE = 0.15         # Fast tracking during warmup
  WARMUP_FRAMES = 30         # ~1 second warmup (no beat detection during calibration)

  # Beat Detection
  BEAT_BASS_DEVIATION = 0.06
  BEAT_MID_DEVIATION = 0.08
  BEAT_HIGH_DEVIATION = 0.08
  BEAT_MIN_BASS = 0.25
  BEAT_MIN_MID = 0.20
  BEAT_MIN_HIGH = 0.20

  # Smoothing
  VISUAL_SMOOTHING_FACTOR = 0.70  # Visual smoothing (smooth motion, 30% new data)
  AUDIO_SMOOTHING_FACTOR = 0.55   # Beat detection smoothing (fast response for beat感)
  IMPULSE_DECAY_AUDIO = 0.65      # Impulse decay rate in AudioAnalyzer (35% decay/frame)
  IMPULSE_DECAY_EFFECT = 0.82     # Impulse decay rate in EffectManager (18% decay/frame)
  EXPONENTIAL_THRESHOLD = 0.06    # Exponential decay threshold (noise handling)

  # Particles
  PARTICLE_COUNT = 3000
  PARTICLE_EXPLOSION_BASE_PROB = 0.20     # Base explosion probability (20%)
  PARTICLE_EXPLOSION_ENERGY_SCALE = 0.50  # Energy scale for explosion probability
  PARTICLE_EXPLOSION_FORCE_SCALE = 0.55   # Energy scale for explosion force
  PARTICLE_FRICTION = 0.86                # Friction coefficient (14% velocity loss/frame)
  PARTICLE_BOUNDARY = 10                  # Boundary distance for particle reset
  PARTICLE_SPAWN_RANGE = 5                # Spawn range for particles

  # Geometry
  GEOMETRY_BASE_SCALE = 1.0         # Base scale for geometry
  GEOMETRY_SCALE_MULTIPLIER = 2.5   # Energy scale multiplier
  GEOMETRY_MAX_EMISSIVE = 2.0       # Maximum emissive intensity

  # Bloom
  BLOOM_BASE_STRENGTH = 1.5    # Base bloom strength
  BLOOM_BASE_THRESHOLD = 0.0   # Base bloom threshold (allow all emissive to glow)
  BLOOM_MAX_STRENGTH = 1.5     # Maximum bloom strength
  BLOOM_MIN_THRESHOLD = 0.1    # Minimum bloom threshold (lower = more glow)

  # Runtime mutable config (set by URL params / keyboard / DevTool / Control Panel)
  @@sensitivity = 1.0
  @@max_brightness = 255
  @@max_lightness = 255
  @@max_emissive = 2.0
  @@max_bloom = 4.5
  @@exclude_max = false  # When true, bypass all max caps

  # Audio-reactive mutable parameters (adjustable via Control Panel / VJ Pad)
  @@bloom_base_strength = BLOOM_BASE_STRENGTH
  @@bloom_energy_scale = 2.5
  @@bloom_impulse_scale = 1.5
  @@particle_explosion_base_prob = PARTICLE_EXPLOSION_BASE_PROB
  @@particle_explosion_energy_scale = PARTICLE_EXPLOSION_ENERGY_SCALE
  @@particle_explosion_force_scale = PARTICLE_EXPLOSION_FORCE_SCALE
  @@particle_friction = PARTICLE_FRICTION
  @@visual_smoothing = VISUAL_SMOOTHING_FACTOR
  @@impulse_decay = IMPULSE_DECAY_EFFECT

  def self.sensitivity
    @@sensitivity
  end

  def self.sensitivity=(v)
    @@sensitivity = [v, 0.05].max
  end

  def self.max_brightness
    @@max_brightness
  end

  def self.max_brightness=(v)
    @@max_brightness = [[v, 0].max, 255].min
  end

  def self.max_lightness
    @@max_lightness
  end

  def self.max_lightness=(v)
    @@max_lightness = [[v, 0].max, 255].min
  end

  def self.max_emissive
    @@max_emissive
  end

  def self.max_emissive=(v)
    @@max_emissive = [v, 0.0].max
  end

  def self.max_bloom
    @@max_bloom
  end

  def self.max_bloom=(v)
    @@max_bloom = [v, 0.0].max
  end

  def self.exclude_max
    @@exclude_max
  end

  def self.exclude_max=(v)
    @@exclude_max = !!v  # Convert to boolean
  end

  # === Audio-reactive mutable parameter accessors ===

  def self.bloom_base_strength; @@bloom_base_strength; end
  def self.bloom_base_strength=(v); @@bloom_base_strength = [v.to_f, 0.0].max; end

  def self.bloom_energy_scale; @@bloom_energy_scale; end
  def self.bloom_energy_scale=(v); @@bloom_energy_scale = [v.to_f, 0.0].max; end

  def self.bloom_impulse_scale; @@bloom_impulse_scale; end
  def self.bloom_impulse_scale=(v); @@bloom_impulse_scale = [v.to_f, 0.0].max; end

  def self.particle_explosion_base_prob; @@particle_explosion_base_prob; end
  def self.particle_explosion_base_prob=(v); @@particle_explosion_base_prob = [[v.to_f, 0.0].max, 1.0].min; end

  def self.particle_explosion_energy_scale; @@particle_explosion_energy_scale; end
  def self.particle_explosion_energy_scale=(v); @@particle_explosion_energy_scale = [v.to_f, 0.0].max; end

  def self.particle_explosion_force_scale; @@particle_explosion_force_scale; end
  def self.particle_explosion_force_scale=(v); @@particle_explosion_force_scale = [v.to_f, 0.0].max; end

  def self.particle_friction; @@particle_friction; end
  def self.particle_friction=(v); @@particle_friction = [[v.to_f, 0.50].max, 0.99].min; end

  def self.visual_smoothing; @@visual_smoothing; end
  def self.visual_smoothing=(v); @@visual_smoothing = [[v.to_f, 0.0].max, 0.99].min; end

  def self.impulse_decay; @@impulse_decay; end
  def self.impulse_decay=(v); @@impulse_decay = [[v.to_f, 0.50].max, 0.99].min; end

  # === Rendering Policy Cap Methods ===
  # Centralized capping to prevent configuration oversights

  def self.cap_rgb(r, g, b)
    return [r, g, b] if @@exclude_max
    max_c = @@max_brightness / 255.0
    [[r, max_c].min, [g, max_c].min, [b, max_c].min]
  end

  def self.cap_value(v)
    return v if @@exclude_max
    max_v = @@max_lightness / 255.0
    [v, max_v].min
  end

  def self.cap_emissive(intensity)
    return intensity if @@exclude_max
    [intensity, @@max_emissive].min
  end

  def self.cap_bloom(strength)
    return strength if @@exclude_max
    [strength, @@max_bloom].min
  end

  # === DevTool Console Interface ===
  # Allows dynamic config changes from Chrome DevTools via rubyVisualizerPolicy.set/get/list/reset

  MUTABLE_KEYS = {
    'sensitivity' => { min: 0.05, max: 10.0, type: :float, default: 1.0, group: 'Master', step: 0.05 },
    'bloom_base_strength' => { min: 0.0, max: 5.0, type: :float, default: 1.5, group: 'Bloom', step: 0.1 },
    'max_bloom' => { min: 0.0, max: 10.0, type: :float, default: 4.5, group: 'Bloom', step: 0.1 },
    'bloom_energy_scale' => { min: 0.0, max: 5.0, type: :float, default: 2.5, group: 'Bloom', step: 0.1 },
    'bloom_impulse_scale' => { min: 0.0, max: 3.0, type: :float, default: 1.5, group: 'Bloom', step: 0.1 },
    'particle_explosion_base_prob' => { min: 0.0, max: 1.0, type: :float, default: 0.20, group: 'Particles', step: 0.01 },
    'particle_explosion_energy_scale' => { min: 0.0, max: 2.0, type: :float, default: 0.50, group: 'Particles', step: 0.01 },
    'particle_explosion_force_scale' => { min: 0.0, max: 2.0, type: :float, default: 0.55, group: 'Particles', step: 0.01 },
    'particle_friction' => { min: 0.50, max: 0.99, type: :float, default: 0.86, group: 'Particles', step: 0.01 },
    'max_brightness' => { min: 0, max: 255, type: :int, default: 255, group: 'Rendering', step: 1 },
    'max_lightness' => { min: 0, max: 255, type: :int, default: 255, group: 'Rendering', step: 1 },
    'max_emissive' => { min: 0.0, max: 10.0, type: :float, default: 2.0, group: 'Rendering', step: 0.1 },
    'visual_smoothing' => { min: 0.0, max: 0.99, type: :float, default: 0.70, group: 'Audio', step: 0.01 },
    'impulse_decay' => { min: 0.50, max: 0.99, type: :float, default: 0.82, group: 'Audio', step: 0.01 },
    'exclude_max' => { min: 0, max: 1, type: :bool, default: false, group: 'Master', step: 1 }
  }.freeze

  def self.set_by_key(key, value)
    key_str = key.to_s
    spec = MUTABLE_KEYS[key_str]
    return "Unknown key: #{key_str}. Use list() to see available keys." unless spec

    val = case spec[:type]
    when :int then value.to_i
    when :bool then value.to_s == 'true' || value.to_i == 1
    else value.to_f
    end

    val = [[val, spec[:min]].max, spec[:max]].min unless spec[:type] == :bool

    case key_str
    when 'sensitivity' then self.sensitivity = val
    when 'max_brightness' then self.max_brightness = val
    when 'max_lightness' then self.max_lightness = val
    when 'max_emissive' then self.max_emissive = val
    when 'max_bloom' then self.max_bloom = val
    when 'exclude_max' then self.exclude_max = val
    when 'bloom_base_strength' then self.bloom_base_strength = val
    when 'bloom_energy_scale' then self.bloom_energy_scale = val
    when 'bloom_impulse_scale' then self.bloom_impulse_scale = val
    when 'particle_explosion_base_prob' then self.particle_explosion_base_prob = val
    when 'particle_explosion_energy_scale' then self.particle_explosion_energy_scale = val
    when 'particle_explosion_force_scale' then self.particle_explosion_force_scale = val
    when 'particle_friction' then self.particle_friction = val
    when 'visual_smoothing' then self.visual_smoothing = val
    when 'impulse_decay' then self.impulse_decay = val
    end

    "#{key_str} = #{val}"
  end

  def self.get_by_key(key)
    case key.to_s
    when 'sensitivity' then sensitivity
    when 'max_brightness' then max_brightness
    when 'max_lightness' then max_lightness
    when 'max_emissive' then max_emissive
    when 'max_bloom' then max_bloom
    when 'exclude_max' then exclude_max
    when 'bloom_base_strength' then bloom_base_strength
    when 'bloom_energy_scale' then bloom_energy_scale
    when 'bloom_impulse_scale' then bloom_impulse_scale
    when 'particle_explosion_base_prob' then particle_explosion_base_prob
    when 'particle_explosion_energy_scale' then particle_explosion_energy_scale
    when 'particle_explosion_force_scale' then particle_explosion_force_scale
    when 'particle_friction' then particle_friction
    when 'visual_smoothing' then visual_smoothing
    when 'impulse_decay' then impulse_decay
    else "Unknown key: #{key}"
    end
  end

  def self.list_keys
    MUTABLE_KEYS.map { |k, spec|
      current = get_by_key(k)
      "#{k}: #{current} (#{spec[:min]}..#{spec[:max]})"
    }.join("\n")
  end

  def self.reset_runtime
    self.sensitivity = 1.0
    self.max_brightness = 255
    self.max_lightness = 255
    self.max_emissive = 2.0
    self.max_bloom = 4.5
    self.exclude_max = false
    self.bloom_base_strength = BLOOM_BASE_STRENGTH
    self.bloom_energy_scale = 2.5
    self.bloom_impulse_scale = 1.5
    self.particle_explosion_base_prob = PARTICLE_EXPLOSION_BASE_PROB
    self.particle_explosion_energy_scale = PARTICLE_EXPLOSION_ENERGY_SCALE
    self.particle_explosion_force_scale = PARTICLE_EXPLOSION_FORCE_SCALE
    self.particle_friction = PARTICLE_FRICTION
    self.visual_smoothing = VISUAL_SMOOTHING_FACTOR
    self.impulse_decay = IMPULSE_DECAY_EFFECT
    "All runtime values reset to defaults"
  end

  def self.register_devtool_callbacks
    JS.global[:rubyConfigSet] = lambda { |key, value|
      begin
        result = VisualizerPolicy.set_by_key(key.to_s, value.to_f)
        JS.global[:console].log("[VisualizerPolicy] #{result}")
        result
      rescue => e
        JS.global[:console].error("[VisualizerPolicy] Error: #{e.message}")
      end
    }
    JS.global[:rubyConfigGet] = lambda { |key|
      VisualizerPolicy.get_by_key(key.to_s)
    }
    JS.global[:rubyConfigList] = lambda {
      result = VisualizerPolicy.list_keys
      JS.global[:console].log("[VisualizerPolicy]\n#{result}")
      result
    }
    JS.global[:rubyConfigReset] = lambda {
      result = VisualizerPolicy.reset_runtime
      JS.global[:console].log("[VisualizerPolicy] #{result}")
      result
    }
  end
end
