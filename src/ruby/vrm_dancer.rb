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

    rotations = []

    # hips (gentle sway and twist - natural human range)
    rotations.concat([
      Math.sin(@beat_phase * 0.8) * 0.02,   # Forward/back tilt (±9° after 8x)
      Math.sin(@sway_phase) * 0.08,         # Left/right twist (±37° after 8x)
      0
    ])

    # spine (twist with hips - natural human range)
    sway = Math.sin(@beat_phase * 0.9) * 0.07  # Twist (±32° after 8x)
    rotations.concat([
      Math.sin(@beat_phase * 1.2) * 0.04,       # Forward/back (±18° after 8x)
      Math.sin(@sway_phase * 1.1) * 0.08,       # Left/right twist (±37° after 8x)
      sway
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

    # left upper arm (gentle swing - natural human range)
    # Z rotation: -0.02 to 0.08 rad → -9° to 37° after 8x amplification
    arm_wave = Math.sin(@beat_phase * 0.8) * 0.04  # Slow wave (±18° after 8x)
    raise_l = @arm_raise  # Smoothed raise cycle
    rotations.concat([
      Math.sin(@beat_phase * 1.0) * 0.03,       # Forward/back swing (±14° after 8x)
      Math.sin(@sway_phase * 0.9) * 0.02,       # Inward/outward (±9° after 8x)
      -0.01 + arm_wave + raise_l                # From relaxed down to raised
    ])

    # left lower arm (natural elbow bend - human range: 0-145°)
    # 0.02 to 0.08 rad → 9° to 37° after 8x amplification
    elbow_l = 0.03 + Math.sin(@beat_phase * 1.2 + 0.3) * 0.03
    rotations.concat([0, 0, elbow_l])

    # left hand
    rotations.concat([0, 0, 0])

    # right upper arm (mirror)
    rotations.concat([
      Math.sin(@beat_phase * 1.0) * 0.03,
      Math.sin(@sway_phase * 0.9 + Math::PI) * 0.02,
      -(-0.01 + arm_wave + raise_l)  # Mirror
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
      blink: @blink_value
    }
  end
end
  
