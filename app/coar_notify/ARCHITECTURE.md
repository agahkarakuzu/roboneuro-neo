# COAR Notify Architecture Guide

## Overview

This document describes the modular, extensible architecture of the COAR Notify implementation for NeuroLibre. The system implements all 12 COAR Notify specification patterns with a clean, maintainable design.

---

## Core Principles

1. **Auto-Discovery**: Patterns and handlers register themselves automatically
2. **Schema-Driven**: Forms and validation driven by pattern schemas
3. **Single Responsibility**: Each class has one clear purpose
4. **Open/Closed**: Open for extension, closed for modification
5. **Zero Technical Debt**: Self-contained module with minimal coupling to Buffy

---

## Directory Structure

```
app/coar_notify/
├── registry/                      # Pattern Definitions
│   ├── pattern_registry.rb        # Central pattern registry
│   └── patterns/                  # Pattern schema definitions
│       ├── base_pattern.rb        # Base class for all patterns
│       ├── request_review.rb      # RequestReview schema
│       ├── request_endorsement.rb # RequestEndorsement schema
│       ├── undo_offer.rb          # UndoOffer schema
│       ├── accept.rb              # Accept schema
│       ├── reject.rb              # Reject schema
│       ├── tentative_accept.rb    # TentativeAccept schema
│       ├── tentative_reject.rb    # TentativeReject schema
│       ├── announce_review.rb     # AnnounceReview schema
│       ├── announce_endorsement.rb # AnnounceEndorsement schema
│       ├── announce_relationship.rb # AnnounceRelationship schema
│       ├── announce_resource.rb   # AnnounceResource schema
│       └── unprocessable.rb       # Unprocessable schema
│
├── handlers/                      # Received Notification Handlers
│   ├── handler_registry.rb        # Auto-discovers handlers
│   ├── base_handler.rb            # Base handler with common logic
│   ├── accept_handler.rb          # Handles Accept notifications
│   ├── reject_handler.rb          # Handles Reject notifications
│   ├── tentative_accept_handler.rb # Handles TentativeAccept
│   ├── tentative_reject_handler.rb # Handles TentativeReject
│   ├── announce_review_handler.rb  # Handles AnnounceReview
│   ├── announce_endorsement_handler.rb # Handles AnnounceEndorsement
│   ├── announce_relationship_handler.rb # Handles AnnounceRelationship (NEW)
│   ├── announce_resource_handler.rb # Handles AnnounceResource (NEW)
│   ├── unprocessable_handler.rb    # Handles Unprocessable (NEW)
│   └── unknown_handler.rb          # Fallback for unknown types
│
├── services/                      # Business Logic
│   ├── sender.rb                  # Send notifications (RequestReview, etc.)
│   ├── receiver.rb                # Receive notifications (inbox endpoint)
│   ├── processor.rb               # DEPRECATED: Use handlers instead
│   └── github_notifier.rb         # GitHub/NeuroLibre integration
│
├── models/                        # Database Layer
│   ├── notification.rb            # Notification model
│   └── service_registry.rb        # Service configuration
│
├── workers/                       # Async Processing
│   ├── send_worker.rb             # Async send notifications
│   └── receive_worker.rb          # Async receive notifications (uses handlers)
│
├── routes/                        # HTTP Endpoints
│   ├── inbox.rb                   # W3C LDN inbox (GET/POST)
│   └── inbox_ui.rb                # Dashboard UI (future)
│
└── config/
    └── services.yml               # External service registry
```

---

## Pattern Registry System

### Overview

The Pattern Registry provides a central, schema-driven definition of all 12 COAR Notify patterns. Each pattern is defined as a Ruby class that describes its structure, required fields, and metadata.

### BasePattern Class

All patterns inherit from `Registry::Patterns::BasePattern` and use a DSL to define their schema:

```ruby
class RequestReview < BasePattern
  pattern_name 'RequestReview'
  direction :send  # :send or :receive
  activity_type 'Offer'  # Activity Streams type
  coar_type 'coar-notify:ReviewAction'  # COAR-specific type
  description 'Request peer review of a preprint'

  field :object,
    type: 'RequestReviewObject',
    required: true,
    description: 'The preprint being reviewed',
    properties: { ... }

  field :actor,
    type: 'NotifyActor',
    required: false,
    description: 'Editor making the request',
    properties: { ... }
end
```

### Pattern Registry API

