# Audio Input Enhancement Plan

Enable mic mute/unmute, Chrome tab audio capture (mixed with mic), and tab video overlay as background.

## Goal

Allow users to:
1. Mute/unmute microphone input (startup button, keyboard toggle, VJ command)
2. Capture audio from another Chrome tab, mixed with mic input for visualization
3. Display the captured tab's video as a background with 50% black overlay
4. Composite VJ effects (particles, torus, VRM, bloom) on top of the tab video

## Architecture

### Audio Signal Flow (Web Audio API)

```
Mic Stream → MediaStreamSource → micGain (GainNode) ─┐
                                                       ├→ analyser → visualization
Tab Stream → MediaStreamSource → tabGain (GainNode) ──┘
```

- `micGain`: gain=1 (unmuted) or gain=0 (muted). Controlled by UI/keyboard/command.
- `tabGain`: gain=1 when tab capture is active, disconnected when not.
- Both GainNodes connect to the same AnalyserNode. Web Audio API auto-mixes multiple inputs.
- Tab audio is NOT routed to speakers (the original tab already plays sound).

### Video Compositing (CSS Layering + mix-blend-mode)

```
Layer stack (bottom to top):
1. <video id="tabVideo">          — Tab's video stream (full-screen, object-fit: cover)
2. <div id="tabOverlay">          — Semi-transparent black (rgba(0,0,0,0.5))
3. <canvas> (Three.js)            — mix-blend-mode: screen (when tab active)
```

**Why `mix-blend-mode: screen` instead of alpha transparency:**
- Screen blend: black pixels = transparent, bright pixels = additive composite
- This is the standard VJ compositing technique (same as real VJ software)
- Three.js renderer stays unchanged (no `alpha: true` needed)
- Bloom post-processing works exactly as before (black background internally)
- When no tab is captured, canvas uses `mix-blend-mode: normal` (unchanged behavior)
- When tab is captured, switch to `mix-blend-mode: screen`

### State Management

New JS globals:
- `micGain` (GainNode) — mic gain control
- `micMuted` (boolean) — mic mute state
- `tabStream` (MediaStream | null) — captured tab stream
- `tabAudioGain` (GainNode | null) — tab audio gain
- `tabVideoElement` (HTMLVideoElement) — video element for tab display

New Ruby state:
- `AudioInputState` module — tracks mic/tab status for display/commands

## Implementation Phases

### Phase 1: Mic GainNode Infrastructure

**File: `index.html` (JS)**

1. Add `micGain` GainNode between mic source and analyser in `initAudio()`:
   ```javascript
   // Current: source.connect(analyser)
   // New:
   micGain = audioContext.createGain();
   micGain.gain.value = 1.0;
   source.connect(micGain);
   micGain.connect(analyser);
   ```

2. Add `toggleMic()` function:
   ```javascript
   function toggleMic() {
     micMuted = !micMuted;
     micGain.gain.value = micMuted ? 0 : 1;
     console.log('[JS] Mic ' + (micMuted ? 'muted' : 'unmuted'));
     if (window.rubyOnMicToggle) window.rubyOnMicToggle(micMuted);
   }
   ```

3. Add global variable declarations alongside existing ones (line ~218):
   ```javascript
   let micGain = null;
   let micMuted = false;
   ```

### Phase 2: Tab Audio/Video Capture

**File: `index.html` (JS)**

1. Add tab capture variables:
   ```javascript
   let tabStream = null;
   let tabAudioSource = null;
   let tabAudioGain = null;
   ```

