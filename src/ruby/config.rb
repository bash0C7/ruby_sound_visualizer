# Centralized configuration for all default values and constants.
# Each class references Config:: constants instead of defining their own.
# This makes it easier to adjust parameters and understand the system behavior.
module Config
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

  # Runtime mutable config (set by URL params / keyboard / DevTool)
  @@sensitivity = 1.0
  @@max_brightness = 255
  @@max_lightness = 255

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

  # === DevTool Console Interface ===
  # Allows dynamic config changes from Chrome DevTools via rubyConfig.set/get/list/reset

  MUTABLE_KEYS = {
    'sensitivity' => { min: 0.05, max: 10.0, type: :float, default: 1.0 },
    'max_brightness' => { min: 0, max: 255, type: :int, default: 255 },
    'max_lightness' => { min: 0, max: 255, type: :int, default: 255 }
  }.freeze

  def self.set_by_key(key, value)
    key_str = key.to_s
    spec = MUTABLE_KEYS[key_str]
    return "Unknown key: #{key_str}. Use list() to see available keys." unless spec

    val = spec[:type] == :int ? value.to_i : value.to_f
    val = [[val, spec[:min]].max, spec[:max]].min

    case key_str
    when 'sensitivity' then self.sensitivity = val
    when 'max_brightness' then self.max_brightness = val
    when 'max_lightness' then self.max_lightness = val
    end

    "#{key_str} = #{val}"
  end

  def self.get_by_key(key)
    case key.to_s
    when 'sensitivity' then sensitivity
    when 'max_brightness' then max_brightness
    when 'max_lightness' then max_lightness
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
    "All runtime values reset to defaults"
  end

  def self.register_devtool_callbacks
    JS.global[:rubyConfigSet] = lambda { |key, value|
      begin
        result = Config.set_by_key(key.to_s, value.to_f)
        JS.global[:console].log("[Config] #{result}")
        result
      rescue => e
        JS.global[:console].error("[Config] Error: #{e.message}")
      end
    }
    JS.global[:rubyConfigGet] = lambda { |key|
      Config.get_by_key(key.to_s)
    }
    JS.global[:rubyConfigList] = lambda {
      result = Config.list_keys
      JS.global[:console].log("[Config]\n#{result}")
      result
    }
    JS.global[:rubyConfigReset] = lambda {
      result = Config.reset_runtime
      JS.global[:console].log("[Config] #{result}")
      result
    }
  end
end
