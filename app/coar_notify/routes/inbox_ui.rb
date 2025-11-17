# frozen_string_literal: true

require 'sinatra/base'
require 'json'

module CoarNotify
  module Routes
    # Web UI for viewing COAR Notify notifications (inbox and outbox)
    class Dashboard < Sinatra::Base
      # Configure Sinatra
      set :views, File.join(__dir__, '../views')
      set :public_folder, File.join(__dir__, '../../../public')

      # Main dashboard view
      get '/coar_notify/dashboard' do
        # Get filter parameters
        @status = params[:status] || ''
        @service = params[:service] || ''
        @direction = params[:direction] || 'received'
        @offset = (params[:offset] || 0).to_i
        @limit = (params[:limit] || 50).to_i

        # Build query
        query = CoarNotify::Models::Notification.where(direction: @direction)
        query = query.where(status: @status) if @status && !@status.empty?
        query = query.where(service_name: @service) if @service && !@service.empty?

        # Get total count for pagination
        @total_count = query.count

        # Get notifications ordered by most recent first
        @notifications = query.order(Sequel.desc(:created_at)).limit(@limit).offset(@offset).all

        # Get unique services for filter dropdown
        @services = CoarNotify::Models::Notification
          .where(direction: @direction)
          .select(:service_name)
          .distinct
          .map(:service_name)
          .compact
          .sort

        # Get stats
        @stats = {
          total: CoarNotify::Models::Notification.where(direction: @direction).count,
          pending: CoarNotify::Models::Notification.where(direction: @direction, status: 'pending').count,
          processing: CoarNotify::Models::Notification.where(direction: @direction, status: 'processing').count,
          processed: CoarNotify::Models::Notification.where(direction: @direction, status: 'processed').count,
          failed: CoarNotify::Models::Notification.where(direction: @direction, status: 'failed').count
        }

        # Set legacy variable names for backwards compatibility
        @current_status = @status
        @current_service = @service
        @current_direction = @direction

        erb :dashboard
      end

      # Send notification form
      get '/coar_notify/dashboard/send' do
        erb :send_notification
      end

      # Handle send notification form submission
      post '/coar_notify/dashboard/send' do
        begin
          # Get form parameters
          issue_id = params[:issue_id]&.to_i
          pattern = params[:pattern]
          service_name = params[:service]
          notes = params[:notes]

          # Validate required parameters
          halt 400, "Issue ID is required" unless issue_id && issue_id > 0
          halt 400, "Notification type is required" unless pattern
          halt 400, "Service is required" unless service_name

          # Validate pattern
          unless ['RequestReview', 'RequestEndorsement'].include?(pattern)
            halt 400, "Invalid notification type: #{pattern}"
          end

          # Fetch paper data from NeuroLibre API
          paper_data = CoarNotify::Services::GitHubNotifier.get_paper_by_issue(issue_id)
          halt 404, "Paper not found for issue ##{issue_id}" unless paper_data

          # Add notes if provided
          paper_data[:notes] = notes if notes && !notes.empty?

          # Send notification using existing Sender service
          sender = CoarNotify::Services::Sender.new

          result = case pattern
          when 'RequestReview'
            sender.send_request_review(paper_data, service_name)
          when 'RequestEndorsement'
            sender.send_request_endorsement(paper_data, service_name)
          end

          # Check if send was successful
          if result[:success]
            # Redirect to dashboard with success message
            redirect "/coar_notify/dashboard?status=processed&direction=sent"
          else
            halt 500, "Failed to send notification: #{result[:error]}"
          end

        rescue ArgumentError => e
          # Service not found or validation error
          halt 400, "Error: #{e.message}"
        rescue => e
          # Unexpected error
          warn "Error sending notification: #{e.class} - #{e.message}"
          warn e.backtrace.join("\n")
          halt 500, "Unexpected error: #{e.message}"
        end
      end

      # View individual notification details
      get '/coar_notify/dashboard/:id' do
        @notification = CoarNotify::Models::Notification.where(id: params[:id]).first
        halt 404, 'Notification not found' unless @notification

        erb :notification_detail
      end

      # API endpoint to get notification payload as JSON
      get '/coar_notify/dashboard/api/:id/payload' do
        content_type :json
        notification = CoarNotify::Models::Notification.where(id: params[:id]).first
        halt 404, { error: 'Notification not found' }.to_json unless notification

        JSON.pretty_generate(notification.payload)
      end
    end
  end
end
