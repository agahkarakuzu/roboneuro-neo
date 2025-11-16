# frozen_string_literal: true

module CoarNotify
  module Handlers
    # Handler Registry
    #
    # Auto-discovers handler classes and dispatches notifications to the appropriate handler.
    # Maps notification types (Activity Streams and COAR-specific) to handler classes.
    #
    # Usage:
    #   HandlerRegistry.handle(notification, record)  # Automatically dispatches
    #   HandlerRegistry.get_handler(notification)     # Get handler class
    class HandlerRegistry
      class << self
        # Get the handler mapping
        # @return [Hash] notification type => handler class
        def handlers
          @handlers ||= discover_handlers
        end

        # Get the appropriate handler class for a notification
        # @param notification [Coarnotify::Patterns::*] notification object
        # @return [Class] handler class (never nil, returns UnknownHandler as fallback)
        def get_handler(notification)
          # Get notification types
          notification_types = Array(notification.type).map(&:to_s)

          # Try COAR-specific types first (more specific)
          coar_types = notification_types.select { |t| t.include?('coar-notify') }
          coar_types.each do |coar_type|
            handler_class = handlers[coar_type]
            return handler_class if handler_class
          end

          # Fall back to Activity Streams types
          activity_types = notification_types.reject { |t| t.include?('coar-notify') }
          activity_types.each do |activity_type|
            handler_class = handlers[activity_type]
            return handler_class if handler_class
          end

          # Final fallback to UnknownHandler
          handlers['Unknown'] || UnknownHandler
        end

        # Handle a notification (main entry point)
        # @param notification [Coarnotify::Patterns::*] notification object
        # @param record [Models::Notification] database record
        # @return [void]
        def handle(notification, record)
          handler_class = get_handler(notification)
          handler = handler_class.new(notification, record)
          handler.process
        end

        # Reset the registry (useful for testing)
        def reset!
          @handlers = nil
        end

        private

        # Auto-discover all handler classes
        # @return [Hash] notification type => handler class
        def discover_handlers
          require_all_handlers

          handler_map = {}

          # Discover all handler classes
          Handlers.constants.each do |const_name|
            next if const_name == :BaseHandler || const_name == :HandlerRegistry

            klass = Handlers.const_get(const_name)
            next unless klass.is_a?(Class) && klass < BaseHandler

            # Map handler to notification types it handles
            handler_name = const_name.to_s.gsub('Handler', '')

            # Map specific types based on naming convention
            case handler_name
            when 'Accept'
              handler_map['Accept'] = klass
            when 'Reject'
              handler_map['Reject'] = klass
            when 'TentativeAccept'
              handler_map['TentativeAccept'] = klass
            when 'TentativeReject'
              handler_map['TentativeReject'] = klass
            when 'AnnounceReview'
              handler_map['coar-notify:ReviewAction'] = klass
              # Also map to 'Announce' as a fallback, but only if not already mapped
              handler_map['Announce'] ||= klass
            when 'AnnounceEndorsement'
              handler_map['coar-notify:EndorsementAction'] = klass
            when 'AnnounceRelationship'
              handler_map['coar-notify:RelationshipAction'] = klass
            when 'AnnounceResource'
              # Generic Announce - will be used if no specific COAR type matches
              # Only set if not already set by a more specific handler
              handler_map['Announce'] ||= klass
            when 'Unprocessable'
              handler_map['coar-notify:UnprocessableNotification'] = klass
              handler_map['Flag'] ||= klass
            when 'Unknown'
              handler_map['Unknown'] = klass
            end
          end

          handler_map
        end

        # Require all handler files
        def require_all_handlers
          handlers_dir = File.dirname(__FILE__)
          Dir[File.join(handlers_dir, '*_handler.rb')].each do |file|
            require file
          end
        end
      end
    end
  end
end
