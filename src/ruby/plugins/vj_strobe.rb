# Plugin: strobe
# Quick bloom strobe flash for bright visual burst without impulse.
VJPlugin.define(:strobe) do
  desc "Quick bloom strobe flash"
  param :intensity, default: 3.0, range: 0.0..5.0

  on_trigger do |params|
    { bloom_flash: params[:intensity] }
  end
end
