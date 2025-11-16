# frozen_string_literal: true

require_relative 'base_pattern'

module CoarNotify
  module Registry
    module Patterns
      # TentativeAccept pattern definition
      #
      # Received when a service provisionally accepts our request but may change their decision.
      #
      # Specification: https://coar-notify.net/specification/1.0.1/tentative-accept/
      class TentativeAccept < BasePattern
        pattern_name 'TentativeAccept'
        direction :receive
        activity_type 'TentativeAccept'
        coar_type nil
        description 'Service has tentatively accepted the request (may change)'

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
          description: 'Conditions or explanation of tentative acceptance'

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
