---
name: troubleshoot
description: Troubleshooting guide for ruby.wasm Sound Visualizer common issues
disable-model-invocation: true
---

# Ruby WASM Sound Visualizer Troubleshooting

## Ruby WASM Loading Failure

### Symptom

- "Error: Failed to fetch ruby.wasm"
- Network error in browser console
- Blank screen with loading message stuck

### Diagnostic Steps

1. **Check local server is running**
   ```bash
   lsof -i :8000
   # Should show ruby process listening on port 8000
   ```

2. **Verify network requests**
   ```
   mcp__claude-in-chrome__read_network_requests(
     tabId: XXX,
     urlPattern: "ruby.wasm"
   )
   ```

3. **Check browser console for CORS errors**
   ```
   mcp__claude-in-chrome__read_console_messages(
     tabId: XXX,
     pattern: "CORS|blocked|fetch",
     onlyErrors: true
   )
   ```

### Solutions

- **Start local server**: `bundle exec ruby -run -ehttpd . -p8000`
- **Verify internet connection**: ruby.wasm is loaded from CDN
- **Clear browser cache**: Hard refresh with Ctrl+Shift+R (Cmd+Shift+R on Mac)
- **Check firewall settings**: Ensure port 8000 is not blocked

## Microphone Not Working

### Symptom

- "Permission denied" error
- Microphone permission dialog doesn't appear
- No audio input detected

### Diagnostic Steps

1. **Verify URL protocol**
   ```
   mcp__claude-in-chrome__javascript_tool(
     tabId: XXX,
     text: "window.location.protocol"
   )
   ```
   - Must be `https:` or `http:` on `localhost`

2. **Check microphone permission state**
   ```javascript
   navigator.permissions.query({ name: 'microphone' })
     .then(status => console.log('Mic permission:', status.state))
   ```

3. **Verify getUserMedia availability**
   ```javascript
   console.log('getUserMedia available:',
     !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia))
   ```

### Solutions

- **Use localhost or HTTPS**: Non-HTTPS sites cannot access microphone
- **Grant permission in browser**:
  - Chrome: Click lock icon → Site settings → Microphone → Allow
  - Firefox: Preferences → Privacy & Security → Permissions → Microphone
- **Check system permissions**: Ensure browser has microphone access in OS settings
- **Try different browser**: Some browsers have stricter policies

## Poor Performance / Low FPS

### Symptom

- Frame rate below 20 FPS
- Laggy particle movement
- Delayed audio response

### Diagnostic Steps

1. **Profile with Chrome DevTools**
   - Open DevTools → Performance tab
   - Record 3-5 seconds of runtime
   - Look for JavaScript/WebGL bottlenecks

2. **Check particle count**
   ```
   mcp__claude-in-chrome__javascript_tool(
     tabId: XXX,
     text: "particleSystem?.children.length || 'N/A'"
   )
   ```

3. **Verify GPU acceleration**
   - Navigate to `chrome://gpu/`
   - Check "WebGL" and "WebGL2" status

### Solutions

1. **Reduce particle count** in index.html:
   ```javascript
   const particleCount = 5000;  // Down from 10000
   ```
   ```ruby
   PARTICLE_COUNT = 5000  # Down from 10000
   ```

2. **Enable hardware acceleration**:
   - Chrome: Settings → System → Use hardware acceleration
   - Firefox: Preferences → Performance → Use recommended performance settings

3. **Close other tabs**: Free up GPU memory

4. **Close DevTools**: Reduces rendering overhead

## Three.js / WebGL Errors

### Symptom

- "WebGL context lost" error
- "THREE.WebGLRenderer: Error creating WebGL context"
- Black screen with no rendering

### Diagnostic Steps

1. **Check WebGL availability**
   ```
   mcp__claude-in-chrome__javascript_tool(
     tabId: XXX,
     text: `
       const canvas = document.createElement('canvas');
       const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
       JSON.stringify({
         webgl: !!gl,
         version: gl?.getParameter(gl.VERSION),
         vendor: gl?.getParameter(gl.VENDOR)
       });
     `
   )
   ```

