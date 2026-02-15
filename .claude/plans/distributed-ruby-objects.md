# MicroDRb: Distributed Ruby Objects over Serial

## Overview

A lightweight distributed object library inspired by DRb (Distributed Ruby),
enabling RPC method calls and shared instance variables between ruby.wasm
(browser) and PicoRuby (ESP32) over serial communication.

Both sides can host objects and call remote methods. The library is standalone,
independent of the existing visualizer's SerialProtocol/SerialManager.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Library structure | Standalone | Reusable, separate transport layer, integrate later |
| PicoRuby compatibility | Shared interface definition | Static method/var declarations, no metaprogramming |
| Call semantics | Synchronous | PicoRuby: blocking UART wait. Browser: Fiber-based pseudo-sync |
| Initial scope (v0.1) | RPC + variable sharing | Method calls + instance variable get/set |
| Serialization | Minimal JSON subset | No gems needed, hand-written parser for both platforms |
| Conflict avoidance | Arbitration by user | No automatic distributed locking |

## Architecture

```
┌─────────────────────────────────┐     Serial      ┌─────────────────────────────────┐
│  Browser (ruby.wasm)            │  ←──────────→    │  PicoRuby (ESP32)               │
│                                 │   115200 baud    │                                 │
│  ┌───────────┐ ┌──────────────┐ │                  │ ┌──────────────┐ ┌───────────┐  │
│  │  Server    │ │   Client     │ │                  │ │   Client     │ │  Server   │  │
│  │ (dispatch) │ │ (Fiber-sync) │ │                  │ │ (UART-block) │ │(dispatch) │  │
│  └─────┬─────┘ └──────┬───────┘ │                  │ └──────┬───────┘ └─────┬─────┘  │
│        │               │         │                  │        │               │        │
│  ┌─────┴───────────────┴───────┐ │                  │ ┌──────┴───────────────┴─────┐  │
│  │        Registry             │ │                  │ │        Registry            │  │
│  │  (named objects + interfaces)│ │                  │ │  (named objects + ifaces)  │  │
│  └─────────────┬───────────────┘ │                  │ └────────────┬───────────────┘  │
│                │                  │                  │              │                  │
│  ┌─────────────┴───────────────┐ │                  │ ┌────────────┴───────────────┐  │
│  │   Transport (WebSerial)     │ │                  │ │   Transport (UART)         │  │
│  │   encode / decode / send    │ │                  │ │   encode / decode / send   │  │
│  └─────────────────────────────┘ │                  │ └────────────────────────────┘  │
└─────────────────────────────────┘                  └─────────────────────────────────┘
```

### Key Asymmetry

ruby.wasm cannot block the main thread (no Promise await, single-threaded).
PicoRuby can block on UART read.

| Role | Browser (ruby.wasm) | PicoRuby |
|------|-------------------|----------|
| As server (receiving calls) | Synchronous dispatch in receive callback | Synchronous dispatch in main loop |
| As client (making calls) | **Fiber-based pseudo-sync** | **Blocking UART wait** |

### Fiber-based Pseudo-sync (Browser Side)

```ruby
# User code (feels synchronous)
def my_command
  result = @drb.call("led", :get_status)   # ← Fiber.yield inside
  JSBridge.log "Status: #{result}"          # ← resumes when response arrives
end

# Internal mechanism:
# 1. call() sends request frame, stores msg_id → Fiber mapping
# 2. call() does Fiber.yield (returns control to browser event loop)
# 3. Serial receive callback gets response, finds pending Fiber by msg_id
# 4. Fiber.resume(decoded_value) continues execution at the yield point
```

Limitation: Fiber-based calls must be initiated from a Fiber context
(e.g., VJPad command handler wraps execution in Fiber.new).

## Protocol Specification

### Frame Format

```
{<type>|<msg_id>|<payload...>}\n
```

- Delimiters: `{` start, `}` end, `\n` terminator
- Field separator: `|` (pipe)
- Distinct from existing audio frames (`<...>`) to coexist on same serial line

### Message Types

| Type | Name | Format | Direction |
|------|------|--------|-----------|
| `C` | Call | `{C\|<id>\|<obj>\|<method>\|<args>}` | request |
| `R` | Return | `{R\|<id>\|<value>}` | response |
| `E` | Error | `{E\|<id>\|<message>}` | response |
| `G` | Get var | `{G\|<id>\|<obj>\|<varname>}` | request |
| `P` | Put var | `{P\|<id>\|<obj>\|<varname>\|<value>}` | request |

