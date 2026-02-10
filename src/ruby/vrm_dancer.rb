class VRMDancer
  # Bone order must match JavaScript VRM_BONE_ORDER
  BONE_ORDER = %w[
    hips spine chest head
    leftUpperArm leftLowerArm leftHand
    rightUpperArm rightLowerArm rightHand
    leftUpperLeg leftLowerLeg
    rightUpperLeg rightLowerLeg
  ]

  # Motion speed multiplier (centralized parameter)
  MOTION_SPEED = 4.0

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

    # Smoothing state for natural movement (store previous rotation targets)
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

    # VRM dances with constant rhythm (independent of audio)
    # Use fixed periods for natural human movement

    # Constant phase accumulators (independent of audio)
    # Speed controlled by MOTION_SPEED constant
    @beat_phase += delta * 0.8 * MOTION_SPEED       # Main body rhythm
    @sway_phase += delta * 0.5 * MOTION_SPEED       # Gentle sway
    @head_nod_phase += delta * 1.2 * MOTION_SPEED   # Head movement
    @step_phase += delta * Math::PI / 2.0 * MOTION_SPEED  # Leg step phase

    # Arm raise cycles smoothly (0 to 0.2 over 8 seconds)
    arm_target = (Math.sin(@time * 0.8) + 1.0) * 0.10  # 0.0 to 0.2
    @arm_raise = MathHelper.lerp(@arm_raise, arm_target, 2.0 * delta)

    # Blink periodically (2-4 seconds interval)
    @blink_timer += delta
    if @blink_timer > 3.0 + Math.sin(@time * 0.5) * 1.0  # Random 2-4 sec interval
      @blink_timer = 0.0
      @blink_value = 1.0  # Trigger blink
    end

    # Blink decay (fast close, slower open)
    if @blink_value > 0.0
      @blink_value = [@blink_value - delta * 8.0, 0.0].max  # Decay in ~0.125 sec
    end

    # Mouth motion (open/close cycle)
    @mouth_phase += delta * 1.0  # Mouth cycle (~6 sec)
    # Vertical mouth open (aa sound): 0.0 to 0.8
    @mouth_open_vertical = (Math.sin(@mouth_phase) + 1.0) * 0.4  # 0.0 to 0.8
    # Horizontal mouth open (ee sound): 0.0 to 0.6
    @mouth_open_horizontal = (Math.sin(@mouth_phase + Math::PI / 2) + 1.0) * 0.3  # 0.0 to 0.6

    rotations = []

    # hips (sway, twist, and tilt - natural human range)
    rotations.concat([
      Math.sin(@beat_phase * 0.8) * 0.03,   # Forward/back tilt (±14° after 8x)
      Math.sin(@sway_phase) * 0.12,         # Left/right twist (±55° after 8x)
      Math.sin(@beat_phase * 0.6) * 0.04    # Left/right lean (±18° after 8x)
    ])

    # spine (twist with hips - natural human range)
    sway = Math.sin(@beat_phase * 0.9) * 0.10  # Twist (±46° after 8x)
    rotations.concat([
      Math.sin(@beat_phase * 1.2) * 0.05,        # Forward/back (±23° after 8x)
      Math.sin(@sway_phase * 1.1) * 0.12,        # Left/right twist (±55° after 8x)
      sway + Math.sin(@sway_phase * 0.7) * 0.05  # Twist + lean (±32-55° after 8x)
    ])

    # chest (subtle counter-rotate for natural movement)
    rotations.concat([
      0,
      -Math.sin(@sway_phase * 1.1) * 0.04,      # Counter-rotate (±18° after 8x)
      -sway * 0.5
    ])

    # head (gentle nods and turns - natural human range)
    head_nod = Math.sin(@head_nod_phase) * 0.03        # Nod (±14° after 8x)
    head_turn = Math.sin(@sway_phase * 0.6) * 0.04     # Turn (±18° after 8x)
    rotations.concat([
      head_nod + Math.sin(@beat_phase * 1.5) * 0.03,   # Combined nod
      head_turn,                                         # Gentle turn
      Math.sin(@beat_phase) * 0.02                      # Slight tilt (±9° after 8x)
    ])

    # left upper arm - ダンサブルな動き（周期的に上下しつつ、高さに応じて前傾・横広げ）
    # 腕を常に前方に（体の横より前）
    arm_swing_x = Math.sin(@sway_phase) * 0.02             # 前方で小さく揺れる ±9° after 8x（減らして常に前方）
    arm_swing_y = Math.cos(@sway_phase) * 0.15             # 外側から内側へ大きく ±68° after 8x
    arm_wave = Math.sin(@beat_phase * 0.8) * 0.02         # 上下の波 ±9° after 8x
    raise_l = @arm_raise * 0.5  # 0.0 (下) to 0.1 (上)
    max_raise = 0.1  # raise_l の最大値

    # raise_l に応じた調整
    x_forward_bonus = raise_l * 0.6       # 上のとき前に +30deg (0.0 to 0.06 rad)
    y_outward_bonus = (max_raise - raise_l) * 0.4  # 下のとき横に広げる (0.04 to 0.0)

    rotations.concat([
      0.40 + arm_swing_x + x_forward_bonus - 2.0, # 前方に出す（-2.0 rad で spine より前方へ）
      0.44 + arm_swing_y + y_outward_bonus + 1.5, # 横に広げる（+1.5 rad で外側へ）
      0.15 + arm_wave + raise_l * 2.0             # 周期的に上下
    ])

    # left lower arm (natural elbow bend with subtle rotation)
    # 肘をもっと曲げる（機械的に見えないように）
    elbow_l = 0.06 + Math.sin(@beat_phase * 1.2 + 0.3) * 0.06  # Bend (Z-axis, 2x)
    elbow_twist = Math.sin(@sway_phase * 1.3) * 0.02           # Twist (Y-axis, 2x)
    rotations.concat([0, elbow_twist, elbow_l])

    # left hand (wrist - natural relaxed bend)
    wrist_bend = Math.sin(@beat_phase * 1.5 + 0.5) * 0.02      # Gentle bend
    wrist_twist = Math.cos(@sway_phase * 1.4) * 0.015          # Gentle twist
    rotations.concat([0, wrist_twist, wrist_bend])

    # right upper arm (mirror) - ダンサブルな動き
    rotations.concat([
      0.40 + arm_swing_x + x_forward_bonus - 2.0,  # 前方に出す（-2.0 rad で spine より前方へ）
      -0.44 + Math.cos(@sway_phase + Math::PI) * 0.15 - y_outward_bonus - 1.5,  # 横に広げる（-1.5 rad で外側へ）
      0.15 + arm_wave + raise_l * 2.0              # 周期的に上下 (same as left)
    ])

    # right lower arm (natural elbow bend with subtle rotation)
    # 肘をもっと曲げる（機械的に見えないように）
    elbow_r = 0.06 + Math.sin(@beat_phase * 1.2 - 0.3) * 0.06  # Bend (Z-axis, 2x)
    rotations.concat([0, -elbow_twist, -elbow_r])

    # right hand (wrist - natural relaxed bend)
    rotations.concat([0, -wrist_twist, -wrist_bend])

    # legs - smooth alternating step with up/down and left/right sway (natural human range)
    # 係数を2倍にしてダンサブルに
    step_sin = Math.sin(@step_phase)  # -1 to 1, smooth transition
    step_forward = step_sin * 0.08    # ±36° after 8x (smooth left/right, 2x)
    step_open = Math.sin(@beat_phase * 0.7) * 0.04  # Open/close (±18° after 8x, 2x)
    leg_sway_lr = Math.sin(@sway_phase) * 0.03  # 左右の揺れ ±14° after 8x (2x)
    leg_lift = Math.cos(@step_phase) * 0.04  # 上下の動き ±18° after 8x (2x)

    # Left leg: forward when step_sin > 0, back when step_sin < 0
    rotations.concat([
      -step_forward,           # Left upper leg (smooth forward/back)
      -step_open + leg_sway_lr,  # Left leg: inward + 左右揺れ
      leg_lift                 # 上下の動き
    ])
    # Left knee: bend + subtle up/down and left/right (2x for danceable movement)
    left_knee = 0.04 + [0.0, -step_sin * 0.04].max  # Bend (2x)
    knee_sway = Math.sin(@sway_phase) * 0.02  # 膝の左右揺れ ±9° after 8x (2x)
    rotations.concat([left_knee, knee_sway, 0])

    # Right leg: opposite of left
    rotations.concat([
      step_forward,            # Right upper leg (opposite of left)
      step_open - leg_sway_lr,   # Right leg: outward + 左右揺れ (opposite sway)
      -leg_lift                # 上下の動き (opposite)
    ])
    # Right knee: bend + subtle up/down and left/right (2x for danceable movement)
    right_knee = 0.04 + [0.0, step_sin * 0.04].max  # Bend (2x)
    rotations.concat([right_knee, -knee_sway, 0])

    # Apply smoothing to rotations (natural human movement has inertia)
    smoothing_factor = 8.0  # Higher = slower response, smoother movement
    smoothed_rotations = []
    rotations.each_with_index do |target, i|
      smoothed = MathHelper.lerp(@prev_rotations[i], target, smoothing_factor * delta)
      smoothed_rotations << smoothed
      @prev_rotations[i] = smoothed
    end

    # Amplify rotations for visibility (8x for natural movement)
    amplified_rotations = smoothed_rotations.map { |r| r * 8.0 }

    {
      rotations: amplified_rotations,
      hips_position_y: 0.0,  # No vertical bounce
      blink: @blink_value,
      mouth_open_vertical: @mouth_open_vertical,
      mouth_open_horizontal: @mouth_open_horizontal
    }
  end
end
  
