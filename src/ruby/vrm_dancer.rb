class VRMDancer
  # Bone order must match JavaScript VRM_BONE_ORDER
  BONE_ORDER = %w[
    hips spine chest head
    leftUpperArm leftLowerArm leftHand
    rightUpperArm rightLowerArm rightHand
    leftUpperLeg leftLowerLeg
    rightUpperLeg rightLowerLeg
  ]

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
    @beat_phase += delta * 0.8       # Main body rhythm (~7.5 sec cycle)
    @sway_phase += delta * 0.5       # Gentle sway (~12 sec cycle)
    @head_nod_phase += delta * 1.2   # Head movement (~5 sec cycle)
    @step_phase += delta * Math::PI / 2.0  # Leg step phase (~4 sec full cycle)

    # Arm raise cycles smoothly (0 to 0.3 over 8 seconds)
    arm_target = (Math.sin(@time * 0.8) + 1.0) * 0.15  # 0.0 to 0.3
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

    # left upper arm (natural human range - 前方 + 小 swing、横に超大きく広げる)
    # Z rotation: 腕を下げる（頭にめり込まないように）
    arm_wave = Math.sin(@beat_phase * 0.8) * 0.02  # Slow wave (小さく) ±9° after 8x
    raise_l = @arm_raise * 0.3  # Raise を抑える（頭にめり込まない）
    rotations.concat([
      0.17 + Math.sin(@beat_phase * 1.0) * 0.01,  # Forward + 小 swing (後ろ倒れず) 73°-82° after 8x
      0.20 + Math.sin(@sway_phase * 0.9) * 0.05,  # Outward (クロスせず横に超広げる) 69°-115° after 8x
      -0.05 + arm_wave + raise_l                  # 下げる（頭にめり込まない） -23° to 9° after 8x
    ])

    # left lower arm (natural elbow bend - human range: 0-145°)
    # 0.02 to 0.08 rad → 9° to 37° after 8x amplification
    elbow_l = 0.03 + Math.sin(@beat_phase * 1.2 + 0.3) * 0.03
    rotations.concat([0, 0, elbow_l])

    # left hand
    rotations.concat([0, 0, 0])

    # right upper arm (mirror)
    rotations.concat([
      0.17 + Math.sin(@beat_phase * 1.0) * 0.01,  # Forward + 小 swing (後ろ倒れず) same as left
      -0.20 + Math.sin(@sway_phase * 0.9 + Math::PI) * 0.05,  # Outward (クロスせず横に超広げる) mirrored
      -(-0.05 + arm_wave + raise_l)  # Mirror Z rotation (下げる)
    ])

    # right lower arm (natural elbow bend)
    elbow_r = 0.03 + Math.sin(@beat_phase * 1.2 - 0.3) * 0.03
    rotations.concat([0, 0, -elbow_r])

    # right hand
    rotations.concat([0, 0, 0])

    # legs - smooth alternating step using sin wave (natural human range)
    # Hip extension/flexion: ±145°, Knee flexion: 0-145°
    step_sin = Math.sin(@step_phase)  # -1 to 1, smooth transition
    step_forward = step_sin * 0.04    # ±18° after 8x (smooth left/right)
    step_open = Math.sin(@beat_phase * 0.7) * 0.02  # Open/close (±9° after 8x)

    # Left leg: forward when step_sin > 0, back when step_sin < 0
    # Right leg: opposite
    rotations.concat([
      -step_forward,           # Left upper leg (smooth forward/back)
      -step_open,              # Left leg slightly inward (Y-axis)
      0
    ])
    # Left knee bend: more when leg is back (step_sin < 0)
    left_knee = 0.02 + [0.0, -step_sin * 0.02].max
    rotations.concat([left_knee, 0, 0])

    rotations.concat([
      step_forward,            # Right upper leg (opposite of left)
      step_open,               # Right leg slightly outward (Y-axis)
      0
    ])
    # Right knee bend: more when leg is back (step_sin > 0)
    right_knee = 0.02 + [0.0, step_sin * 0.02].max
    rotations.concat([right_knee, 0, 0])

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
  
