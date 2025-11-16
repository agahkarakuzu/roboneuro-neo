# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # UndoOffer pattern definition
      #
      # Used to retract a previously sent request (RequestReview or RequestEndorsement).
      # This is an outgoing notification from NeuroLibre to cancel a pending request.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/undo-offer/
      class UndoOffer < BasePattern
        pattern_name 'UndoOffer'
        direction :send
        activity_type 'Undo'
        coar_type nil  # No COAR-specific type for Undo
        description 'Withdraw a previously sent review or endorsement request'

        # The original offer being withdrawn
        field :object,
          type: 'NotifyObject',
          required: true,
          description: 'The original offer/request being withdrawn',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'Notification ID of the original request'
            }
          }

        # Reply reference to original notification
        field :inReplyTo,
          type: :string,
          required: true,
          description: 'Notification ID of the original request being undone'

        # Reason for withdrawal (optional)
        field :summary,
          type: :string,
          required: false,
          description: 'Brief explanation of why the offer is being withdrawn'

        # Actor withdrawing the offer (optional)
        field :actor,
          type: 'NotifyActor',
          required: false,
          description: 'Person withdrawing the request',
          properties: {
            id: { type: :string, description: 'ORCID' },
            name: { type: :string, description: 'Name' },
            type: { type: :string, default: 'Person' }
          }

        # Target service (auto-populated)
        field :target,
          type: 'NotifyService',
          required: true,
          auto_populate: true,
          description: 'Service that received the original request',
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string, required: true },
            type: { type: :string, default: 'Service' }
          }

        # Origin service (auto-populated)
        field :origin,
          type: 'NotifyService',
          required: true,
          auto_populate: true,
          description: 'NeuroLibre service',
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string, required: true },
            type: { type: :string, default: 'Service' }
          }
      end
    end
  end
end
