class VRMDancer
  BONE_ORDER = %w[
    hips spine chest head
    leftUpperArm leftLowerArm leftHand
    rightUpperArm rightLowerArm rightHand
    leftUpperLeg leftLowerLeg
    rightUpperLeg rightLowerLeg
  ]

  MOTION_SPEED = 4.0
  ROTATION_AMPLIFY = 8.0
  SMOOTHING_FACTOR = 8.0

  def initialize
    @time = 0.0
    @beat_phase = 0.0
    @sway_phase = 0.0
    @head_nod_phase = 0.0
    @step_phase = 0.0
    @arm_raise = 0.0
    @blink_timer = 0.0
    @blink_value = 0.0
    @mouth_phase = 0.0
    @mouth_open_vertical = 0.0
    @mouth_open_horizontal = 0.0
    @prev_rotations = Array.new(BONE_ORDER.length * 3, 0.0)
  end

  def update(analysis, delta_time = nil)
    if delta_time
      delta = delta_time.to_f
    else
      dt = JS.global[:_animDeltaTime]
      delta = dt.typeof == "number" ? dt.to_f : 0.033
    end
    delta = [[delta, 0.001].max, 0.1].min

    @time += delta
    update_phases(delta)
    update_face(delta)

    rotations = build_rotations
    smoothed = apply_smoothing(rotations, delta)

    {
      rotations: smoothed.map { |r| r * ROTATION_AMPLIFY },
      hips_position_y: 0.0,
      blink: @blink_value,
      mouth_open_vertical: @mouth_open_vertical,
      mouth_open_horizontal: @mouth_open_horizontal
    }
  end

  private

  def update_phases(delta)
    @beat_phase += delta * 0.8 * MOTION_SPEED
    @sway_phase += delta * 0.5 * MOTION_SPEED
    @head_nod_phase += delta * 1.2 * MOTION_SPEED
    @step_phase += delta * Math::PI / 2.0 * MOTION_SPEED

    arm_target = (Math.sin(@time * 0.8) + 1.0) * 0.10
    @arm_raise = MathHelper.lerp(@arm_raise, arm_target, 2.0 * delta)
  end

  def update_face(delta)
    @blink_timer += delta
    if @blink_timer > 3.0 + Math.sin(@time * 0.5) * 1.0
      @blink_timer = 0.0
      @blink_value = 1.0
    end
    @blink_value = [@blink_value - delta * 8.0, 0.0].max if @blink_value > 0.0

    @mouth_phase += delta * 1.0
    @mouth_open_vertical = (Math.sin(@mouth_phase) + 1.0) * 0.4
    @mouth_open_horizontal = (Math.sin(@mouth_phase + Math::PI / 2) + 1.0) * 0.3
  end

  def build_rotations
    rotations = []
    rotations.concat(build_torso)
    rotations.concat(build_arms)
    rotations.concat(build_legs)
    rotations
  end

  def build_torso
    sway = Math.sin(@beat_phase * 0.9) * 0.10
    head_nod = Math.sin(@head_nod_phase) * 0.03
    head_turn = Math.sin(@sway_phase * 0.6) * 0.04

    [
      # hips
      Math.sin(@beat_phase * 0.8) * 0.03,
      Math.sin(@sway_phase) * 0.12,
      Math.sin(@beat_phase * 0.6) * 0.04,
      # spine
      Math.sin(@beat_phase * 1.2) * 0.05,
      Math.sin(@sway_phase * 1.1) * 0.12,
      sway + Math.sin(@sway_phase * 0.7) * 0.05,
      # chest (counter-rotate)
      0,
      -Math.sin(@sway_phase * 1.1) * 0.04,
      -sway * 0.5,
      # head
      head_nod + Math.sin(@beat_phase * 1.5) * 0.03,
      head_turn,
      Math.sin(@beat_phase) * 0.02,
    ]
  end

  def build_arms
    arm_swing_x = Math.sin(@sway_phase) * 0.02
    arm_swing_y = Math.cos(@sway_phase) * 0.15
    arm_wave = Math.sin(@beat_phase * 0.8) * 0.02
    raise_l = @arm_raise * 0.5
    max_raise = 0.1

    x_forward_bonus = raise_l * 0.6
    y_outward_bonus = (max_raise - raise_l) * 0.4

    elbow_twist = Math.sin(@sway_phase * 1.3) * 0.02
    elbow_l = 0.06 + Math.sin(@beat_phase * 1.2 + 0.3) * 0.06
    elbow_r = 0.06 + Math.sin(@beat_phase * 1.2 - 0.3) * 0.06
    wrist_bend = Math.sin(@beat_phase * 1.5 + 0.5) * 0.02
    wrist_twist = Math.cos(@sway_phase * 1.4) * 0.015

    [
      # left upper arm
      0.40 + arm_swing_x + x_forward_bonus - 2.0,
      0.44 + arm_swing_y + y_outward_bonus + 1.5,
      0.15 + arm_wave + raise_l * 2.0,
      # left lower arm
      0, elbow_twist, elbow_l,
      # left hand
      0, wrist_twist, wrist_bend,
      # right upper arm (mirror)
      0.40 + arm_swing_x + x_forward_bonus - 2.0,
      -0.44 + Math.cos(@sway_phase + Math::PI) * 0.15 - y_outward_bonus - 1.5,
      0.15 + arm_wave + raise_l * 2.0,
      # right lower arm
      0, -elbow_twist, -elbow_r,
      # right hand
      0, -wrist_twist, -wrist_bend,
    ]
  end

  def build_legs
    step_sin = Math.sin(@step_phase)
    step_forward = step_sin * 0.08
    step_open = Math.sin(@beat_phase * 0.7) * 0.04
    leg_sway_lr = Math.sin(@sway_phase) * 0.03
    leg_lift = Math.cos(@step_phase) * 0.04

    left_knee = 0.04 + [0.0, -step_sin * 0.04].max
    right_knee = 0.04 + [0.0, step_sin * 0.04].max
    knee_sway = Math.sin(@sway_phase) * 0.02

    [
      # left upper leg
      -step_forward,
      -step_open + leg_sway_lr,
      leg_lift,
      # left lower leg
      left_knee, knee_sway, 0,
      # right upper leg (mirror)
      step_forward,
      step_open - leg_sway_lr,
      -leg_lift,
      # right lower leg
      right_knee, -knee_sway, 0,
    ]
  end

  def apply_smoothing(rotations, delta)
    rotations.each_with_index.map do |target, i|
      smoothed = MathHelper.lerp(@prev_rotations[i], target, SMOOTHING_FACTOR * delta)
      @prev_rotations[i] = smoothed
      smoothed
    end
  end
end
