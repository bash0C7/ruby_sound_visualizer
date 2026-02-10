# Plan: In-Browser Ruby Prompt Area (VJ Mode)

## Goal

Implement an on-screen prompt area where users can type Ruby commands to dynamically control visualizations, enabling a VJ (Visual Jockey) workflow.

## Target Design

### UI Layout

```
+--------------------------------------------------+
|                                                    |
|              [3D Visualization Area]               |
|                                                    |
+--------------------------------------------------+
| > ruby command here_                    [Enter]   |  <- Prompt area
+--------------------------------------------------+
| FPS: XX | Mode: 1:Hue | Bass: XX% ...            |  <- Existing status
+--------------------------------------------------+
```

### Command DSL

A simple Ruby DSL for VJ control:

```ruby
# Color control
color :red              # Switch to red mode
color :yellow           # Switch to yellow mode
hue 45                  # Set hue offset to 45 degrees

# Particle control
particles :explode      # Trigger explosion
particles :calm         # Reduce movement
particle_count 5000     # Change count (if performance allows)

# Geometry control
scale 2.0               # Set torus scale multiplier
rotation_speed 0.5      # Set rotation speed factor

# Bloom control
bloom 3.0               # Set bloom strength
bloom_threshold 0.1     # Set bloom threshold

# Sensitivity
sensitivity 1.5         # Set audio sensitivity

# Presets / sequences
preset :intense         # High energy preset
preset :chill           # Low energy preset

# Timed sequences (VJ mode)
sequence do
  at 0, -> { color :red; bloom 4.0 }
  at 4, -> { color :blue; bloom 2.0 }
  at 8, -> { color :yellow; particles :explode }
  loop!
end
```

### Architecture

```
Browser Prompt Input (HTML/CSS/JS)
  ↓ keydown Enter
JavaScript captures input string
  ↓ window.rubyEvalCommand(commandString)
Ruby CommandInterpreter
  ↓ DSL method dispatch
Ruby Config / ColorPalette / EffectManager / etc.
  ↓ Values updated
Next frame picks up new values
```

### Components

#### 1. PromptUI (JavaScript)
- HTML input element overlaid on canvas
- Toggle visibility with backtick (`) key
- Command history (up/down arrows)
- Auto-hide after command execution

#### 2. CommandInterpreter (Ruby)
```ruby
class CommandInterpreter
  def initialize(config, palette, effect_manager)
    @config = config
    @palette = palette
    @effect_manager = effect_manager
    @history = []
    @sequences = []
  end

  def execute(command_string)
    @history << command_string
    # Evaluate in a sandboxed DSL context
    dsl = DSLContext.new(@config, @palette, @effect_manager)
    dsl.instance_eval(command_string)
    { success: true, result: dsl.last_result }
  rescue => e
    { success: false, error: e.message }
  end
end
```

#### 3. DSLContext (Ruby)
```ruby
class DSLContext
  attr_reader :last_result

  def initialize(config, palette, effect_manager)
    @config = config
    @palette = palette
    @effect_manager = effect_manager
  end

  def color(mode)
    mapping = { red: 1, yellow: 2, blue: 3, gray: nil }
    @palette.hue_mode = mapping[mode]
    @last_result = "Color mode: #{mode}"
  end

  def sensitivity(val)
    @config.sensitivity = val.to_f
    @last_result = "Sensitivity: #{val}"
  end

  # ... more DSL methods
end
```

#### 4. SequenceRunner (Ruby)
```ruby
class SequenceRunner
  def initialize
    @sequences = []
    @start_time = nil
  end

  def add(sequence)
    @sequences << sequence
  end

  def update(current_time)
    @sequences.each { |seq| seq.tick(current_time) }
  end
end
```

## Dependencies

- **config-centralization**: DSL methods need centralized config to modify
- **ruby-class-restructure**: CommandInterpreter needs clean class interfaces
- **devtool-interface**: Similar pattern for JS->Ruby callback registration

## Changes Required

### Phase 1: Basic prompt UI + simple commands
- `index.html` (requires user approval): Prompt HTML/CSS, toggle logic, JS bridge
- New `src/ruby/command_interpreter.rb`: Basic command execution
- New `src/ruby/dsl_context.rb`: DSL method definitions
- `src/ruby/main.rb`: Register rubyEvalCommand callback

### Phase 2: Command history + feedback
- Prompt UI shows command result / error
- Up/down arrow for history navigation
- Tab completion for known commands

### Phase 3: Sequence runner (VJ mode)
- New `src/ruby/sequence_runner.rb`: Timed command sequences
- DSL `sequence` block support
- Integration with main loop for timing

## TDD Approach

Phase 1:
1. Write tests for DSLContext (each command returns expected result)
2. Write tests for CommandInterpreter (execute, error handling)
3. Implement Ruby classes
4. Build prompt UI
5. Verify with Chrome MCP (local session)

Phase 2-3:
1. Tests for history management
2. Tests for SequenceRunner timing
3. Implement and integrate

## Estimated Scope

- Files: 2-3 new Ruby files, `index.html` modification, `main.rb` modification
- Risk: High (new feature, complex UI + DSL design)
- Recommendation: Phase 1 first, assess usability before Phase 2-3
- Prerequisites: config-centralization, ruby-class-restructure (for clean interfaces)
