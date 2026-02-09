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
    @bounce_vel = 0.0
    @bounce_pos = 0.0
    @arm_raise = 0.0
    @step_foot = 0
    @last_beat_bass = false
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

    bass = analysis[:bass] || 0.0
    mid = analysis[:mid] || 0.0
    high = analysis[:high] || 0.0
    energy = analysis[:overall_energy] || 0.0
    impulse = analysis[:impulse] || {}
    imp_bass = impulse[:bass] || 0.0
    imp_mid = impulse[:mid] || 0.0
    imp_high = impulse[:high] || 0.0
    beat = analysis[:beat] || {}

    # Rhythmic phase accumulators
    @beat_phase += delta * (3.0 + energy * 3.0)
    @sway_phase += delta * 1.5

    # Trigger bounce on bass beat
    if beat[:bass] && !@last_beat_bass
      @bounce_vel = -(0.08 + bass * 0.12)
      @step_foot = 1 - @step_foot
    end
    @last_beat_bass = beat[:bass] || false

    # Bounce spring physics
    @bounce_vel += -@bounce_pos * 25.0 * delta
    @bounce_vel *= (1.0 - 5.0 * delta)
    @bounce_pos += @bounce_vel

    # Arm raise tracks energy
    arm_target = energy > 0.4 ? (energy - 0.2) * 1.0 : 0.0
    @arm_raise = MathHelper.lerp(@arm_raise, arm_target, 3.0 * delta)

    rotations = []

    # hips
    rotations.concat([
      0,
      Math.sin(@sway_phase) * mid * 0.15,
      0
    ])

    # spine
    sway = Math.sin(@beat_phase) * mid * 0.12
    rotations.concat([
      Math.sin(@beat_phase * 2) * bass * 0.08,
      Math.sin(@sway_phase * 1.3) * mid * 0.15,
      sway
    ])

    # chest (counter-rotate)
    rotations.concat([
      0,
      -Math.sin(@sway_phase * 1.3) * mid * 0.08,
      -sway * 0.5
    ])

    # head
    rotations.concat([
      Math.sin(@beat_phase * 2) * bass * 0.12 + imp_bass * 0.08,
      Math.sin(@sway_phase * 0.7) * 0.1,
      Math.sin(@beat_phase) * high * 0.06
    ])

    # left upper arm
    arm_pump = Math.sin(@beat_phase * 2) * energy * 0.25
    raise_l = @arm_raise + Math.sin(@beat_phase * 2 + 0.5) * energy * 0.2
    rotations.concat([
      arm_pump + imp_bass * 0.15,
      0,
      0.3 + raise_l
    ])

    # left lower arm
    elbow_l = 0.2 + Math.sin(@beat_phase * 2 + 0.3) * energy * 0.3
    rotations.concat([0, 0, elbow_l])

    # left hand
    rotations.concat([0, 0, 0])

    # right upper arm (mirror)
    raise_r = @arm_raise + Math.sin(@beat_phase * 2 - 0.5) * energy * 0.2
    rotations.concat([
      arm_pump + imp_bass * 0.15,
      0,
      -(0.3 + raise_r)
    ])

    # right lower arm
    elbow_r = 0.2 + Math.sin(@beat_phase * 2 - 0.3) * energy * 0.3
    rotations.concat([0, 0, -elbow_r])

    # right hand
    rotations.concat([0, 0, 0])

    # legs - alternating step
    step = bass * 0.15 + imp_bass * 0.1
    if @step_foot == 0
      rotations.concat([-step, 0, 0])         # left upper leg (step)
      rotations.concat([step * 0.6, 0, 0])    # left lower leg
      rotations.concat([step * 0.2, 0, 0])    # right upper leg
      rotations.concat([step * 0.3, 0, 0])    # right lower leg
    else
      rotations.concat([step * 0.2, 0, 0])    # left upper leg
      rotations.concat([step * 0.3, 0, 0])    # left lower leg
      rotations.concat([-step, 0, 0])          # right upper leg (step)
      rotations.concat([step * 0.6, 0, 0])    # right lower leg
    end

    {
      rotations: rotations,
      hips_position_y: @bounce_pos
    }
  end
end
  
