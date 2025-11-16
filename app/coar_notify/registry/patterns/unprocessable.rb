# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # Unprocessable pattern definition
      #
      # Received when a service could not process a notification we sent.
      # This indicates an error or validation failure on their end.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/unprocessable/
      class Unprocessable < BasePattern
        pattern_name 'Unprocessable'
        direction :receive
        activity_type 'Flag'
        coar_type 'coar-notify:UnprocessableNotification'
        description 'Service could not process our notification'

        # The notification that couldn't be processed
        field :object,
          type: 'Activity',
          required: true,
          description: 'The problematic notification',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'Notification ID of the notification that failed'
            }
          }

        # Reference to the failed notification
        field :inReplyTo,
          type: :string,
          required: true,
          description: 'Notification ID of the failed notification'

        # Error description
        field :summary,
          type: :string,
          required: true,
          description: 'Explanation of why the notification was unprocessable'

        # Service reporting the error
        field :origin,
          type: 'NotifyService',
          required: true,
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string },
            type: { type: :string, default: 'Service' }
          }

        # NeuroLibre
        field :target,
          type: 'NotifyService',
          required: true,
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string },
            type: { type: :string, default: 'Service' }
          }

        field :actor,
          type: 'NotifyActor',
          required: false,
          properties: {
            id: { type: :string },
            name: { type: :string },
            type: { type: :string }
          }
      end
    end
  end
end
