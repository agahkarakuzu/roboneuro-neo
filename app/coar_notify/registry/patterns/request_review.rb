# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # RequestReview pattern definition
      #
      # Used to request peer review of a scholarly article from an external service.
      # This is an outgoing notification from NeuroLibre to review services like PREreview.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/request-review/
      class RequestReview < BasePattern
        pattern_name 'RequestReview'
        direction :send
        activity_type 'Offer'
        coar_type 'coar-notify:ReviewAction'
        description 'Request peer review of a preprint from an external review service'

        # The preprint to be reviewed
        field :object,
          type: 'RequestReviewObject',
          required: true,
          description: 'The scholarly article/preprint being reviewed',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'DOI of the preprint (e.g., https://doi.org/10.55458/neurolibre.00027)'
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
            },
            item: {
              type: :object,
              required: false,
              description: 'Accessible representation of the preprint',
              properties: {
                id: {
                  type: :string,
                  description: 'URL to access the preprint (repository URL or landing page)'
                },
                media_type: {
                  type: :string,
                  default: 'text/html',
                  description: 'Media type of the accessible item'
                },
                type: {
                  type: :string,
                  default: 'WebPage',
                  description: 'Type of the accessible item'
                }
              }
            }
          }

        # Editor making the request (optional)
        field :actor,
          type: 'NotifyActor',
          required: false,
          description: 'Editor or person requesting the review',
          properties: {
            id: {
              type: :string,
              description: 'ORCID of the editor (e.g., https://orcid.org/0000-0001-2345-6789)'
            },
            name: {
              type: :string,
              description: 'Name of the editor'
            },
            type: {
              type: :string,
              default: 'Person',
              description: 'Type of actor'
            }
          }

        # Target service (auto-populated from service registry)
        field :target,
          type: 'NotifyService',
          required: true,
          auto_populate: true,
          description: 'Review service receiving the request',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'Service identifier'
            },
            inbox: {
              type: :string,
              required: true,
              description: 'Service inbox URL'
            },
            type: {
              type: :string,
              default: 'Service'
            }
          }

        # Origin service (auto-populated from config)
        field :origin,
          type: 'NotifyService',
          required: true,
          auto_populate: true,
          description: 'NeuroLibre repository service',
          properties: {
            id: {
              type: :string,
              required: true,
              description: 'NeuroLibre service identifier'
            },
            inbox: {
              type: :string,
              required: true,
              description: 'NeuroLibre inbox URL'
            },
            type: {
              type: :string,
              default: 'Service'
            }
          }
      end
    end
  end
end
