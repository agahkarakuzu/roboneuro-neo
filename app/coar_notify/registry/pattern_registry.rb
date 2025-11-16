# frozen_string_literal: true

module CoarNotify
  module Registry
    # Pattern Registry
    #
    # Central registry for all COAR Notify notification patterns.
    # Auto-discovers pattern classes and provides lookup by name, direction, etc.
    #
    # Usage:
    #   PatternRegistry.patterns              # All patterns
    #   PatternRegistry.get('RequestReview')  # Get specific pattern
    #   PatternRegistry.send_patterns         # Patterns we send
    #   PatternRegistry.receive_patterns      # Patterns we receive
    #   PatternRegistry.schema_for('Accept')  # Get pattern schema
    class PatternRegistry
      class << self
        # Get all discovered patterns
        # @return [Hash] pattern name => pattern class
        def patterns
          @patterns ||= discover_patterns
        end

        # Get a specific pattern by name
        # @param pattern_name [String, Symbol] pattern name
        # @return [Class, nil] pattern class or nil if not found
        def get(pattern_name)
          patterns[pattern_name.to_s]
        end

        # Get all patterns with direction :send
        # @return [Hash] send pattern name => pattern class
        def send_patterns
          @send_patterns ||= patterns.select { |_, pattern| pattern.direction == :send }
        end

        # Get all patterns with direction :receive
        # @return [Hash] receive pattern name => pattern class
        def receive_patterns
          @receive_patterns ||= patterns.select { |_, pattern| pattern.direction == :receive }
        end

        # Get schema for a specific pattern
        # @param pattern_name [String, Symbol] pattern name
        # @return [Hash, nil] pattern schema or nil if not found
        def schema_for(pattern_name)
          pattern = get(pattern_name)
          pattern&.schema
        end

        # Get all pattern names
        # @return [Array<String>] list of pattern names
        def pattern_names
          patterns.keys
        end

        # Get all send pattern names
        # @return [Array<String>] list of send pattern names
        def send_pattern_names
          send_patterns.keys
        end

        # Get all receive pattern names
        # @return [Array<String>] list of receive pattern names
        def receive_pattern_names
          receive_patterns.keys
        end

        # Find pattern by notification types
        # @param types [Array<String>] notification types from a notification
        # @return [Class, nil] matching pattern class or nil
        def find_by_types(types)
          types_array = Array(types).map(&:to_s)

          # Try to match by COAR type first (more specific)
          coar_types = types_array.select { |t| t.include?('coar-notify') }
          coar_types.each do |coar_type|
            pattern = patterns.values.find { |p| p.coar_type == coar_type }
            return pattern if pattern
          end

          # Fall back to Activity Streams type
          activity_types = types_array.reject { |t| t.include?('coar-notify') }
          activity_types.each do |activity_type|
            pattern = patterns.values.find { |p| p.activity_type == activity_type }
            return pattern if pattern
          end

          nil
        end

        # Reset the registry (useful for testing)
        def reset!
          @patterns = nil
          @send_patterns = nil
          @receive_patterns = nil
        end

        private

        # Auto-discover all pattern classes in the Patterns module
        # @return [Hash] pattern name => pattern class
        def discover_patterns
          require_all_patterns

          pattern_classes = {}

          # Discover all pattern classes
          Patterns.constants.each do |const_name|
            next if const_name == :BasePattern # Skip base class

            klass = Patterns.const_get(const_name)
            next unless klass.is_a?(Class) && klass < Patterns::BasePattern

            pattern_name = klass.pattern_name
            if pattern_name
              pattern_classes[pattern_name] = klass
            else
              warn "COAR Notify: Pattern class #{const_name} has no pattern_name defined"
            end
          end

          pattern_classes
        end

        # Require all pattern files
        def require_all_patterns
          patterns_dir = File.expand_path('patterns', __dir__)
          Dir[File.join(patterns_dir, '*.rb')].each do |file|
            require file
          end
        end
      end
    end
  end
end
