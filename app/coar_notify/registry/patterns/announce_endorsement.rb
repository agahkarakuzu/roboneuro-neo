# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # AnnounceEndorsement pattern definition
      #
      # Received when a service publishes an endorsement of one of our preprints.
      # This can be in response to a RequestEndorsement or unsolicited.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/announce-endorsement/
      class AnnounceEndorsement < BasePattern
        pattern_name 'AnnounceEndorsement'
        direction :receive
        activity_type 'Announce'
        coar_type 'coar-notify:EndorsementAction'
        description 'An endorsement of the preprint has been published'

        # The published endorsement
        field :object,
          type: 'Endorsement',
          required: true,
          description: 'The published endorsement resource',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'URL of the published endorsement'
            },
            'ietf:cite-as': {
              type: :string,
              description: 'Persistent citation URI for the endorsement'
            },
            type: {
              type: :array,
              required: true,
              description: 'Type including Activity Streams and schema.org types'
            }
          }

        # The preprint that was endorsed
        field :context,
          type: 'ScholarlyArticle',
          required: false,
          description: 'The preprint that was endorsed',
          properties: {
            id: { type: :string, description: 'DOI or URL of the preprint' },
            type: { type: :array, default: ['ScholarlyArticle'] }
          }

        # Optional reply reference
        field :inReplyTo,
          type: :string,
          required: false,
          description: 'Notification ID of the original RequestEndorsement (if applicable)'

        # Summary
        field :summary,
          type: :string,
          required: false,
          description: 'Brief summary of the endorsement'

        # Endorsement service
        field :origin,
          type: 'NotifyService',
          required: true,
          description: 'Service that published the endorsement',
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
