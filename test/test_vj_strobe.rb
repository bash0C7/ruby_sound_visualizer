require_relative 'test_helper'

class TestVJStrobePlugin < Test::Unit::TestCase
  def setup
    VJPlugin.reset!
    load File.expand_path('../src/ruby/plugins/vj_strobe.rb', __dir__)
  end

  def test_plugin_registered
    assert VJPlugin.find(:strobe)
  end

  def test_description
    plugin = VJPlugin.find(:strobe)
    assert_match(/bloom/, plugin.description.downcase)
  end

  def test_default_effects
    plugin = VJPlugin.find(:strobe)
    result = plugin.execute({})
    assert_in_delta 3.0, result[:bloom_flash], 0.001
    assert_nil result[:impulse]
  end

  def test_custom_intensity
    plugin = VJPlugin.find(:strobe)
    result = plugin.execute({ intensity: 4.5 })
    assert_in_delta 4.5, result[:bloom_flash], 0.001
  end

  def test_range_clamping_upper
    plugin = VJPlugin.find(:strobe)
    result = plugin.execute({ intensity: 10.0 })
    assert_in_delta 5.0, result[:bloom_flash], 0.001
  end

  def test_via_vj_pad
    pad = VJPad.new
    result = pad.exec("strobe")
    assert_equal true, result[:ok]
    assert_equal "strobe!", result[:msg]
    actions = pad.pending_actions
    assert_equal :strobe, actions[0][:name]
  end
end
