# Fix notification_id uniqueness constraint
#
# The notification_id should be unique per direction, not globally.
# This allows the same notification to exist as both 'sent' and 'received'
# (e.g., when sending to yourself for testing, or when both parties store
# the same notification).

Sequel.migration do
  up do
    # Drop the unique index on notification_id
    alter_table(:coar_notifications) do
      drop_index :notification_id
    end

    # Add a non-unique index on notification_id (for queries)
    alter_table(:coar_notifications) do
      add_index :notification_id
    end

    # Add composite unique constraint on (notification_id, direction)
    alter_table(:coar_notifications) do
      add_index [:notification_id, :direction], unique: true
    end
  end

  down do
    # Reverse: remove composite index and restore single-column unique index
    alter_table(:coar_notifications) do
      drop_index [:notification_id, :direction]
      drop_index :notification_id
      add_index :notification_id, unique: true
    end
  end
end
