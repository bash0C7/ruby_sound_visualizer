module MathHelper
  def self.lerp(a, b, t)
    a + (b - a) * t
  end
end

