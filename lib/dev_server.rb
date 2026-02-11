#!/usr/bin/env ruby
# frozen_string_literal: true

require 'webrick'

# Development server with no-cache headers for all responses
# This ensures browser always fetches latest files during development

port = (ARGV[0] || 8000).to_i
document_root = ARGV[1] || '.'

server = WEBrick::HTTPServer.new(
  Port: port,
  DocumentRoot: document_root,
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO),
  AccessLog: [[File.open('server.log', 'a'), WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
)

# Add no-cache headers to all responses
server.mount_proc('/') do |req, res|
  # Set aggressive no-cache headers
  res['Cache-Control'] = 'no-cache, no-store, must-revalidate'
  res['Pragma'] = 'no-cache'
  res['Expires'] = '0'

  # Let WEBrick handle the actual file serving
  WEBrick::HTTPServlet::FileHandler.new(server, document_root).service(req, res)
end

trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }

puts "Starting development server on http://localhost:#{port}/"
puts "Press Ctrl+C to stop"

server.start
