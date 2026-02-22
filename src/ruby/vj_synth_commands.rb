# VJ Pad commands for controlling the analog monophonic synthesizer.
# Mixed into VJPad to provide synth parameter control via command line.
module VJSynthCommands
  # Synth waveform: syn_w [sine|square|sawtooth|triangle]
  def syn_w(type = :_get)
    return "synth: not available" unless @synth_engine
    if type == :_get
      return "synth wave: #{@synth_engine.waveform}"
    end
    @synth_engine.set_waveform(type.to_s)
    "synth wave: #{@synth_engine.waveform}"
  end

  # Synth attack: syn_a [seconds]
  def syn_a(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth attack: #{@synth_engine.attack}s"
    end
    @synth_engine.set_attack(val.to_f)
    "synth attack: #{@synth_engine.attack}s"
  end

  # Synth decay: syn_d [seconds]
  def syn_d(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth decay: #{@synth_engine.decay}s"
    end
    @synth_engine.set_decay(val.to_f)
    "synth decay: #{@synth_engine.decay}s"
  end

  # Synth sustain: syn_s [0.0-1.0]
  def syn_s(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth sustain: #{@synth_engine.sustain}"
    end
    @synth_engine.set_sustain(val.to_f)
    "synth sustain: #{@synth_engine.sustain}"
  end

  # Synth release: syn_r [seconds]
  def syn_r(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth release: #{@synth_engine.release}s"
    end
    @synth_engine.set_release(val.to_f)
    "synth release: #{@synth_engine.release}s"
  end

  # Synth filter cutoff: syn_fc [Hz]
  def syn_fc(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth cutoff: #{@synth_engine.filter_cutoff.round}Hz"
    end
    @synth_engine.set_filter_cutoff(val.to_f)
    "synth cutoff: #{@synth_engine.filter_cutoff.round}Hz"
  end

  # Synth filter resonance: syn_fq [Q value]
  def syn_fq(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth Q: #{@synth_engine.filter_resonance}"
    end
    @synth_engine.set_filter_resonance(val.to_f)
    "synth Q: #{@synth_engine.filter_resonance}"
  end

  # Synth filter type: syn_ft [lowpass|highpass|bandpass]
  def syn_ft(type = :_get)
    return "synth: not available" unless @synth_engine
    if type == :_get
      return "synth filter: #{@synth_engine.filter_type}"
    end
    @synth_engine.set_filter_type(type.to_s)
    "synth filter: #{@synth_engine.filter_type}"
  end

  # Synth gain: syn_g [0-100 percent]
  def syn_g(val = :_get)
    return "synth: not available" unless @synth_engine
    if val == :_get
      return "synth gain: #{(@synth_engine.gain * 100).round}%"
    end
    @synth_engine.set_gain(val.to_f / 100.0)
    "synth gain: #{(@synth_engine.gain * 100).round}%"
  end

  # Synth info: syn_i
  def syn_i
    return "synth: not available" unless @synth_engine
    @synth_engine.status
  end

  # Oscilloscope enable/disable: osc [1/0]
  def osc(val = :_get)
    return "oscilloscope: not available" unless @oscilloscope_renderer
    if val == :_get
      return "oscilloscope: #{@oscilloscope_renderer.enabled? ? 'on' : 'off'}"
    end
    if val.to_i != 0
      @oscilloscope_renderer.enable
    else
      @oscilloscope_renderer.disable
    end
    "oscilloscope: #{@oscilloscope_renderer.enabled? ? 'on' : 'off'}"
  end

  # Oscilloscope scroll speed: osc_sp [speed]
  def osc_sp(val = :_get)
    return "oscilloscope: not available" unless @oscilloscope_renderer
    if val == :_get
      return "osc speed: #{@oscilloscope_renderer.scroll_speed}"
    end
    @oscilloscope_renderer.set_scroll_speed(val.to_f)
    "osc speed: #{@oscilloscope_renderer.scroll_speed}"
  end
end
