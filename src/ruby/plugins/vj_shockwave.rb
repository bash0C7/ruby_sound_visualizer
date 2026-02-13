# Plugin: shockwave
# Bass-heavy impulse combined with bloom flash for dramatic visual impact.
VJPlugin.define(:shockwave) do
  desc "Bass-heavy impulse with bloom flash"
  param :force, default: 1.5, range: 0.0..5.0

  on_trigger do |params|
    f = params[:force]
    {
      impulse: { bass: f, mid: f * 0.5, high: f * 0.3, overall: f },
      bloom_flash: f * 0.8
    }
  end
end
