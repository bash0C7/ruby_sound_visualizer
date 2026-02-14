require_relative 'test_helper'

class TestPenInput < Test::Unit::TestCase
  def setup
    @pen = PenInput.new
  end

  # --- Initial state ---

  def test_initial_state_empty
    assert_equal false, @pen.has_visible_strokes?
    assert_equal 0, @pen.strokes.length
  end

  # --- Stroke creation ---

  def test_start_stroke_creates_new_stroke
    @pen.start_stroke(100.0, 200.0)
    assert_equal 1, @pen.strokes.length
    assert_equal [[100.0, 200.0]], @pen.strokes[0].points
  end

  def test_add_point_extends_stroke
    @pen.start_stroke(100.0, 200.0)
    @pen.add_point(110.0, 210.0)
    @pen.add_point(120.0, 220.0)
    assert_equal 3, @pen.strokes[0].points.length
  end

  def test_add_point_ignores_duplicate_positions
    @pen.start_stroke(100.0, 200.0)
    @pen.add_point(100.0, 200.0)
    assert_equal 1, @pen.strokes[0].points.length
  end

  def test_add_point_noop_when_not_drawing
    @pen.add_point(100.0, 200.0)
    assert_equal 0, @pen.strokes.length
  end

  def test_end_stroke_stops_drawing
    @pen.start_stroke(100.0, 200.0)
    @pen.end_stroke
    @pen.add_point(200.0, 300.0)
    # Point should not be added after end_stroke
    assert_equal 1, @pen.strokes[0].points.length
  end

  # --- Multiple strokes ---

  def test_multiple_strokes
    @pen.start_stroke(100.0, 200.0)
    @pen.add_point(110.0, 210.0)
    @pen.end_stroke

    @pen.start_stroke(300.0, 400.0)
    @pen.add_point(310.0, 410.0)
    @pen.end_stroke

    assert_equal 2, @pen.strokes.length
  end

  def test_max_strokes_limit
    (PenInput::MAX_STROKES + 5).times do |i|
      @pen.start_stroke(i.to_f, i.to_f)
      @pen.end_stroke
    end
    assert @pen.strokes.length <= PenInput::MAX_STROKES
  end

  # --- Fade-out ---

  def test_stroke_opacity_starts_at_one
    @pen.start_stroke(100.0, 200.0)
    assert_in_delta 1.0, @pen.strokes[0].opacity, 0.01
  end

  def test_stroke_fades_over_time
    @pen.start_stroke(100.0, 200.0)
    @pen.end_stroke
    (PenInput::FADE_DURATION_FRAMES / 2).times { @pen.update }
    assert @pen.strokes[0].opacity < 1.0
    assert @pen.strokes[0].opacity > 0.0
  end

  def test_stroke_removed_after_full_fade
    @pen.start_stroke(100.0, 200.0)
    @pen.end_stroke
    PenInput::FADE_DURATION_FRAMES.times { @pen.update }
    assert_equal 0, @pen.strokes.length
    assert_equal false, @pen.has_visible_strokes?
  end

  # --- Clear ---

  def test_clear_removes_all_strokes
    @pen.start_stroke(100.0, 200.0)
    @pen.start_stroke(200.0, 300.0)
    @pen.clear
    assert_equal 0, @pen.strokes.length
    assert_equal false, @pen.has_visible_strokes?
  end

  # --- Color ---

  def test_stroke_has_color
    @pen.start_stroke(100.0, 200.0)
    assert @pen.strokes[0].color.start_with?('hsl(')
  end

  def test_stroke_color_syncs_with_color_palette
    ColorPalette.set_hue_mode(1)  # Red mode
    @pen.start_stroke(100.0, 200.0)
    color1 = @pen.strokes[0].color
    @pen.end_stroke

    ColorPalette.set_hue_mode(3)  # Blue mode
    @pen.start_stroke(200.0, 300.0)
    color2 = @pen.strokes[1].color
    @pen.end_stroke

    # Different color modes should produce different colors
    assert color1 != color2

    # Clean up
    ColorPalette.set_hue_mode(nil)
  end

  # --- JSON rendering ---

  def test_to_render_json_empty
    json = @pen.to_render_json
    assert_equal '[]', json
  end

  def test_to_render_json_with_strokes
    @pen.start_stroke(100.0, 200.0)
    @pen.add_point(110.0, 210.0)
    json = @pen.to_render_json
    assert json.start_with?('[')
    assert json.end_with?(']')
    assert json.include?('"points"')
    assert json.include?('"color"')
    assert json.include?('"width"')
    assert json.include?('"opacity"')
  end

  def test_to_render_json_contains_point_coordinates
    @pen.start_stroke(100.0, 200.0)
    @pen.add_point(150.0, 250.0)
    json = @pen.to_render_json
    assert json.include?('100.0')
    assert json.include?('200.0')
    assert json.include?('150.0')
    assert json.include?('250.0')
  end

  # --- Has visible strokes ---

  def test_has_visible_strokes_true_when_drawing
    @pen.start_stroke(100.0, 200.0)
    assert_equal true, @pen.has_visible_strokes?
  end

  def test_has_visible_strokes_false_after_fade
    @pen.start_stroke(100.0, 200.0)
    @pen.end_stroke
    (PenInput::FADE_DURATION_FRAMES + 1).times { @pen.update }
    assert_equal false, @pen.has_visible_strokes?
  end
end
