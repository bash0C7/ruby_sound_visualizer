# Plan: Compact Info Area to 4 Lines

## Goal

Reduce the bottom-left info area from its current multi-line layout to exactly 4 lines with smaller font size.

## Current State

`index.html:73-78` defines the status area with 5 elements:
- `#status` container (line 73): "Ruby WASM Sound Visualizer" title
- `#fpsCounter` (line 75): FPS display
- `#debugInfo` (line 76): Audio analysis data (Mode, Bass/Mid/High/Overall, Vol, HSV, BPM)
- `#paramInfo` (line 77): Sensitivity, MaxBrightness, MaxLightness
- `#keyGuide` (line 78): Keyboard shortcut guide

`src/ruby/main.rb:156-165` formats the debug text, param text, and key guide text.

## Target Layout (4 lines)

```
Line 1: FPS: XX  |  Mode: 1:Hue  |  Bass: XX%  Mid: XX%  High: XX%  Overall: XX%  Vol: XXdB
Line 2: H: XX  S: XX%  B: XX%  |  XXX BPM [B+M]  |  Sensitivity: Xx  MaxBr: XXX  MaxLt: XXX
Line 3: VRM rot: h=X.XXX s=X.XXX c=X.XXX hY=X.XXX
Line 4: 0-3: Color  |  4/5: Hue  |  6/7: Brightness  |  8/9: Lightness  |  +/-: Sens  |  a/s/w/x/q/z: Cam
```

## Changes Required

### 1. index.html (requires user approval)

- Remove `<div>Ruby WASM Sound Visualizer</div>` from `#status`
- Merge `#fpsCounter`, `#debugInfo`, `#paramInfo` into a single `#infoLine` div
- Keep `#keyGuide` as line 4
- Reduce font-size from 12px to 10px for the status area

### 2. src/ruby/main.rb

- Merge FPS into debug_text line 1 (read from `JS.global[:currentFPS]`)
- Merge param_text into debug_text line 2
- Add VRM debug as line 3 (currently set separately via `JS.global[:vrmDebugText]`)
- Shorten key guide labels

### 3. index.html JavaScript side

- Update `updateDebugInfo()` function to use the new merged format
- Remove separate FPS counter update logic (now handled by Ruby)

## TDD Approach

1. Write test for new debug text format (4-line output structure)
2. Modify `main.rb` formatting
3. Modify `index.html` HTML structure and JS update functions
4. Verify with Chrome MCP (visual confirmation - local session)

## Estimated Scope

- Files: `index.html`, `src/ruby/main.rb`
- Risk: Low (display-only changes, no logic changes)
