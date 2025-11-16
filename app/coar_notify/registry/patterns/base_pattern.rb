# frozen_string_literal: true

module CoarNotify
  module Registry
    module Patterns
      # Base class for all COAR Notify pattern definitions
      #
      # This class provides a DSL for defining notification patterns with their
      # schemas, validation rules, and metadata. All pattern classes inherit from
      # this base and use the DSL to declare their structure.
      #
      # Example:
      #   class RequestReview < BasePattern
      #     pattern_name 'RequestReview'
      #     direction :send
      #     activity_type 'Offer'
      #     coar_type 'coar-notify:ReviewAction'
      #
      #     field :object, type: 'RequestReviewObject', required: true, ...
      #   end
      class BasePattern
        class << self
          # Define or get the pattern name
          # @param name [String, nil] the pattern name (e.g., 'RequestReview')
          # @return [String] the pattern name
          def pattern_name(name = nil)
            @pattern_name = name if name
            @pattern_name
          end

          # Define or get the direction (send or receive)
          # @param dir [Symbol, nil] :send or :receive
          # @return [Symbol] the direction
          def direction(dir = nil)
            @direction = dir if dir
            @direction
          end

          # Define or get the Activity Streams type
          # @param type [String, nil] Activity Streams type (e.g., 'Offer', 'Accept', 'Announce')
          # @return [String] the activity type
          def activity_type(type = nil)
            @activity_type = type if type
            @activity_type
          end

          # Define or get the COAR Notify specific type
          # @param type [String, nil] COAR type (e.g., 'coar-notify:ReviewAction')
          # @return [String, nil] the COAR type
          def coar_type(type = nil)
            @coar_type = type if type
            @coar_type
          end

          # Define or get the description
          # @param desc [String, nil] human-readable description
          # @return [String] the description
          def description(desc = nil)
            @description = desc if desc
            @description
          end

          # Define a field in the pattern schema
          # @param name [Symbol] field name
          # @param options [Hash] field configuration
          # @option options [String] :type field type
          # @option options [Boolean] :required whether field is required
          # @option options [String] :description human-readable description
          # @option options [Hash] :properties nested properties for object types
          # @option options [Object] :default default value
          def field(name, **options)
            fields[name] = options
          end

          # Get all defined fields
          # @return [Hash] field definitions
          def fields
            @fields ||= {}
          end

          # Get required field names
          # @return [Array<Symbol>] list of required field names
          def required_fields
            fields.select { |_, opts| opts[:required] }.keys
          end

          # Get optional field names
          # @return [Array<Symbol>] list of optional field names
          def optional_fields
            fields.reject { |_, opts| opts[:required] }.keys
          end

          # Get the full schema for this pattern
          # @return [Hash] complete schema definition
          def schema
            {
              name: pattern_name,
              direction: direction,
              activity_type: activity_type,
              coar_type: coar_type,
              description: description,
              fields: fields,
              required_fields: required_fields,
              optional_fields: optional_fields
            }
          end

          # Get notification types for this pattern
          # @return [Array<String>] array of types to include in notification
          def notification_types
            types = []
            types << activity_type if activity_type
            types << coar_type if coar_type
            types
          end
        end
      end
    end
  end
end
