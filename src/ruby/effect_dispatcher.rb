# EffectDispatcher: Translates plugin effect hashes into EffectManager calls.
# Decouples plugin definitions from EffectManager internals.
class EffectDispatcher
  def initialize(effect_manager)
    @effect_manager = effect_manager
  end

  def dispatch(effects)
    return unless effects.is_a?(Hash)

    if effects[:impulse]
      imp = effects[:impulse]
      JSBridge.log("effect.type=impulse effect.bass=#{(imp[:bass] || 0.0).round(3)} effect.mid=#{(imp[:mid] || 0.0).round(3)} effect.high=#{(imp[:high] || 0.0).round(3)} effect.overall=#{(imp[:overall] || 0.0).round(3)}")
      dispatch_impulse(imp)
    end
    if effects[:bloom_flash]
      JSBridge.log("effect.type=bloom_flash effect.magnitude=#{effects[:bloom_flash].round(3)}")
      dispatch_bloom_flash(effects[:bloom_flash])
    end
    dispatch_set_param(effects[:set_param]) if effects[:set_param]
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

  def dispatch_set_param(params)
    params.each do |key, value|
      VisualizerPolicy.set_by_key(key, value)
    end
  end
end
