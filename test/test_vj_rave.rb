require_relative 'test_helper'

class TestVJRavePlugin < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    VisualizerPolicy.reset_runtime
    load File.expand_path('../src/ruby/plugins/vj_rave.rb', __dir__)
  end

  def test_plugin_registered
    assert VJPlugin.find(:rave)
  end

  def test_description
    plugin = VJPlugin.find(:rave)
    assert_match(/energy/, plugin.description.downcase)
  end

  def test_default_effects_impulse
    plugin = VJPlugin.find(:rave)
    result = plugin.execute({})
    # level default 1.0
    assert_in_delta 1.0, result[:impulse][:bass], 0.001
    assert_in_delta 1.0, result[:impulse][:overall], 0.001
  end

  def test_default_effects_bloom_flash
    plugin = VJPlugin.find(:rave)
    result = plugin.execute({})
    assert_in_delta 2.0, result[:bloom_flash], 0.001  # 1.0 * 2.0
  end

  def test_default_effects_set_param
    plugin = VJPlugin.find(:rave)
    result = plugin.execute({})
    params = result[:set_param]
    assert_in_delta 3.0, params["bloom_base_strength"], 0.001  # 2.0 + 1.0
    assert_in_delta 0.4, params["particle_explosion_base_prob"], 0.001  # min(0.2 + 1.0*0.2, 1.0)
  end

  def test_custom_level
    plugin = VJPlugin.find(:rave)
    result = plugin.execute({ level: 2.0 })
    assert_in_delta 2.0, result[:impulse][:bass], 0.001
    assert_in_delta 4.0, result[:bloom_flash], 0.001  # 2.0 * 2.0
    params = result[:set_param]
    assert_in_delta 4.0, params["bloom_base_strength"], 0.001  # 2.0 + 2.0
    assert_in_delta 0.6, params["particle_explosion_base_prob"], 0.001  # min(0.2 + 2.0*0.2, 1.0)
  end

  def test_range_clamping
    plugin = VJPlugin.find(:rave)
    result = plugin.execute({ level: 10.0 })
    # clamped to 3.0
    assert_in_delta 3.0, result[:impulse][:bass], 0.001
  end

  def test_set_param_prob_capped_at_1
    plugin = VJPlugin.find(:rave)
    result = plugin.execute({ level: 3.0 })
    params = result[:set_param]
    # 0.2 + 3.0*0.2 = 0.8 (still under 1.0)
    assert_in_delta 0.8, params["particle_explosion_base_prob"], 0.001
  end

  def test_via_vj_pad_dispatches_set_param
    # Full pipeline: VJPad -> EffectDispatcher -> VisualizerPolicy
    load File.expand_path('../src/ruby/plugins/vj_burst.rb', __dir__)
    load File.expand_path('../src/ruby/plugins/vj_flash.rb', __dir__)

    pad = VJPad.new
    effect_manager = EffectManager.new
    dispatcher = EffectDispatcher.new(effect_manager)

    pad.exec("rave 2.0")
    pad.consume_actions.each do |action|
      dispatcher.dispatch(action[:effects])
    end

    # set_param should have updated VisualizerPolicy
    assert_in_delta 4.0, VisualizerPolicy.bloom_base_strength, 0.001
  end
end
