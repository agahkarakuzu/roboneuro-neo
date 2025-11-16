# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # AnnounceRelationship pattern definition
      #
      # Received when a service announces a relationship between two resources,
      # typically linking a preprint to related content like datasets, code, or supplementary materials.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/announce-relationship/
      class AnnounceRelationship < BasePattern
        pattern_name 'AnnounceRelationship'
        direction :receive
        activity_type 'Announce'
        coar_type 'coar-notify:RelationshipAction'
        description 'A relationship between resources has been established'

        # The relationship being announced
        field :object,
          type: 'Relationship',
          required: true,
          description: 'The relationship between two resources',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'Unique identifier for this relationship'
            },
            type: {
              type: :string,
              required: true,
              default: 'Relationship',
              description: 'Type must be "Relationship"'
            },
            'as:subject': {
              type: :string,
              required: true,
              description: 'Subject resource URI (the resource that has the relationship)'
            },
            'as:relationship': {
              type: :string,
              required: true,
              description: 'FRBR relationship type URI (e.g., http://purl.org/vocab/frbr/core#supplement)'
            },
            'as:object': {
              type: :string,
              required: true,
              description: 'Object resource URI (the related resource)'
            }
          }

        # Context (usually the preprint)
        field :context,
          type: 'ScholarlyArticle',
          required: false,
          description: 'The preprint or resource being related',
          properties: {
            id: { type: :string, description: 'DOI or URL' },
            type: { type: :array },
            'ietf:cite-as': { type: :string },
            'ietf:item': {
              type: :object,
              description: 'Downloadable item',
              properties: {
                id: { type: :string },
                type: { type: :array },
                mediaType: { type: :string }
              }
            }
          }

        # Summary
        field :summary,
          type: :string,
          required: false,
          description: 'Description of the relationship'

        # Service announcing the relationship
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
