# frozen_string_literal: true

require 'sinatra/base'
require 'json'

module CoarNotify
  module Routes
    # Dashboard web interface for COAR Notify
    #
    # Provides a web UI for:
    # - Viewing notification history
    # - Sending notifications
    # - Viewing notification details
    # - Filtering and searching notifications
    class Dashboard < Sinatra::Base
      set :views, File.expand_path('../views', __dir__)
      set :public_folder, File.expand_path('../public', __dir__)

      # Enable sessions for flash messages
      enable :sessions
      set :session_secret, ENV['ROBONEURO_SECRET'] || 'coar_notify_dashboard_secret'

      # Simple authentication helper
      helpers do
        def authenticated?
          # In development, allow access without auth
          return true if ENV['RACK_ENV'] == 'development'

          # In production, check for auth token
          auth_token = request.env['HTTP_AUTHORIZATION']&.gsub('Bearer ', '')
          auth_token == ENV['COAR_DASHBOARD_TOKEN']
        end

        def require_auth!
          halt 401, erb(:unauthorized) unless authenticated?
        end

        def flash
          session[:flash] ||= {}
        end

        def current_page?(path)
          request.path_info == path
        end
      end

      # Authentication filter (applies to all routes)
      before do
        require_auth!
      end

      # Clear flash after each request
      after do
        session[:flash] = {}
      end

      # Main dashboard - list notifications
      get '/' do
        @direction = params[:direction] # 'sent', 'received', or nil (all)
        @status = params[:status] # 'pending', 'processed', 'failed', or nil (all)
        @service = params[:service]
        @limit = (params[:limit] || 50).to_i
        @offset = (params[:offset] || 0).to_i

        # Build query
        query = Models::Notification.dataset

        # Apply filters
        query = query.where(direction: @direction) if @direction
        query = query.where(status: @status) if @status
        query = query.where(service_name: @service) if @service && !@service.empty?

        # Get total count for pagination
        @total_count = query.count

        # Get paginated results
        @notifications = query
          .reverse_order(:created_at)
          .limit(@limit)
          .offset(@offset)
          .all

        # Get service list for filter dropdown
        @services = Models::ServiceRegistry.all.keys

        erb :dashboard
      end

      # Send notification form
      get '/send' do
        @send_patterns = Registry::PatternRegistry.send_patterns
        @services = Models::ServiceRegistry.all

        # Get papers from NeuroLibre (mock for now, integrate with actual API)
        @papers = fetch_papers

        erb :send_notification
      end

      # Handle send notification form submission
      post '/send' do
        pattern_name = params[:pattern]
        service_name = params[:service]
        issue_id = params[:issue_id].to_i

        # Get paper data
        paper_data = fetch_paper_by_issue(issue_id)

        unless paper_data
          flash[:error] = "Paper not found for issue ##{issue_id}"
          redirect '/coar/dashboard/send'
        end

        # Send notification based on pattern
        sender = Services::Sender.new

        result = case pattern_name
        when 'RequestReview'
          sender.send_request_review(paper_data, service_name)
        when 'RequestEndorsement'
          sender.send_request_endorsement(paper_data, service_name)
        when 'UndoOffer'
          original_notification_id = params[:original_notification_id]
          unless original_notification_id && !original_notification_id.empty?
            flash[:error] = "Original notification ID is required for UndoOffer"
            redirect '/coar/dashboard/send'
          end
          paper_data[:withdrawal_reason] = params[:withdrawal_reason] if params[:withdrawal_reason]
          sender.send_undo_offer(paper_data, service_name, original_notification_id)
        else
          flash[:error] = "Unknown pattern: #{pattern_name}"
          redirect '/coar/dashboard/send'
        end

        if result[:success]
          flash[:success] = "✅ Notification sent successfully!"
          redirect "/coar/dashboard/notifications/#{result[:record_id]}"
        else
          flash[:error] = "❌ Failed to send: #{result[:error]}"
          redirect '/coar/dashboard/send'
        end
      rescue => e
        flash[:error] = "❌ Error: #{e.message}"
        redirect '/coar/dashboard/send'
      end

      # View notification details
      get '/notifications/:id' do
        @notification = Models::Notification[params[:id].to_i]

        halt 404, erb(:not_found) unless @notification

        # Parse payload for display
        @payload = @notification.payload
        @payload_json = JSON.pretty_generate(@payload)

        erb :notification_detail
      end

      # Retry failed notification
      post '/notifications/:id/retry' do
        notification = Models::Notification[params[:id].to_i]

        halt 404, 'Notification not found' unless notification

        if notification.direction == 'received'
          # Re-enqueue receive worker
          notification.update(status: 'pending')
          Workers::ReceiveWorker.perform_async(notification.id)
          flash[:success] = "✅ Notification queued for reprocessing"
        elsif notification.direction == 'sent'
          flash[:error] = "❌ Cannot retry sent notifications (send a new one instead)"
        end

        redirect "/coar/dashboard/notifications/#{notification.id}"
      end

      # API: Get pattern schema (for dynamic form building)
      get '/api/patterns/:name/schema' do
        content_type :json

        pattern = Registry::PatternRegistry.get(params[:name])

        unless pattern
          halt 404, { error: 'Pattern not found' }.to_json
        end

        pattern.schema.to_json
      end

      # API: Get paper data by issue_id
      get '/api/papers/:issue_id' do
        content_type :json

        paper = fetch_paper_by_issue(params[:issue_id].to_i)

        unless paper
          halt 404, { error: 'Paper not found' }.to_json
        end

        paper.to_json
      end

      # API: List papers
      get '/api/papers' do
        content_type :json

        papers = fetch_papers
        papers.to_json
      end

      # API: Get sent notifications for a paper (for UndoOffer)
      get '/api/papers/:issue_id/sent_notifications' do
        content_type :json

        issue_id = params[:issue_id].to_i

        notifications = Models::Notification
          .where(issue_id: issue_id, direction: 'sent')
          .where(Sequel.~(status: 'withdrawn'))
          .reverse_order(:created_at)
          .all
          .map { |n| { id: n.notification_id, type: n.primary_type, created_at: n.created_at } }

        notifications.to_json
      end

      private

      # Fetch papers from NeuroLibre API or GitHub
      def fetch_papers
        # TODO: Integrate with actual NeuroLibre API
        # For now, return mock data or fetch from GitHub
        begin
          # Try to get papers from GitHubNotifier if available
          if defined?(Services::GitHubNotifier) && Services::GitHubNotifier.respond_to?(:get_all_papers)
            Services::GitHubNotifier.get_all_papers
          else
            # Mock data for development
            [
              { issue_id: 1, title: 'Sample Paper 1', doi: '10.55458/neurolibre.00001' },
              { issue_id: 2, title: 'Sample Paper 2', doi: '10.55458/neurolibre.00002' }
            ]
          end
        rescue => e
          warn "Could not fetch papers: #{e.message}"
          []
        end
      end

      # Fetch specific paper by GitHub issue ID
      def fetch_paper_by_issue(issue_id)
        # TODO: Integrate with actual NeuroLibre API
        begin
          if defined?(Services::GitHubNotifier) && Services::GitHubNotifier.respond_to?(:get_paper_by_issue)
            Services::GitHubNotifier.get_paper_by_issue(issue_id)
          else
            # Mock data for development
            {
              issue_id: issue_id,
              doi: "10.55458/neurolibre.0000#{issue_id}",
              title: "Sample Paper #{issue_id}",
              repository_url: "https://github.com/user/repo-#{issue_id}",
              editor_orcid: '0000-0001-2345-6789',
              editor_name: 'Dr. Test Editor'
            }
          end
        rescue => e
          warn "Could not fetch paper #{issue_id}: #{e.message}"
          nil
        end
      end
    end
  end
end
