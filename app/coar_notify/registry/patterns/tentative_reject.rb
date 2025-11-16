# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # TentativeReject pattern definition
      #
      # Received when a service provisionally rejects our request but may reconsider.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/tentative-reject/
      class TentativeReject < BasePattern
        pattern_name 'TentativeReject'
        direction :receive
        activity_type 'TentativeReject'
        coar_type nil
        description 'Service has tentatively rejected the request (may reconsider)'

        field :inReplyTo,
          type: :string,
          required: true,
          description: 'Notification ID of the original request'

        field :object,
          type: 'NotifyObject',
          required: false,
          properties: {
            id: { type: :string }
          }

        field :summary,
          type: :string,
          required: false,
          description: 'Conditions for reconsideration or explanation'

        field :origin,
          type: 'NotifyService',
          required: true,
          properties: {
            id: { type: :string, required: true },
            inbox: { type: :string },
            type: { type: :string, default: 'Service' }
          }

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
            type: { type: :string, default: 'Person' }
          }
      end
    end
  end
end