```ruby
# Get all patterns
CoarNotify::Registry::PatternRegistry.patterns
# => { "RequestReview" => RequestReview, "Accept" => Accept, ... }

# Get patterns by direction
CoarNotify::Registry::PatternRegistry.send_patterns
# => { "RequestReview" => ..., "RequestEndorsement" => ..., "UndoOffer" => ... }

CoarNotify::Registry::PatternRegistry.receive_patterns
# => { "Accept" => ..., "Reject" => ..., "AnnounceReview" => ..., ... }

# Get specific pattern schema
CoarNotify::Registry::PatternRegistry.schema_for('RequestReview')
# => { name: 'RequestReview', direction: :send, fields: { ... } }

# Find pattern by notification types
types = ["Announce", "coar-notify:ReviewAction"]
pattern = CoarNotify::Registry::PatternRegistry.find_by_types(types)
# => AnnounceReview
```

### All 12 Patterns

**SEND (NeuroLibre → External Services):**
1. **RequestReview** - Request peer review
2. **RequestEndorsement** - Request endorsement
3. **UndoOffer** - Withdraw a previous request ✨ NEW

**RECEIVE (External Services → NeuroLibre):**
4. **Accept** - Service accepted our request
5. **Reject** - Service declined our request
6. **TentativeAccept** - Service provisionally accepted
7. **TentativeReject** - Service provisionally declined
8. **AnnounceReview** - Review published
9. **AnnounceEndorsement** - Endorsement published
10. **AnnounceRelationship** - Related resource announced ✨ NEW
11. **AnnounceResource** - Service result announced ✨ NEW
12. **Unprocessable** - Service couldn't process our notification ✨ NEW

---

## Handler Architecture

### Overview

The Handler system replaces the monolithic `Processor` class with individual, focused handler classes. Each received notification type has its own handler.

### BaseHandler Class

All handlers inherit from `Handlers::BaseHandler` which provides:

- **Common Helpers**: `service_name`, `post_to_github`, `build_message`, `find_issue_id`
- **Metadata Updates**: `update_paper_metadata`
- **Status Management**: `mark_processed`, `mark_failed`
- **Template Method**: `process()` calls `handle()` and manages errors

```ruby
class AnnounceReviewHandler < BaseHandler
  def handle
    review_url = notification.object&.id

    message = build_message(
      title: "📝 Review published by #{service_name.capitalize}",
      summary: notification.summary,
      details: "**Review URL:** #{review_url}"
    )

    post_to_github(message)
    update_paper_metadata(review_url: review_url)
  end
end
```

### Handler Registry

The Handler Registry auto-discovers all handler classes and maps notification types to handlers:

```ruby
# Automatically dispatch to appropriate handler
CoarNotify::Handlers::HandlerRegistry.handle(notification, record)

# Get handler class for a notification
handler_class = CoarNotify::Handlers::HandlerRegistry.get_handler(notification)
# => AnnounceReviewHandler
```

**Mapping:**
- `Accept` → `AcceptHandler`
- `Reject` → `RejectHandler`
- `TentativeAccept` → `TentativeAcceptHandler`
- `TentativeReject` → `TentativeRejectHandler`
- `coar-notify:ReviewAction` → `AnnounceReviewHandler`
- `coar-notify:EndorsementAction` → `AnnounceEndorsementHandler`
- `coar-notify:RelationshipAction` → `AnnounceRelationshipHandler`
- `coar-notify:UnprocessableNotification` → `UnprocessableHandler`
- `Announce` (fallback) → `AnnounceResourceHandler`
- Unknown → `UnknownHandler`

### Handler Responsibilities

Each handler:
1. **Extracts data** from the notification
2. **Builds a message** for GitHub
3. **Posts to GitHub** issue
4. **Updates metadata** in NeuroLibre (if applicable)
5. **Marks notification** as processed or failed

---

## Sender Service

The Sender service constructs and sends notifications to external services.

### Public Methods

```ruby
sender = CoarNotify::Services::Sender.new

# Send RequestReview
result = sender.send_request_review(paper_data, 'prereview')

# Send RequestEndorsement
result = sender.send_request_endorsement(paper_data, 'pci')

# Send UndoOffer ✨ NEW
result = sender.send_undo_offer(paper_data, 'prereview', original_notification_id)

# Send generic notification
result = sender.send_notification(notification, extra_attrs)
```

### Paper Data Format

