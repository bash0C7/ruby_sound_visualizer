require 'test/unit'

# Prevent `require 'js'` inside Ruby source files from failing.
# Our mock JS module (below) replaces the real js gem.
$LOADED_FEATURES << 'js.rb'

# Mock JS module for testing Ruby WASM classes outside the browser.
# In the real environment, `require 'js'` provides JS::Object and JS.global.
# Here we simulate them so that Ruby classes can be loaded and tested.
module JS
  class MockJSObject
    def initialize(typeof: "undefined")
      @typeof = typeof
    end

    def typeof
      @typeof
    end

    def to_s
      ""
    end

    def to_f
      0.0
    end

    def to_i
      0
    end

    def method_missing(_name, *_args)
      MockJSObject.new
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  class MockGlobal
    def initialize
      @values = {}
    end

    def [](key)
      @values[key.to_s] || MockJSObject.new
    end

    def []=(key, value)
      @values[key.to_s] = value
    end

    # Intercept JS function calls (e.g., JS.global.updateVRM(...))
    def method_missing(name, *args)
      # no-op for JS function calls from Ruby
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  @global = MockGlobal.new

  def self.global
    @global
  end

  # Allow tests to set mock values (e.g., delta time)
  def self.set_global(key, value)
    @global[key] = value
  end

  def self.reset_global!
    @global = MockGlobal.new
  end

  def self.eval(_code)
    MockJSObject.new
  end
end

# Load Ruby source files directly (standard require_relative).
# Skips main.rb which has side effects (global variable init,
# lambda registrations on JS.global).
RUBY_SRC_DIR = File.expand_path('../src/ruby', __dir__)

require_relative '../src/ruby/visualizer_policy'
require_relative '../src/ruby/math_helper'
require_relative '../src/ruby/js_bridge'
require_relative '../src/ruby/frequency_mapper'
require_relative '../src/ruby/audio_limiter'
require_relative '../src/ruby/audio_analyzer'
require_relative '../src/ruby/color_palette'
require_relative '../src/ruby/particle_system'
require_relative '../src/ruby/geometry_morpher'
require_relative '../src/ruby/camera_controller'
require_relative '../src/ruby/bloom_controller'
require_relative '../src/ruby/effect_manager'
require_relative '../src/ruby/effect_dispatcher'
require_relative '../src/ruby/vrm_dancer'
require_relative '../src/ruby/vrm_material_controller'
require_relative '../src/ruby/keyboard_handler'
require_relative '../src/ruby/audio_input_manager'
require_relative '../src/ruby/vj_plugin'
require_relative '../src/ruby/vj_serial_commands'
require_relative '../src/ruby/vj_pad'
require_relative '../src/ruby/serial_protocol'
require_relative '../src/ruby/serial_manager'
require_relative '../src/ruby/serial_audio_source'
require_relative '../src/ruby/wordart_renderer'
require_relative '../src/ruby/pen_input'
require_relative '../src/ruby/debug_formatter'
require_relative '../src/ruby/bpm_estimator'
require_relative '../src/ruby/frame_counter'

# Load plugins (same order as index.html)
require_relative '../src/ruby/plugins/vj_burst'
require_relative '../src/ruby/plugins/vj_flash'
require_relative '../src/ruby/plugins/vj_shockwave'
require_relative '../src/ruby/plugins/vj_strobe'
require_relative '../src/ruby/plugins/vj_rave'
require_relative '../src/ruby/plugins/vj_serial'
require_relative '../src/ruby/plugins/vj_wordart'
