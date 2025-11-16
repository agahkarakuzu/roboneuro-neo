# frozen_string_literal: true

require_relative 'base_handler'

module CoarNotify
  module Handlers
    # Handler for AnnounceResource notifications
    #
    # Processes announcements of service results or resources.
    class AnnounceResourceHandler < BaseHandler
      def handle
        resource_url = notification.object&.id
        resource_type = Array(notification.object&.type).join(', ')

        unless resource_url
          warn "COAR Notify: AnnounceResource missing object.id"
          return
        end

        message = build_message(
          title: "📦 Service result published by #{service_name.capitalize}",
          notification_id: notification.id,
          summary: notification.summary,
          details: "**Resource URL:** #{resource_url}\n**Type:** #{resource_type}"
        )

        post_to_github(message)

        update_paper_metadata(
          service: service_name,
          resource_url: resource_url,
          resource_type: resource_type,
          notification_id: notification.id,
          received_at: Time.now.iso8601
        )
      end
    end
  end
end
