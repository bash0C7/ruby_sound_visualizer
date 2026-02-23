# SynthEffects: Master effects chain parameters for the polyphonic synthesizer.
# Manages distortion, filter, delay, reverb, and compressor settings.
# Pure Ruby state - delegates audio processing to JavaScript via JSBridge.
#
# Signal chain: InputBus → Distortion → Filter → Delay → Reverb → Compressor → Output
class SynthEffects
  # --- Presets ---

  THROUGH_PRESET = {
    distortion:      0,
    filter_type:     'allpass',
    filter_cutoff:   20000.0,
    filter_q:        1.0,
    delay_time:      0.25,
    delay_feedback:  0.0,
    delay_wet:       0.0,
    reverb_size:     1.0,
    reverb_decay:    2.0,
    reverb_wet:      0.0,
    comp_threshold:  -3.0,
    comp_ratio:      1.0,
    comp_attack:     0.003,
    comp_release:    0.25,
  }.freeze

  HARDCORE_PRESET = {
    distortion:      250,
    filter_type:     'lowpass',
    filter_cutoff:   4000.0,
    filter_q:        12.0,
    delay_time:      0.125,
    delay_feedback:  0.45,
    delay_wet:       0.3,
    reverb_size:     1.5,
    reverb_decay:    3.0,
    reverb_wet:      0.2,
    comp_threshold:  -18.0,
    comp_ratio:      10.0,
    comp_attack:     0.003,
    comp_release:    0.08,
  }.freeze

  DEFAULT_PRESET = THROUGH_PRESET

  # --- Clamp ranges ---

  DIST_MIN = 0;   DIST_MAX = 400
  CUTOFF_MIN = 20.0;  CUTOFF_MAX = 20000.0
  Q_MIN = 0.1;    Q_MAX = 30.0
  DELAY_TIME_MIN = 0.0;   DELAY_TIME_MAX = 2.0
  DELAY_FB_MIN = 0.0;     DELAY_FB_MAX = 0.95
  WET_MIN = 0.0;  WET_MAX = 1.0
  REVERB_SIZE_MIN = 0.1;  REVERB_SIZE_MAX = 5.0
  REVERB_DECAY_MIN = 0.1; REVERB_DECAY_MAX = 10.0
  COMP_THRESHOLD_MIN = -60.0; COMP_THRESHOLD_MAX = 0.0
  COMP_RATIO_MIN = 1.0;   COMP_RATIO_MAX = 20.0
  COMP_ATK_MIN = 0.001;   COMP_ATK_MAX = 1.0
  COMP_REL_MIN = 0.001;   COMP_REL_MAX = 2.0

  VALID_FILTER_TYPES = %w[lowpass highpass bandpass allpass notch].freeze

  attr_reader :distortion, :filter_type, :filter_cutoff, :filter_q,
              :delay_time, :delay_feedback, :delay_wet,
              :reverb_size, :reverb_decay, :reverb_wet,
              :comp_threshold, :comp_ratio, :comp_attack, :comp_release

  def initialize
    apply_preset(DEFAULT_PRESET)
  end

  # --- Preset application ---

  def apply_preset(preset)
    @distortion     = preset[:distortion].to_i
    @filter_type    = preset[:filter_type].to_s
    @filter_cutoff  = preset[:filter_cutoff].to_f
    @filter_q       = preset[:filter_q].to_f
    @delay_time     = preset[:delay_time].to_f
    @delay_feedback = preset[:delay_feedback].to_f
    @delay_wet      = preset[:delay_wet].to_f
    @reverb_size    = preset[:reverb_size].to_f
    @reverb_decay   = preset[:reverb_decay].to_f
    @reverb_wet     = preset[:reverb_wet].to_f
    @comp_threshold = preset[:comp_threshold].to_f
    @comp_ratio     = preset[:comp_ratio].to_f
    @comp_attack    = preset[:comp_attack].to_f
    @comp_release   = preset[:comp_release].to_f
    @pending_update = true
  end

  # --- Distortion ---

  def set_distortion(val)
    @distortion = clamp(val.to_i, DIST_MIN, DIST_MAX)
    @pending_update = true
  end

  # --- Filter ---

  def set_filter_type(type)
    t = type.to_s
    raise ArgumentError, "Invalid filter type: #{type}" unless VALID_FILTER_TYPES.include?(t)
    @filter_type = t
    @pending_update = true
  end

  def set_filter_cutoff(val)
    @filter_cutoff = clamp(val.to_f, CUTOFF_MIN, CUTOFF_MAX)
    @pending_update = true
  end

  def set_filter_q(val)
    @filter_q = clamp(val.to_f, Q_MIN, Q_MAX)
    @pending_update = true
  end

  # --- Delay ---

  def set_delay_time(val)
    @delay_time = clamp(val.to_f, DELAY_TIME_MIN, DELAY_TIME_MAX)
    @pending_update = true
  end

  def set_delay_feedback(val)
    @delay_feedback = clamp(val.to_f, DELAY_FB_MIN, DELAY_FB_MAX)
    @pending_update = true
  end

  def set_delay_wet(val)
    @delay_wet = clamp(val.to_f, WET_MIN, WET_MAX)
    @pending_update = true
  end

  # --- Reverb ---

  def set_reverb_size(val)
    @reverb_size = clamp(val.to_f, REVERB_SIZE_MIN, REVERB_SIZE_MAX)
    @pending_update = true
  end

  def set_reverb_decay(val)
    @reverb_decay = clamp(val.to_f, REVERB_DECAY_MIN, REVERB_DECAY_MAX)
    @pending_update = true
  end

  def set_reverb_wet(val)
    @reverb_wet = clamp(val.to_f, WET_MIN, WET_MAX)
    @pending_update = true
  end

  # --- Compressor ---

  def set_comp_threshold(val)
    @comp_threshold = clamp(val.to_f, COMP_THRESHOLD_MIN, COMP_THRESHOLD_MAX)
    @pending_update = true
  end

  def set_comp_ratio(val)
    @comp_ratio = clamp(val.to_f, COMP_RATIO_MIN, COMP_RATIO_MAX)
    @pending_update = true
  end

  # --- Pending update ---

  def pending_update?
    @pending_update
  end

  def consume_update
    return nil unless @pending_update
    @pending_update = false
    to_h
  end

  def to_h
    {
      distortion:     @distortion,
      filter_type:    @filter_type,
      filter_cutoff:  @filter_cutoff,
      filter_q:       @filter_q,
      delay_time:     @delay_time,
      delay_feedback: @delay_feedback,
      delay_wet:      @delay_wet,
      reverb_size:    @reverb_size,
      reverb_decay:   @reverb_decay,
      reverb_wet:     @reverb_wet,
      comp_threshold: @comp_threshold,
      comp_ratio:     @comp_ratio,
      comp_attack:    @comp_attack,
      comp_release:   @comp_release,
    }
  end

  def status
    "fx: dist=#{@distortion} filt=#{@filter_type}/#{@filter_cutoff.round}Hz/Q#{@filter_q} " \
      "dly=#{@delay_time.round(3)}s/fb#{@delay_feedback}/w#{@delay_wet} " \
      "rev=#{@reverb_size.round(2)}s/w#{@reverb_wet} " \
      "comp=#{@comp_threshold}dB/#{@comp_ratio}:1"
  end

  private

  def clamp(val, min, max)
    [[val, min].max, max].min
  end
end
