# VJPlugin: Plugin registration and definition system for VJ Pad commands.
# Plugins are defined via VJPlugin.define(:name) { ... } DSL and
# automatically become available as VJ Pad commands.
module VJPlugin
  @registry = {}

  def self.define(name, &block)
    plugin = PluginDefinition.new(name)
    plugin.instance_eval(&block)
    @registry[name] = plugin
    plugin
  end

  def self.find(name)
    @registry[name]
  end

  def self.all
    @registry.values
  end

  def self.names
    @registry.keys
  end

  def self.reset!
    @registry = {}
  end
end

# Definition of a single VJ Pad plugin command.
# Built via DSL inside VJPlugin.define block.
class PluginDefinition
  attr_reader :name, :description, :params

  def initialize(name)
    @name = name
    @description = ""
    @params = {}
    @trigger_block = nil
  end

  def desc(text)
    @description = text
  end

  def param(name, default:, range: nil)
    @params[name] = { default: default, range: range }
  end

  def on_trigger(&block)
    @trigger_block = block
  end

  def execute(args = {})
    return {} unless @trigger_block

    resolved = resolve_params(args)
    @trigger_block.call(resolved)
  end

  def format_result(args)
    if args.empty?
      "#{@name}!"
    else
      "#{@name}: #{args.join(', ')}"
    end
  end

  private

  def resolve_params(args)
    resolved = {}
    @params.each do |key, config|
      val = args.key?(key) ? args[key] : config[:default]
      val = val.to_f
      if config[:range]
        val = [[val, config[:range].min].max, config[:range].max].min
      end
      resolved[key] = val
    end
    resolved
  end
end
