# COAR Notify Local Testing Guide

This guide walks you through testing the COAR Notify implementation on your local development machine.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup](#setup)
3. [Testing the Inbox (Receiving Notifications)](#testing-the-inbox-receiving-notifications)
4. [Testing the Outbox (Sending Notifications)](#testing-the-outbox-sending-notifications)
5. [Testing Bot Commands](#testing-bot-commands)
6. [Testing Database Storage](#testing-database-storage)
7. [Simulating External Services](#simulating-external-services)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

- **Ruby** 2.7+ installed
- **PostgreSQL** installed and running
- **Redis** installed and running (for Sidekiq)
- **Git** for cloning the repository

```bash
# Check versions
ruby --version    # Should be 2.7 or higher
postgres --version
redis-cli ping    # Should return PONG
```

---

## Setup

### 1. Install Dependencies

```bash
cd /path/to/roboneuro-neo

# Initialize git submodules (includes coarnotifyrb)
git submodule update --init --recursive

# Install gems
bundle install

# If you encounter issues, try:
bundle update
```

**Note**: The `coarnotify` gem is not published to RubyGems, so it's included as a git submodule at `coarnotifyrb/`. The `git submodule update` command is required to fetch it.

### 2. Create Local Database

```bash
# Create database
createdb roboneuro_development

# Verify it was created
psql -l | grep roboneuro
```

### 3. Set Environment Variables

Create a `.env` file in the project root:

```bash
cat > .env << 'EOF'
# COAR Notify Configuration
COAR_NOTIFY_ENABLED=true
COAR_INBOX_URL=http://localhost:4567/coar/inbox
COAR_SERVICE_ID=https://neurolibre.org
DATABASE_URL=postgres://localhost/roboneuro_development

# Security (disabled for local testing)
COAR_IP_WHITELIST_ENABLED=false

# Roboneuro Configuration (use your actual values)
BUFFY_GH_ACCESS_TOKEN=your_github_token_here
ROBONEURO_SECRET=test_secret_123
REVIEWS_REPOSITORY=your-org/your-reviews-repo
NEUROLIBRE_API_URL=http://localhost:3000/papers
RACK_ENV=development
EOF
```

**Load environment variables:**

```bash
export $(cat .env | xargs)
```

### 4. Run Database Migrations

```bash
# Run migrations
sequel -m db/migrations $DATABASE_URL

# Verify table was created
psql $DATABASE_URL -c "\d coar_notifications"
```

Expected output:
```
Table "public.coar_notifications"
Column              | Type
--------------------+--------------------------
id                  | integer
notification_id     | character varying
direction           | character varying
...
```

### 5. Start Services

**Terminal 1 - Start Roboneuro (Sinatra):**

```bash
export $(cat .env | xargs)
bundle exec ruby app.rb
```

You should see:
```
== Sinatra (v3.0.5) has taken the stage on 4567 for development
```

**Terminal 2 - Start Sidekiq (Background Workers):**

```bash
export $(cat .env | xargs)
bundle exec sidekiq -r ./app/lib/workers.rb
```

You should see Sidekiq boot up with the COAR Notify queue.

**Terminal 3 - Testing Terminal (keep this open for running test commands):**

```bash
export $(cat .env | xargs)
# This terminal is for running curl commands
```

---

## Testing the Inbox (Receiving Notifications)

### Test 1: POST a Valid Notification

Create a test notification file:

```bash
cat > test_announce_review.json << 'EOF'
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://purl.org/coar/notify"
  ],
  "id": "urn:uuid:test-12345-abcde",
  "type": ["Announce", "coar-notify:ReviewAction"],
  "origin": {
    "id": "https://prereview.org",
    "inbox": "https://prereview.org/inbox",
    "type": "Service"
  },
  "target": {
    "id": "https://neurolibre.org",
    "inbox": "http://localhost:4567/coar/inbox",
    "type": "Service"
  },
  "object": {
    "id": "https://prereview.org/reviews/test-review-123",
    "type": "Review"
  },
  "context": {
    "id": "https://doi.org/10.55458/neurolibre.00027",
    "type": "ScholarlyArticle"
  }
}
EOF
```

**Send the notification:**

```bash
curl -X POST http://localhost:4567/coar/inbox \
  -H "Content-Type: application/ld+json" \
  -d @test_announce_review.json \
  -v
```

**Expected response:**

```http
HTTP/1.1 201 Created
Location: urn:uuid:test-12345-abcde
Content-Type: application/ld+json

{
  "message": "Notification received",
  "id": "urn:uuid:test-12345-abcde",
  "record_id": 1
}
```

**Verify in database:**

```bash
psql $DATABASE_URL -c "SELECT id, direction, notification_types, status, service_name FROM coar_notifications;"
```

Expected output:
```
 id | direction | notification_types                      | status  | service_name
----+-----------+-----------------------------------------+---------+-------------
  1 | received  | {Announce,coar-notify:ReviewAction}     | pending | prereview
```

**Check Sidekiq processed it:**

Wait a few seconds, then check:

```bash
psql $DATABASE_URL -c "SELECT id, status, processed_at FROM coar_notifications WHERE id=1;"
```

Expected:
```
 id | status    | processed_at
----+-----------+-------------------------
  1 | processed | 2025-01-15 10:30:45.123
```

### Test 2: GET Inbox (List Notifications)

```bash
curl http://localhost:4567/coar/inbox | jq .
```

**Expected response:**

```json
{
  "@context": "http://www.w3.org/ns/ldp",
  "@id": "http://localhost:4567/coar/inbox/",
  "@type": "ldp:Container",
  "ldp:contains": [
    "urn:uuid:test-12345-abcde"
  ]
}
```

### Test 3: GET Specific Notification

```bash
# Note: URL encoding of the notification ID
curl "http://localhost:4567/coar/inbox/notifications/urn:uuid:test-12345-abcde" | jq .
```

**Expected:** Full notification payload returned.

### Test 4: POST Invalid Notification (Validation Test)

```bash
curl -X POST http://localhost:4567/coar/inbox \
  -H "Content-Type: application/ld+json" \
  -d '{"invalid": "notification"}' \
  -v
```

**Expected response:**

```http
HTTP/1.1 400 Bad Request

{
  "error": "Invalid notification",
  "details": { ... }
}
```

---

## Testing the Outbox (Sending Notifications)

### Test 5: Send Notification Programmatically

Create a test script:

```bash
cat > test_send.rb << 'EOF'
require_relative 'app/coar_notify/coar_notify'
require_relative 'app/coar_notify/services/sender'

# Simulate paper data
paper_data = {
  doi: '10.55458/neurolibre.00027',
  issue_id: 123,
  repository_url: 'https://github.com/test/repo',
  title: 'Test Paper',
  editor_orcid: '0000-0001-2345-6789',
  editor_name: 'Dr. Test Editor'
}

# Send notification
sender = CoarNotify::Services::Sender.new

begin
  result = sender.send_request_review(paper_data, 'prereview')
  puts "✅ Success!"
  puts "Notification ID: #{result[:notification_id]}"
  puts "Service: #{result[:service]}"
  puts "Record ID: #{result[:record_id]}"
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end
EOF

# Run the script
bundle exec ruby test_send.rb
```

**Expected output:**

```
✅ Success!
Notification ID: http://localhost:4567/coar/inbox/notifications/abc123...
Service: prereview
Record ID: 2
```

**Verify in database:**

```bash
psql $DATABASE_URL -c "SELECT id, direction, notification_types, status FROM coar_notifications WHERE direction='sent';"
```

Expected:
```
 id | direction | notification_types                     | status
----+-----------+----------------------------------------+-----------
  2 | sent      | {Offer,coar-notify:ReviewAction}       | processed
```

---

## Testing Bot Commands

### Test 6: Simulate Bot Command via Worker

Since we don't have a full GitHub webhook setup locally, we can test the worker directly:

```bash
cat > test_bot_command.rb << 'EOF'
require_relative 'app/coar_notify/coar_notify'
require_relative 'app/coar_notify/workers/send_worker'
require_relative 'app/coar_notify/services/github_notifier'

# Mock GitHub API (so it doesn't actually post)
module CoarNotify::Services
  class GitHubNotifier
    def self.post_comment(issue_id, message)
      puts "\n📝 Would post to GitHub issue ##{issue_id}:"
      puts "---"
      puts message
      puts "---\n"
    end

    def self.get_paper_by_issue(issue_id)
      # Mock paper data
      {
        id: 27,
        doi: '10.55458/neurolibre.00027',
        title: 'Test Paper Title',
        repository_url: 'https://github.com/test/repo',
        issue_id: issue_id,
        review_issue_id: issue_id,
        state: 'under_review'
      }
    end
  end
end

# Simulate command: @roboneuro coar request from prereview
worker = CoarNotify::Workers::SendWorker.new
worker.perform(123, 'prereview', 'request_review')

puts "\n✅ Worker executed successfully!"
EOF

bundle exec ruby test_bot_command.rb
```

**Expected output:**

```
📝 Would post to GitHub issue #123:
---
### ✅ COAR Notification Sent

Successfully sent review request to **PREreview**.

<details>
<summary>Notification Details</summary>

**Notification ID:** `http://localhost:4567/coar/inbox/notifications/...`
...
</details>
---

✅ Worker executed successfully!
```

---

## Testing Database Storage

### Test 7: Query Notifications by Paper

```bash
psql $DATABASE_URL << 'EOF'
-- Get all notifications for a specific paper
SELECT
  id,
  direction,
  notification_types[array_length(notification_types, 1)] as primary_type,
  service_name,
  status,
  created_at
FROM coar_notifications
WHERE paper_doi = '10.55458/neurolibre.00027'
ORDER BY created_at DESC;
EOF
```

### Test 8: Check Notification Payload

```bash
psql $DATABASE_URL << 'EOF'
-- View full notification payload (formatted JSON)
SELECT
  id,
  direction,
  jsonb_pretty(payload) as notification_payload
FROM coar_notifications
WHERE id = 1;
EOF
```

### Test 9: Query by Status

```bash
psql $DATABASE_URL -c "SELECT status, COUNT(*) FROM coar_notifications GROUP BY status;"
```

Expected:
```
 status    | count
-----------+-------
 processed |     3
 pending   |     0
 failed    |     0
```

---

## Simulating External Services

### Test 10: Simulate PREreview Sending Accept

Create an Accept notification:

```bash
cat > test_accept.json << 'EOF'
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://purl.org/coar/notify"
  ],
  "id": "urn:uuid:accept-test-67890",
  "type": "Accept",
  "origin": {
    "id": "https://prereview.org",
    "inbox": "https://prereview.org/inbox",
    "type": "Service"
  },
  "target": {
    "id": "https://neurolibre.org",
    "inbox": "http://localhost:4567/coar/inbox",
    "type": "Service"
  },
  "inReplyTo": "http://localhost:4567/coar/inbox/notifications/original-request-id",
  "object": {
    "id": "https://doi.org/10.55458/neurolibre.00027",
    "type": "ScholarlyArticle"
  }
}
EOF

curl -X POST http://localhost:4567/coar/inbox \
  -H "Content-Type: application/ld+json" \
  -d @test_accept.json
```

Check Sidekiq terminal - you should see the worker process the Accept notification.

### Test 11: Simulate Multiple Services

Send notifications from different services:

```bash
# From PCI
cat > test_pci.json << 'EOF'
{
  "@context": ["https://www.w3.org/ns/activitystreams", "https://purl.org/coar/notify"],
  "id": "urn:uuid:pci-test-111",
  "type": ["Announce", "coar-notify:EndorsementAction"],
  "origin": {"id": "https://pci.express", "inbox": "https://pci.express/inbox", "type": "Service"},
  "target": {"id": "https://neurolibre.org", "inbox": "http://localhost:4567/coar/inbox", "type": "Service"},
  "object": {"id": "https://pci.express/endorsements/test-123", "type": "Endorsement"},
  "context": {"id": "https://doi.org/10.55458/neurolibre.00027", "type": "ScholarlyArticle"}
}
EOF

curl -X POST http://localhost:4567/coar/inbox -H "Content-Type: application/ld+json" -d @test_pci.json

# Check database for multiple services
psql $DATABASE_URL -c "SELECT service_name, COUNT(*) FROM coar_notifications WHERE direction='received' GROUP BY service_name;"
```

---

## Troubleshooting

### Issue: Database connection failed

**Error:**
```
PG::ConnectionBad: could not connect to server
```

**Solution:**
```bash
# Check PostgreSQL is running
pg_isready

# If not running, start it:
# macOS with Homebrew:
brew services start postgresql

# Linux:
sudo systemctl start postgresql

# Verify DATABASE_URL
echo $DATABASE_URL
```

### Issue: Table doesn't exist

**Error:**
```
Sequel::DatabaseError: PG::UndefinedTable: relation "coar_notifications" does not exist
```

**Solution:**
```bash
# Run migrations
sequel -m db/migrations $DATABASE_URL

# Verify
psql $DATABASE_URL -c "\dt coar_notifications"
```

### Issue: Sidekiq not processing

**Check Sidekiq is running:**
```bash
# In Sidekiq terminal, you should see:
#   ===  COAR Notify queue ready
```

**Check Redis is running:**
```bash
redis-cli ping  # Should return PONG
```

**Manually check job queue:**
```bash
redis-cli
> LLEN queue:coar_notify
> LRANGE queue:coar_notify 0 -1
```

### Issue: IP whitelist blocking

**Error:**
```
HTTP/1.1 403 Forbidden
{"error":"Unauthorized IP: ..."}
```

**Solution:**
```bash
# Disable IP whitelist for local testing
export COAR_IP_WHITELIST_ENABLED=false

# OR add your IP to allowed list
export COAR_ALLOWED_IPS=127.0.0.1,::1

# Restart roboneuro
```

### Issue: COAR Notify is disabled

**Error:**
```
{"error":"COAR Notify is not enabled"}
```

**Solution:**
```bash
export COAR_NOTIFY_ENABLED=true
# Restart roboneuro
```

### Debug: View Logs

**Roboneuro logs (Terminal 1):**
Look for COAR-related log messages:
```
COAR Notify: Successfully processed notification...
COAR Notify: Sent request_review to prereview...
```

**Sidekiq logs (Terminal 2):**
```
CoarNotify::Workers::ReceiveWorker JID-xxx INFO: start
CoarNotify::Workers::ReceiveWorker JID-xxx INFO: done: 0.125 sec
```

**Database query for failed notifications:**
```bash
psql $DATABASE_URL -c "SELECT id, error_message, created_at FROM coar_notifications WHERE status='failed';"
```

---

## Clean Up

To reset for fresh testing:

```bash
# Clear database
psql $DATABASE_URL -c "TRUNCATE TABLE coar_notifications RESTART IDENTITY CASCADE;"

# Clear Redis queues
redis-cli FLUSHDB

# Remove test files
rm -f test_*.json test_*.rb
```

---

## Next Steps

Once local testing is complete:

1. ✅ Verify all endpoints work (inbox GET/POST, notifications GET)
2. ✅ Confirm database storage and querying
3. ✅ Test worker processing (send and receive)
4. ✅ Validate notification payloads with coarnotifyrb
5. 📋 Deploy to staging environment
6. 📋 Test with actual external service (PREreview test instance)
7. 📋 Set up monitoring and alerting
8. 📋 Deploy to production

---

## Quick Reference

**Common Commands:**

```bash
# Start services
bundle exec ruby app.rb                    # Terminal 1
bundle exec sidekiq -r ./app/lib/workers.rb  # Terminal 2

# Test inbox
curl -X POST http://localhost:4567/coar/inbox -H "Content-Type: application/ld+json" -d @notification.json
curl http://localhost:4567/coar/inbox

# Check database
psql $DATABASE_URL -c "SELECT COUNT(*) FROM coar_notifications;"
psql $DATABASE_URL -c "SELECT * FROM coar_notifications ORDER BY created_at DESC LIMIT 5;"

# Check status
curl http://localhost:4567/status

# View recent notifications
psql $DATABASE_URL -c "SELECT id, direction, notification_types, status, created_at FROM coar_notifications ORDER BY created_at DESC LIMIT 10;"
```

---

## Success Criteria

Your local setup is working correctly if:

- ✅ POST to `/coar/inbox` returns 201 Created
- ✅ GET `/coar/inbox` returns list of notifications
- ✅ Notifications are stored in PostgreSQL
- ✅ Sidekiq workers process notifications (status changes to 'processed')
- ✅ Different notification types are handled correctly
- ✅ SendWorker can send notifications
- ✅ No errors in Roboneuro or Sidekiq logs

Happy testing! 🎉
