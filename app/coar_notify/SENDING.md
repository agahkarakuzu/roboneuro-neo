# Sending COAR Notify Notifications

This guide shows you how to send COAR Notify notifications from roboneuro.

## API Endpoints

### POST /coar/outbox
Send any COAR Notify notification (generic endpoint).

**Request:**
- Method: `POST`
- Headers: `Content-Type: application/ld+json`
- Body: Valid COAR Notify JSON-LD notification

**Response:**
- Status: `202 Accepted` on success, `400 Bad Request` on validation error, `500 Internal Server Error` on failure
- Body: JSON with status and notification details

### POST /coar/outbox/endorsement
Simplified endpoint for sending endorsement notifications (Offer + EndorsementAction).

### POST /coar/outbox/announce-review
Simplified endpoint for announcing reviews.

## Examples

### 1. Send Generic Notification (Your Example)

```bash
curl -X POST http://localhost:3000/coar/outbox \
  -H "Content-Type: application/ld+json" \
  -d '{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://coar-notify.net"
  ],
  "actor": {
    "id": "https://orcid.org/0000-0002-1825-0097",
    "name": "Josiah Carberry",
    "type": "Person"
  },
  "id": "urn:uuid:0370c0fb-bb78-4a9b-87f5-bed307a509dd",
  "object": {
    "id": "https://research-organisation.org/repository/preprint/201203/421/",
    "ietf:cite-as": "https://doi.org/10.5555/12345680",
    "ietf:item": {
      "id": "https://research-organisation.org/repository/preprint/201203/421/content.pdf",
      "mediaType": "application/pdf",
      "type": [
        "Article",
        "sorg:ScholarlyArticle"
      ]
    },
    "type": [
      "Page",
      "sorg:AboutPage"
    ]
  },
  "origin": {
    "id": "https://research-organisation.org/repository",
    "inbox": "https://research-organisation.org/inbox/",
    "type": "Service"
  },
  "target": {
    "id": "https://overlay-journal.com/system",
    "inbox": "https://overlay-journal.com/inbox/",
    "type": "Service"
  },
  "type": [
    "Offer",
    "coar-notify:EndorsementAction"
  ]
}'
```

**Success Response:**
```json
{
  "status": "accepted",
  "message": "Notification queued for sending",
  "notification_id": "urn:uuid:0370c0fb-bb78-4a9b-87f5-bed307a509dd",
  "record_id": 42
}
```

### 2. Send Endorsement (Simplified)

```bash
curl -X POST http://localhost:3000/coar/outbox/endorsement \
  -H "Content-Type: application/json" \
  -d '{
    "target_id": "https://overlay-journal.com/system",
    "target_inbox": "https://overlay-journal.com/inbox/",
    "object_id": "https://research-organisation.org/repository/preprint/201203/421/",
    "object_doi": "https://doi.org/10.5555/12345680",
    "actor_id": "https://orcid.org/0000-0002-1825-0097",
    "actor_name": "Josiah Carberry"
  }'
```

### 3. Announce a Review

```bash
curl -X POST http://localhost:3000/coar/outbox/announce-review \
  -H "Content-Type: application/json" \
  -d '{
    "target_id": "https://prereview.org",
    "target_inbox": "https://prereview.org/inbox",
    "review_url": "https://neurolibre.org/review/12345",
    "review_doi": "https://doi.org/10.5555/neurolibre-review-001",
    "preprint_doi": "https://doi.org/10.55458/neurolibre.00001",
    "actor_name": "NeuroLibre"
  }'
```

## Programmatic Usage (Ruby)

```ruby
require 'coarnotify'

# Parse your JSON notification
notification = Coarnotify.from_json(json_string)
# OR build from hash
notification = Coarnotify.from_hash(hash)

# Send via the Sender service
sender = CoarNotify::Services::Sender.new
result = sender.send_notification(notification)

if result[:success]
  puts "Notification sent! ID: #{result[:notification_id]}"
  puts "Database record ID: #{result[:record_id]}"
else
  puts "Failed to send: #{result[:error]}"
end
```

## Notification Templates

### Endorsement (Offer + EndorsementAction)
Used when endorsing a preprint for publication.

**Pattern:** Repository → Overlay Journal
**Action:** Repository offers preprint to journal for endorsement

```json
{
  "@context": ["https://www.w3.org/ns/activitystreams", "https://purl.org/coar/notify"],
  "type": ["Offer", "coar-notify:EndorsementAction"],
  "origin": {"id": "repo-id", "inbox": "repo-inbox"},
  "target": {"id": "journal-id", "inbox": "journal-inbox"},
  "object": {"id": "preprint-url", "ietf:cite-as": "preprint-doi"},
  "actor": {"id": "orcid", "name": "name", "type": "Person"}
}
```

### Request Review
Request a review service to review a preprint.

**Pattern:** Repository → Review Service
**Action:** Request review of preprint

```json
{
  "@context": ["https://www.w3.org/ns/activitystreams", "https://purl.org/coar/notify"],
  "type": ["Offer", "coar-notify:ReviewAction"],
  "origin": {"id": "neurolibre-id", "inbox": "neurolibre-inbox"},
  "target": {"id": "prereview-id", "inbox": "prereview-inbox"},
  "object": {
    "id": "https://doi.org/10.55458/neurolibre.00027",
    "ietf:cite-as": "https://doi.org/10.55458/neurolibre.00027",
    "type": ["ScholarlyArticle"]
  }
}
```

### Announce Review
Announce that a review has been published.

**Pattern:** Review Service → Repository
**Action:** Announce review publication

```json
{
  "@context": ["https://www.w3.org/ns/activitystreams", "https://purl.org/coar/notify"],
  "type": ["Announce", "coar-notify:ReviewAction"],
  "origin": {"id": "prereview-id", "inbox": "prereview-inbox"},
  "target": {"id": "neurolibre-id", "inbox": "neurolibre-inbox"},
  "object": {
    "id": "review-url",
    "ietf:cite-as": "review-doi",
    "type": ["Page", "sorg:Review"]
  },
  "context": {
    "id": "preprint-doi",
    "type": ["ScholarlyArticle"]
  }
}
```

## Viewing Sent Notifications

All sent notifications are saved to the database with `direction = 'sent'`.

View them in the UI:
```
http://localhost:3000/coar/dashboard?direction=sent
```

Or query the database:
```bash
psql $DATABASE_URL -c "SELECT * FROM coar_notifications WHERE direction = 'sent' ORDER BY created_at DESC LIMIT 10;"
```

## Error Handling

If sending fails:
- The notification is still saved to the database with `status = 'failed'`
- The error message is stored in the `error_message` column
- You can retry by reading the `payload` column and sending again

```bash
# Find failed notifications
psql $DATABASE_URL -c "SELECT id, notification_id, error_message FROM coar_notifications WHERE direction = 'sent' AND status = 'failed';"
```

## Next Steps

- Check sent notifications in the UI: `/coar/dashboard?direction=sent`
- Monitor for responses in the inbox: `/coar/dashboard?direction=received`
- Set up Sidekiq workers to automatically process received notifications
