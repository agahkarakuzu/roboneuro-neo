# COAR Notify Integration for Roboneuro

A modular, production-grade implementation of the COAR Notify protocol for roboneuro, enabling seamless integration with external peer review and endorsement services.

## Overview

This module implements **Option 2** from the COAR Notify architecture specification: an embedded receiver and consumer with persistent PostgreSQL storage, providing full W3C Linked Data Notifications (LDN) compliance.

### Features

- ✅ **W3C LDN Compliant**: Full inbox/outbox support per specification
- ✅ **COAR Notify Patterns**: RequestReview, AnnounceReview, Accept, Reject, and more
- ✅ **PostgreSQL Storage**: Durable, queryable notification persistence
- ✅ **Async Processing**: Sidekiq workers for reliable background processing
- ✅ **Modular Architecture**: Self-contained in `app/coar_notify/` for easy maintenance
- ✅ **GitHub Integration**: Automatic posting of results to review issues
- ✅ **Bot Commands**: Simple `@roboneuro coar` commands for editors
- ✅ **Security**: IP whitelisting, validation, and authentication
- ✅ **Extensible**: Easy to add new services and notification patterns

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  External Services (PREreview, PCI, Sciety, etc.)      │
└─────────────────┬─────────────────────────────────┬─────┘
                  │ POST (Receive)                  │ POST (Send)
                  ▼                                 ▲
┌─────────────────────────────────────────────────────────┐
│  COAR Notify Module (roboneuro)                         │
│                                                          │
│  ┌──────────────────────┐   ┌──────────────────────┐   │
│  │ Inbox (Receiver)     │   │ Outbox (Sender)      │   │
│  │ - POST /coar/inbox   │   │ - Bot commands       │   │
│  │ - GET /coar/inbox    │   │ - SendWorker         │   │
│  └──────────┬───────────┘   └──────────┬───────────┘   │
│             │                           │               │
│             ▼                           ▼               │
│  ┌─────────────────────────────────────────────────┐   │
│  │ PostgreSQL (coar_notifications table)          │   │
│  └─────────────────────────────────────────────────┘   │
│             │                                           │
│             ▼                                           │
│  ┌──────────────────────┐                              │
│  │ ReceiveWorker        │ → Process → GitHub/API       │
│  └──────────────────────┘                              │
└─────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  NeuroLibre (Rails) - Store metadata, display reviews  │
└─────────────────────────────────────────────────────────┘
```

**Flow:**
1. **Outgoing**: Editor triggers `@roboneuro coar request from prereview` → SendWorker → Notification sent → Stored in DB
2. **Incoming**: External service POSTs to `/coar/inbox` → Validated → Stored in DB → ReceiveWorker → Processed → GitHub comment

---

## Installation

### 1. Dependencies

The module requires:
- PostgreSQL (for notification storage)
- Redis (for Sidekiq job queue - already present in roboneuro)
- `coarnotify` gem (COAR Notify protocol implementation - **via git submodule**)
- `sequel` gem (database ORM)

Dependencies are already added to `Gemfile_custom`:

```ruby
gem 'coarnotify', path: 'coarnotifyrb'  # Local submodule (not published to RubyGems)
gem 'sequel', '~> 5.0'
gem 'pg', '~> 1.5'
```

Initialize submodules and install gems:

```bash
# Initialize git submodules (coarnotifyrb)
git submodule update --init --recursive

# Install gems
bundle install
```

**Note**: The `coarnotify` gem is not published to RubyGems, so it's included as a git submodule at `coarnotifyrb/` and referenced locally in the Gemfile.

### 2. Database Setup

#### Local Development

```bash
# Create database
createdb roboneuro_development

# Set DATABASE_URL
export DATABASE_URL="postgres://localhost/roboneuro_development"

# Run migrations
sequel -m db/migrations $DATABASE_URL
```

#### Heroku Production

```bash
# Add PostgreSQL add-on (if not already present)
heroku addons:create heroku-postgresql:mini --app roboneuro-production

# Run migrations
heroku run sequel -m db/migrations \$DATABASE_URL --app roboneuro-production
```

### 3. Environment Variables

Required environment variables:

```bash
# Enable COAR Notify
COAR_NOTIFY_ENABLED=true

# Inbox URL (where external services send notifications)
COAR_INBOX_URL=https://robo.neurolibre.org/coar/inbox

# Service ID (NeuroLibre identifier)
COAR_SERVICE_ID=https://neurolibre.org

# Database connection
DATABASE_URL=postgres://user:pass@host:5432/dbname

