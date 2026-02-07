require 'js'

module JSBridge
  def self.update_particles(data)
    begin
      positions = data[:positions]
      colors = data[:colors]

      if positions.is_a?(Array) && colors.is_a?(Array)
        # Convert Ruby arrays to JavaScript array-like objects
        js_update = JS.global[:updateParticles]
        js_update.call(positions, colors)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating particles: #{e.message}")
    end
  end

  def self.update_geometry(data)
    begin
      scale = data[:scale].to_f
      rotation = data[:rotation]

      if rotation.is_a?(Array)
        js_update = JS.global[:updateGeometry]
        js_update.call(scale, rotation)
      end
    rescue => e
      JS.global[:console].error("JSBridge error updating geometry: #{e.message}")
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
