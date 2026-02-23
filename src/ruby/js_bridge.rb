require 'js'

module JSBridge
  @frame_count = 0

  def self.frame_count
    @frame_count
  end

  def self.frame_count=(val)
    @frame_count = val
  end

  def self.update_particles(data)
    begin
      positions = data[:positions]
      colors = data[:colors]
      avg_size = data[:avg_size] || 0.05
      avg_opacity = data[:avg_opacity] || 0.8

      if positions.is_a?(Array) && colors.is_a?(Array)
        JS.global.updateParticles(positions, colors, avg_size, avg_opacity)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating particles: #{e.message}")
    end
  end

  def self.update_geometry(data)
    begin
      scale = data[:scale].to_f
      rotation = data[:rotation]
      emissive = data[:emissive_intensity].to_f
      color = data[:color] || [0.3, 0.3, 0.3]

      if rotation.is_a?(Array)
        JS.global.updateGeometry(scale, rotation, emissive, color)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating geometry: #{e.message}")
    end
  end

  def self.update_bloom(data)
    begin
      strength = data[:strength].to_f
      threshold = data[:threshold].to_f

      JS.global.updateBloom(strength, threshold)
    rescue => e
      JS.global[:console].error("JSBridge error updating bloom: #{e.message}")
    end
  end

  def self.update_camera(data)
    begin
      position = data[:position]
      shake = data[:shake]

      if position.is_a?(Array) && shake.is_a?(Array)
        JS.global.updateCamera(position, shake)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating camera: #{e.message}")
    end
  end

  def self.update_particle_rotation(geometry_rotation)
    begin
      if geometry_rotation.is_a?(Array) && geometry_rotation.length >= 3
        particle_rotation = geometry_rotation.map { |r| r * 0.5 }
        JS.global.updateParticleRotation(particle_rotation)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating particle rotation: #{e.message}")
    end
  end

  def self.update_vrm(data)
    begin
      rotations = data[:rotations]
      hips_y = data[:hips_position_y] || 0.0
      blink = data[:blink] || 0.0
      mouth_v = data[:mouth_open_vertical] || 0.0
      mouth_h = data[:mouth_open_horizontal] || 0.0

      if rotations.is_a?(Array)
        JS.global.updateVRM(rotations, hips_y, blink, mouth_v, mouth_h)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating VRM: #{e.message}")
    end
  end

  def self.update_vrm_material(config)
    begin
      intensity = config[:intensity] || 1.0
      color = config[:color] || [1.0, 1.0, 1.0]

      JS.global.updateVRMMaterial(intensity, color)
    rescue => e
      JS.global[:console].error("JSBridge error updating VRM material: #{e.message}")
    end
  end

  def self.update_synth(data)
    begin
      if data[:params]
        p = data[:params]
        JS.global.updateSynthParams(
          p[:waveform].to_s,
          p[:attack],
          p[:decay],
          p[:sustain],
          p[:release],
          p[:gain],
          p[:max_sustain_ms]
        )
      end
      if data[:voice_events]
        data[:voice_events].each do |evt|
          case evt[:type]
          when :note_on
            JS.global.startPolyVoice(evt[:voice_id], evt[:freq], evt[:duty])
          when :note_off
            JS.global.releasePolyVoice(evt[:voice_id])
          end
        end
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating synth: #{e.message}")
    end
  end

  def self.update_synth_effects(data)
    begin
      JS.global.updateSynthEffects(
        data[:distortion],
        data[:filter_type].to_s,
        data[:filter_cutoff],
        data[:filter_q],
        data[:delay_time],
        data[:delay_feedback],
        data[:delay_wet],
        data[:reverb_size],
        data[:reverb_decay],
        data[:reverb_wet],
        data[:comp_threshold],
        data[:comp_ratio],
        data[:comp_attack],
        data[:comp_release]
      )
    rescue => e
      JS.global[:console].error("JSBridge error updating synth effects: #{e.message}")
    end
  end

  def self.update_oscilloscope(data)
    begin
      return unless data[:enabled]

      JS.global.updateOscilloscope(
        data[:waveform],
        data[:scroll_offset],
        data[:intensity],
        data[:color],
        data[:z_position],
        data[:y_position],
        data[:tube_radius],
        data[:spark_intensity],
        data[:spark_color]
      )
    rescue => e
      JS.global[:console].error("JSBridge error updating oscilloscope: #{e.message}")
    end
  end

  def self.log(message)
    begin
      JS.global[:console].log("[Ruby] #{message}")
    rescue => e
      $stderr.puts "[Ruby][WARN] console.log failed: #{e.message}"
    end
  end

  def self.error(message)
    begin
      JS.global[:console].error("[Ruby] #{message}")
    rescue => e
      $stderr.puts "[Ruby][WARN] console.error failed: #{e.message}"
    end
  end
end