# Security: IP whitelist (optional but recommended)
COAR_IP_WHITELIST_ENABLED=true
COAR_ALLOWED_IPS=54.xxx.xxx.xxx,52.xxx.xxx.xxx

# Existing roboneuro variables (already set)
BUFFY_GH_ACCESS_TOKEN=ghp_xxxxx
ROBONEURO_SECRET=xxxxx
REVIEWS_REPOSITORY=neurolibre/neurolibre-reviews
NEUROLIBRE_API_URL=https://neurolibre.org/papers
```

---

## Configuration

### Adding External Services

Services are configured in `app/coar_notify/config/services.yml`:

```yaml
services:
  prereview:
    name: "PREreview"
    id: "https://prereview.org"
    inbox_url: "https://api.prereview.org/inbox"
    supported_patterns:
      - RequestReview
      - AnnounceReview
      - Accept
      - Reject

  pci:
    name: "PCI Express"
    id: "https://pci.express"
    inbox_url: "https://pci.express/inbox"
    supported_patterns:
      - RequestEndorsement
      - AnnounceEndorsement
```

To add a new service:
1. Get their inbox URL and service ID
2. Add entry to `services.yml`
3. Get their IP addresses for whitelist (if using IP whitelist)
4. Add their IPs to `COAR_ALLOWED_IPS`

---

## Usage

### Bot Commands

Editors can use these commands in GitHub issue comments:

#### Request Review

```
@roboneuro coar request from prereview
```

Sends a RequestReview notification to PREreview.

#### Check Status

```
@roboneuro coar status
```

Shows all COAR notifications for the current issue.

#### List Services

```
@roboneuro coar list
```

Lists all available COAR services.

#### Help

```
@roboneuro coar help
```

Shows command help.

### Notification Flow Examples

#### Example 1: Request Review from PREreview

```
1. Editor: "@roboneuro coar request from prereview"
2. Roboneuro: "🔄 Sending review request to PREreview..."
3. SendWorker: Fetches paper data, constructs notification, sends
4. Roboneuro: "✅ Review request sent to PREreview. Notification ID: ..."
5. PREreview: Receives notification, processes review request
6. PREreview: Sends Accept notification back
7. Roboneuro: Receives Accept, posts "✅ PREreview accepted the review request"
8. PREreview: Completes review, sends AnnounceReview notification
9. Roboneuro: Receives AnnounceReview, posts review URL to GitHub
10. NeuroLibre: Displays external review link on paper page
```

#### Example 2: Receive Unsolicited Review

```
1. Sciety: Sends AnnounceReview notification to roboneuro inbox
2. Roboneuro: Validates, stores, enqueues ReceiveWorker
3. ReceiveWorker: Processes AnnounceReview
4. ReceiveWorker: Looks up paper by DOI, finds GitHub issue
5. ReceiveWorker: Posts "📝 Review published by Sciety: [URL]"
6. ReceiveWorker: Stores review URL in neurolibre metadata
```

---

## API Endpoints

### POST /coar/inbox

Receive incoming COAR Notify notifications (W3C LDN endpoint).

**Request:**
```http
POST /coar/inbox HTTP/1.1
Content-Type: application/ld+json

{
  "@context": [...],
  "id": "https://prereview.org/notifications/abc123",
  "type": ["Accept"],
  "origin": { "id": "https://prereview.org", "inbox": "..." },
  "target": { "id": "https://neurolibre.org", "inbox": "..." },
  ...
}
```

**Response:**
```http
HTTP/1.1 201 Created
Location: https://prereview.org/notifications/abc123
Content-Type: application/ld+json

{
  "message": "Notification received",
  "id": "https://prereview.org/notifications/abc123"
}
```

### GET /coar/inbox

List all received notifications (W3C LDN endpoint).

**Request:**
```http
GET /coar/inbox?limit=50&offset=0 HTTP/1.1
```

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/ld+json

{
  "@context": "http://www.w3.org/ns/ldp",
  "@id": "https://robo.neurolibre.org/coar/inbox/",
  "@type": "ldp:Container",
  "ldp:contains": [
    "https://robo.neurolibre.org/coar/inbox/notifications/abc123",
    "https://robo.neurolibre.org/coar/inbox/notifications/def456"
  ]
}
```

### GET /coar/inbox/notifications/:id

Get specific notification payload.

**Request:**
```http
GET /coar/inbox/notifications/abc123 HTTP/1.1
```

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/ld+json

