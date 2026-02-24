# VJSynthPatchCommands: VJPad mix-in for SynthPatch control commands.
# Provides sp_* commands for real-time parameter control via VJPad.exec.
module VJSynthPatchCommands
  # sp_i: show synth patch status
  def sp_i
    return "synth_patch: not available" unless @synth_patch
    @synth_patch.status
  end

  # sp_osc_w [waveform]: change carrier waveform (sine/square/sawtooth/triangle)
  def sp_osc_w(val)
    return "synth_patch: not available" unless @synth_patch
    node = @synth_patch[:carrier]
    return "carrier: not found" unless node
    node.set_param(:waveform, val.to_s)
    "osc_waveform: #{val}"
  end

  # sp_osc_freq [hz]: change carrier frequency
  def sp_osc_freq(val)
    return "synth_patch: not available" unless @synth_patch
    node = @synth_patch[:carrier]
    return "carrier: not found" unless node
    node.set_param(:frequency, val.to_f)
    "osc_freq: #{val}"
  end

  # sp_co [hz]: change main_filter cutoff frequency
  def sp_co(val)
    return "synth_patch: not available" unless @synth_patch
    node = @synth_patch[:main_filter]
    return "main_filter: not found" unless node
    node.set_param(:cutoff, val.to_f)
    "cutoff: #{val}"
  end

  # sp_q [value]: change main_filter Q factor
  def sp_q(val)
    return "synth_patch: not available" unless @synth_patch
    node = @synth_patch[:main_filter]
    return "main_filter: not found" unless node
    node.set_param(:q, val.to_f)
    "q: #{val}"
  end

  # sp_gain [value]: change master_gain gain value
  def sp_gain(val)
    return "synth_patch: not available" unless @synth_patch
    node = @synth_patch[:master_gain]
    return "master_gain: not found" unless node
    node.set_param(:gain, val.to_f)
    "gain: #{val}"
  end

  # sp_a [seconds]: set ADSR attack
  def sp_a(val)
    return "synth_patch: not available" unless @synth_patch
    @synth_patch.set_attack(val.to_f)
    "attack: #{@synth_patch.attack}"
  end

  # sp_d [seconds]: set ADSR decay
  def sp_d(val)
    return "synth_patch: not available" unless @synth_patch
    @synth_patch.set_decay(val.to_f)
    "decay: #{@synth_patch.decay}"
  end

  # sp_s [0-1]: set ADSR sustain
  def sp_s(val)
    return "synth_patch: not available" unless @synth_patch
    @synth_patch.set_sustain(val.to_f)
    "sustain: #{@synth_patch.sustain}"
  end

  # sp_r [seconds]: set ADSR release
  def sp_r(val)
    return "synth_patch: not available" unless @synth_patch
    @synth_patch.set_release(val.to_f)
    "release: #{@synth_patch.release}"
  end

  # sp_ft [lowpass|highpass|bandpass]: change main_filter type
  def sp_ft(val)
    return "synth_patch: not available" unless @synth_patch
    node = @synth_patch[:main_filter]
    return "main_filter: not found" unless node
    node.set_param(:filter_type, val.to_s)
    "filter_type: #{val}"
  end
end