Response messages (`R`, `E`) use the same `msg_id` as the originating request.

### Message ID

Each side maintains its own incrementing counter.

- Browser: even IDs (0, 2, 4, ...)
- PicoRuby: odd IDs (1, 3, 5, ...)

Wraps at 9998/9999 back to 0/1. Counter never collides because of even/odd split.

### Examples

```
Browser calls PicoRuby:
  → {C|0|led|set_color|255,0,128}
  ← {R|0|true}

  → {C|2|led|get_status|}
  ← {R|2|"running"}

  → {G|4|led|brightness}
  ← {R|4|200}

  → {P|6|led|brightness|128}
  ← {R|6|128}

PicoRuby calls Browser:
  → {C|1|audio|get_level|}
  ← {R|1|0.75}

Error case:
  → {C|8|led|unknown_method|}
  ← {E|8|"method not found: unknown_method"}
```

### Value Encoding (Minimal JSON Subset)

A hand-parseable subset of JSON that works in PicoRuby without gems.

| Ruby type | Encoded form | Examples |
|-----------|-------------|----------|
| Integer | bare number | `42`, `-5`, `0` |
| Float | number with `.` | `3.14`, `-0.5` |
| String | double-quoted | `"hello"`, `"hello world"` |
| Symbol | colon-prefixed | `:name`, `:set_color` |
| true | `true` | |
| false | `false` | |
| nil | `null` | |
| Array | bracket-enclosed | `[1,2,"x"]` |

Strings support minimal escaping: `\"` and `\\` only.
No nested arrays or hashes in v0.1 (flat structures only).

Arguments in `C` messages use comma separation (same as array interior).
Top-level commas in strings must be escaped or the string must be quoted.

## Shared Interface Definition

Both sides load the same interface module to declare available methods and
variables. This enables static dispatch without metaprogramming.

### Interface DSL

```ruby
# shared/led_service.rb — loaded on both browser and PicoRuby
module LedService
  include MicroDRb::Interface

  # Declare callable methods with argument types
  dro_method :set_color,      args: [:integer, :integer, :integer]
  dro_method :set_brightness,  args: [:integer]
  dro_method :get_status,      args: []
  dro_method :clear,           args: []

  # Declare shared instance variables with types
  dro_var :brightness,  type: :integer
  dro_var :mode,        type: :string
  dro_var :colors,      type: :array
end
```

### Server Side (Object Host)

```ruby
# PicoRuby side — implements the interface
class LedController
  include LedService

  def initialize
    @brightness = 128
    @mode = "normal"
    @colors = [255, 0, 0]
  end

  def set_color(r, g, b)
    @colors = [r, g, b]
    true
  end

  def set_brightness(val)
    @brightness = val
  end

  def get_status
    @mode
  end

  def clear
    @colors = [0, 0, 0]
    @brightness = 0
    true
  end
end

# Registration
node = MicroDRb::Node.new(transport)
node.register("led", LedController.new, LedService)
node.start
```

### Client Side (Proxy)

```ruby
# Browser side — calls remote object
led = @node.proxy("led", LedService)

led.set_color(255, 0, 128)   # → RPC: {C|0|led|set_color|255,0,128}
status = led.get_status       # → RPC: {C|2|led|get_status|}
led.brightness                # → Get: {G|4|led|brightness}
led.brightness = 200          # → Put: {P|6|led|brightness|200}
```

### How the Proxy Works (PicoRuby Compatible)

Since PicoRuby likely lacks `method_missing` and `define_method`, the
interface module generates methods at `include` time using class_eval or
equivalent. If even that is unavailable, fall back to explicit `call` API:

```ruby
# Fallback explicit API (always works)
led = @node.proxy("led", LedService)
led.call(:set_color, 255, 0, 128)
led.get_var(:brightness)
led.set_var(:brightness, 200)
```

The interface definition provides validation: calling an undeclared method
or setting an undeclared variable raises an error locally before sending.

## Component Design

### 1. MicroDRb::Protocol

Encoding and decoding of wire messages.

```
Methods:
  .encode_call(id, obj, method, args)    → frame string
  .encode_return(id, value)              → frame string
  .encode_error(id, message)             → frame string
  .encode_get(id, obj, varname)          → frame string
  .encode_put(id, obj, varname, value)   → frame string
  .decode(frame)                         → {type:, id:, ...} hash
  .extract_frames(buffer)               → [frames], remaining
  .encode_value(ruby_obj)               → encoded string
  .decode_value(encoded)                → ruby object
```

