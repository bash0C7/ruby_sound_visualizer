require 'minitest/autorun'

# Prevent `require 'js'` inside Ruby blocks from failing.
# Our mock JS module (below) replaces the real js gem.
$LOADED_FEATURES << 'js.rb'

# Mock JS module for testing Ruby WASM classes outside the browser.
# In the real environment, `require 'js'` provides JS::Object and JS.global.
# Here we simulate them so that Ruby classes can be loaded and tested.
module JS
  class MockJSObject
    def typeof
      "undefined"
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
end

# Extract and load Ruby code blocks from index.html.
# Skips 'ruby-main' block which has side effects (global variable init,
# lambda registrations on JS.global).
def load_ruby_blocks_from_html(html_path, skip_ids: ['ruby-main'])
  html = File.read(html_path, encoding: 'UTF-8')

  # Extract all <script type="text/ruby" id="...">...</script> blocks
  html.scan(/<script\s+type="text\/ruby"\s+id="([^"]+)">(.*?)<\/script>/m).each do |id, code|
    next if skip_ids.include?(id)

    begin
      eval(code, TOPLEVEL_BINDING, "#{html_path}:#{id}")
    rescue => e
      warn "Warning: Failed to load Ruby block '#{id}': #{e.message}"
    end
  end
end

# Load all Ruby class definitions from index.html
INDEX_HTML_PATH = File.expand_path('../index.html', __dir__)
load_ruby_blocks_from_html(INDEX_HTML_PATH)