```ruby
paper_data = {
  doi: '10.55458/neurolibre.00027',
  issue_id: 123,
  repository_url: 'https://github.com/user/repo',
  title: 'Paper Title',
  editor_orcid: '0000-0001-2345-6789',  # optional
  editor_name: 'Dr. Jane Smith',        # optional
  withdrawal_reason: '...'               # for UndoOffer only
}
```

---

## Receiver Service & Workers

### Receiver Service

Handles incoming W3C LDN notifications:

```ruby
receiver = CoarNotify::Services::Receiver.new

# Receive notification (validates, stores, enqueues worker)
result = receiver.receive(json_body, request_ip: '1.2.3.4')

# List received notifications
notifications = receiver.list_notifications(limit: 50, offset: 0)

# Get specific notification
notification = receiver.get_notification(notification_id)
```

### ReceiveWorker

Async worker that processes received notifications:

1. Fetches notification from database
2. Parses notification using `coarnotify` gem
3. **Dispatches to appropriate handler via HandlerRegistry** ✨ NEW
4. Marks as processed or failed

```ruby
# In app/coar_notify/workers/receive_worker.rb
notification = record.to_coar_object
Handlers::HandlerRegistry.handle(notification, record)
```

---

## Data Flow

### Sending a Notification

```
1. Editor Command
   @roboneuro coar request from prereview

2. Bot Responder
   → CoarResponder.perform(issue_id, command)

3. Sender Service
   → Sender.send_request_review(paper_data, 'prereview')

4. Build Notification
   → build_request_review(paper_data, service_config)
   → Coarnotify::Patterns::RequestReview.new

5. Send via HTTP
   → Coarnotify.client(inbox_url).send(notification)

6. Persist to DB
   → Models::Notification.create_from_coar(notification, 'sent')
```

### Receiving a Notification

```
1. HTTP POST to /coar/inbox

2. Receiver Service
   → Receiver.receive(json_body)
   → Validate with coarnotify gem
   → Store in database (status: 'pending')
   → Enqueue ReceiveWorker

3. ReceiveWorker (Sidekiq)
   → Fetch notification from DB
   → Parse with coarnotify gem
   → HandlerRegistry.handle(notification, record)  ✨ NEW

4. Handler Dispatch
   → HandlerRegistry.get_handler(notification)
   → handler_class.new(notification, record).process()

5. Handler Execution
   → AcceptHandler / AnnounceReviewHandler / etc.
   → post_to_github(message)
   → update_paper_metadata(...)
   → mark_processed()
```

---

## Adding a New Pattern

To add a new COAR Notify pattern (e.g., future patterns):

### 1. Create Pattern Definition

```ruby
# app/coar_notify/registry/patterns/new_pattern.rb
class NewPattern < BasePattern
  pattern_name 'NewPattern'
  direction :receive  # or :send
  activity_type 'SomeType'
  coar_type 'coar-notify:SomeAction'  # optional
  description 'Description of the pattern'

  field :object, type: 'Object', required: true, properties: { ... }
  field :actor, type: 'Actor', required: false, properties: { ... }
end
```

**That's it!** The pattern is automatically discovered by `PatternRegistry`.

### 2. Create Handler (if receiving)

```ruby
# app/coar_notify/handlers/new_pattern_handler.rb
class NewPatternHandler < BaseHandler
  def handle
    # Extract data
    data = notification.object&.id

    # Build message
    message = build_message(
      title: "✨ New Pattern received",
      summary: notification.summary,
      details: "Data: #{data}"
    )

    # Post to GitHub
    post_to_github(message)

    # Update metadata (optional)
    update_paper_metadata(new_pattern_data: data)
  end
end
```

**That's it!** The handler is automatically discovered by `HandlerRegistry`.

### 3. Add Send Method (if sending)

```ruby
# app/coar_notify/services/sender.rb
def send_new_pattern(paper_data, service_name)
  # Validate
  service_config = Models::ServiceRegistry.get(service_name)
  validate_paper_data!(paper_data, [:doi, :issue_id])

  # Build notification
  notification = build_new_pattern(paper_data, service_config)

  # Send
  client = Coarnotify.client(inbox_url: service_config['inbox_url'])
  response = client.send(notification, validate: true)

  # Persist
  record = Models::Notification.create_from_coar(notification, 'sent', ...)

  { success: true, notification_id: notification.id, ... }
end

private

def build_new_pattern(paper_data, service_config)
  notification = Coarnotify::Patterns::NewPattern.new
  # ... populate fields ...
  notification
end
```

