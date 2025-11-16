# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for Reject notifications
    #
    # Processes rejections when a service declines our review or endorsement request.
    class RejectHandler < BaseHandler
      def handle
        message = build_message(
          title: "❌ #{service_name.capitalize} declined the request",
          notification_id: notification.id,
          summary: notification.summary,
          details: "The service has declined to process this request."
        )

        post_to_github(message)
      end
    end
  end
end
