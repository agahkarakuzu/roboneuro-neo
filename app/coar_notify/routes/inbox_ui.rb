# frozen_string_literal: true

require 'sinatra/base'
require 'json'

module CoarNotify
  module Routes
    # Web UI for viewing COAR Notify inbox
    class InboxUI < Sinatra::Base
      # Configure Sinatra
      set :views, File.join(__dir__, '../views')
      set :public_folder, File.join(__dir__, '../../../public')

      # Main inbox view
      get '/coar/inbox/view' do
        # Get filter parameters
        status_filter = params[:status]
        service_filter = params[:service]
        direction_filter = params[:direction] || 'received'

        # Build query
        query = CoarNotify::Models::Notification.where(direction: direction_filter)
        query = query.where(status: status_filter) if status_filter && !status_filter.empty?
        query = query.where(service_name: service_filter) if service_filter && !service_filter.empty?

        # Get notifications ordered by most recent first
        @notifications = query.order(Sequel.desc(:created_at)).limit(100).all

        # Get unique services for filter dropdown
        @services = CoarNotify::Models::Notification
          .where(direction: direction_filter)
          .select(:service_name)
          .distinct
          .map(:service_name)
          .compact
          .sort

        # Get stats
        @stats = {
          total: CoarNotify::Models::Notification.where(direction: direction_filter).count,
          pending: CoarNotify::Models::Notification.where(direction: direction_filter, status: 'pending').count,
          processing: CoarNotify::Models::Notification.where(direction: direction_filter, status: 'processing').count,
          processed: CoarNotify::Models::Notification.where(direction: direction_filter, status: 'processed').count,
          failed: CoarNotify::Models::Notification.where(direction: direction_filter, status: 'failed').count
        }

        @current_status = status_filter
        @current_service = service_filter
        @current_direction = direction_filter

        erb :inbox
      end

      # View individual notification details
      get '/coar/inbox/view/:id' do
        @notification = CoarNotify::Models::Notification.where(id: params[:id]).first
        halt 404, 'Notification not found' unless @notification

        erb :notification_detail
      end

      # API endpoint to get notification payload as JSON
      get '/coar/inbox/api/:id/payload' do
        content_type :json
        notification = CoarNotify::Models::Notification.where(id: params[:id]).first
        halt 404, { error: 'Notification not found' }.to_json unless notification

        JSON.pretty_generate(notification.payload)
      end
    end
  end
end