### 4. Update Services Config

```yaml
# app/coar_notify/config/services.yml
services:
  someservice:
    name: "Some Service"
    supported_patterns:
      - NewPattern  # Add here
```

---

## Testing

### Unit Tests

```ruby
# Test pattern registry
describe CoarNotify::Registry::PatternRegistry do
  it 'discovers all patterns' do
    expect(PatternRegistry.patterns.keys).to include('RequestReview', 'Accept', ...)
  end

  it 'finds pattern by types' do
    types = ['Announce', 'coar-notify:ReviewAction']
    pattern = PatternRegistry.find_by_types(types)
    expect(pattern).to eq(CoarNotify::Registry::Patterns::AnnounceReview)
  end
end

# Test handlers
describe CoarNotify::Handlers::AnnounceReviewHandler do
  let(:notification) { build_notification(...) }
  let(:record) { create(:notification) }

  it 'posts to GitHub' do
    expect(GitHubNotifier).to receive(:post_comment)
    handler = described_class.new(notification, record)
    handler.handle
  end
end
```

### Integration Tests

```ruby
# Test complete flow
it 'processes AnnounceReview notification end-to-end' do
  # Send notification to inbox
  post '/coar/inbox', notification_json

  # Wait for worker
  ReceiveWorker.drain

  # Verify GitHub comment posted
  expect(github_comments).to include(match(/Review published/))

  # Verify metadata updated
  expect(paper.reviews).to include(review_url)
end
```

---

## Configuration

### Environment Variables

```bash
# Enable COAR Notify
COAR_NOTIFY_ENABLED=true

# Service URLs
COAR_INBOX_URL=https://robo.neurolibre.org/coar/inbox
COAR_SERVICE_ID=https://neurolibre.org

# Database
DATABASE_URL=postgres://localhost/roboneuro_development

# Security (optional)
COAR_IP_WHITELIST_ENABLED=true
COAR_ALLOWED_IPS=54.1.2.3,52.4.5.6
```

### Service Registry

Edit `app/coar_notify/config/services.yml` to add/modify services.

---

## Migration Guide (from old Processor)

The old `Services::Processor` class has been **deprecated** and replaced by the Handler system.

### Before (Deprecated)

```ruby
# Old way
processor = Services::Processor.new
processor.process(notification, record)
```

### After (Current)

```ruby
# New way
Handlers::HandlerRegistry.handle(notification, record)
```

### Why the Change?

1. **Single Responsibility**: Each handler handles one notification type
2. **Extensibility**: Add new patterns by adding one file
3. **Testability**: Test handlers in isolation
4. **Maintainability**: Clear, focused code
5. **Auto-Discovery**: No manual registration needed

---

## Performance Considerations

- **Async Processing**: All received notifications processed via Sidekiq
- **Retry Logic**: 3 retries with exponential backoff
- **Idempotency**: Duplicate notifications detected and skipped
- **Database Indexes**: Optimized queries on notification_types, direction, status

---

## Security

- **IP Whitelist**: Optional IP-based access control
- **Validation**: All notifications validated with `coarnotify` gem
- **Authentication**: HTTPS + optional bearer tokens
- **Rate Limiting**: (Future) Configure in Rack middleware

---

## Future Enhancements

### Phase 3: Dashboard UI (Planned)

- Web interface for sending notifications
- View notification history
- Dynamic forms based on pattern schemas
- Retry failed notifications

### Additional Features

- Webhooks for notification events
- Prometheus metrics
- Advanced auth (OAuth, JWT)
- Notification templates
- Batch operations

---

## Support

- **Documentation**: This file + README.md + COAR_NOTIFY_LOCAL_TESTING.md
- **COAR Spec**: https://coar-notify.net/specification/1.0.1/
- **W3C LDN**: https://www.w3.org/TR/ldn/

---

## Summary

The COAR Notify implementation is now:

✅ **Complete**: All 12 patterns implemented
✅ **Modular**: Registry + Handlers architecture
✅ **Extensible**: Add patterns with one file
✅ **Maintainable**: Clear responsibilities, auto-discovery
✅ **Self-Contained**: Minimal coupling to Buffy
✅ **Production-Ready**: Async processing, retry logic, validation

**Zero technical debt. Maximum developer happiness.** 🎉
