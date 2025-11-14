# frozen_string_literal: true

require 'sequel'
require 'coarnotify'

module CoarNotify
  module Models
    # Notification model for persisting COAR Notify notifications
    #
    # This model stores both sent (outbox) and received (inbox) notifications
    # in compliance with W3C LDN and COAR Notify specifications.
    #
    # Example usage:
    #   # Create from received notification
    #   notification = Notification.create_from_coar(coar_obj, 'received')
    #
    #   # Query notifications
    #   Notification.received.pending.all
    #   Notification.for_paper('10.55458/neurolibre.00027').all
    class Notification < Sequel::Model(:coar_notifications)
      # Use the shared database connection from CoarNotify module
      def self.db
        CoarNotify.database
      end

      plugin :timestamps, update_on_create: true
      plugin :validation_helpers

      # Scopes for common queries
      dataset_module do
        # Get received notifications (inbox)
        def received
          where(direction: 'received')
        end

        # Get sent notifications (outbox)
        def sent
          where(direction: 'sent')
        end

        # Get pending notifications
        def pending
          where(status: 'pending')
        end

        # Get processing notifications
        def processing
          where(status: 'processing')
        end

        # Get processed notifications
        def processed
          where(status: 'processed')
        end

        # Get failed notifications
        def failed
          where(status: 'failed')
        end

        # Get notifications for a specific paper DOI
        def for_paper(doi)
          where(paper_doi: doi)
        end

        # Get notifications by service
        def by_service(service_name)
          where(service_name: service_name)
        end

        # Get recent notifications
        def recent(limit: 100)
          reverse_order(:created_at).limit(limit)
        end

        # Get notifications by type
        def by_type(notification_type)
          where(Sequel.pg_array(:notification_types).contains([notification_type]))
        end
      end

      # Validations
      def validate
        super
        validates_presence [:notification_id, :direction, :notification_types,
                            :origin_id, :target_id, :object_id, :payload, :status]
        validates_includes ['sent', 'received'], :direction
        validates_includes ['pending', 'processing', 'processed', 'failed'], :status
        validates_unique :notification_id
      end

      # Parse stored payload back to coarnotifyrb object
      # @return [Coarnotify::Patterns::*] coarnotifyrb notification object
      def to_coar_object
        Coarnotify.from_hash(payload)
      end

      # Get human-readable notification type
      # @return [String] primary notification type
      def primary_type
        notification_types.last # COAR patterns typically have base type last
      end

      # Check if notification is of a specific type
      # @param type [String] notification type to check
      # @return [Boolean]
      def type?(type)
        notification_types.include?(type)
      end

      # Mark notification as processing
      def mark_processing!
        update(status: 'processing', updated_at: Time.now)
      end

      # Mark notification as processed
      def mark_processed!
        update(
          status: 'processed',
          processed_at: Time.now,
          updated_at: Time.now,
          error_message: nil
        )
      end

      # Mark notification as failed
      # @param error [String, Exception] error message or exception
      def mark_failed!(error)
        error_msg = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
        update(
          status: 'failed',
          error_message: error_msg,
          updated_at: Time.now
        )
      end

      # Class methods for creating notifications
      class << self
        # Create notification record from coarnotifyrb object
        # @param notification [Coarnotify::Patterns::*] coarnotifyrb notification
        # @param direction [String] 'sent' or 'received'
        # @param extra_attrs [Hash] additional attributes (issue_id, etc.)
        # @return [Notification] created record
        def create_from_coar(notification, direction, extra_attrs = {})
          # Extract types and wrap in Sequel.pg_array for PostgreSQL
          notif_types = extract_types(notification.type)
          obj_types = extract_types(notification.object&.type)
          ctx_types = extract_types(notification.context&.type)

          create(
            notification_id: notification.id,
            direction: direction,
            notification_types: notif_types ? Sequel.pg_array(notif_types) : nil,
            origin_id: notification.origin.id,
            origin_inbox: notification.origin&.inbox,
            target_id: notification.target.id,
            target_inbox: notification.target&.inbox,
            object_id: notification.object.id,
            object_type: obj_types ? Sequel.pg_array(obj_types) : nil,
            context_id: notification.context&.id,
            context_type: ctx_types ? Sequel.pg_array(ctx_types) : nil,
            in_reply_to: (notification.respond_to?(:in_reply_to) ? notification.in_reply_to : nil),
            actor_id: notification.actor&.id,
            actor_name: notification.actor&.name,
            summary: (notification.respond_to?(:summary) ? notification.summary : nil),
            payload: parse_payload(notification),
            paper_doi: extract_paper_doi(notification),
            service_name: extract_service_name(notification, direction),
            status: extra_attrs[:status] || 'pending',
            issue_id: extra_attrs[:issue_id],
            created_at: Time.now,
            updated_at: Time.now
          )
        end

        # Extract paper DOI from notification
        # @param notification [Coarnotify::Patterns::*] coarnotifyrb notification
        # @return [String, nil] extracted DOI or nil
        def extract_paper_doi(notification)
          # Try object.id first (usually the preprint DOI)
          doi_url = notification.object&.id || notification.context&.id
          return nil unless doi_url

          # Extract DOI pattern (e.g., "10.55458/neurolibre.00027")
          match = doi_url.match(%r{(10\.\d+/[\w\.\-]+)})
          match ? match[1] : nil
        end

        # Extract service name from notification
        # @param notification [Coarnotify::Patterns::*] coarnotifyrb notification
        # @param direction [String] 'sent' or 'received'
        # @return [String, nil] service name or nil
        def extract_service_name(notification, direction)
          service_id = if direction == 'sent'
                         notification.target&.id
                       else
                         notification.origin&.id
                       end

          return nil unless service_id

          ServiceRegistry.name_from_id(service_id) || service_id
        end

        private

        # Extract types from coarnotify type object to array of strings
        # @param type_obj [Object] type object from coarnotify
        # @return [Array<String>, nil] array of type strings or nil
        def extract_types(type_obj)
          return nil if type_obj.nil?

          # If it's already an array of strings, return it
          return type_obj if type_obj.is_a?(Array) && type_obj.all? { |t| t.is_a?(String) }

          # If it's a single string, wrap in array
          return [type_obj] if type_obj.is_a?(String)

          # If it responds to to_a, convert to array
          if type_obj.respond_to?(:to_a)
            types = type_obj.to_a
            return types.map(&:to_s) if types.is_a?(Array)
          end

          # Try to get the value if it's a wrapper object
          if type_obj.respond_to?(:value)
            return extract_types(type_obj.value)
          end

          # Fallback: convert to string and wrap in array
          [type_obj.to_s]
        end

        # Parse notification to JSON hash
        # @param notification [Coarnotify::Patterns::*] coarnotifyrb notification
        # @return [Hash] JSON-compatible hash
        def parse_payload(notification)
          json_string = notification.to_json
          JSON.parse(json_string)
        rescue JSON::ParserError
          # Fallback: use notification's internal hash representation
          notification.instance_variable_get(:@properties) || {}
        end
      end
    end
  end
end
