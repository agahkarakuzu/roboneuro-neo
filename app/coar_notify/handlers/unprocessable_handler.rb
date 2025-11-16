# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for Unprocessable notifications
    #
    # Processes error notifications when a service couldn't process our notification.
    class UnprocessableHandler < BaseHandler
      def handle
        error_summary = notification.summary
        failed_notification_id = notification.object&.id

        message = build_message(
          title: "⚠️ #{service_name.capitalize} couldn't process our notification",
          notification_id: notification.id,
          summary: error_summary,
          details: failed_notification_id ? "**Failed Notification:** `#{failed_notification_id}`" : nil
        )

        post_to_github(message)

        # Mark the original sent notification as failed if we can find it
        if failed_notification_id
          original = Models::Notification.where(
            notification_id: failed_notification_id,
            direction: 'sent'
          ).first

          if original
            original.update(
              status: 'failed',
              error_message: "Service reported: #{error_summary}"
            )
          end
        end
      end
    end
  end
end
