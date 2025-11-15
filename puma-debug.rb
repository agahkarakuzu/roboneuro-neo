# Simplified Puma config for debugging - single worker, no preload
# Usage: bundle exec puma -C ./puma-debug.rb

# Load .env file if it exists
if File.exist?('.env')
  require 'dotenv'
  Dotenv.load('.env')
end

threads 1, 5
port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RACK_ENV") { "development" }

# No workers (single mode for easier debugging)
# No preload (errors show immediately)

puts "=" * 80
puts "PUMA DEBUG MODE - Single worker, no preload"
puts "Environment variables:"
puts "  COAR_NOTIFY_ENABLED: #{ENV['COAR_NOTIFY_ENABLED']}"
puts "  DATABASE_URL: #{ENV['DATABASE_URL'] ? ENV['DATABASE_URL'].gsub(/:[^:@]+@/, ':***@') : 'NOT SET'}"
puts "  COAR_AUTO_MIGRATE: #{ENV['COAR_AUTO_MIGRATE']}"
puts "=" * 80
