require 'js'

$initialized = false
$audio_analyzer = nil
$effect_manager = nil
$vrm_dancer = nil
$vrm_material_controller = nil
$frame_count = 0
$beat_times = []  # ビート検出時のフレーム番号を記録
$estimated_bpm = 0

# URL パラメーターから設定値を読取
# 注意: JS.global[:location][:search] は JS::Object を返す。
# JS::Object は BasicObject 継承のため、.match 等の Ruby メソッドが
# method_missing 経由で JS 側に転送されてしまう。
# 必ず .to_s で Ruby String に変換してから操作すること。
begin
  search_str = JS.global[:location][:search].to_s
  if search_str.is_a?(String) && search_str.length > 0
    match = search_str.match(/sensitivity=([0-9.]+)/)
    if match
      Config.sensitivity = match[1].to_f
    end
    match_br = search_str.match(/maxBrightness=([0-9]+)/)
    if match_br
      Config.max_brightness = match_br[1].to_i
    end
    match_lt = search_str.match(/maxLightness=([0-9]+)/)
    if match_lt
      Config.max_lightness = match_lt[1].to_i
    end
  end
rescue => e
  # URLパラメーター読取失敗時はデフォルト値を使用（Config モジュールの初期値）
end

begin
  JSBridge.log "Ruby VM started, initializing... (Sensitivity: #{Config.sensitivity})"

  $audio_analyzer = AudioAnalyzer.new
  $effect_manager = EffectManager.new
  $vrm_dancer = VRMDancer.new  # Always initialize (VRM optional)
  $vrm_material_controller = VRMMaterialController.new  # For VRM bloom control

  JS.global[:rubyUpdateVisuals] = lambda do |freq_array|
    begin
      unless $initialized
        JSBridge.log "First update received, initializing effect system..."
        $initialized = true
      end

      analysis = $audio_analyzer.analyze(freq_array, Config.sensitivity)
      $effect_manager.update(analysis, Config.sensitivity)

      JSBridge.update_particles($effect_manager.particle_data)
      JSBridge.update_geometry($effect_manager.geometry_data)
      JSBridge.update_bloom($effect_manager.bloom_data)
      # Camera controller always enabled (keyboard control can override)
      JSBridge.update_camera($effect_manager.camera_data)
      JSBridge.update_particle_rotation($effect_manager.geometry_data[:rotation])

      # VRM dance update (always update, JavaScript will use if VRM is loaded)
      scaled_for_vrm = {
        bass: [analysis[:bass] * Config.sensitivity, 1.0].min,
        mid: [analysis[:mid] * Config.sensitivity, 1.0].min,
        high: [analysis[:high] * Config.sensitivity, 1.0].min,
        overall_energy: [analysis[:overall_energy] * Config.sensitivity, 1.0].min,
        beat: analysis[:beat],
        impulse: {
          overall: $effect_manager.impulse_overall || 0.0,
          bass: $effect_manager.impulse_bass || 0.0,
          mid: $effect_manager.impulse_mid || 0.0,
          high: $effect_manager.impulse_high || 0.0
        }
      }
      vrm_data = $vrm_dancer.update(scaled_for_vrm)
      JSBridge.update_vrm(vrm_data)

      # VRM material bloom control (based on audio energy)
      vrm_material_config = $vrm_material_controller.apply_emissive(scaled_for_vrm[:overall_energy])
      JSBridge.update_vrm_material(vrm_material_config)

      # VRM debug info (60フレームごとに更新、コンパクト表示)
      if $frame_count % 60 == 0
        rotations = vrm_data[:rotations] || []
        # 回転値の最大・最小を表示（動きの範囲を確認）
        if rotations.length >= 9
          hips_rot_max = rotations[0..2].map(&:abs).max.round(3)
          spine_rot_max = rotations[3..5].map(&:abs).max.round(3)
          chest_rot_max = rotations[6..8].map(&:abs).max.round(3)
          hips_y = (vrm_data[:hips_position_y] || 0.0).round(3)

          vrm_debug = "VRM rot: h=#{hips_rot_max} s=#{spine_rot_max} c=#{chest_rot_max} hY=#{hips_y}"
          JS.global[:vrmDebugText] = vrm_debug
        end
      end

      $frame_count += 1

      # BPM 推定（ビート間隔から計算）
      beat = analysis[:beat] || {}
      if beat[:bass]
        $beat_times << $frame_count
        # 直近16回分のみ保持
        $beat_times = $beat_times.last(16) if $beat_times.length > 16

        if $beat_times.length >= 3
          # ビート間隔の平均からBPMを推定
          intervals = []
          ($beat_times.length - 1).times do |i|
            intervals << $beat_times[i + 1] - $beat_times[i]
          end
          avg_interval = intervals.sum.to_f / intervals.length
          if avg_interval > 0
            fps_val = JS.global[:currentFPS]
            fps = fps_val.typeof == "number" ? fps_val.to_f : 30.0
            fps = 30.0 if fps < 10
            $estimated_bpm = (60.0 / (avg_interval / fps)).round(0)
            # BPM を妥当な範囲にクリップ
            $estimated_bpm = 0 if $estimated_bpm < 40 || $estimated_bpm > 240
          end
        end
      end

      # 現在のフレームのビート状態
      beat_now = []
      beat_now << "B" if beat[:bass]
      beat_now << "M" if beat[:mid]
      beat_now << "H" if beat[:high]

      # デバッグ情報文字列を Ruby でフォーマット（JavaScript 側の負荷を減らす）
      energy = analysis[:overall_energy]
      volume_db = energy > 0.001 ? (20.0 * Math.log10(energy)).round(1) : -60.0
      hsv = ColorPalette.get_last_hsv
      hue_mode_val = ColorPalette.get_hue_mode
      mode_str_base = hue_mode_val.nil? ? "0:Gray" : "#{hue_mode_val}:Hue"
      hue_offset_val = ColorPalette.get_hue_offset
      mode_str = hue_offset_val == 0.0 ? mode_str_base : "#{mode_str_base}+#{hue_offset_val.round(0)}deg"
      bass_str = (analysis[:bass] * 100).round(1).to_s
      mid_str = (analysis[:mid] * 100).round(1).to_s
      high_str = (analysis[:high] * 100).round(1).to_s
      overall_str = (analysis[:overall_energy] * 100).round(1).to_s
      h_str = (hsv[0] * 360).round(1).to_s
      s_str = (hsv[1] * 100).round(1).to_s
      b_str = (hsv[2] * 100).round(1).to_s
      bpm_str = $estimated_bpm > 0 ? "#{$estimated_bpm} BPM" : "---"
      beat_indicator = beat_now.empty? ? "" : " [#{beat_now.join("+")}]"

      debug_text = "Mode: #{mode_str}  |  Bass: #{bass_str}%  Mid: #{mid_str}%  High: #{high_str}%  Overall: #{overall_str}%  Vol: #{volume_db.round(1)}dB\n" +
                   "H: #{h_str}  S: #{s_str}%  B: #{b_str}%  |  #{bpm_str}#{beat_indicator}"
      JS.global[:debugInfoText] = debug_text

      # パラメーター情報文字列も Ruby でフォーマット
      param_text = "Sensitivity: #{Config.sensitivity.round(2)}x  |  MaxBrightness: #{Config.max_brightness}  |  MaxLightness: #{Config.max_lightness}"
      JS.global[:paramInfoText] = param_text

      # キーガイド（固定文字列だが統一のため Ruby で定義）
      JS.global[:keyGuideText] = "0-3: Color Mode  |  4/5: Hue Shift  |  6/7: Brightness ±5  |  8/9: Lightness ±5  |  +/-: Sensitivity  |  a/s: Cam X  |  w/x: Cam Y  |  q/z: Cam Z"

      if $frame_count % 60 == 0
        bass = (analysis[:bass] * 100).round(1)
        mid = (analysis[:mid] * 100).round(1)
        high = (analysis[:high] * 100).round(1)
        overall = (analysis[:overall_energy] * 100).round(1)
        sensitivity_str = Config.sensitivity.round(2).to_s
        JSBridge.log "Audio: Bass=#{bass}% Mid=#{mid}% High=#{high}% Overall=#{overall}% | Sensitivity: #{sensitivity_str}x"
      end
    rescue => e
      JSBridge.error "Error in rubyUpdateVisuals: #{e.class} #{e.message}"
      JSBridge.error e.backtrace[0..4].join(", ")
    end
  end

  # Register keyboard callback for color mode changes
  JS.global[:rubySetColorMode] = lambda do |key_number|
    begin
      key = key_number.to_i

      case key
      when 0
        ColorPalette.set_hue_mode(nil)
        JSBridge.log "Color Mode: Grayscale"
      when 1
        ColorPalette.set_hue_mode(1)
        JSBridge.log "Color Mode: 1:Red (240-120deg)"
      when 2
        ColorPalette.set_hue_mode(2)
        JSBridge.log "Color Mode: 2:Green (0-240deg)"
      when 3
        ColorPalette.set_hue_mode(3)
        JSBridge.log "Color Mode: 3:Blue (120-360deg)"
      end
    rescue => e
      JSBridge.error "Error in rubySetColorMode: #{e.message}"
    end
  end

  # Sensitivity 増減コールバック
  JS.global[:rubyAdjustSensitivity] = lambda do |delta|
    begin
      d = delta.to_f
      Config.sensitivity = [(Config.sensitivity + d).round(2), 0.05].max
      JSBridge.log "Sensitivity: #{Config.sensitivity}x"
    rescue => e
      JSBridge.error "Error in rubyAdjustSensitivity: #{e.message}"
    end
  end

  # 色相位置マニュアルシフト（4: -5度, 5: +5度）
  JS.global[:rubyShiftHue] = lambda do |delta|
    begin
      d = delta.to_f
      ColorPalette.shift_hue_offset(d)
      offset = ColorPalette.get_hue_offset
      JSBridge.log "Hue Offset: #{offset.round(1)} deg"
    rescue => e
      JSBridge.error "Error in rubyShiftHue: #{e.message}"
    end
  end

  # 最大輝度 増減コールバック（6: -5, 7: +5）
  JS.global[:rubyAdjustMaxBrightness] = lambda do |delta|
    begin
      d = delta.to_i
      Config.max_brightness = [[Config.max_brightness + d, 0].max, 255].min
      JSBridge.log "MaxBrightness: #{Config.max_brightness}"
    rescue => e
      JSBridge.error "Error in rubyAdjustMaxBrightness: #{e.message}"
    end
  end

  # 最大明度 増減コールバック（8: -5, 9: +5）
  JS.global[:rubyAdjustMaxLightness] = lambda do |delta|
    begin
      d = delta.to_i
      Config.max_lightness = [[Config.max_lightness + d, 0].max, 255].min
      JSBridge.log "MaxLightness: #{Config.max_lightness}"
    rescue => e
      JSBridge.error "Error in rubyAdjustMaxLightness: #{e.message}"
    end
  end

  JSBridge.log "Keyboard controls ready (0-3: color, 4/5: hue shift, 6/7: brightness, 8/9: lightness, +/-: sensitivity)"
  JSBridge.log "Ruby initialization complete!"

rescue => e
  JSBridge.error "Fatal error during Ruby initialization: #{e.message}"
end
  