Shared code: identical implementation on both platforms.

### 2. MicroDRb::Interface

DSL module for declaring shared interfaces.

```
Class methods (added when included):
  .dro_method(name, args: [])            → registers method signature
  .dro_var(name, type: :any)             → registers variable signature
  .dro_methods                           → {name => {args: [...]}}
  .dro_vars                              → {name => {type: ...}}
```

Shared code: identical on both platforms.

### 3. MicroDRb::Registry

Named object registry with interface validation.

```
Methods:
  #register(name, object, interface_mod) → registers object
  #lookup(name)                          → {object:, interface:} or nil
  #registered?(name)                     → boolean
  #dispatch_call(name, method, args)     → return value (or raise)
  #dispatch_get(name, varname)           → value
  #dispatch_put(name, varname, value)    → value
```

Shared code with platform-specific error handling.

### 4. MicroDRb::Node

Central coordinator. Each side (browser/PicoRuby) runs one Node.

```
Methods:
  #initialize(transport)
  #register(name, object, interface)     → register local object
  #proxy(name, interface)                → create proxy for remote object
  #start                                 → begin processing loop
  #process_incoming(data)                → handle received data
  #on_request(frame)                     → dispatch to local registry
  #on_response(frame)                    → resolve pending call
```

### 5. MicroDRb::Proxy

Client-side proxy representing a remote object.

```
Methods:
  #initialize(node, name, interface)
  #call(method, *args)                   → send C message, wait for R/E
  #get_var(varname)                      → send G message, wait for R
  #set_var(varname, value)               → send P message, wait for R
  + generated methods from interface (if platform supports it)
```

### 6. Transport (Platform-Specific)

#### MicroDRb::WasmTransport (Browser)

```
Methods:
  #initialize(serial_send_func)          → JS.global.serialSend wrapper
  #send(frame_string)                    → send via Web Serial
  #on_receive(data)                      → feed data to Node
```

Integrates with existing JS serial infrastructure. Registered as
a `rubySerialOnReceive` callback handler (alongside existing handlers).

#### MicroDRb::PicoTransport (PicoRuby)

```
Methods:
  #initialize(uart)                      → UART instance
  #send(frame_string)                    → uart.write
  #receive_blocking(timeout_ms)          → busy-wait UART read
  #poll                                  → non-blocking check for data
```

### 7. MicroDRb::FiberClient (Browser Only)

Wraps proxy calls in Fiber yield/resume for synchronous-looking API.

```
# Internally:
# 1. Stores {msg_id => Fiber.current} in pending table
# 2. Sends request via transport
# 3. Fiber.yield — returns control to event loop
# 4. When response arrives, Node finds Fiber by msg_id
# 5. Fiber.resume(value) — execution continues
```

Callers must be in a Fiber context. The VJPad command handler and
other entry points wrap execution in Fiber.new { ... }.resume.

## File Structure

```
lib/
  micro_drb/
    protocol.rb          # Wire protocol encode/decode (shared)
    interface.rb         # Interface definition DSL (shared)
    registry.rb          # Named object registry (shared)
    value_codec.rb       # Value serialization (shared)
    node.rb              # Coordinator (shared core, platform hooks)
    proxy.rb             # Remote object proxy (shared)
    wasm_transport.rb    # WebSerial transport (browser only)
    pico_transport.rb    # UART transport (PicoRuby only)
    fiber_client.rb      # Fiber-based sync wrapper (browser only)

shared/                  # Interface definitions loaded on both sides
  (user-defined, e.g. led_service.rb, audio_service.rb)

test/
  test_protocol.rb       # Protocol encode/decode tests
  test_value_codec.rb    # Value serialization tests
  test_interface.rb      # Interface DSL tests
  test_registry.rb       # Registry dispatch tests
  test_proxy.rb          # Proxy + mock transport tests
  test_node.rb           # Node integration tests (mock transport)
  test_fiber_client.rb   # Fiber-based sync tests
```

## Test Strategy

Following t-wada style TDD (Red → Green → Refactor).

### Phase 1: Protocol Layer
1. `test_value_codec.rb` — encode/decode each type (int, float, string,
   symbol, bool, nil, array). Round-trip property.
2. `test_protocol.rb` — encode/decode each message type (C, R, E, G, P).
   Frame extraction from buffer. Coexistence with `<...>` audio frames.

### Phase 2: Interface & Registry
3. `test_interface.rb` — dro_method/dro_var declaration, introspection.
4. `test_registry.rb` — register, lookup, dispatch_call, dispatch_get,
   dispatch_put. Error cases (unknown object, unknown method, type mismatch).

