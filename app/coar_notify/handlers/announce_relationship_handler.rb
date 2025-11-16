# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for AnnounceRelationship notifications
    #
    # Processes announcements of relationships between resources (e.g., supplementary data).
    class AnnounceRelationshipHandler < BaseHandler
      def handle
        relationship = notification.object

        unless relationship
          warn "COAR Notify: AnnounceRelationship missing object"
          return
        end

        # Extract relationship details
        # Note: Activity Streams uses 'as:subject', 'as:relationship', 'as:object'
        # but the Ruby lib may expose them with different accessors
        subject_url = extract_field(relationship, :subject)
        relationship_type = extract_field(relationship, :relationship)
        object_url = extract_field(relationship, :object)

        relationship_type_label = extract_relationship_type(relationship_type)

        message = build_message(
          title: "🔗 Related resource announced by #{service_name.capitalize}",
          notification_id: notification.id,
          summary: notification.summary,
          details: build_relationship_details(subject_url, relationship_type_label, object_url)
        )

        post_to_github(message)

        update_paper_metadata(
          service: service_name,
          relationship: {
            subject: subject_url,
            type: relationship_type_label,
            object: object_url
          },
          notification_id: notification.id,
          received_at: Time.now.iso8601
        )
      end

      private

      # Extract field from object (handles both direct access and hash access)
      def extract_field(obj, field_name)
        return nil unless obj

        # Try different accessor patterns
        if obj.respond_to?(field_name)
          obj.send(field_name)
        elsif obj.respond_to?(:[])
          obj[field_name.to_s] || obj[field_name.to_sym] || obj["as:#{field_name}"]
        end
      end

      # Extract human-readable relationship type from FRBR URI
      # e.g., "http://purl.org/vocab/frbr/core#supplement" -> "supplement"
      def extract_relationship_type(relationship_uri)
        return relationship_uri unless relationship_uri

        if relationship_uri.include?('#')
          relationship_uri.split('#').last
        elsif relationship_uri.include?('/')
          relationship_uri.split('/').last
        else
          relationship_uri
        end
      end

      # Build formatted relationship details
      def build_relationship_details(subject, type, object)
        <<~DETAILS.strip
          **Relationship Type:** #{type}
          **Subject Resource:** #{subject}
          **Related Resource:** #{object}
        DETAILS
      end
    end
  end
end
