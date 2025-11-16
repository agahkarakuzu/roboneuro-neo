# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for Accept notifications
    #
    # Processes acknowledgements when a service accepts our review or endorsement request.
    class AcceptHandler < BaseHandler
      def handle
        message = build_message(
          title: "✅ #{service_name.capitalize} accepted the request",
          notification_id: notification.id,
          summary: notification.summary
        )

        post_to_github(message)
      end
    end
  end
end
