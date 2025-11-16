# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for TentativeReject notifications
    #
    # Processes provisional rejections (may reconsider).
    class TentativeRejectHandler < BaseHandler
      def handle
        message = build_message(
          title: "🟡 #{service_name.capitalize} tentatively declined the request",
          notification_id: notification.id,
          summary: notification.summary,
          details: "The service has provisionally declined but may reconsider."
        )

        post_to_github(message)
      end
    end
  end
end