{
  "@context": [...],
  "id": "https://robo.neurolibre.org/coar/inbox/notifications/abc123",
  "type": ["Announce", "coar-notify:ReviewAction"],
  ...
}
```

---

## Database Schema

The module uses a single table: `coar_notifications`

Key fields:
- `notification_id` - Unique W3C LDN identifier
- `direction` - 'sent' or 'received'
- `notification_types` - Array of types (e.g., ["Offer", "coar-notify:ReviewAction"])
- `payload` - Full JSON-LD notification (JSONB)
- `paper_doi` - Extracted DOI for querying
- `issue_id` - GitHub issue ID for posting comments
- `status` - 'pending', 'processing', 'processed', 'failed'

See `db/migrations/001_create_coar_notifications.rb` for full schema.

---

## Security

### IP Whitelist

Recommended for production:

```bash
COAR_IP_WHITELIST_ENABLED=true
COAR_ALLOWED_IPS=54.xxx.xxx.xxx,52.xxx.xxx.xxx,35.xxx.xxx.xxx
```

Get IP addresses from each service provider.

### Validation

All incoming notifications are validated against COAR Notify specification using the `coarnotify` gem before processing.

### Authentication

- **Incoming**: IP whitelist or future token-based auth
- **Outgoing**: Services typically don't require auth for public inboxes
- **API calls**: `ROBONEURO_SECRET` for neurolibre API calls

---

## Testing

### Manual Testing

```bash
# Send test notification to inbox
curl -X POST https://robo.neurolibre.org/coar/inbox \
  -H "Content-Type: application/ld+json" \
  -d @test_notification.json

# List received notifications
curl https://robo.neurolibre.org/coar/inbox

# Get specific notification
curl https://robo.neurolibre.org/coar/inbox/notifications/abc123
```

### Automated Tests

```bash
# Run COAR Notify tests
rspec spec/coar_notify/
```

---

## Troubleshooting

### Notifications not being received

1. Check `COAR_NOTIFY_ENABLED=true`
2. Verify database is connected (`DATABASE_URL`)
3. Check IP whitelist if enabled
4. Check Sidekiq is running for async processing

### Notifications not being sent

1. Verify paper data is available (DOI, issue_id)
2. Check service configuration in `services.yml`
3. Verify service inbox URL is correct
4. Check SendWorker logs for errors

### Database issues

```bash
# Check database connection
sequel $DATABASE_URL -e "SELECT 1"

# Check tables exist
sequel $DATABASE_URL -e "SELECT table_name FROM information_schema.tables WHERE table_name = 'coar_notifications'"

# View recent notifications
sequel $DATABASE_URL -e "SELECT id, direction, notification_types, status, created_at FROM coar_notifications ORDER BY created_at DESC LIMIT 10"
```

---

## Development

### File Structure

```
app/coar_notify/
├── coar_notify.rb              # Module entry point
├── models/
│   ├── notification.rb         # Notification model
│   └── service_registry.rb     # Service configuration
├── services/
│   ├── sender.rb               # Send notifications
│   ├── receiver.rb             # Receive notifications
│   ├── processor.rb            # Process by type
│   └── github_notifier.rb      # GitHub integration
├── workers/
│   ├── send_worker.rb          # Async send
│   └── receive_worker.rb       # Async receive
├── responders/
│   └── coar_responder.rb       # Bot commands
├── routes/
│   └── inbox.rb                # Sinatra routes
├── config/
│   └── services.yml            # Service registry
├── README.md                   # This file
└── NEUROLIBRE_INTEGRATION.md   # Rails integration guide
```

### Adding New Notification Patterns

1. Add pattern support to `services.yml`
2. Add processing logic to `processor.rb`
3. Optionally add sending method to `sender.rb`
4. Update bot responder if needed

---

## Monitoring

### Key Metrics

- Notifications sent/received per day
- Processing success rate
- Average processing time
- Failed notifications (check `status = 'failed'`)

### Queries

```sql
-- Recent activity
SELECT direction, COUNT(*), status
FROM coar_notifications
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY direction, status;

-- By service
SELECT service_name, direction, COUNT(*)
FROM coar_notifications
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY service_name, direction;

-- Failed notifications
SELECT id, notification_id, error_message, created_at
FROM coar_notifications
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 10;
```

---

## References

- **COAR Notify Specification**: https://coar-notify.net
- **W3C LDN Specification**: https://www.w3.org/TR/ldn/
- **coarnotifyrb Gem**: https://github.com/coar-notify/coarnotifyrb
- **Event Notifications**: https://www.eventnotifications.net/

---

## Support

For questions or issues:
1. Check this README and `NEUROLIBRE_INTEGRATION.md`
2. Review COAR Notify documentation at https://coar-notify.net
3. Check Sidekiq logs for worker errors
4. Contact the roboneuro maintainers

---

## License

This module follows the same license as roboneuro (Buffy).
