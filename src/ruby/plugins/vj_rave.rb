# Plugin: rave
# Max energy preset: full impulse + bloom flash + param boost.
VJPlugin.define(:rave) do
  desc "Max energy preset with impulse and param boost"
  param :level, default: 1.0, range: 0.0..3.0

  on_trigger do |params|
    l = params[:level]
    {
      impulse: { bass: l, mid: l, high: l, overall: l },
      bloom_flash: l * 2.0,
      set_param: {
        "bloom_base_strength" => 2.0 + l,
        "particle_explosion_base_prob" => [0.2 + l * 0.2, 1.0].min
      }
    }
  end
end
