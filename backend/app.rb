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

  use Rack::CommonLogger, $stdout

  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/*.rb'
  end

  configure do
    set :show_exceptions, false
    set :host_authorization, { permitted_hosts: [".internal", "localhost", "127.0.0.1"] }
    set :logging, true
  end

  before do
    content_type :json
    puts "[#{Time.now}] #{request.request_method} #{request.path} from #{request.ip} (Host: #{request.host})"
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
      VpnManager.new(client: keenetic_client)
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
  end

  # Health check
  get '/health' do
    json({ status: 'ok' })
  end

  # Get client's VPN status
  get '/api/status' do
    begin
      router_info = vpn_manager.client_info
      ip = client_ip
      vpn_status = vpn_manager.client_vpn_status_by(ip)

      json({
        client: router_info,
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

  # Get available VPN policies
  get '/api/policies' do
    begin
      policies = vpn_manager.available_policies
      json({ policies: policies })
    rescue KeeneticClient::ClientError => e
      status 503
      json({ error: e.message })
    rescue StandardError => e
      status 500
      json({ error: "Internal error: #{e.message}" })
    end
  end

  # Control VPN - enable/disable with policy selection
  post '/api/vpn' do
    begin
      policy_name = json_body['policy']
      ip = client_ip

      if policy_name
        vpn_manager.enable_vpn_for_client_by(ip, policy_name)
      else
        vpn_manager.disable_vpn_for_client_by(ip)
      end

      vpn_status = vpn_manager.client_vpn_status_by(ip)
      json(vpn_status)
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
