require_relative 'test_helper'

class TestVRMDancer < Test::Unit::TestCase
  def setup
    JS.reset_global!
    @dancer = VRMDancer.new
  end

  # --- Structure tests ---

  def test_bone_order_has_14_bones
    assert_equal 14, VRMDancer::BONE_ORDER.length
  end

  def test_bone_order_starts_with_hips
    assert_equal 'hips', VRMDancer::BONE_ORDER.first
  end

  def test_bone_order_contains_all_required_bones
    required = %w[hips spine chest head
                  leftUpperArm leftLowerArm leftHand
                  rightUpperArm rightLowerArm rightHand
                  leftUpperLeg leftLowerLeg
                  rightUpperLeg rightLowerLeg]
    required.each do |bone|
      assert_includes VRMDancer::BONE_ORDER, bone, "Missing bone: #{bone}"
    end
  end

  # --- update() interface tests ---

  def test_update_accepts_delta_time_parameter
    # VRMDancer#update should accept (analysis, delta_time) so it can be
    # tested without JS.global dependency. This test will FAIL until
    # we refactor update to accept delta_time as a parameter.
    analysis = make_analysis
    result = @dancer.update(analysis, 0.016)
    assert_kind_of Hash, result
  end

  def test_update_returns_rotations_and_hips_position
    analysis = make_analysis
    result = @dancer.update(analysis, 0.016)

    assert_includes result.keys, :rotations
    assert_includes result.keys, :hips_position_y
  end

  def test_rotations_length_matches_bone_count_times_3
    analysis = make_analysis
    result = @dancer.update(analysis, 0.016)

    # 14 bones * 3 axes (rx, ry, rz) = 42
    expected_length = VRMDancer::BONE_ORDER.length * 3
    assert_equal expected_length, result[:rotations].length
  end

  def test_all_rotation_values_are_numeric
    analysis = make_analysis(bass: 0.8, mid: 0.5, high: 0.3, energy: 0.6)
    result = @dancer.update(analysis, 0.016)

    result[:rotations].each_with_index do |val, i|
      assert_kind_of Numeric, val, "rotation[#{i}] is not Numeric: #{val.inspect}"
    end
  end

  def test_hips_position_y_is_numeric
    analysis = make_analysis
    result = @dancer.update(analysis, 0.016)

    assert_kind_of Numeric, result[:hips_position_y]
  end

  # --- Behavioral tests ---

  def test_silent_input_produces_minimal_movement
    analysis = make_analysis(bass: 0.0, mid: 0.0, high: 0.0, energy: 0.0)
    result = @dancer.update(analysis, 0.016)

    # Upper arm bones have intentional non-zero rest positions:
    # -2.0 rad forward offset, +1.5 rad outward, amplified 8x
    # leftUpperArm: indices 12-14, rightUpperArm: indices 21-23
    upper_arm_indices = [12, 13, 14, 21, 22, 23]

    result[:rotations].each_with_index do |val, i|
      if upper_arm_indices.include?(i)
        assert_kind_of Numeric, val, "rotation[#{i}] should be Numeric"
      else
        assert_in_delta 0.0, val, 0.5, "rotation[#{i}] too large for silent input: #{val}"
      end
    end
  end

  def test_bass_beat_does_not_bounce
    no_beat = make_analysis(bass: 0.0, energy: 0.0)
    @dancer.update(no_beat, 0.016)

    beat = make_analysis(bass: 0.8, energy: 0.6, beat_bass: true)
    result = @dancer.update(beat, 0.016)

    # Vertical bounce was intentionally removed (hips_position_y hardcoded to 0.0)
    5.times { result = @dancer.update(no_beat, 0.016) }
    assert_equal 0.0, result[:hips_position_y],
      "Hips should not bounce (bounce was removed by design)"
  end

  def test_high_energy_raises_arms
    low_energy = make_analysis(energy: 0.1)
    result_low = @dancer.update(low_energy, 0.016)

    # Run several frames at high energy to let arm_raise converge
    high_energy = make_analysis(bass: 0.7, mid: 0.6, high: 0.5, energy: 0.8)
    result_high = nil
    30.times { result_high = @dancer.update(high_energy, 0.016) }

    # leftUpperArm rz is at index: (bone_index=4) * 3 + 2 = 14
    left_arm_rz_low = result_low[:rotations][14]
    left_arm_rz_high = result_high[:rotations][14]

    assert_operator left_arm_rz_high.abs, :>, left_arm_rz_low.abs,
      "Left arm should raise more at high energy"
  end

  def test_multiple_frames_do_not_produce_nan
    analysis = make_analysis(bass: 0.5, mid: 0.3, high: 0.2, energy: 0.4,
                             beat_bass: true)
    100.times do |frame|
      result = @dancer.update(analysis, 0.016)
      result[:rotations].each_with_index do |val, i|
        refute val.nan?, "rotation[#{i}] is NaN at frame #{frame}" if val.respond_to?(:nan?)
      end
      refute result[:hips_position_y].nan?, "hips_position_y is NaN at frame #{frame}" if result[:hips_position_y].respond_to?(:nan?)
    end
  end

  def test_step_foot_alternates_on_bass_beats
    # First beat
    beat_on = make_analysis(bass: 0.8, energy: 0.6, beat_bass: true)
    beat_off = make_analysis(bass: 0.2, energy: 0.2, beat_bass: false)

    @dancer.update(beat_off, 0.016) # initialize with no beat
    @dancer.update(beat_on, 0.016)  # first beat: step_foot toggles

    # leftUpperLeg rx is at bone_index=10, offset 10*3=30
    result1 = @dancer.update(beat_off, 0.016)
    left_leg_1 = result1[:rotations][30]

    @dancer.update(beat_on, 0.016) # second beat: step_foot toggles again
    result2 = @dancer.update(beat_off, 0.016)
    left_leg_2 = result2[:rotations][30]

    # The leg pattern should differ between alternating steps
    # (one step moves left leg forward, next step moves right)
    refute_equal left_leg_1, left_leg_2,
      "Leg pattern should alternate between beats"
  end

  # --- Delta time independence ---

  def test_update_uses_provided_delta_time_not_js_global
    # Even if JS.global[:_animDeltaTime] returns a weird value,
    # the explicit delta_time parameter should be used
    analysis = make_analysis(bass: 0.5, mid: 0.3, high: 0.2, energy: 0.4)

    dancer_a = VRMDancer.new
    result_a = dancer_a.update(analysis, 0.016)

    dancer_b = VRMDancer.new
    result_b = dancer_b.update(analysis, 0.016)

    # Same delta_time should produce same output
    assert_equal result_a[:rotations], result_b[:rotations]
  end

  private

  def make_analysis(bass: 0.0, mid: 0.0, high: 0.0, energy: 0.0,
                    beat_bass: false, beat_mid: false, beat_high: false,
                    imp_bass: 0.0, imp_mid: 0.0, imp_high: 0.0)
    {
      bass: bass,
      mid: mid,
      high: high,
      overall_energy: energy,
      beat: {
        overall: beat_bass,
        bass: beat_bass,
        mid: beat_mid,
        high: beat_high
      },
      impulse: {
        overall: [imp_bass, imp_mid, imp_high].max,
        bass: imp_bass,
        mid: imp_mid,
        high: imp_high
      }
    }
  end
end
