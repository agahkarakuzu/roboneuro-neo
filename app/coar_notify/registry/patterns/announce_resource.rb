# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # AnnounceResource pattern definition
      #
      # Received when a service announces a service result or resource related to a preprint.
      # This could be processing results, generated content, or other service outputs.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/announce-resource/
      class AnnounceResource < BasePattern
        pattern_name 'AnnounceResource'
        direction :receive
        activity_type 'Announce'
        coar_type nil  # No specific COAR type, just Announce
        description 'A service result or resource has been published'

        # The resource being announced
        field :object,
          type: 'Resource',
          required: true,
          description: 'The service result or resource',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'URL of the resource'
            },
            type: {
              type: :array,
              required: true,
              description: 'Type of resource (e.g., Page, WebPage, Dataset)'
            }
          }

        # Context (the preprint this resource relates to)
        field :context,
          type: 'ScholarlyArticle',
          required: false,
          description: 'The preprint this resource relates to',
          properties: {
            id: { type: :string },
            type: { type: :array }
          }

        # Optional reply reference
        field :inReplyTo,
          type: :string,
          required: false,
          description: 'Reference to a previous notification'

        # Summary
        field :summary,
          type: :string,
          required: false,
          description: 'Description of the resource'

        # Service announcing the resource
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
