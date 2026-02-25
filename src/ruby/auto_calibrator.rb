class AutoCalibrator
  MEASUREMENT_DURATION_FRAMES = 600  # ~10 seconds at 60fps
  TARGET_ENERGY = 0.35

  # Per-level adjustment amounts for intensity macro (-5..+5)
  INTENSITY_ADJUSTMENTS = {
    'bloom_base_strength' => 0.15,
    'bloom_energy_scale'  => 0.20,
    'bloom_impulse_scale' => 0.15,
    'max_emissive'        => 0.30,
    'particle_explosion_base_prob' => 0.03,
    'impulse_decay'       => 0.02,
  }.freeze

  # Vivid color mood presets
  MOOD_PRESETS = {
    red: {
      hue_mode: 1, hue_offset: 0.0,
      max_saturation: 100, max_brightness: 255, max_lightness: 255,
      max_emissive: 3.5, bloom_energy_scale: 2.0
    },
    yellow: {
      hue_mode: 2, hue_offset: 0.0,
      max_saturation: 100, max_brightness: 255, max_lightness: 255,
      max_emissive: 3.5, bloom_energy_scale: 2.0
    },
    green: {
      hue_mode: 2, hue_offset: 60.0,
      max_saturation: 100, max_brightness: 255, max_lightness: 255,
      max_emissive: 3.5, bloom_energy_scale: 2.0
    },
    blue: {
      hue_mode: 3, hue_offset: 60.0,
      max_saturation: 100, max_brightness: 255, max_lightness: 255,
      max_emissive: 3.5, bloom_energy_scale: 2.0
    },
    neon: {
      hue_mode: 1, hue_offset: 0.0,
      max_saturation: 100, max_brightness: 255, max_lightness: 255,
      max_emissive: 4.0, bloom_energy_scale: 3.0
    },
  }.freeze

  attr_reader :state, :progress, :baseline_params, :intensity_level

  def initialize
    @state = :idle
    @progress = 0.0
    @baseline_params = {}
    @intensity_level = 0
    @measurements = []
  end

  def start
    @state = :measuring
    @measurements = []
    @progress = 0.0
  end

  def feed(analysis)
    return unless @state == :measuring

    @measurements << {
      bass: analysis[:bass],
      mid: analysis[:mid],
      high: analysis[:high],
      overall: analysis[:overall_energy],
      beat_bass: analysis.dig(:beat, :bass) || false,
      beat_mid: analysis.dig(:beat, :mid) || false,
      beat_high: analysis.dig(:beat, :high) || false
    }

    @progress = @measurements.length.to_f / MEASUREMENT_DURATION_FRAMES

    if @measurements.length >= MEASUREMENT_DURATION_FRAMES
      @baseline_params = calculate(@measurements)
      @state = :done
    end
  end

  # Pure function: measurements array -> parameter hash (no side effects)
  def calculate(measurements)
    return {} if measurements.empty?

    avg_overall = average(measurements.map { |m| m[:overall] })
    avg_bass = average(measurements.map { |m| m[:bass] })
    avg_mid = average(measurements.map { |m| m[:mid] })
    avg_high = average(measurements.map { |m| m[:high] })
    peak_overall = measurements.map { |m| m[:overall] }.max

    # Input gain: normalize average energy to TARGET_ENERGY
    input_gain = calculate_input_gain(avg_overall)

    # Sensitivity: fine-tune based on dynamic range
    dynamic_range = peak_overall - avg_overall
    sensitivity = calculate_sensitivity(dynamic_range, avg_overall)

    # Bloom: adjust base and energy scale for the environment
    bloom_base = calculate_bloom_base(avg_overall)
    bloom_energy_scale = calculate_bloom_energy_scale(avg_overall)

    # Particles: scale based on average energy
    particle_prob = calculate_particle_prob(avg_overall)

    {
      'input_gain' => clamp_param(:input_gain, input_gain),
      'sensitivity' => clamp_param(:sensitivity, sensitivity),
      'bloom_base_strength' => clamp_param(:bloom_base_strength, bloom_base),
      'bloom_energy_scale' => clamp_param(:bloom_energy_scale, bloom_energy_scale),
      'particle_explosion_base_prob' => clamp_param(:particle_explosion_base_prob, particle_prob),
    }
  end

  def apply_baseline
    return {} unless @state == :done
    apply(@baseline_params)
    @baseline_params
  end

  def apply(params_hash)
    params_hash.each do |key, value|
      VisualizerPolicy.set_by_key(key.to_s, value)
    end
  end

  def set_intensity(level)
    level = [[-5, level].max, 5].min
    @intensity_level = level
    base = @baseline_params.empty? ? default_baseline : @baseline_params
    params = intensity_params(level, base)
    apply(params)
    params
  end

  # Pure function: level + baseline -> adjusted params hash (no side effects)
  def intensity_params(level, baseline)
    result = {}
    INTENSITY_ADJUSTMENTS.each do |key, step|
      base_val = baseline[key]
      next unless base_val
      adjusted = base_val + (step * level)
      result[key] = clamp_param(key.to_sym, adjusted)
    end
    result
  end

  # Pure function: mood name -> color config hash
  def self.mood_params(mood_name)
    MOOD_PRESETS[mood_name.to_sym] || {}
  end

  def self.apply_mood(mood_name)
    params = mood_params(mood_name)
    return {} if params.empty?

    ColorPalette.set_hue_mode(params[:hue_mode])
    ColorPalette.set_hue_offset(params[:hue_offset]) if params[:hue_offset]

    policy_keys = [:max_saturation, :max_brightness, :max_lightness,
                   :max_emissive, :bloom_energy_scale]
    policy_keys.each do |key|
      VisualizerPolicy.send(:"#{key}=", params[key]) if params[key]
    end

    params
  end

  private

  def average(values)
    return 0.0 if values.empty?
    values.sum / values.length.to_f
  end

  def calculate_input_gain(avg_energy)
    # Avoid log of zero
    return 20.0 if avg_energy < 0.001
    20.0 * Math.log10(TARGET_ENERGY / avg_energy)
  end

  def calculate_sensitivity(dynamic_range, avg_energy)
    # High dynamic range = good signal, moderate sensitivity
    # Low dynamic range = flat signal, boost sensitivity
    if dynamic_range > 0.3
      0.8
    elsif dynamic_range > 0.15
      1.0
    elsif avg_energy < 0.1
      1.5
    else
      1.2
    end
  end

  def calculate_bloom_base(avg_energy)
    # Loud environment: lower base to avoid whiteout
    # Quiet environment: higher base for visibility
    if avg_energy > 0.5
      0.2
    elsif avg_energy > 0.3
      0.5
    else
      0.8
    end
  end

  def calculate_bloom_energy_scale(avg_energy)
    # Scale inversely with energy to prevent saturation
    if avg_energy > 0.5
      0.6
    elsif avg_energy > 0.3
      1.0
    else
      1.5
    end
  end

  def calculate_particle_prob(avg_energy)
    # High energy: lower base prob (already lots of triggers)
    # Low energy: higher base prob for responsiveness
    if avg_energy > 0.5
      0.10
    elsif avg_energy > 0.3
      0.20
    else
      0.30
    end
  end

  def clamp_param(name, value)
    spec = VisualizerPolicy::RUNTIME_PARAMS[name.to_sym]
    return value unless spec
    val = value.to_f
    val = [val, spec[:min]].max if spec[:min]
    val = [val, spec[:max]].min if spec[:max]
    val
  end

  def default_baseline
    result = {}
    INTENSITY_ADJUSTMENTS.each_key do |key|
      spec = VisualizerPolicy::RUNTIME_PARAMS[key.to_sym]
      result[key] = spec[:default] if spec
    end
    result
  end
end