2. **Verify GPU status**: Visit `chrome://gpu/`

3. **Check context loss event**
   ```javascript
   canvas.addEventListener('webglcontextlost', (e) => {
     console.error('WebGL context lost:', e);
   });
   ```

### Solutions

- **Free GPU memory**: Close other GPU-intensive tabs
- **Restart browser**: Reset GPU state
- **Update graphics drivers**: Especially on Windows
- **Disable browser extensions**: Some extensions interfere with WebGL
- **Try incognito mode**: Rule out extension interference

## Ruby Execution Errors

### Symptom

- "[Ruby] Error: ..." in console
- Stack trace with `eval:line_number`
- Unexpected behavior in audio analysis

### Diagnostic Steps

1. **Read full error message**
   ```
   mcp__claude-in-chrome__read_console_messages(
     tabId: XXX,
     pattern: "\[Ruby\]",
     onlyErrors: true
   )
   ```

2. **Identify error location**
   - `eval:123` refers to line 123 in `<script type="text/ruby">` block
   - Count from first line of Ruby code in index.html

3. **Check variable types**
   ```ruby
   # Add debug output before error line
   JS.global[:console].log("[DEBUG] typeof=#{obj.typeof}")
   ```

### Solutions

- **JS::Object type errors**: Use `.to_s` before Ruby string methods
- **NoMethodError on BasicObject**: Use `.typeof` instead of `.class`
- **Function call errors**: Use `JS.global.funcName()` not `JS.global[:funcName].call()`
- **Array/Hash access**: Ensure proper conversion with `.to_a` or `.to_h`

## Audio Not Responding to Input

### Symptom

- Visualizer runs but doesn't react to sound
- Particles don't move
- Torus doesn't scale

### Diagnostic Steps

1. **Check microphone input**
   ```javascript
   navigator.mediaDevices.getUserMedia({ audio: true })
     .then(stream => {
       const audioContext = new AudioContext();
       const analyser = audioContext.createAnalyser();
       const source = audioContext.createMediaStreamSource(stream);
       source.connect(analyser);

       const dataArray = new Uint8Array(analyser.frequencyBinCount);
       analyser.getByteFrequencyData(dataArray);

       const sum = dataArray.reduce((a, b) => a + b, 0);
       console.log('Audio input level:', sum / dataArray.length);
     });
   ```

2. **Verify AnalyserNode connection**
   ```
   mcp__claude-in-chrome__javascript_tool(
     tabId: XXX,
     text: `JSON.stringify({
       analyserConnected: !!analyser,
       bufferLength: dataArray?.length || 0,
       sampleRate: audioContext?.sampleRate || 0
     })`
   )
   ```

### Solutions

- **Increase microphone volume**: System sound settings
- **Select correct input device**: Browser may use wrong microphone
- **Check analyser FFT size**: Should be 2048 or higher
- **Test with music**: Play loud music near microphone
- **Verify Ruby callback**: Ensure `rubyUpdateVisuals` is registered

## Browser Compatibility Issues

### Symptom

- Works in Chrome but not Firefox/Safari
- Inconsistent behavior across browsers

### Diagnostic Steps

1. **Check feature support**:
   - WebAssembly: `typeof WebAssembly !== 'undefined'`
   - Audio API: `typeof AudioContext !== 'undefined'`
   - WebGL2: `!!canvas.getContext('webgl2')`

2. **Test with minimal example**: Isolate Ruby WASM loading

### Solutions

- **Use latest browser version**: ruby.wasm requires modern features
- **Prefer Chrome/Edge**: Best WebAssembly support
- **Check Safari restrictions**: May have stricter security policies
- **Avoid Firefox on Linux**: Known WebGL issues on some distros

## Still Not Working?

If none of these solutions work:

1. **Check browser console** for any errors not covered above
2. **Enable verbose logging** in index.html
3. **Test with minimal HTML**: Isolate the problem component
4. **Report issue** with:
   - Browser version
   - Operating system
   - Full console error log
   - Network tab screenshot
