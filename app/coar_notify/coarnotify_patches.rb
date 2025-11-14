# frozen_string_literal: true

# Monkey patches for coarnotifyrb library bugs
#
# This file contains patches for bugs in the upstream coarnotifyrb library
# that need to be fixed locally until they are resolved upstream.

require 'coarnotify'

# Patch 1: Fix ValidationError constant reference in pattern classes
#
# Issue: Pattern classes use Core::Notify::ValidationError which doesn't exist.
# The correct class is Coarnotify::ValidationError
#
# Affected files in coarnotifyrb:
# - lib/coarnotify/patterns/announce_review.rb
# - lib/coarnotify/patterns/announce_endorsement.rb
# - lib/coarnotify/patterns/announce_relationship.rb
# - lib/coarnotify/patterns/announce_service_result.rb
# - lib/coarnotify/patterns/request_endorsement.rb

module Coarnotify
  module Core
    module Notify
      # Create an alias for ValidationError at the location where pattern classes expect it
      ValidationError = ::Coarnotify::ValidationError
    end
  end
end
