# frozen_string_literal: true

module CoarNotify
  module Handlers
    # Base handler for all received COAR Notify notifications
    #
    # Provides common functionality for processing notifications:
    # - GitHub posting
    # - Issue lookup
    # - Metadata updates
    # - Error handling
    #
    # All specific handlers inherit from this class and implement the #handle method.
    #
    # Example:
    #   class AcceptHandler < BaseHandler
    #     def handle
    #       message = build_message(title: "✅ Request accepted")
    #       post_to_github(message)
    #     end
    #   end
    class BaseHandler
      attr_reader :notification, :record

      # Initialize handler with notification and database record
      # @param notification [Coarnotify::Patterns::*] parsed notification object
      # @param record [Models::Notification] database record
      def initialize(notification, record)
        @notification = notification
        @record = record
      end

      # Process the notification (template method)
      # Calls handle() and manages status updates
      # @return [void]
      def process
        handle
        mark_processed
      rescue => e
        mark_failed(e)
        raise
      end

      # Handle the notification (override in subclasses)
      # @return [void]
      def handle
        raise NotImplementedError, "#{self.class} must implement #handle"
      end

      protected

      # Get service name from record or extract from notification
      # @return [String] service name
      def service_name
        @service_name ||= record.service_name || extract_service_name || 'External service'
      end

      # Post a message to the GitHub issue
      # @param message [String] markdown message
      # @return [void]
      def post_to_github(message)
        issue_id = find_issue_id

        unless issue_id
          warn "COAR Notify: Could not find issue ID for notification #{record.id}"
          return
        end

        GitHubNotifier.post_comment(issue_id, message)
      end

      # Build a formatted GitHub comment message
      # @param title [String] message title
      # @param summary [String, nil] notification summary
      # @param details [String, nil] additional details
      # @param notification_id [String, nil] notification ID
      # @return [String] formatted markdown message
      def build_message(title:, summary: nil, details: nil, notification_id: nil)
        parts = []
        parts << "### #{title}"
        parts << ""
        parts << summary if summary && !summary.empty?
        parts << details if details && !details.empty?
        parts << ""
        parts << "<details>"
        parts << "<summary>Notification Details</summary>"
        parts << ""
        parts << "**Notification ID:** `#{notification_id || notification.id}`"
        parts << ""
        parts << "_Via COAR Notify protocol._"
        parts << "</details>"

        parts.join("\n")
      end

      # Find GitHub issue ID for this notification
      # Tries multiple strategies in order
      # @return [Integer, nil] issue ID or nil
      def find_issue_id
        # Strategy 1: Already stored in record
        return record.issue_id if record.issue_id

        # Strategy 2: Find from sent notification via inReplyTo
        if record.in_reply_to
          sent = Models::Notification.where(
            notification_id: record.in_reply_to,
            direction: 'sent'
          ).first

          return sent.issue_id if sent&.issue_id
        end

        # Strategy 3: Query neurolibre API by DOI
        if record.paper_doi
          issue_id = GitHubNotifier.get_issue_by_doi(record.paper_doi)

          # Update record with found issue_id for future use
          if issue_id
            record.update(issue_id: issue_id)
            return issue_id
          end
        end

        # Strategy 4: Extract from context if present
        if notification.respond_to?(:context) && notification.context
          context_id = notification.context.id
          if context_id && context_id.include?('doi.org')
            doi = context_id.split('doi.org/').last
            issue_id = GitHubNotifier.get_issue_by_doi(doi)

            if issue_id
              record.update(
                issue_id: issue_id,
                paper_doi: doi
              )
              return issue_id
            end
          end
        end

        nil
      end

      # Update paper metadata in NeuroLibre
      # @param metadata_hash [Hash] metadata to update
      # @return [void]
      def update_paper_metadata(metadata_hash)
        return unless record.paper_doi

        GitHubNotifier.update_paper_metadata(record.paper_doi, metadata_hash)
      rescue => e
        warn "COAR Notify: Failed to update paper metadata: #{e.message}"
      end

      # Mark notification as processed
      # @return [void]
      def mark_processed
        record.update(
          status: 'processed',
          processed_at: Time.now
        )
      end

      # Mark notification as failed
      # @param error [Exception] the error that occurred
      # @return [void]
      def mark_failed(error)
        record.update(
          status: 'failed',
          error_message: "#{error.class}: #{error.message}",
          processed_at: Time.now
        )
      end

      # Extract service name from origin ID
      # @return [String, nil] service name or nil
      def extract_service_name
        origin_id = notification.origin&.id
        return nil unless origin_id

        # Match against known services
        Models::ServiceRegistry.all.each do |service_key, service_config|
          return service_key if service_config['id'] == origin_id
        end

        nil
      end
    end
  end
end
