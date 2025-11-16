# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for AnnounceEndorsement notifications
    #
    # Processes endorsement publication announcements from external services.
    class AnnounceEndorsementHandler < BaseHandler
      def handle
        endorsement_url = notification.object&.id

        unless endorsement_url
          warn "COAR Notify: AnnounceEndorsement missing object.id (endorsement URL)"
          return
        end

        message = build_message(
          title: "⭐ Endorsement published by #{service_name.capitalize}",
          notification_id: notification.id,
          summary: notification.summary,
          details: "**Endorsement URL:** #{endorsement_url}"
        )

        post_to_github(message)

        update_paper_metadata(
          service: service_name,
          endorsement_url: endorsement_url,
          notification_id: notification.id,
          received_at: Time.now.iso8601
        )
      end
    end
  end
end
