# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # AnnounceReview pattern definition
      #
      # Received when a service publishes a review of one of our preprints.
      # This can be in response to a RequestReview or unsolicited.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/announce-review/
      class AnnounceReview < BasePattern
        pattern_name 'AnnounceReview'
        direction :receive
        activity_type 'Announce'
        coar_type 'coar-notify:ReviewAction'
        description 'A review of the preprint has been published'

        # The published review
        field :object,
          type: 'Review',
          required: true,
          description: 'The published review resource',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'URL of the published review'
            },
            'ietf:cite-as': {
              type: :string,
              description: 'Persistent citation URI for the review'
            },
            type: {
              type: :array,
              required: true,
              description: 'Type including Activity Streams and schema.org types'
            }
          }

        # The preprint that was reviewed
        field :context,
          type: 'ScholarlyArticle',
          required: false,
          description: 'The preprint that was reviewed',
          properties: {
            id: {
              type: :string,
              description: 'DOI or URL of the preprint'
            },
            type: {
              type: :array,
              default: ['ScholarlyArticle']
            }
          }

        # Optional reply reference (if this is in response to a RequestReview)
        field :inReplyTo,
          type: :string,
          required: false,
          description: 'Notification ID of the original RequestReview (if applicable)'

        # Summary of the review
        field :summary,
          type: :string,
          required: false,
          description: 'Brief summary or abstract of the review'

        # Review service
        field :origin,
          type: 'NotifyService',
          required: true,
          description: 'Service that published the review',
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

        # Actor (review service or reviewer)
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
