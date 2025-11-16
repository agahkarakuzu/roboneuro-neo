# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for unknown notification types
    #
    # Fallback handler for notification types we don't specifically handle.
    class UnknownHandler < BaseHandler
      def handle
        notification_types = Array(notification.type).join(', ')

        warn "COAR Notify: Unknown notification type: #{notification_types}"

        message = build_message(
          title: "ℹ️ COAR Notification received",
          notification_id: notification.id,
          summary: notification.summary,
          details: "**Type:** #{notification_types}"
        )

        post_to_github(message)
      end
    end
  end
end
