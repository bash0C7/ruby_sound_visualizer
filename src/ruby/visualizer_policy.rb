module VisualizerPolicy
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
  BLOOM_MAX_STRENGTH = 1.5
  BLOOM_MIN_THRESHOLD = 0.1

  # Runtime-mutable parameter definitions: drives accessor generation,
  # reset_runtime, set_by_key, and get_by_key via metaprogramming.
  RUNTIME_PARAMS = {
    sensitivity:                     { default: 1.0,                          type: :float, min: 0.1,   max: 1.9  },
    input_gain:                      { default: 0.0,                          type: :float, min: -20.0, max: 20.0 },
    max_brightness:                  { default: 255,                          type: :int,   min: 0,     max: 255  },
    max_lightness:                   { default: 255,                          type: :int,   min: 0,     max: 255  },
    max_saturation:                  { default: 100,                          type: :int,   min: 0,     max: 100  },
    max_emissive:                    { default: 2.0,                          type: :float, min: 0.0              },
    max_bloom:                       { default: 4.5,                          type: :float, min: 0.0              },
    exclude_max:                     { default: false,                        type: :bool                         },
    bloom_base_strength:             { default: BLOOM_BASE_STRENGTH,          type: :float, min: 0.0              },
    bloom_energy_scale:              { default: 2.5,                          type: :float, min: 0.0              },
    bloom_impulse_scale:             { default: 1.5,                          type: :float, min: 0.0              },
    particle_explosion_base_prob:    { default: PARTICLE_EXPLOSION_BASE_PROB, type: :float, min: 0.0,  max: 1.0  },
    particle_explosion_energy_scale: { default: PARTICLE_EXPLOSION_ENERGY_SCALE, type: :float, min: 0.0           },
    particle_explosion_force_scale:  { default: PARTICLE_EXPLOSION_FORCE_SCALE,  type: :float, min: 0.0           },
    particle_friction:               { default: PARTICLE_FRICTION,            type: :float, min: 0.50, max: 0.99 },
    visual_smoothing:                { default: VISUAL_SMOOTHING_FACTOR,      type: :float, min: 0.0,  max: 0.99 },
    impulse_decay:                   { default: IMPULSE_DECAY_EFFECT,         type: :float, min: 0.50, max: 0.99 },
  }.freeze

  # Auto-generate class variables, getters, and clamped setters
  RUNTIME_PARAMS.each do |name, spec|
    class_variable_set(:"@@#{name}", spec[:default])

    define_singleton_method(name) { class_variable_get(:"@@#{name}") }

    define_singleton_method(:"#{name}=") do |v|
      val = case spec[:type]
            when :int then v.to_i
            when :bool then !!v
            else v.to_f
            end
      unless spec[:type] == :bool
        val = [val, spec[:min]].max if spec[:min]
        val = [val, spec[:max]].min if spec[:max]
      end
      class_variable_set(:"@@#{name}", val)
    end
  end

  def self.input_gain_linear
    10.0 ** (@@input_gain / 20.0)
  end

  # === Rendering Policy Cap Methods ===

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

  def self.cap_saturation(sat)
    sat * (@@max_saturation / 100.0)
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
  # Slider ranges are designed so that default = center position:
  #   min --|-- default --|-- max  (symmetric around default)

  MUTABLE_KEYS = {
    'sensitivity' => { min: 0.1, max: 1.9, type: :float, default: 1.0, group: 'Master', step: 0.05 },
    'input_gain' => { min: -20.0, max: 20.0, type: :float, default: 0.0, group: 'Master', step: 0.5 },
    'bloom_base_strength' => { min: 0.0, max: 3.0, type: :float, default: 1.5, group: 'Bloom', step: 0.1 },
    'max_bloom' => { min: 0.0, max: 9.0, type: :float, default: 4.5, group: 'Bloom', step: 0.1 },
    'bloom_energy_scale' => { min: 0.0, max: 5.0, type: :float, default: 2.5, group: 'Bloom', step: 0.1 },
    'bloom_impulse_scale' => { min: 0.0, max: 3.0, type: :float, default: 1.5, group: 'Bloom', step: 0.1 },
    'particle_explosion_base_prob' => { min: 0.0, max: 0.40, type: :float, default: 0.20, group: 'Particles', step: 0.01 },
    'particle_explosion_energy_scale' => { min: 0.0, max: 1.0, type: :float, default: 0.50, group: 'Particles', step: 0.01 },
    'particle_explosion_force_scale' => { min: 0.0, max: 1.10, type: :float, default: 0.55, group: 'Particles', step: 0.01 },
    'particle_friction' => { min: 0.73, max: 0.99, type: :float, default: 0.86, group: 'Particles', step: 0.01 },
    'max_brightness' => { min: 0, max: 255, type: :int, default: 255, group: 'Rendering', step: 1 },
    'max_lightness' => { min: 0, max: 255, type: :int, default: 255, group: 'Rendering', step: 1 },
    'max_saturation' => { min: 0, max: 100, type: :int, default: 100, group: 'Color', step: 1 },
    'max_emissive' => { min: 0.0, max: 4.0, type: :float, default: 2.0, group: 'Rendering', step: 0.1 },
    'visual_smoothing' => { min: 0.41, max: 0.99, type: :float, default: 0.70, group: 'Audio', step: 0.01 },
    'impulse_decay' => { min: 0.65, max: 0.99, type: :float, default: 0.82, group: 'Audio', step: 0.01 },
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

    send(:"#{key_str}=", val)
    "#{key_str} = #{val}"
  end

  def self.get_by_key(key)
    key_str = key.to_s
    return "Unknown key: #{key}" unless MUTABLE_KEYS.key?(key_str)
    send(key_str.to_sym)
  end

  def self.list_keys
    MUTABLE_KEYS.map { |k, spec|
      current = get_by_key(k)
      "#{k}: #{current} (#{spec[:min]}..#{spec[:max]})"
    }.join("\n")
  end

  def self.reset_runtime
    RUNTIME_PARAMS.each { |name, spec| send(:"#{name}=", spec[:default]) }
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
