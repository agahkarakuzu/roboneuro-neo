# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for TentativeAccept notifications
    #
    # Processes provisional acceptances (may change).
    class TentativeAcceptHandler < BaseHandler
      def handle
        message = build_message(
          title: "🟡 #{service_name.capitalize} tentatively accepted the request",
          notification_id: notification.id,
          summary: notification.summary,
          details: "The service has provisionally accepted. Awaiting confirmation."
        )

        post_to_github(message)
      end
    end
  end
end
