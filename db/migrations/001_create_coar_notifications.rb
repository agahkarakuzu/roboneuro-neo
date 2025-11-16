# COAR Notify Database Schema
# W3C LDN + COAR Notify Specification Compliant
#
# This migration creates the coar_notifications table for storing
# both sent (outbox) and received (inbox) COAR Notify notifications
# in compliance with the W3C Linked Data Notifications specification.

Sequel.migration do
  change do
    create_table(:coar_notifications) do
      primary_key :id

      # ===== CORE W3C LDN PROPERTIES =====
      String :notification_id, null: false
      # The notification.id (e.g., "https://robo.neurolibre.org/coar/inbox/notifications/abc123")
      # Unique per direction (allows same notification to be both sent and received)

      String :direction, null: false
      # 'sent' (outbox) or 'received' (inbox)

      # ===== COAR NOTIFY REQUIRED PROPERTIES =====
      column :notification_types, 'text[]', null: false
      # Array of types, e.g., ["Offer", "coar-notify:ReviewAction"]
      # Stored as PostgreSQL array for querying

      String :origin_id, null: false
      # notification.origin.id (e.g., "https://neurolibre.org")

      String :origin_inbox
      # notification.origin.inbox

      String :target_id, null: false
      # notification.target.id (e.g., "https://prereview.org")

      String :target_inbox
      # notification.target.inbox

      Text :object_id, null: false
      # notification.object.id (the resource: DOI, URL, etc.)
      # TEXT to support long URLs

      String :object_type
      # notification.object.type (e.g., "ScholarlyArticle")

      # ===== COAR NOTIFY OPTIONAL PROPERTIES =====
      Text :context_id
      # notification.context.id (related resource, e.g., review URL)

      String :context_type
      # notification.context.type

      String :in_reply_to
      # notification.inReplyTo (reference to previous notification ID)

      String :actor_id
      # notification.actor.id (e.g., ORCID)

      String :actor_name
      # notification.actor.name

      Text :summary
      # notification.summary

      # ===== FULL PAYLOAD =====
      column :payload, :jsonb, null: false
      # Complete notification JSON-LD (source of truth)
      # Indexed for JSONB queries

      # ===== NEUROLIBRE-SPECIFIC MAPPING =====
      String :paper_doi
      # Extracted from object.id or context.id (e.g., "10.55458/neurolibre.00027")

      Integer :issue_id
      # GitHub issue ID (for posting comments)

      String :service_name
      # Human-readable service name (e.g., "prereview", "pci")

      # ===== PROCESSING STATUS =====
      String :status, null: false, default: 'pending'
      # 'pending', 'processing', 'processed', 'failed'

      Text :error_message
      # Error details if processing failed

      DateTime :processed_at
      # When processing completed

      # ===== TIMESTAMPS =====
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      # ===== INDEXES =====
      index [:notification_id, :direction], unique: true  # Composite unique constraint
      index :notification_id  # Non-unique index for queries
      index :direction
      index :origin_id
      index :target_id
      index :object_id
      index :context_id
      index :in_reply_to
      index :paper_doi
      index :issue_id
      index :service_name
      index :status
      index [:direction, :status]
      index [:paper_doi, :direction]
      index [:service_name, :direction]
      index :notification_types, type: 'gin'  # GIN index for array queries
      index :payload, type: 'gin'              # GIN index for JSONB queries
    end
  end
end
