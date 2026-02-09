module MathHelper
  def self.clamp(value, min, max)
    [[value, min].max, max].min
  end

  def self.lerp(a, b, t)
    a + (b - a) * t
  end

  def self.map_range(value, in_min, in_max, out_min, out_max)
    if in_max == in_min
      return out_min
    end
    (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
  end

  def self.normalize(value, min, max)
    if max == min
      return 0.0
    end
    (value - min) / (max - min)
  end
end
  
