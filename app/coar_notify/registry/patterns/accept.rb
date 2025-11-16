# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # Accept pattern definition
      #
      # Received when an external service accepts our review or endorsement request.
      # Indicates the service acknowledges the request and intends to act on it.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/accept/
      class Accept < BasePattern
        pattern_name 'Accept'
        direction :receive
        activity_type 'Accept'
        coar_type nil  # No COAR-specific type
        description 'Service has accepted the review or endorsement request'

        # Reference to the original offer
        field :inReplyTo,
          type: :string,
          required: true,
          description: 'Notification ID of the original request being accepted'

        # The accepted object (our original offer)
        field :object,
          type: 'NotifyObject',
          required: false,
          description: 'The offer being accepted',
          properties: {
            id: { type: :string, description: 'Reference to the offer' }
          }

        # Optional summary explaining acceptance
        field :summary,
          type: :string,
          required: false,
          description: 'Optional explanation of the acceptance'

        # Service accepting the request
        field :origin,
          type: 'NotifyService',
          required: true,
          description: 'Service that accepted the request',
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string },
            type: { type: :string, default: 'Service' }
          }

        # NeuroLibre (target of acceptance)
        field :target,
          type: 'NotifyService',
          required: true,
          description: 'NeuroLibre service',
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string },
            type: { type: :string, default: 'Service' }
          }

        # Actor who accepted (optional)
        field :actor,
          type: 'NotifyActor',
          required: false,
          description: 'Person who accepted the request',
          properties: {
            id: { type: :string },
            name: { type: :string },
            type: { type: :string, default: 'Person' }
          }
      end
    end
  end
end
