require 'rake/testtask'

PID_FILE = 'server.pid'
PORT = 8000

namespace :server do
  desc 'Start local HTTP server on port 8000 (background)'
  task :start do
    if File.exist?(PID_FILE)
      pid = File.read(PID_FILE).strip.to_i
      if process_running?(pid)
        puts "Server is already running (PID: #{pid})"
        exit 1
      else
        puts "Stale PID file found. Removing..."
        File.delete(PID_FILE)
      end
    end

    if port_in_use?(PORT)
      puts "Port #{PORT} is already in use by another process"
      exit 1
    end

    puts "Starting server on port #{PORT}..."
    pid = spawn('bundle', 'exec', 'ruby', 'lib/dev_server.rb', PORT.to_s, '.',
                out: 'server.log', err: 'server.log')
    Process.detach(pid)
    File.write(PID_FILE, pid)

    sleep 1
    if process_running?(pid)
      puts "Server started successfully (PID: #{pid})"
      puts "Access at http://localhost:#{PORT}/index.html"
      puts "Logs: server.log"
    else
      puts "Failed to start server. Check server.log for details."
      File.delete(PID_FILE) if File.exist?(PID_FILE)
      exit 1
    end
  end

  desc 'Stop local HTTP server'
  task :stop do
    unless File.exist?(PID_FILE)
      puts "Server is not running (no PID file found)"
      exit 0
    end

    pid = File.read(PID_FILE).strip.to_i

    unless process_running?(pid)
      puts "Server is not running (stale PID file)"
      File.delete(PID_FILE)
      exit 0
    end

    puts "Stopping server (PID: #{pid})..."
    Process.kill('TERM', pid)

    # Wait for process to terminate
    10.times do
      sleep 0.5
      unless process_running?(pid)
        File.delete(PID_FILE)
        puts "Server stopped successfully"
        exit 0
      end
    end

    # Force kill if still running
    if process_running?(pid)
      puts "Server did not stop gracefully, forcing..."
      Process.kill('KILL', pid)
      sleep 0.5
    end

    File.delete(PID_FILE)
    puts "Server stopped"
  end

  desc 'Restart local HTTP server'
  task :restart => [:stop, :start]

  desc 'Check server status'
  task :status do
    if File.exist?(PID_FILE)
      pid = File.read(PID_FILE).strip.to_i
      if process_running?(pid)
        puts "Server is running (PID: #{pid})"
        puts "Access at http://localhost:#{PORT}/index.html"
      else
        puts "Server is not running (stale PID file found)"
      end
    else
      puts "Server is not running"
    end

    if port_in_use?(PORT)
      puts "Note: Port #{PORT} is in use"
    end
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

task :default => :test

# Helper methods
def process_running?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH, Errno::EPERM
  false
end

def port_in_use?(port)
  result = `lsof -i :#{port} 2>/dev/null`
  !result.empty?
end
