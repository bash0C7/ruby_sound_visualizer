require_relative 'test_helper'

class TestWordartRenderer < Test::Unit::TestCase
  def setup
    @renderer = WordartRenderer.new
  end

  # --- Initial state ---

  def test_initial_state_inactive
    assert_equal false, @renderer.active?
    assert_equal :none, @renderer.phase
  end

  # --- Trigger ---

  def test_trigger_activates_animation
    @renderer.trigger("Hello World")
    assert_equal true, @renderer.active?
    assert_equal :entrance, @renderer.phase
    assert_equal "Hello World", @renderer.text
  end

  def test_trigger_strips_whitespace
    @renderer.trigger("  test  ")
    assert_equal "test", @renderer.text
  end

  def test_trigger_ignores_empty_text
    @renderer.trigger("")
    assert_equal false, @renderer.active?
  end

  def test_trigger_ignores_nil
    @renderer.trigger(nil)
    assert_equal false, @renderer.active?
  end

  def test_trigger_cycles_styles
    @renderer.trigger("one")
    idx1 = @renderer.style_index
    @renderer.trigger("two")
    idx2 = @renderer.style_index
    assert idx1 != idx2
  end

  def test_trigger_with_explicit_style_index
    @renderer.trigger("test", style_index: 2)
    # After trigger, style_index advances to 3
    assert_equal 3, @renderer.style_index
  end

  # --- Animation phases ---

  def test_entrance_transitions_to_sustain
    @renderer.trigger("test")
    assert_equal :entrance, @renderer.phase

    # Advance through entrance
    WordartRenderer::ENTRANCE_FRAMES.times { @renderer.update }
    assert_equal :sustain, @renderer.phase
  end

  def test_sustain_transitions_to_exit
    @renderer.trigger("test")
    WordartRenderer::ENTRANCE_FRAMES.times { @renderer.update }
    assert_equal :sustain, @renderer.phase

    WordartRenderer::SUSTAIN_FRAMES.times { @renderer.update }
    assert_equal :exit, @renderer.phase
  end

  def test_exit_transitions_to_none
    @renderer.trigger("test")
    total = WordartRenderer::ENTRANCE_FRAMES + WordartRenderer::SUSTAIN_FRAMES + WordartRenderer::EXIT_FRAMES
    total.times { @renderer.update }
    assert_equal :none, @renderer.phase
    assert_equal false, @renderer.active?
  end

  def test_full_lifecycle_frame_count
    @renderer.trigger("test")
    total = WordartRenderer::ENTRANCE_FRAMES + WordartRenderer::SUSTAIN_FRAMES + WordartRenderer::EXIT_FRAMES
    total.times { @renderer.update }
    assert_equal false, @renderer.active?
  end

  # --- Update with audio ---

  def test_update_with_analysis_data
    @renderer.trigger("test")
    analysis = { overall_energy: 0.8, bass: 0.5, mid: 0.3, high: 0.2 }
    @renderer.update(analysis)
    assert_equal :entrance, @renderer.phase
  end

  def test_update_noop_when_inactive
    @renderer.update
    assert_equal false, @renderer.active?
  end

  # --- Stop ---

  def test_stop_immediately_deactivates
    @renderer.trigger("test")
    assert_equal true, @renderer.active?
    @renderer.stop
    assert_equal false, @renderer.active?
  end

  # --- Render data ---

  def test_render_data_nil_when_inactive
    assert_nil @renderer.render_data
  end

  def test_render_data_includes_text
    @renderer.trigger("Hello")
    data = @renderer.render_data
    assert_equal "Hello", data[:text]
  end

  def test_render_data_includes_font_properties
    @renderer.trigger("test")
    data = @renderer.render_data
    assert data.key?(:fontSize)
    assert data.key?(:fontFamily)
    assert data.key?(:bold)
  end

  def test_render_data_includes_gradient
    @renderer.trigger("test")
    data = @renderer.render_data
    assert data.key?(:gradient)
    assert data[:gradient].key?(:type)
    assert data[:gradient].key?(:stops)
  end

  def test_render_data_includes_outline
    @renderer.trigger("test")
    data = @renderer.render_data
    assert data.key?(:outlineColor)
    assert data.key?(:outlineWidth)
  end

  def test_render_data_entrance_has_animation_properties
    @renderer.trigger("test")
    data = @renderer.render_data
    # Should have at least opacity and scale
    assert data.key?(:opacity) || data.key?(:scale)
  end

  def test_render_data_sustain_has_full_opacity
    @renderer.trigger("test")
    WordartRenderer::ENTRANCE_FRAMES.times { @renderer.update }
    data = @renderer.render_data
    assert_in_delta 1.0, data[:opacity], 0.01
  end

  def test_render_data_exit_fading
    @renderer.trigger("test")
    (WordartRenderer::ENTRANCE_FRAMES + WordartRenderer::SUSTAIN_FRAMES).times { @renderer.update }
    # Advance partway through exit
    (WordartRenderer::EXIT_FRAMES / 2).times { @renderer.update }
    data = @renderer.render_data
    assert data[:opacity] < 1.0 if data[:opacity]
  end

  # --- JSON serialization ---

  def test_to_render_json_returns_string
    @renderer.trigger("test")
    json = @renderer.to_render_json
    assert_instance_of String, json
    assert json.include?('"text"')
    assert json.include?('test')
  end

  def test_to_render_json_empty_when_inactive
    json = @renderer.to_render_json
    assert_equal '{}', json
  end

  def test_to_render_json_valid_format
    @renderer.trigger("Hello World")
    json = @renderer.to_render_json
    # Should be parseable JSON-like structure
    assert json.start_with?('{')
    assert json.end_with?('}')
    assert json.include?('"text":"Hello World"')
  end

  # --- JSON escape handling (B-3) ---

  def test_to_render_json_escapes_newlines
    @renderer.trigger("Hello\nWorld")
    @renderer.update
    json = @renderer.to_render_json
    assert json.include?('\\n'), "newlines should be escaped"
    assert !json.include?("\n" + '"'), "raw newlines should not appear in JSON values"
  end

  def test_to_render_json_escapes_tabs
    @renderer.trigger("Hello\tWorld")
    @renderer.update
    json = @renderer.to_render_json
    assert json.include?('\\t'), "tabs should be escaped"
  end

  def test_to_render_json_escapes_quotes
    @renderer.trigger('Say "Hello"')
    @renderer.update
    json = @renderer.to_render_json
    assert json.include?('\\"Hello\\"'), "quotes should be escaped"
  end

  def test_to_render_json_escapes_backslash
    @renderer.trigger('path\\to\\file')
    @renderer.update
    json = @renderer.to_render_json
    assert json.include?('\\\\'), "backslashes should be escaped"
  end

  # --- Style cycling ---

  def test_styles_cycle_through_all
    indices = []
    (WordartRenderer::STYLES.length + 1).times do |i|
      @renderer.trigger("test#{i}")
      indices << @renderer.style_index
    end
    # Should cycle back to beginning
    assert_equal indices[0], indices[WordartRenderer::STYLES.length]
  end
end