### Phase 3: Node & Proxy
5. `test_proxy.rb` — proxy call/get_var/set_var with mock transport.
   Generated methods from interface.
6. `test_node.rb` — end-to-end: two Nodes with loopback transport.
   Browser-side Node calls PicoRuby-side Node and vice versa.

### Phase 4: Fiber & Transport
7. `test_fiber_client.rb` — Fiber yield/resume lifecycle.
   Timeout handling. Multiple concurrent pending calls.

### Integration Testing

Manual integration with actual hardware (PicoRuby + ATOM Matrix) is
human-operated. Automated tests use mock transports.

Loopback test: connect two Nodes via in-memory transport, each hosting
objects the other calls. Verifies full request-response cycle.

## Implementation Phases

### v0.1: Core Protocol + RPC

Deliverables:
- [ ] MicroDRb::Protocol (encode/decode all message types)
- [ ] MicroDRb::ValueCodec (serialize/deserialize basic types)
- [ ] MicroDRb::Interface DSL
- [ ] MicroDRb::Registry (dispatch calls and variable access)
- [ ] MicroDRb::Proxy (explicit call/get_var/set_var API)
- [ ] MicroDRb::Node (coordinator with mock transport)
- [ ] Full test suite for above

### v0.2: Transport Integration

Deliverables:
- [ ] MicroDRb::WasmTransport (Web Serial bridge)
- [ ] MicroDRb::PicoTransport (UART)
- [ ] MicroDRb::FiberClient (browser-side sync wrapper)
- [ ] Integration with existing serial infrastructure
- [ ] Loopback integration tests

### v0.3: Visualizer Integration

Deliverables:
- [ ] Example shared interfaces (LedService, AudioService)
- [ ] VJPad commands for distributed object interaction
- [ ] Coexistence with existing audio frame protocol
- [ ] End-to-end demo with actual hardware

### Future (v0.4+)

- Proxy method generation (if PicoRuby supports define_method)
- Change notification / observer pattern for shared variables
- Batch calls (multiple RPC in single frame)
- Binary encoding option for performance
- Heartbeat / connection health monitoring

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| PicoRuby lacks Fiber | Blocking client still works | PicoRuby uses simple blocking UART wait |
| PicoRuby lacks define_method | No generated proxy methods | Explicit call() API as fallback |
| Frame exceeds UART buffer | Truncated messages | Length limit check + error response |
| Serial latency > 100ms | Slow RPC round-trip | Timeout mechanism, async option for non-critical calls |
| ruby.wasm Fiber edge cases | Yield from wrong context | Clear documentation, context validation |
| Frame delimiter collision | Parse errors | `{...}` distinct from `<...>`, escape `}` in strings |
| Concurrent requests from both sides | Interleaved frames | Frame extraction handles interleaving, msg_id matching |

## Protocol Size Constraints

At 115200 baud (~11.5 KB/s), maximum practical frame rate:

| Frame size | Max frames/sec | Round-trip latency |
|-----------|---------------|-------------------|
| 30 bytes | ~380 | ~5ms |
| 60 bytes | ~190 | ~10ms |
| 100 bytes | ~115 | ~17ms |
| 200 bytes | ~57 | ~35ms |

For RPC with small arguments, 30-60 byte frames are typical.
A method call + response round-trip takes ~10-20ms at 115200 baud,
well within acceptable latency for interactive use.

PicoRuby buffer should be increased from 64 to 256 bytes to accommodate
RPC frames. This is safe given ESP32's ~520KB SRAM.

## Coexistence with Existing Audio Protocol

MicroDRb frames use `{...}\n` delimiters, existing audio frames use `<...>\n`.
The serial receive handler distinguishes by first character:

```ruby
# In serial receive processing
if frame.start_with?('{')
  micro_drb_node.process_incoming(frame)
elsif frame.start_with?('<')
  serial_protocol.decode(frame)  # existing audio handling
end
```

Both protocols share the same physical serial connection without conflict.

## Open Questions

1. Does PicoRuby support `class_eval` or `define_method`? If yes, proxy
   can generate methods from interface at include time. If no, explicit
   call() API is the only option.
2. Maximum UART buffer size on ESP32 for PicoRuby? Need to verify 256-byte
   buffer is safe.
3. Should interface definitions live in a shared/ directory or be defined
   inline? Depends on how PicoRuby loads files (require support).
4. Timeout default: 500ms? 1000ms? Needs tuning with real hardware.
