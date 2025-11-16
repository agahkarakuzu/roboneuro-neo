# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for AnnounceReview notifications
    #
    # Processes review publication announcements from external services.
    class AnnounceReviewHandler < BaseHandler
      def handle
        review_url = notification.object&.id

        unless review_url
          warn "COAR Notify: AnnounceReview missing object.id (review URL)"
          return
        end

        message = build_message(
          title: "📝 Review published by #{service_name.capitalize}",
          notification_id: notification.id,
          summary: notification.summary,
          details: "**Review URL:** #{review_url}"
        )

        post_to_github(message)

        update_paper_metadata(
          service: service_name,
          review_url: review_url,
          notification_id: notification.id,
          received_at: Time.now.iso8601
        )
      end
    end
  end
end
