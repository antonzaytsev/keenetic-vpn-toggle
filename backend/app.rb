# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/reloader'
require 'rack/cors'
require 'json'
require 'socket'
require 'pry'

require_relative 'lib/keenetic_client'
require_relative 'lib/vpn_manager'

class VpnManagerApp < Sinatra::Base
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: %i[get post put patch delete options head]
    end
  end

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/*.rb'
  end

  configure do
    set :show_exceptions, false
  end

  before do
    content_type :json
  end

  helpers do
    def keenetic_client
      @keenetic_client ||= KeeneticClient.new(
        host: ENV.fetch('KEENETIC_HOST', '192.168.1.1'),
        login: ENV.fetch('KEENETIC_LOGIN', 'admin'),
        password: ENV.fetch('KEENETIC_PASSWORD', '')
      )
    end

    def vpn_manager
      @vpn_manager ||= VpnManager.new(
        client: keenetic_client,
        interface_name: ENV.fetch('VPN_INTERFACE', 'Wireguard0')
      )
    end

    def json_body
      @json_body ||= JSON.parse(request.body.read)
    rescue JSON::ParserError
      {}
    end

    def client_ip
      ip = request.env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
           request.env['HTTP_X_REAL_IP'] ||
           request.ip
      ip = normalize_ip(ip)
      ip = '192.168.0.2' if ip == '127.0.0.1'
      ip
    end

    def normalize_ip(ip)
      return nil if ip.nil?
      # Handle IPv6-mapped IPv4 addresses like ::ffff:192.168.1.100
      ip.start_with?('::ffff:') ? ip[7..] : ip
    end

    def resolve_client_identifier
      ip = client_ip
      # If localhost, use hostname to find device in Keenetic
      if ip == '127.0.0.1' || ip == '::1' || ip&.start_with?('127.')
        { type: :hostname, value: Socket.gethostname.split('.').first }
      else
        { type: :ip, value: ip }
      end
    end
  end

  # Health check
  get '/health' do
    json({ status: 'ok' })
  end

  # Get client's VPN status
  get '/api/status' do
    begin
      router_info = vpn_manager.client_info
      identifier = resolve_client_identifier
      vpn_status = vpn_manager.client_vpn_status_by(identifier[:type], identifier[:value])

      json({
        client: router_info,
        vpn: vpn_status,
        requester: {
          ip: vpn_status[:ip] || client_ip,
          name: vpn_status[:name]
        }
      })
    rescue KeeneticClient::ClientError => e
      status 503
      json({ error: e.message })
    rescue StandardError => e
      status 500
      json({ error: "Internal error: #{e.message}" })
    end
  end

  # Toggle VPN for the requesting client
  post '/api/toggle' do
    begin
      identifier = resolve_client_identifier
      result = vpn_manager.toggle_vpn_for_client_by(identifier[:type], identifier[:value])
      vpn_status = vpn_manager.client_vpn_status_by(identifier[:type], identifier[:value])

      json({
        result: result,
        vpn: vpn_status
      })
    rescue KeeneticClient::ClientError => e
      status 503
      json({ error: e.message })
    rescue StandardError => e
      status 500
      json({ error: "Internal error: #{e.message}" })
    end
  end

  # Enable VPN for the requesting client
  post '/api/enable' do
    begin
      identifier = resolve_client_identifier
      result = vpn_manager.enable_vpn_for_client_by(identifier[:type], identifier[:value])
      vpn_status = vpn_manager.client_vpn_status_by(identifier[:type], identifier[:value])

      json({
        result: result,
        vpn: vpn_status
      })
    rescue KeeneticClient::ClientError => e
      status 503
      json({ error: e.message })
    rescue StandardError => e
      status 500
      json({ error: "Internal error: #{e.message}" })
    end
  end

  # Disable VPN for the requesting client
  post '/api/disable' do
    begin
      identifier = resolve_client_identifier
      result = vpn_manager.disable_vpn_for_client_by(identifier[:type], identifier[:value])
      vpn_status = vpn_manager.client_vpn_status_by(identifier[:type], identifier[:value])

      json({
        result: result,
        vpn: vpn_status
      })
    rescue KeeneticClient::ClientError => e
      status 503
      json({ error: e.message })
    rescue StandardError => e
      status 500
      json({ error: "Internal error: #{e.message}" })
    end
  end

  error do
    status 500
    json({ error: 'Internal server error' })
  end
end
