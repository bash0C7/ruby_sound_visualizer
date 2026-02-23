# VJ Pad commands for the master effects chain and polyphonic voice config.
# Mixed into VJPad to provide sfx_* effect control and voice pool settings.
module VJSynthEffectsCommands
  # --- Presets ---

  # sfx_hardcore: apply hardcore techno preset
  def sfx_hardcore
    return "synth_effects: not available" unless @synth_effects
    @synth_effects.apply_preset(SynthEffects::HARDCORE_PRESET)
    "fx: hardcore preset applied"
  end

  # sfx_thru: bypass all effects (through preset)
  def sfx_thru
    return "synth_effects: not available" unless @synth_effects
    @synth_effects.apply_preset(SynthEffects::THROUGH_PRESET)
    "fx: through (bypass) applied"
  end

  # --- Distortion ---

  # sfx_dist [0-400]: distortion amount
  def sfx_dist(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx dist: #{@synth_effects.distortion}" if val == :_get
    @synth_effects.set_distortion(val.to_i)
    "fx dist: #{@synth_effects.distortion}"
  end

  # --- Filter ---

  # sfx_filt [Hz]: master filter cutoff frequency
  def sfx_filt(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx filter cutoff: #{@synth_effects.filter_cutoff.round}Hz" if val == :_get
    @synth_effects.set_filter_cutoff(val.to_f)
    "fx filter cutoff: #{@synth_effects.filter_cutoff.round}Hz"
  end

  # sfx_q [0.1-30]: filter resonance (Q factor)
  def sfx_q(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx filter Q: #{@synth_effects.filter_q}" if val == :_get
    @synth_effects.set_filter_q(val.to_f)
    "fx filter Q: #{@synth_effects.filter_q}"
  end

  # sfx_ft [lowpass|highpass|bandpass|allpass|notch]: filter type
  def sfx_ft(type = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx filter type: #{@synth_effects.filter_type}" if type == :_get
    @synth_effects.set_filter_type(type.to_s)
    "fx filter type: #{@synth_effects.filter_type}"
  end

  # --- Delay ---

  # sfx_dly [seconds]: delay time
  def sfx_dly(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx delay: #{@synth_effects.delay_time}s" if val == :_get
    @synth_effects.set_delay_time(val.to_f)
    "fx delay: #{@synth_effects.delay_time}s"
  end

  # sfx_dlyfb [0-0.95]: delay feedback amount
  def sfx_dlyfb(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx delay fb: #{@synth_effects.delay_feedback}" if val == :_get
    @synth_effects.set_delay_feedback(val.to_f)
    "fx delay fb: #{@synth_effects.delay_feedback}"
  end

  # sfx_dlyw [0-1]: delay wet mix
  def sfx_dlyw(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx delay wet: #{@synth_effects.delay_wet}" if val == :_get
    @synth_effects.set_delay_wet(val.to_f)
    "fx delay wet: #{@synth_effects.delay_wet}"
  end

  # --- Reverb ---

  # sfx_rev [0-1]: reverb wet mix
  def sfx_rev(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx reverb wet: #{@synth_effects.reverb_wet}" if val == :_get
    @synth_effects.set_reverb_wet(val.to_f)
    "fx reverb wet: #{@synth_effects.reverb_wet}"
  end

  # sfx_revs [0.1-5]: reverb size (IR duration in seconds)
  def sfx_revs(val = :_get)
    return "synth_effects: not available" unless @synth_effects
    return "fx reverb size: #{@synth_effects.reverb_size}s" if val == :_get
    @synth_effects.set_reverb_size(val.to_f)
    "fx reverb size: #{@synth_effects.reverb_size}s"
  end

  # --- Voice pool ---

  # sfx_voices [1-16]: max simultaneous voices
  def sfx_voices(val = :_get)
    return "synth: not available" unless @synth_engine
    return "poly voices: #{@synth_engine.max_voices}" if val == :_get
    @synth_engine.set_max_voices(val.to_i)
    "poly voices: #{@synth_engine.max_voices}"
  end

  # sfx_sus_ms [50-10000]: max note sustain duration (ms)
  def sfx_sus_ms(val = :_get)
    return "synth: not available" unless @synth_engine
    return "poly sustain_ms: #{@synth_engine.max_sustain_ms}" if val == :_get
    @synth_engine.set_max_sustain_ms(val.to_i)
    "poly sustain_ms: #{@synth_engine.max_sustain_ms}"
  end

  # sfx_i: show current effects + voice pool status
  def sfx_i
    parts = []
    parts << @synth_engine.status if @synth_engine
    parts << @synth_effects.status if @synth_effects
    parts.empty? ? "synth_effects: not available" : parts.join("\n")
  end
end