2. Add `startTabCapture()` function:
   ```javascript
   async function startTabCapture() {
     try {
       tabStream = await navigator.mediaDevices.getDisplayMedia({
         video: true,
         audio: true
       });

       // Audio: connect tab audio to analyser via gain node
       const audioTracks = tabStream.getAudioTracks();
       if (audioTracks.length > 0) {
         tabAudioSource = audioContext.createMediaStreamSource(
           new MediaStream(audioTracks)
         );
         tabAudioGain = audioContext.createGain();
         tabAudioGain.gain.value = 1.0;
         tabAudioSource.connect(tabAudioGain);
         tabAudioGain.connect(analyser);
       }

       // Video: display in background video element
       const videoTracks = tabStream.getVideoTracks();
       if (videoTracks.length > 0) {
         const videoEl = document.getElementById('tabVideo');
         videoEl.srcObject = new MediaStream(videoTracks);
         videoEl.play();
         videoEl.style.display = 'block';
         document.getElementById('tabOverlay').style.display = 'block';
         renderer.domElement.style.mixBlendMode = 'screen';
       }

       // Handle stream end (user stops sharing)
       tabStream.getTracks().forEach(track => {
         track.addEventListener('ended', stopTabCapture);
       });

       if (window.rubyOnTabToggle) window.rubyOnTabToggle(true);
     } catch (error) {
       console.error('[JS] Tab capture error:', error);
     }
   }
   ```

3. Add `stopTabCapture()` function:
   ```javascript
   function stopTabCapture() {
     if (tabStream) {
       tabStream.getTracks().forEach(t => t.stop());
       tabStream = null;
     }
     if (tabAudioSource) {
       tabAudioSource.disconnect();
       tabAudioSource = null;
     }
     if (tabAudioGain) {
       tabAudioGain.disconnect();
       tabAudioGain = null;
     }
     const videoEl = document.getElementById('tabVideo');
     videoEl.srcObject = null;
     videoEl.style.display = 'none';
     document.getElementById('tabOverlay').style.display = 'none';
     renderer.domElement.style.mixBlendMode = 'normal';

     if (window.rubyOnTabToggle) window.rubyOnTabToggle(false);
   }
   ```

4. Add `toggleTabCapture()` function:
   ```javascript
   function toggleTabCapture() {
     if (tabStream) {
       stopTabCapture();
     } else {
       startTabCapture();
     }
   }
   ```

### Phase 3: HTML/CSS for Video Background

**File: `index.html` (HTML)**

Add before the `<div id="loading">` element:
```html
<video id="tabVideo" autoplay playsinline muted
       style="display:none; position:fixed; top:0; left:0; width:100%; height:100%;
              object-fit:cover; z-index:-2;"></video>
<div id="tabOverlay"
     style="display:none; position:fixed; top:0; left:0; width:100%; height:100%;
            background:rgba(0,0,0,0.5); z-index:-1;"></div>
```

Note: The `<video>` element has `muted` attribute to prevent double audio playback.
Tab audio is routed only through Web Audio API analyser, not through speakers.

### Phase 4: Startup UI

**File: `index.html` (HTML + JS)**

1. Add "Capture Tab" button to VRM upload section:
   ```html
   <button id="captureTabBtn" class="vrm-upload-btn" style="margin-left: 10px;">
     Capture Tab (optional)
   </button>
   ```

2. Wire up the button in `init()` or via event listener:
   ```javascript
   document.getElementById('captureTabBtn').addEventListener('click', async () => {
     await startTabCapture();
     document.getElementById('captureTabBtn').textContent = 'Tab Captured!';
     document.getElementById('captureTabBtn').disabled = true;
   });
   ```

3. Add mic mute indicator to status area (shown after init):
   - Part of the param info line, updated by Ruby debug_formatter

### Phase 5: Keyboard Controls

**File: `index.html` (JS keydown handler)**

Add to the keyboard handler (before Ruby dispatch):
```javascript
if (key === 'm') { toggleMic(); return; }
if (key === 't') { toggleTabCapture(); return; }
```

### Phase 6: VJ Pad Commands

**File: `src/ruby/vj_pad.rb`**

