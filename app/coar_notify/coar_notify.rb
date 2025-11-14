# frozen_string_literal: true

require 'sequel'
require 'coarnotify'

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
  # Autoload models
  module Models
    autoload :Notification, 'coar_notify/models/notification'
    autoload :ServiceRegistry, 'coar_notify/models/service_registry'
  end

  # Autoload services
  module Services
    autoload :Sender, 'coar_notify/services/sender'
    autoload :Receiver, 'coar_notify/services/receiver'
    autoload :Processor, 'coar_notify/services/processor'
    autoload :GitHubNotifier, 'coar_notify/services/github_notifier'
  end

  # Autoload workers
  module Workers
    autoload :SendWorker, 'coar_notify/workers/send_worker'
    autoload :ReceiveWorker, 'coar_notify/workers/receive_worker'
  end

  # Autoload routes
  module Routes
    autoload :Inbox, 'coar_notify/routes/inbox'
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

      setup_database
      run_migrations if auto_migrate?
      load_models
    end

    private

    def establish_database_connection
      database_url = ENV['DATABASE_URL']

      unless database_url
        warn 'COAR Notify: DATABASE_URL not set, using in-memory SQLite (not recommended for production)'
        database_url = 'sqlite::memory:'
      end

      Sequel.connect(database_url)
    end

    def setup_database
      # Set up Sequel plugins globally
      Sequel::Model.plugin :timestamps
      Sequel::Model.plugin :validation_helpers
    end

    def run_migrations
      migrations_path = File.join(__dir__, '../../db/migrations')
      Sequel.extension :migration
      Sequel::Migrator.run(database, migrations_path)
    end

    def auto_migrate?
      ENV['COAR_AUTO_MIGRATE'] == 'true'
    end

    def load_models
      # Ensure models use our database connection
      Models::Notification.db = database
    end
  end
end
