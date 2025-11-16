# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # Reject pattern definition
      #
      # Received when an external service rejects our review or endorsement request.
      # Indicates the service will not act on the request.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/reject/
      class Reject < BasePattern
        pattern_name 'Reject'
        direction :receive
        activity_type 'Reject'
        coar_type nil
        description 'Service has rejected the review or endorsement request'

        # Reference to the original offer
        field :inReplyTo,
          type: :string,
          required: true,
          description: 'Notification ID of the original request being rejected'

        # The rejected object
        field :object,
          type: 'NotifyObject',
          required: false,
          description: 'The offer being rejected',
          properties: {
            id: { type: :string }
          }

        # Reason for rejection (should be provided)
        field :summary,
          type: :string,
          required: false,
          description: 'Explanation of why the request was rejected'

        # Service rejecting
        field :origin,
          type: 'NotifyService',
          required: true,
          description: 'Service that rejected the request',
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string },
            type: { type: :string, default: 'Service' }
          }

        # NeuroLibre
        field :target,
          type: 'NotifyService',
          required: true,
          description: 'NeuroLibre service',
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
            type: { type: :string, default: 'Person' }
          }
      end
    end
  end
end
