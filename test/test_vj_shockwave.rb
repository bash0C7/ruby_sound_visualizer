require_relative 'test_helper'

class TestVJShockwavePlugin < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    load File.expand_path('../src/ruby/plugins/vj_shockwave.rb', __dir__)
  end

  def test_plugin_registered
    assert VJPlugin.find(:shockwave)
  end

  def test_description
    plugin = VJPlugin.find(:shockwave)
    assert_match(/impulse/, plugin.description.downcase)
    assert_match(/bloom/, plugin.description.downcase)
  end

  def test_default_effects
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({})
    # force default 1.5
    assert_in_delta 1.5, result[:impulse][:bass], 0.001
    assert_in_delta 0.75, result[:impulse][:mid], 0.001   # 1.5 * 0.5
    assert_in_delta 0.45, result[:impulse][:high], 0.001  # 1.5 * 0.3
    assert_in_delta 1.5, result[:impulse][:overall], 0.001
    assert_in_delta 1.2, result[:bloom_flash], 0.001      # 1.5 * 0.8
  end

  def test_custom_force
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({ force: 3.0 })
    assert_in_delta 3.0, result[:impulse][:bass], 0.001
    assert_in_delta 1.5, result[:impulse][:mid], 0.001
    assert_in_delta 2.4, result[:bloom_flash], 0.001
  end

  def test_range_clamping_upper
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({ force: 10.0 })
    assert_in_delta 5.0, result[:impulse][:bass], 0.001
  end

  def test_range_clamping_lower
    plugin = VJPlugin.find(:shockwave)
    result = plugin.execute({ force: -1.0 })
    assert_in_delta 0.0, result[:impulse][:bass], 0.001
  end

  def test_via_vj_pad
    pad = VJPad.new
    result = pad.exec("shockwave 2.0")
    assert_equal true, result[:ok]
    assert_equal "shockwave: 2.0", result[:msg]
    actions = pad.pending_actions
    assert_equal 1, actions.length
    assert_equal :shockwave, actions[0][:name]
  end
end
