require_relative 'test_helper'

class TestVJPad < Test::Unit::TestCase
  def setup
    JS.reset_global!
    VisualizerPolicy.reset_runtime
    ColorPalette.set_hue_mode(nil)
    ColorPalette.set_hue_offset(0.0)
    @pad = VJPad.new
  end

  # === Getter tests (no args = show current value) ===

  def test_c_getter_default
    result = @pad.c
    assert_equal "color: gray", result
  end

  def test_c_getter_after_set
    ColorPalette.set_hue_mode(1)
    result = @pad.c
    assert_equal "color: red", result
  end

  def test_h_getter_default
    result = @pad.h
    assert_equal "hue: 0.0", result
  end

  def test_h_getter_after_set
    ColorPalette.set_hue_offset(45.0)
    result = @pad.h
    assert_equal "hue: 45.0", result
  end

  def test_s_getter_default
    result = @pad.s
    assert_equal "sens: 1.0", result
  end

  def test_ig_getter_default
    result = @pad.ig
    assert_equal "gain: 0.0dB", result
  end

  def test_ig_setter
    result = @pad.ig(-6.0)
    assert_equal "gain: -6.0dB", result
    assert_in_delta(-6.0, VisualizerPolicy.input_gain, 0.001)
  end

  def test_ig_setter_clamped
    @pad.ig(25.0)
    assert_in_delta 20.0, VisualizerPolicy.input_gain, 0.001
  end

  def test_br_getter_default
    result = @pad.br
    assert_equal "bright: 255", result
  end

  def test_lt_getter_default
    result = @pad.lt
    assert_equal "light: 255", result
  end

  def test_em_getter_default
    result = @pad.em
    assert_equal "emissive: 2.0", result
  end

  def test_bm_getter_default
    result = @pad.bm
    assert_equal "bloom: 4.5", result
  end

  def test_i_shows_all_defaults
    result = @pad.i
    assert_match(/c:gray/, result)
    assert_match(/h:0\.0/, result)
    assert_match(/s:1\.0/, result)
    assert_match(/ig:0\.0dB/, result)
    assert_match(/br:255/, result)
    assert_match(/lt:255/, result)
    assert_match(/em:2\.0/, result)
    assert_match(/bm:4\.5/, result)
    assert_match(/x:false/, result)
  end

  # === Setter tests (with args = change value) ===

  def test_c_set_by_number
    result = @pad.c(1)
    assert_equal "color: red", result
    assert_equal 1, ColorPalette.get_hue_mode
  end

  def test_c_set_mode_0_is_gray
    @pad.c(1)
    result = @pad.c(0)
    assert_equal "color: gray", result
    assert_nil ColorPalette.get_hue_mode
  end

  def test_c_set_mode_2
    result = @pad.c(2)
    assert_equal "color: yellow", result
    assert_equal 2, ColorPalette.get_hue_mode
  end

  def test_c_set_mode_3
    result = @pad.c(3)
    assert_equal "color: blue", result
    assert_equal 3, ColorPalette.get_hue_mode
  end

  def test_c_set_by_symbol_red
    result = @pad.c(:red)
    assert_equal "color: red", result
    assert_equal 1, ColorPalette.get_hue_mode
  end

  def test_c_set_by_symbol_yellow
    result = @pad.c(:yellow)
    assert_equal "color: yellow", result
    assert_equal 2, ColorPalette.get_hue_mode
  end

  def test_c_set_by_symbol_blue
    result = @pad.c(:blue)
    assert_equal "color: blue", result
    assert_equal 3, ColorPalette.get_hue_mode
  end

  def test_c_set_by_symbol_gray
    @pad.c(1)
    result = @pad.c(:gray)
    assert_equal "color: gray", result
    assert_nil ColorPalette.get_hue_mode
  end

  def test_c_short_alias_r
    result = @pad.c(:r)
    assert_equal "color: red", result
  end

  def test_c_short_alias_y
    result = @pad.c(:y)
    assert_equal "color: yellow", result
  end

  def test_c_short_alias_b
    result = @pad.c(:b)
    assert_equal "color: blue", result
  end

  def test_c_short_alias_g
    @pad.c(1)
    result = @pad.c(:g)
    assert_equal "color: gray", result
  end

  def test_h_set_absolute
    result = @pad.h(45)
    assert_equal "hue: 45.0", result
    assert_in_delta 45.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_h_set_wraps
    @pad.h(400)
    assert_in_delta 40.0, ColorPalette.get_hue_offset, 0.001
  end

  def test_s_set
    result = @pad.s(1.5)
    assert_equal "sens: 1.5", result
    assert_in_delta 1.5, VisualizerPolicy.sensitivity, 0.001
  end

  def test_s_set_clamped_min
    @pad.s(0.01)
    assert_in_delta 0.1, VisualizerPolicy.sensitivity, 0.001
  end

  def test_br_set
    result = @pad.br(200)
    assert_equal "bright: 200", result
    assert_equal 200, VisualizerPolicy.max_brightness
  end

  def test_br_set_clamped
    @pad.br(300)
    assert_equal 255, VisualizerPolicy.max_brightness
  end

  def test_lt_set
    result = @pad.lt(128)
    assert_equal "light: 128", result
    assert_equal 128, VisualizerPolicy.max_lightness
  end

  def test_em_set
    result = @pad.em(1.5)
    assert_equal "emissive: 1.5", result
    assert_in_delta 1.5, VisualizerPolicy.max_emissive, 0.001
  end

  def test_bm_set
    result = @pad.bm(3.0)
    assert_equal "bloom: 3.0", result
    assert_in_delta 3.0, VisualizerPolicy.max_bloom, 0.001
  end

  # === Toggle and reset ===

  def test_x_toggles_exclude_max
    assert_equal false, VisualizerPolicy.exclude_max
    result = @pad.x
    assert_equal "exclude_max: true", result
    assert_equal true, VisualizerPolicy.exclude_max
    result2 = @pad.x
    assert_equal "exclude_max: false", result2
    assert_equal false, VisualizerPolicy.exclude_max
  end

  def test_r_resets_all
    @pad.c(1)
    @pad.s(1.5)
    @pad.ig(6.0)
    @pad.br(100)
    @pad.lt(100)
    @pad.em(3.0)
    @pad.bm(8.0)
    @pad.h(90)
    result = @pad.r
    assert_equal "reset done", result
    assert_nil ColorPalette.get_hue_mode
    assert_in_delta 1.0, VisualizerPolicy.sensitivity, 0.001
    assert_in_delta 0.0, VisualizerPolicy.input_gain, 0.001
    assert_equal 255, VisualizerPolicy.max_brightness
    assert_equal 255, VisualizerPolicy.max_lightness
    assert_in_delta 2.0, VisualizerPolicy.max_emissive, 0.001
    assert_in_delta 4.5, VisualizerPolicy.max_bloom, 0.001
  end

  # === exec method ===

  def test_exec_simple_command
    result = @pad.exec("c 1")
    assert_equal true, result[:ok]
    assert_equal "color: red", result[:msg]
    assert_equal 1, ColorPalette.get_hue_mode
  end

  def test_exec_getter
    result = @pad.exec("s")
    assert_equal true, result[:ok]
    assert_equal "sens: 1.0", result[:msg]
  end

  def test_exec_multiple_with_semicolons
    result = @pad.exec("c 1; s 1.5")
    assert_equal true, result[:ok]
    # Last expression result
    assert_equal "sens: 1.5", result[:msg]
    # Both should have taken effect
    assert_equal 1, ColorPalette.get_hue_mode
    assert_in_delta 1.5, VisualizerPolicy.sensitivity, 0.001
  end

  def test_exec_invalid_command
    result = @pad.exec("nonexistent_method_xyz")
    assert_equal false, result[:ok]
    assert_instance_of String, result[:msg]
  end

  def test_exec_empty_string
    result = @pad.exec("")
    assert_equal true, result[:ok]
    assert_equal "", result[:msg]
  end

  def test_exec_whitespace_only
    result = @pad.exec("   ")
    assert_equal true, result[:ok]
    assert_equal "", result[:msg]
  end

  def test_exec_syntax_error
    result = @pad.exec("c(")
    assert_equal false, result[:ok]
  end

  # === History tracking ===

  def test_history_starts_empty
    assert_equal [], @pad.history
  end

  def test_history_tracks_commands
    @pad.exec("c 1")
    @pad.exec("s 2.0")
    assert_equal ["c 1", "s 2.0"], @pad.history
  end

  def test_history_tracks_failed_commands
    @pad.exec("bad_command")
    assert_equal ["bad_command"], @pad.history
  end

  def test_history_skips_empty
    @pad.exec("")
    assert_equal [], @pad.history
  end

  # === last_result ===

  def test_last_result_tracks_success
    @pad.exec("c 1")
    assert_equal "color: red", @pad.last_result
  end

  def test_last_result_tracks_error
    @pad.exec("bad_command")
    assert_instance_of String, @pad.last_result
  end

  # === Action commands: burst and flash ===

  def test_burst_default
    result = @pad.burst
    assert_equal "burst!", result
  end

  def test_burst_with_force
    result = @pad.burst(2.0)
    assert_equal "burst: 2.0", result
  end

  def test_flash_default
    result = @pad.flash
    assert_equal "flash!", result
  end

  def test_flash_with_intensity
    result = @pad.flash(1.5)
    assert_equal "flash: 1.5", result
  end

  def test_pending_actions_empty_initially
    assert_equal [], @pad.pending_actions
  end

  def test_burst_queues_plugin_action
    @pad.burst
    actions = @pad.pending_actions
    assert_equal 1, actions.length
    assert_equal :plugin, actions[0][:type]
    assert_equal :burst, actions[0][:name]
    impulse = actions[0][:effects][:impulse]
    assert_in_delta 1.0, impulse[:bass], 0.001
    assert_in_delta 1.0, impulse[:overall], 0.001
  end

  def test_burst_with_force_queues_correct_effects
    @pad.burst(2.5)
    actions = @pad.pending_actions
    impulse = actions[0][:effects][:impulse]
    assert_in_delta 2.5, impulse[:bass], 0.001
    assert_in_delta 2.5, impulse[:mid], 0.001
  end

  def test_flash_queues_plugin_action
    @pad.flash
    actions = @pad.pending_actions
    assert_equal 1, actions.length
    assert_equal :plugin, actions[0][:type]
    assert_equal :flash, actions[0][:name]
    assert_in_delta 1.0, actions[0][:effects][:bloom_flash], 0.001
  end

  def test_flash_with_intensity_queues_correct_effects
    @pad.flash(2.0)
    actions = @pad.pending_actions
    assert_in_delta 2.0, actions[0][:effects][:bloom_flash], 0.001
  end

  def test_consume_actions_returns_and_clears
    @pad.burst(1.0)
    @pad.flash(2.0)
    consumed = @pad.consume_actions
    assert_equal 2, consumed.length
    assert_equal :burst, consumed[0][:name]
    assert_equal :flash, consumed[1][:name]
    # After consume, should be empty
    assert_equal [], @pad.pending_actions
  end

  def test_burst_via_exec
    result = @pad.exec("burst")
    assert_equal true, result[:ok]
    assert_equal "burst!", result[:msg]
    assert_equal 1, @pad.pending_actions.length
  end

  def test_flash_via_exec
    result = @pad.exec("flash 2.0")
    assert_equal true, result[:ok]
    assert_equal "flash: 2.0", result[:msg]
  end

  # === Plugin delegation edge cases ===

  def test_unknown_command_returns_error
    result = @pad.exec("nonexistent_plugin_xyz")
    assert_equal false, result[:ok]
  end

  def test_plugin_responds_to
    assert @pad.respond_to?(:burst)
    assert @pad.respond_to?(:flash)
    assert_equal false, @pad.respond_to?(:nonexistent_plugin_xyz)
  end

  def test_multiple_plugin_actions_queued
    @pad.burst(1.0)
    @pad.flash(2.0)
    @pad.burst(0.5)
    actions = @pad.pending_actions
    assert_equal 3, actions.length
    assert_equal :burst, actions[0][:name]
    assert_equal :flash, actions[1][:name]
    assert_equal :burst, actions[2][:name]
  end

  def test_mixed_commands_and_plugins_via_exec
    result = @pad.exec("c 1; burst; flash 2.0")
    assert_equal true, result[:ok]
    assert_equal 1, ColorPalette.get_hue_mode
    assert_equal 2, @pad.pending_actions.length
  end

  # === i (info) reflects changed state ===

  def test_i_after_changes
    @pad.c(2)
    @pad.h(90)
    @pad.s(1.5)
    result = @pad.i
    assert_match(/c:yellow/, result)
    assert_match(/h:90\.0/, result)
    assert_match(/s:1\.5/, result)
  end

  # === mic command ===

  def test_mic_getter_default
    JS.set_global('micMuted', false)
    result = @pad.mic
    assert_equal "mic: on", result
  end

  def test_mic_getter_muted
    JS.set_global('micMuted', true)
    result = @pad.mic
    assert_equal "mic: muted", result
  end

  def test_mic_set_mute
    JS.set_global('micMuted', false)
    result = @pad.mic(0)
    assert_match(/mic:/, result)
  end

  def test_mic_set_unmute
    JS.set_global('micMuted', true)
    result = @pad.mic(1)
    assert_match(/mic:/, result)
  end

  def test_mic_via_exec
    JS.set_global('micMuted', false)
    result = @pad.exec("mic")
    assert_equal true, result[:ok]
    assert_equal "mic: on", result[:msg]
  end

  # === tab command ===

  def test_tab_getter_no_capture
    result = @pad.tab
    assert_equal "tab: off", result
  end

  def test_tab_getter_active
    JS.set_global('tabStream', 'active')
    result = @pad.tab
    assert_equal "tab: on", result
  end

  def test_tab_toggle_via_exec
    result = @pad.exec("tab")
    assert_equal true, result[:ok]
  end

  # === AudioInputManager integration tests ===

  def test_vj_pad_accepts_audio_input_manager
    manager = AudioInputManager.new
    _pad = VJPad.new(manager)
    # Should not raise
  end

  def test_mic_getter_reads_from_audio_input_manager
    manager = AudioInputManager.new
    pad = VJPad.new(manager)
    result = pad.mic
    assert_equal "mic: on", result  # default is unmuted

    manager.mute_mic
    result = pad.mic
    assert_equal "mic: muted", result
  end

  def test_mic_setter_updates_audio_input_manager_and_calls_js
    manager = AudioInputManager.new
    pad = VJPad.new(manager)

    # mic(0) should mute
    result = pad.mic(0)
    assert_equal true, manager.mic_muted?
    assert_match(/mic: muted/, result)

    # mic(1) should unmute
    result = pad.mic(1)
    assert_equal false, manager.mic_muted?
    assert_match(/mic: on/, result)
  end

  def test_tab_getter_reads_from_audio_input_manager
    manager = AudioInputManager.new
    pad = VJPad.new(manager)
    result = pad.tab
    assert_equal "tab: off", result  # default is :microphone

    manager.switch_to_tab
    result = pad.tab
    assert_equal "tab: on", result
  end

  def test_tab_setter_updates_audio_input_manager_and_calls_js
    manager = AudioInputManager.new
    pad = VJPad.new(manager)

    # tab(1) should switch to tab capture
    result = pad.tab(1)
    assert_equal :tab, manager.source
    assert_match(/tab:/, result)
  end

  def test_vj_pad_backward_compatibility_without_audio_input_manager
    pad = VJPad.new(nil)
    # Should not raise on other commands
    result = pad.c(1)
    assert_equal "color: red", result
  end

  # === New audio-reactive parameter commands ===

  def test_bbs_getter_default
    result = @pad.bbs
    assert_equal "bloom_base: 1.5", result
  end

  def test_bbs_setter
    result = @pad.bbs(3.0)
    assert_equal "bloom_base: 3.0", result
    assert_in_delta 3.0, VisualizerPolicy.bloom_base_strength, 0.001
  end

  def test_bes_getter_default
    result = @pad.bes
    assert_equal "bloom_energy: 2.5", result
  end

  def test_bes_setter
    result = @pad.bes(4.0)
    assert_equal "bloom_energy: 4.0", result
    assert_in_delta 4.0, VisualizerPolicy.bloom_energy_scale, 0.001
  end

  def test_bis_getter_default
    result = @pad.bis
    assert_equal "bloom_impulse: 1.5", result
  end

  def test_bis_setter
    result = @pad.bis(2.5)
    assert_equal "bloom_impulse: 2.5", result
    assert_in_delta 2.5, VisualizerPolicy.bloom_impulse_scale, 0.001
  end

  def test_pp_getter_default
    result = @pad.pp
    assert_equal "particle_prob: 0.2", result
  end

  def test_pp_setter
    result = @pad.pp(0.5)
    assert_equal "particle_prob: 0.5", result
    assert_in_delta 0.5, VisualizerPolicy.particle_explosion_base_prob, 0.001
  end

  def test_pf_getter_default
    result = @pad.pf
    assert_equal "particle_force: 0.55", result
  end

  def test_pf_setter
    result = @pad.pf(1.0)
    assert_equal "particle_force: 1.0", result
    assert_in_delta 1.0, VisualizerPolicy.particle_explosion_force_scale, 0.001
  end

  def test_fr_getter_default
    result = @pad.fr
    assert_equal "friction: 0.86", result
  end

  def test_fr_setter
    result = @pad.fr(0.75)
    assert_equal "friction: 0.75", result
    assert_in_delta 0.75, VisualizerPolicy.particle_friction, 0.001
  end

  def test_vs_getter_default
    result = @pad.vs
    assert_equal "smoothing: 0.7", result
  end

  def test_vs_setter
    result = @pad.vs(0.85)
    assert_equal "smoothing: 0.85", result
    assert_in_delta 0.85, VisualizerPolicy.visual_smoothing, 0.001
  end

  def test_id_getter_default
    result = @pad.id
    assert_equal "impulse_decay: 0.82", result
  end

  def test_id_setter
    result = @pad.id(0.90)
    assert_equal "impulse_decay: 0.9", result
    assert_in_delta 0.90, VisualizerPolicy.impulse_decay, 0.001
  end

  def test_new_commands_via_exec
    result = @pad.exec("bbs 2.0; bes 3.0; pp 0.4")
    assert_equal true, result[:ok]
    assert_in_delta 2.0, VisualizerPolicy.bloom_base_strength, 0.001
    assert_in_delta 3.0, VisualizerPolicy.bloom_energy_scale, 0.001
    assert_in_delta 0.4, VisualizerPolicy.particle_explosion_base_prob, 0.001
  end

  # === plugins command ===

  def test_plugins_lists_registered_plugins
    result = @pad.exec("plugins")
    assert_equal true, result[:ok]
    assert_match(/burst/, result[:msg])
    assert_match(/flash/, result[:msg])
  end

  def test_plugins_shows_descriptions
    result = @pad.plugins
    assert_match(/impulse/, result.downcase)
    assert_match(/bloom/, result.downcase)
  end

  def test_plugins_shows_param_info
    result = @pad.plugins
    assert_match(/force/, result)
    assert_match(/intensity/, result)
  end

  # --- WordArt unquoted text preprocessing ---

  def test_wa_with_unquoted_text_works
    $wordart_renderer = Object.new
    $wordart_renderer.define_singleton_method(:trigger) { |text| text }
    result = @pad.exec('wa hello')
    assert result[:ok], "wa hello should succeed, got: #{result[:msg]}"
    assert_match(/hello/, result[:msg])
  ensure
    $wordart_renderer = nil
  end

  def test_wa_with_unquoted_multiword_text_works
    $wordart_renderer = Object.new
    $wordart_renderer.define_singleton_method(:trigger) { |text| text }
    result = @pad.exec('wa hello world')
    assert result[:ok], "wa 'hello world' should succeed, got: #{result[:msg]}"
    assert_match(/hello world/, result[:msg])
  ensure
    $wordart_renderer = nil
  end

  def test_wa_with_quoted_text_still_works
    $wordart_renderer = Object.new
    $wordart_renderer.define_singleton_method(:trigger) { |text| text }
    result = @pad.exec('wa "hello"')
    assert result[:ok], "wa \"hello\" should succeed, got: #{result[:msg]}"
    assert_match(/hello/, result[:msg])
  ensure
    $wordart_renderer = nil
  end
end
