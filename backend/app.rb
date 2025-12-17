# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'rack/cors'
require 'json'

require_relative 'lib/keenetic_client'
require_relative 'lib/vpn_manager'

class VpnManagerApp < Sinatra::Base
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: %i[get post put patch delete options head]
    end
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
  end

  # Health check
  get '/health' do
    json({ status: 'ok' })
  end

  # Get client info and VPN status
  get '/api/status' do
    begin
      client_info = vpn_manager.client_info
      vpn_status = vpn_manager.status

      json({
        client: client_info,
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

  # Get available VPN interfaces
  get '/api/interfaces' do
    begin
      interfaces = vpn_manager.available_interfaces
      json({ interfaces: interfaces })
    rescue KeeneticClient::ClientError => e
      status 503
      json({ error: e.message })
    rescue StandardError => e
      status 500
      json({ error: "Internal error: #{e.message}" })
    end
  end

  # Toggle VPN interface
  post '/api/toggle' do
    begin
      result = vpn_manager.toggle
      vpn_status = vpn_manager.status

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

  # Enable VPN interface
  post '/api/enable' do
    begin
      result = vpn_manager.enable
      vpn_status = vpn_manager.status

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

  # Disable VPN interface
  post '/api/disable' do
    begin
      result = vpn_manager.disable
      vpn_status = vpn_manager.status

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

  # Set specific interface
  post '/api/interface' do
    begin
      interface_name = json_body['interface']
      
      unless interface_name
        status 400
        return json({ error: 'Interface name required' })
      end

      manager = VpnManager.new(
        client: keenetic_client,
        interface_name: interface_name
      )
      
      vpn_status = manager.status
      json({ vpn: vpn_status })
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

