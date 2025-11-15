# neurolibre-neo Integration Guide

This document describes the required changes to neurolibre-neo (the Rails application) to support COAR Notify integration.

## Required Changes

### 1. Add API Endpoint for DOI Lookup

**File:** `app/controllers/dispatch_controller.rb`

Add this new action:

```ruby
# GET /papers/api_lookup_by_doi?doi=10.55458/neurolibre.00027&secret=xxx
def api_lookup_by_doi
  return head :forbidden unless params[:secret] == ENV['ROBONEURO_SECRET']

  doi = params[:doi]
  paper = Paper.find_by(doi: doi)

  if paper
    render json: {
      paper_id: paper.id,
      review_issue_id: paper.review_issue_id,
      meta_review_issue_id: paper.meta_review_issue_id,
      state: paper.state,
      doi: paper.doi,
      title: paper.title,
      repository_url: paper.repository_url
    }
  else
    render json: { error: 'Paper not found' }, status: 404
  end
end
```

**Purpose:** Allows roboneuro to find the GitHub issue ID for a paper given its DOI (needed when processing incoming COAR notifications).

---

### 2. Add API Endpoint for Storing COAR Review Metadata

**File:** `app/controllers/dispatch_controller.rb`

Add this new action:

```ruby
# POST /papers/api_update_coar_review
# Body: { secret: "xxx", doi: "10.xxx", review: { service: "prereview", review_url: "...", ... } }
def api_update_coar_review
  return head :forbidden unless params[:secret] == ENV['ROBONEURO_SECRET']

  doi = params[:doi]
  review_data = params[:review]

  paper = Paper.find_by(doi: doi)
  return render json: { error: 'Paper not found' }, status: 404 unless paper

  # Store in metadata field (existing jsonb column)
  paper.metadata ||= {}
  paper.metadata['coar_reviews'] ||= []
  paper.metadata['coar_reviews'] << {
    service: review_data[:service],
    review_url: review_data[:review_url],
    endorsement_url: review_data[:endorsement_url],
    notification_id: review_data[:notification_id],
    received_at: Time.now.iso8601
  }

  paper.save

  render json: { success: true, paper_id: paper.id }
end
```

**Purpose:** Stores external review/endorsement links received via COAR Notify in the paper's metadata.

---

### 3. Add API Endpoint for Fetching Paper by Issue

**File:** `app/controllers/dispatch_controller.rb`

Add this new action (if not already exists):

```ruby
# GET /papers/api_paper_by_issue?issue_id=123&secret=xxx
def api_paper_by_issue
  return head :forbidden unless params[:secret] == ENV['ROBONEURO_SECRET']

  issue_id = params[:issue_id]
  paper = Paper.find_by(review_issue_id: issue_id) || Paper.find_by(meta_review_issue_id: issue_id)

  if paper
    render json: {
      id: paper.id,
      doi: paper.doi,
      title: paper.title,
      repository_url: paper.repository_url,
      issue_id: issue_id,
      review_issue_id: paper.review_issue_id,
      state: paper.state,
      # Add editor info if available
      editor_orcid: paper.editor&.orcid,
      editor_name: paper.editor&.full_name
    }
  else
    render json: { error: 'Paper not found' }, status: 404
  end
end
```

**Purpose:** Allows roboneuro to fetch paper details when sending COAR notifications.

---

### 4. Add Routes

**File:** `config/routes.rb`

Add these routes:

```ruby
get '/papers/api_lookup_by_doi', to: 'dispatch#api_lookup_by_doi'
post '/papers/api_update_coar_review', to: 'dispatch#api_update_coar_review'
get '/papers/api_paper_by_issue', to: 'dispatch#api_paper_by_issue'
```

---

### 5. Display COAR Reviews in Paper View (Optional)

**File:** `app/views/papers/show.html.erb`

Add this section to display external reviews:

```erb
<% if @paper.metadata && @paper.metadata['coar_reviews']&.any? %>
  <div class="coar-reviews">
    <h3>External Reviews & Endorsements</h3>
    <ul>
      <% @paper.metadata['coar_reviews'].each do |review| %>
        <li>
          <strong><%= review['service']&.capitalize || 'Unknown Service' %></strong>:
          <% if review['review_url'] %>
            <a href="<%= review['review_url'] %>" target="_blank" rel="noopener">View Review</a>
          <% elsif review['endorsement_url'] %>
            <a href="<%= review['endorsement_url'] %>" target="_blank" rel="noopener">View Endorsement</a>
          <% end %>
          <small class="text-muted">
            (Received via COAR Notify on <%= review['received_at'] %>)
          </small>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

**Purpose:** Displays external reviews/endorsements on the paper's public page.

---

## Testing the Integration

### 1. Test DOI Lookup

```bash
curl "https://neurolibre.org/papers/api_lookup_by_doi?doi=10.55458/neurolibre.00027&secret=YOUR_SECRET"
```

Expected response:
```json
{
  "paper_id": 27,
  "review_issue_id": 456,
  "state": "under_review",
  "doi": "10.55458/neurolibre.00027",
  "title": "..."
}
```

### 2. Test COAR Review Storage

```bash
curl -X POST https://neurolibre.org/papers/api_update_coar_review \
  -H "Content-Type: application/json" \
  -d '{
    "secret": "YOUR_SECRET",
    "doi": "10.55458/neurolibre.00027",
    "review": {
      "service": "prereview",
      "review_url": "https://prereview.org/reviews/abc123",
      "notification_id": "urn:uuid:..."
    }
  }'
```

Expected response:
```json
{
  "success": true,
  "paper_id": 27
}
```

### 3. Test Paper by Issue

```bash
curl "https://neurolibre.org/papers/api_paper_by_issue?issue_id=456&secret=YOUR_SECRET"
```

Expected response:
```json
{
  "id": 27,
  "doi": "10.55458/neurolibre.00027",
  "title": "...",
  "repository_url": "https://github.com/...",
  "issue_id": 456,
  "state": "under_review"
}
```

---

## Database Considerations

**No schema changes required!**

All COAR review data is stored in the existing `papers.metadata` JSONB column. This column already exists in neurolibre-neo and is designed for storing flexible metadata.

The structure used:

```ruby
paper.metadata = {
  # ... existing metadata ...
  "coar_reviews" => [
    {
      "service" => "prereview",
      "review_url" => "https://prereview.org/reviews/abc123",
      "notification_id" => "urn:uuid:...",
      "received_at" => "2025-01-15T10:30:00Z"
    }
  ]
}
```

---

## Security Considerations

1. **Authentication:** All API endpoints check `ROBONEURO_SECRET` parameter
2. **No CORS needed:** All requests come from roboneuro (server-to-server)
3. **Rate limiting:** Consider adding rate limits if not already present
4. **Validation:** Validate DOI format before database queries

---

## Deployment Checklist

- [ ] Add three new controller actions to `dispatch_controller.rb`
- [ ] Add three new routes to `config/routes.rb`
- [ ] (Optional) Add COAR reviews display to paper view
- [ ] Deploy to staging
- [ ] Test all three endpoints with curl
- [ ] Deploy to production
- [ ] Verify `ROBONEURO_SECRET` is set in production environment

---

## Questions?

Contact the roboneuro team or consult the COAR Notify documentation at https://coar-notify.net
