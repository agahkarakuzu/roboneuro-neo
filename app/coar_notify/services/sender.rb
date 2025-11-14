# frozen_string_literal: true

require 'coarnotify'
require 'securerandom'

module CoarNotify
  module Services
    # Sender service for sending COAR Notify notifications (outbox)
    #
    # This service constructs and sends notifications to external services
    # according to COAR Notify patterns. It handles:
    # - Building notification payloads
    # - Sending via coarnotifyrb client
    # - Persisting sent notifications to database
    #
    # Supported patterns:
    # - RequestReview: Request review of a preprint
    # - RequestEndorsement: Request endorsement of a preprint
    #
    # Example usage:
    #   sender = Sender.new
    #   result = sender.send_request_review(paper_data, 'prereview')
    class Sender
      # Send a RequestReview notification
      #
      # @param paper_data [Hash] paper metadata
      # @option paper_data [String] :doi paper DOI
      # @option paper_data [Integer] :issue_id GitHub issue ID
      # @option paper_data [String] :repository_url GitHub repository URL
      # @option paper_data [String] :url preprint URL
      # @option paper_data [String] :title paper title
      # @option paper_data [String] :editor_orcid editor's ORCID (optional)
      # @option paper_data [String] :editor_name editor's name (optional)
      # @param service_name [String] target service name (e.g., 'prereview')
      # @return [Hash] result with success status and notification details
      # @raise [ArgumentError] if service is unknown or required data is missing
      def send_request_review(paper_data, service_name)
        # Validate service
        service_config = Models::ServiceRegistry.get(service_name)
        raise ArgumentError, "Unknown service: #{service_name}" unless service_config

        # Validate required paper data
        validate_paper_data!(paper_data, [:doi, :issue_id])

        # Create COAR Notify client
        client = Coarnotify.client(inbox_url: service_config['inbox_url'])

        # Build RequestReview notification
        notification = build_request_review(paper_data, service_config)

        # Validate notification
        notification.validate

        # Send notification
        response = client.send(notification, validate: true)

        # Persist to database
        record = Models::Notification.create_from_coar(
          notification,
          'sent',
          issue_id: paper_data[:issue_id],
          status: 'processed' # Sent notifications are immediately 'processed'
        )

        {
          success: true,
          notification_id: notification.id,
          response_action: response.action,
          response_location: response.location,
          record_id: record.id,
          service: service_name
        }
      end

      # Send a RequestEndorsement notification
      #
      # @param paper_data [Hash] paper metadata (same as send_request_review)
      # @param service_name [String] target service name
      # @return [Hash] result with success status and notification details
      def send_request_endorsement(paper_data, service_name)
        # Validate service
        service_config = Models::ServiceRegistry.get(service_name)
        raise ArgumentError, "Unknown service: #{service_name}" unless service_config

        # Validate required paper data
        validate_paper_data!(paper_data, [:doi, :issue_id])

        # Create client
        client = Coarnotify.client(inbox_url: service_config['inbox_url'])

        # Build RequestEndorsement notification
        notification = build_request_endorsement(paper_data, service_config)

        # Validate and send
        notification.validate
        response = client.send(notification, validate: true)

        # Persist to database
        record = Models::Notification.create_from_coar(
          notification,
          'sent',
          issue_id: paper_data[:issue_id],
          status: 'processed'
        )

        {
          success: true,
          notification_id: notification.id,
          response_action: response.action,
          response_location: response.location,
          record_id: record.id,
          service: service_name
        }
      end

      private

      # Build RequestReview notification
      #
      # @param paper_data [Hash] paper metadata
      # @param service_config [Hash] service configuration
      # @return [Coarnotify::Patterns::RequestReview] notification object
      def build_request_review(paper_data, service_config)
        notification = Coarnotify::Patterns::RequestReview.new

        # Generate unique notification ID
        notification_uuid = SecureRandom.uuid
        notification.id = "#{CoarNotify.inbox_url}/notifications/#{notification_uuid}"

        # Set origin (NeuroLibre via roboneuro)
        notification.origin = Coarnotify::Core::Notify::NotifyService.new
        notification.origin.id = CoarNotify.service_id
        notification.origin.inbox = CoarNotify.inbox_url

        # Set target (review service)
        notification.target = Coarnotify::Core::Notify::NotifyService.new
        notification.target.id = service_config['id']
        notification.target.inbox = service_config['inbox_url']

        # Set object (the preprint being reviewed)
        notification.object = Coarnotify::Patterns::RequestReviewObject.new
        notification.object.id = "https://doi.org/#{paper_data[:doi]}"
        notification.object.cite_as = "https://doi.org/#{paper_data[:doi]}"
        notification.object.type = ["ScholarlyArticle"]

        # Add item (repository or preprint URL)
        item = Coarnotify::Patterns::RequestReviewItem.new
        item.id = paper_data[:repository_url] || paper_data[:url] || notification.object.id
        item.media_type = "text/html"
        item.type = "WebPage"
        notification.object.item = item

        # Set actor (editor, if available)
        if paper_data[:editor_orcid] || paper_data[:editor_name]
          notification.actor = Coarnotify::Core::Notify::NotifyActor.new
          notification.actor.id = "https://orcid.org/#{paper_data[:editor_orcid]}" if paper_data[:editor_orcid]
          notification.actor.name = paper_data[:editor_name] if paper_data[:editor_name]
          notification.actor.type = "Person"
        end

        notification
      end

      # Build RequestEndorsement notification
      #
      # @param paper_data [Hash] paper metadata
      # @param service_config [Hash] service configuration
      # @return [Coarnotify::Patterns::RequestEndorsement] notification object
      def build_request_endorsement(paper_data, service_config)
        notification = Coarnotify::Patterns::RequestEndorsement.new

        # Generate unique notification ID
        notification_uuid = SecureRandom.uuid
        notification.id = "#{CoarNotify.inbox_url}/notifications/#{notification_uuid}"

        # Set origin
        notification.origin = Coarnotify::Core::Notify::NotifyService.new
        notification.origin.id = CoarNotify.service_id
        notification.origin.inbox = CoarNotify.inbox_url

        # Set target
        notification.target = Coarnotify::Core::Notify::NotifyService.new
        notification.target.id = service_config['id']
        notification.target.inbox = service_config['inbox_url']

        # Set object
        notification.object = Coarnotify::Core::Notify::NotifyObject.new
        notification.object.id = "https://doi.org/#{paper_data[:doi]}"
        notification.object.cite_as = "https://doi.org/#{paper_data[:doi]}"
        notification.object.type = ["ScholarlyArticle"]

        # Set actor
        if paper_data[:editor_orcid] || paper_data[:editor_name]
          notification.actor = Coarnotify::Core::Notify::NotifyActor.new
          notification.actor.id = "https://orcid.org/#{paper_data[:editor_orcid]}" if paper_data[:editor_orcid]
          notification.actor.name = paper_data[:editor_name] if paper_data[:editor_name]
          notification.actor.type = "Person"
        end

        notification
      end

      # Validate required paper data fields
      #
      # @param paper_data [Hash] paper data to validate
      # @param required_fields [Array<Symbol>] required field names
      # @raise [ArgumentError] if any required field is missing
      def validate_paper_data!(paper_data, required_fields)
        missing = required_fields.select { |field| paper_data[field].nil? || paper_data[field].to_s.empty? }

        unless missing.empty?
          raise ArgumentError, "Missing required paper data: #{missing.join(', ')}"
        end
      end
    end
  end
end
