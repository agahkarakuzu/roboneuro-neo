# frozen_string_literal: true

require 'sequel'
require 'coarnotify'
require 'logger'

# CoarNotify module for COAR Notify protocol integration
#
# This module implements W3C Linked Data Notifications (LDN) and
# COAR Notify protocol support for roboneuro.
#
# Architecture: Option 2 - Embedded receiver/consumer with persistent storage
#
# Usage:
#   CoarNotify.enabled?
#   CoarNotify.inbox_url
#   CoarNotify.configure { |config| ... }
module CoarNotify
  # Add app directory to load path for autoloading
  $LOAD_PATH.unshift(File.expand_path('../..', __dir__)) unless $LOAD_PATH.include?(File.expand_path('../..', __dir__))

  # Autoload models
  module Models
    autoload :Notification, File.expand_path('models/notification', __dir__)
    autoload :ServiceRegistry, File.expand_path('models/service_registry', __dir__)
  end

  # Autoload services
  module Services
    autoload :Sender, File.expand_path('services/sender', __dir__)
    autoload :Receiver, File.expand_path('services/receiver', __dir__)
    autoload :Processor, File.expand_path('services/processor', __dir__)
    autoload :GitHubNotifier, File.expand_path('services/github_notifier', __dir__)
  end

  # Autoload workers
  module Workers
    autoload :SendWorker, File.expand_path('workers/send_worker', __dir__)
    autoload :ReceiveWorker, File.expand_path('workers/receive_worker', __dir__)
  end

  # Autoload routes
  module Routes
    autoload :Inbox, File.expand_path('routes/inbox', __dir__)
    autoload :InboxUI, File.expand_path('routes/inbox_ui', __dir__)
    autoload :Outbox, File.expand_path('routes/outbox', __dir__)
  end

  class << self
    # Check if COAR Notify is enabled
    # @return [Boolean] true if enabled
    def enabled?
      ENV['COAR_NOTIFY_ENABLED'] == 'true'
    end

    # Get the inbox URL for this instance
    # @return [String] inbox URL
    def inbox_url
      ENV['COAR_INBOX_URL'] || 'https://robo.neurolibre.org/coar/inbox'
    end

    # Get the service ID for this instance
    # @return [String] service ID
    def service_id
      ENV['COAR_SERVICE_ID'] || 'https://neurolibre.org'
    end

    # Check if IP whitelist is enabled
    # @return [Boolean] true if enabled
    def ip_whitelist_enabled?
      ENV['COAR_IP_WHITELIST_ENABLED'] == 'true'
    end

    # Get allowed IPs for whitelist
    # @return [Array<String>] list of allowed IP addresses
    def allowed_ips
      (ENV['COAR_ALLOWED_IPS'] || '').split(',').map(&:strip).reject(&:empty?)
    end

    # Get database connection
    # @return [Sequel::Database] database connection
    def database
      @database ||= establish_database_connection
    end

    # Configure the module
    # @yield configuration block
    def configure
      yield self if block_given?
    end

    # Initialize the module (called on app boot)
    def init!
      return unless enabled?

      # Establish database connection first
      @database = establish_database_connection

      setup_database
      run_migrations if auto_migrate?

      # Models will use the shared database connection via CoarNotify.database
      # No need to load them here - they'll be autoloaded when needed
    end

    private

    def establish_database_connection
      database_url = ENV['DATABASE_URL']

      unless database_url
        warn 'COAR Notify: DATABASE_URL not set, using in-memory SQLite (not recommended for production)'
        database_url = 'sqlite::memory:'
      end

      db = Sequel.connect(database_url)

      # Enable SQL logging to debug query generation issues
      db.loggers << Logger.new($stderr)

      # Enable PostgreSQL array support if using PostgreSQL
      if db.database_type == :postgres
        db.extension :pg_array
        db.extension :pg_json  # For JSONB column support
      end

      db
    end

    def setup_database
      # Set up Sequel plugins globally
      Sequel::Model.plugin :timestamps
      # NOT using validation_helpers due to SQL generation bugs
    end

    def run_migrations
      migrations_path = File.join(__dir__, '../../db/migrations')
      Sequel.extension :migration
      Sequel::Migrator.run(database, migrations_path)
    end

    def auto_migrate?
      ENV['COAR_AUTO_MIGRATE'] == 'true'
    end
  end
end
