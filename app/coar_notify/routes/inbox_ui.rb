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
