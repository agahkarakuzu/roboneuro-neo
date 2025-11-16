# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # RequestEndorsement pattern definition
      #
      # Used to request endorsement/validation of a scholarly article from an external service.
      # This is an outgoing notification from NeuroLibre to endorsement services like PCI.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/request-endorsement/
      class RequestEndorsement < BasePattern
        pattern_name 'RequestEndorsement'
        direction :send
        activity_type 'Offer'
        coar_type 'coar-notify:EndorsementAction'
        description 'Request endorsement of a preprint from an external endorsement service'

        # The preprint to be endorsed
        field :object,
          type: 'NotifyObject',
          required: true,
          description: 'The scholarly article/preprint being endorsed',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'DOI of the preprint'
            },
            cite_as: {
              type: :string,
              required: true,
              description: 'Persistent citation URI'
            },
            type: {
              type: :array,
              required: true,
              default: ['ScholarlyArticle'],
              description: 'Type of the resource'
            }
          }

        # Author/editor making the request (optional)
        field :actor,
          type: 'NotifyActor',
          required: false,
          description: 'Person requesting the endorsement',
          properties: {
            id: {
              type: :string,
              description: 'ORCID'
            },
            name: {
              type: :string,
              description: 'Name'
            },
            type: {
              type: :string,
              default: 'Person'
            }
          }

        # Target service (auto-populated)
        field :target,
          type: 'NotifyService',
          required: true,
          auto_populate: true,
          description: 'Endorsement service',
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