Add DSL commands:
```ruby
def mic(val = :_get)
  if val == :_get
    muted = JS.global[:micMuted]
    return "mic: #{muted ? 'muted' : 'on'}"
  end
  # 0 = mute, 1 = unmute
  JS.global.toggleMic() if (val.to_i == 0) != JS.global[:micMuted]
  muted = JS.global[:micMuted]
  "mic: #{muted ? 'muted' : 'on'}"
end

def tab(val = :_get)
  if val == :_get
    active = !JS.global[:tabStream].nil?
    return "tab: #{active ? 'on' : 'off'}"
  end
  JS.global.toggleTabCapture()
  "tab: toggled"
end
```

### Phase 7: Ruby Display Updates

**File: `src/ruby/debug_formatter.rb`**

1. Update `format_param_text` to show mic/tab status:
   ```ruby
   def format_param_text
     mic_status = JS.global[:micMuted] ? "MIC:OFF" : "MIC:ON"
     tab_status = JS.global[:tabStream].typeof.to_s != "undefined" &&
                  JS.global[:tabStream].typeof.to_s != "null" ? "TAB:ON" : "TAB:OFF"
     "#{mic_status}  #{tab_status}  |  Sensitivity: #{VisualizerPolicy.sensitivity.round(2)}x  |  ..."
   end
   ```

2. Update `format_key_guide` to include m/t keys:
   ```ruby
   def format_key_guide
     "m: Mic mute  |  t: Tab capture  |  0-3: Color Mode  |  ..."
   end
   ```

### Phase 8: Window Resize Handling

**File: `index.html` (resize handler)**

Update the resize handler to also resize the video element (if CSS handles it via 100%/100%, this is automatic).

### Phase 9: Tests

**New file: `test/test_vj_pad_audio_commands.rb`**

Test the VJ Pad `mic()` and `tab()` command parsing (mock JS.global).

**Update: `test/test_keyboard_handler.rb`**

Add tests for `m` and `t` key dispatch.

**Update: `test/test_debug_formatter.rb`**

Add tests for mic/tab status display.

## Key Design Decisions

1. **Screen blend mode over alpha transparency**: More robust with bloom post-processing, standard VJ technique
2. **GainNode for mute (not disconnect)**: Instant toggle, no reconnection needed, no audio glitches
3. **Video `muted` attribute**: Prevents double audio (browser plays tab audio + Web Audio API)
4. **Separate GainNodes**: Allows independent volume control for mic and tab audio in the future
5. **CSS layering for video**: Zero Three.js overhead, GPU-accelerated video rendering
6. **`m` key for mic, `t` key for tab**: Short, memorable, not conflicting with existing bindings

## File Changes Summary

| File | Changes |
|------|---------|
| `index.html` | HTML: video/overlay elements, capture button. CSS: none (inline styles). JS: GainNode, tab capture, keyboard, resize |
| `src/ruby/vj_pad.rb` | Add `mic()` and `tab()` DSL commands |
| `src/ruby/keyboard_handler.rb` | Add `m` and `t` key handling (delegate to JS) |
| `src/ruby/debug_formatter.rb` | Update param text and key guide with mic/tab status |
| `test/test_vj_pad.rb` | Add tests for `mic()` and `tab()` commands |
| `test/test_keyboard_handler.rb` | Add tests for `m` and `t` keys |
| `test/test_debug_formatter.rb` | Update tests for new param text format |
| `.claude/tasks.md` | Update task descriptions |

## Risks & Mitigations

- **Browser compatibility**: `getDisplayMedia` with `audio: true` requires Chrome 74+. Firefox may not support tab audio capture. → Document Chrome requirement.
- **Tab audio not available**: User may share screen without audio checkbox. → Handle gracefully (video-only mode).
- **Bloom with screen blend**: Bloom glow should composite nicely in screen mode, but verify visually. → Test with actual content.
- **Performance**: Video decoding + Three.js rendering. → CSS video element is GPU-accelerated, minimal overhead.
