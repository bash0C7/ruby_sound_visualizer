require 'js'

module JSBridge
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
      color = data[:color] || [0.3, 0.3, 0.3]  # デフォルト値で安全

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
        # パーティクルをトーラスの半分の速さで回転（星空が流れる効果）
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

  def self.log(message)
    begin
      JS.global[:console].log("[Ruby] #{message}")
    rescue => e
      # Silent fail if console not available
    end
  end

  def self.error(message)
    begin
      JS.global[:console].error("[Ruby] #{message}")
    rescue => e
      # Silent fail if console not available
    end
  end
end
  
