# Plugin: wordart
# Trigger 90s Microsoft WordArt style text animation on screen.
# Usage: wordart "YOUR TEXT" from VJ Pad prompt.
# Text appears with cheesy-cool PowerPoint entrance animation,
# displays for a few seconds with audio-reactive pulsing,
# then exits with a stylish animation.
VJPlugin.define(:wordart) do
  desc "Display 90s WordArt text with PowerPoint-style animation"
  param :force, default: 1.0

  on_trigger do |params|
    # WordArt effect is handled via the custom VJPad command,
    # not through the standard effect dispatch system.
    {}
  end
end
