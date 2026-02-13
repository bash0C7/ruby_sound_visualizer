# EffectDispatcher: Translates plugin effect hashes into EffectManager calls.
# Decouples plugin definitions from EffectManager internals.
class EffectDispatcher
  def initialize(effect_manager)
    @effect_manager = effect_manager
  end

  def dispatch(effects)
    return unless effects.is_a?(Hash)

    dispatch_impulse(effects[:impulse]) if effects[:impulse]
    dispatch_bloom_flash(effects[:bloom_flash]) if effects[:bloom_flash]
  end

  private

  def dispatch_impulse(impulse)
    @effect_manager.inject_impulse(
      bass: impulse[:bass] || 0.0,
      mid: impulse[:mid] || 0.0,
      high: impulse[:high] || 0.0,
      overall: impulse[:overall] || 0.0
    )
  end

  def dispatch_bloom_flash(intensity)
    @effect_manager.inject_bloom_flash(intensity)
  end
end
