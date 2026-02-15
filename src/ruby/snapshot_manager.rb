require 'js'

# Encodes/decodes Controls state to/from URL query string for snapshot save/restore.
# JS callbacks: rubySnapshotEncode(cr, cth, cph) → "?v=1&..."
#               rubySnapshotApply(queryString)    → '{"cr":5,"cth":0,"cph":0}' or ""
class SnapshotManager
  SCHEMA_VERSION = 1

  PARAM_MAP = {
    'hue'  => { get: -> { ColorPalette.get_hue_offset.round(2) },
                set: ->(v) { ColorPalette.set_hue_offset(v.to_f) } },
    'mode' => { get: -> { (ColorPalette.get_hue_mode || 0).to_i },
                set: ->(v) { ColorPalette.set_hue_mode(v.to_i == 0 ? nil : v.to_i) } },
    'brt'  => { get: -> { VisualizerPolicy.max_brightness },
                set: ->(v) { VisualizerPolicy.max_brightness = v.to_i } },
    'sat'  => { get: -> { VisualizerPolicy.max_saturation },
                set: ->(v) { VisualizerPolicy.max_saturation = v.to_i } },
    'sens' => { get: -> { VisualizerPolicy.sensitivity.round(3) },
                set: ->(v) { VisualizerPolicy.sensitivity = v.to_f } },
    'ig'   => { get: -> { VisualizerPolicy.input_gain.round(1) },
                set: ->(v) { VisualizerPolicy.input_gain = v.to_f } },
    'bbs'  => { get: -> { VisualizerPolicy.bloom_base_strength },
                set: ->(v) { VisualizerPolicy.bloom_base_strength = v.to_f } },
    'bmax' => { get: -> { VisualizerPolicy.max_bloom },
                set: ->(v) { VisualizerPolicy.max_bloom = v.to_f } },
    'bes'  => { get: -> { VisualizerPolicy.bloom_energy_scale },
                set: ->(v) { VisualizerPolicy.bloom_energy_scale = v.to_f } },
    'bis'  => { get: -> { VisualizerPolicy.bloom_impulse_scale },
                set: ->(v) { VisualizerPolicy.bloom_impulse_scale = v.to_f } },
    'pp'   => { get: -> { VisualizerPolicy.particle_explosion_base_prob },
                set: ->(v) { VisualizerPolicy.particle_explosion_base_prob = v.to_f } },
    'pes'  => { get: -> { VisualizerPolicy.particle_explosion_energy_scale },
                set: ->(v) { VisualizerPolicy.particle_explosion_energy_scale = v.to_f } },
    'pfs'  => { get: -> { VisualizerPolicy.particle_explosion_force_scale },
                set: ->(v) { VisualizerPolicy.particle_explosion_force_scale = v.to_f } },
    'fr'   => { get: -> { VisualizerPolicy.particle_friction },
                set: ->(v) { VisualizerPolicy.particle_friction = v.to_f } },
    'ml'   => { get: -> { VisualizerPolicy.max_lightness },
                set: ->(v) { VisualizerPolicy.max_lightness = v.to_i } },
    'me'   => { get: -> { VisualizerPolicy.max_emissive },
                set: ->(v) { VisualizerPolicy.max_emissive = v.to_f } },
    'vs'   => { get: -> { VisualizerPolicy.visual_smoothing },
                set: ->(v) { VisualizerPolicy.visual_smoothing = v.to_f } },
    'id'   => { get: -> { VisualizerPolicy.impulse_decay },
                set: ->(v) { VisualizerPolicy.impulse_decay = v.to_f } },
  }.freeze

  def self.encode(camera_hash = {})
    params = [['v', SCHEMA_VERSION]]
    PARAM_MAP.each { |key, h| params << [key, h[:get].call] }
    params << ['cr',  (camera_hash['cr']  || 5).to_f.round(1)]
    params << ['cth', (camera_hash['cth'] || 0).to_i]
    params << ['cph', (camera_hash['cph'] || 0).to_i]
    '?' + params.map { |k, v| "#{k}=#{v}" }.join('&')
  end

  def self.apply(query_string)
    params = parse_query(query_string.to_s)
    return {} unless params.key?('v')
    PARAM_MAP.each do |key, h|
      next unless params.key?(key)
      begin
        h[:set].call(params[key])
      rescue StandardError
        nil
      end
    end
    {
      'cr'  => params.fetch('cr',  '5').to_f,
      'cth' => params.fetch('cth', '0').to_f,
      'cph' => params.fetch('cph', '0').to_f,
    }
  end

  def self.register_callbacks
    JS.global[:rubySnapshotEncode] = lambda { |cr, cth, cph|
      SnapshotManager.encode({ 'cr' => cr.to_f, 'cth' => cth.to_f, 'cph' => cph.to_f })
    }
    JS.global[:rubySnapshotApply] = lambda { |qs|
      cam = SnapshotManager.apply(qs.to_s)
      next "" if cam.empty?
      "{\"cr\":#{cam['cr']},\"cth\":#{cam['cth']},\"cph\":#{cam['cph']}}"
    }
  end

  private_class_method def self.parse_query(str)
    str.sub(/^\?/, '').split('&').each_with_object({}) do |pair, hash|
      k, v = pair.split('=', 2)
      hash[k] = v if k && !k.empty? && v
    end
  end
end
