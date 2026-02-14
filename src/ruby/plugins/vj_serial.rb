# Plugin: serial
# Web Serial API integration for VJ Pad command input.
# Provides connect/disconnect, send text, and view RX/TX logs.
# Actual serial I/O is delegated to JavaScript via JSBridge.
VJPlugin.define(:serial) do
  desc "Web Serial: connect, send, and receive via serial port"
  param :action, default: 0.0

  on_trigger do |params|
    # Serial plugin uses custom VJPad commands, not effect dispatch.
    # This trigger is a no-op; the real work is in VJPad DSL methods.
    {}
  end
end
