require 'js'
require_relative 'utils/math_helper'
require_relative 'utils/js_bridge'
require_relative 'audio/analyzer'

# Initialize state variables
$initialized = false
$audio_analyzer = nil
$frame_count = 0

begin
  JSBridge.log "Ruby VM started, initializing..."

  # Create audio analyzer
  $audio_analyzer = AudioAnalyzer.new

  # Define the main update function that will be called from JavaScript
  JS.global[:rubyUpdateVisuals] = lambda do |freq_array|
    begin
      unless $initialized
        JSBridge.log "First update received, initializing effect system..."
        $initialized = true
      end

      # Analyze audio data
      analysis = $audio_analyzer.analyze(freq_array)

      # Log audio metrics every 30 frames to avoid spam
      $frame_count += 1
      if $frame_count % 30 == 0
        bass = (analysis[:bass] * 100).round(1)
        mid = (analysis[:mid] * 100).round(1)
        high = (analysis[:high] * 100).round(1)
        overall = (analysis[:overall_energy] * 100).round(1)
        JSBridge.log "Audio: Bass=#{bass}% Mid=#{mid}% High=#{high}% Overall=#{overall}%"
      end
    rescue => e
      JSBridge.error "Error in rubyUpdateVisuals: #{e.message}"
    end
  end

  JSBridge.log "Ruby initialization complete!"

rescue => e
  JSBridge.error "Fatal error during Ruby initialization: #{e.message}"
end
