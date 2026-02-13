# Plugin: burst
# Inject impulse across all frequency bands for explosive visual effect.
VJPlugin.define(:burst) do
  desc "Inject impulse across all frequency bands"
  param :force, default: 1.0

  on_trigger do |params|
    f = params[:force]
    { impulse: { bass: f, mid: f, high: f, overall: f } }
  end
end
