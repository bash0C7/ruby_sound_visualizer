# Plugin: flash
# Trigger bloom flash for a bright strobe-like visual burst.
VJPlugin.define(:flash) do
  desc "Trigger bloom flash"
  param :intensity, default: 1.0

  on_trigger do |params|
    { bloom_flash: params[:intensity] }
  end
end
