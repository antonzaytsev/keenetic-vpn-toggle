# frozen_string_literal: true

require 'digest'
require 'typhoeus'
require 'json'

class KeeneticClient
  class ClientError < StandardError; end
  class AuthenticationError < ClientError; end
  class RequestError < ClientError; end

  attr_reader :host, :login, :password, :cookie_file

  def initialize(host:, login:, password:)
    @host = host
    @login = login
    @password = password
    @cookie_file = '/tmp/keenetic_cookies.txt'
  end

  def get(path)
    ensure_logged_in
    make_request(path)
  end

  def post_rci(body)
    ensure_logged_in
    make_request('rci/', body)
  end

  private

  def ensure_logged_in
    auth_response = make_request('auth')
    response_code = auth_response.code rescue nil

    if response_code.nil? || response_code == 0
      return_code = auth_response.return_code rescue nil
      error_msg = case return_code
      when :couldnt_connect
        "Cannot connect to router at #{build_url('auth')}. Check if router is reachable."
      when :operation_timedout
        "Connection to router timed out. Router may be unreachable or slow."
      when :couldnt_resolve_host
        "Cannot resolve router hostname. Check DNS or host configuration."
      else
        "Network error connecting to router: #{return_code || 'unknown'}"
      end
      raise RequestError, error_msg
    end

    return if response_code == 200
    return authenticate if response_code == 401

    raise RequestError, "Unexpected response from /auth: #{response_code}"
  end

  def authenticate
    auth_response = make_request('auth')

    unless auth_response.headers['X-NDM-Realm'] && auth_response.headers['X-NDM-Challenge']
      raise AuthenticationError, 'Missing authentication headers in response'
    end

    md5_hash = Digest::MD5.hexdigest(
      "#{login}:#{auth_response.headers['X-NDM-Realm']}:#{password}"
    )

    sha_hash = Digest::SHA256.hexdigest(
      "#{auth_response.headers['X-NDM-Challenge']}#{md5_hash}"
    )

    login_response = make_request('auth', {
      login: login,
      password: sha_hash
    })

    return if login_response.code == 200

    raise AuthenticationError, "Authentication failed with code: #{login_response.code}"
  end

  def make_request(path, body = nil)
    url = build_url(path)
    options = build_request_options(body)

    Typhoeus::Request.new(url, options).run
  end

  def build_url(path)
    "http://#{host}/#{path}"
  end

  def build_request_options(body = nil)
    options = {
      cookiefile: cookie_file,
      cookiejar: cookie_file,
      method: body ? :post : :get,
      headers: default_headers,
      timeout: 30,
      connecttimeout: 10
    }

    options[:body] = body.to_json if body
    options
  end

  def default_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'Connection' => 'keep-alive',
      'User-Agent' => 'VpnManager/1.0'
    }
  end
end

