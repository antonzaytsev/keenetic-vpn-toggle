# frozen_string_literal: true

require 'json'
require_relative 'keenetic_client'

class VpnManager
  attr_reader :client, :policy_name

  def initialize(client:, policy_name:)
    @client = client
    @policy_name = policy_name
  end

  # Get VPN status by IP
  def client_vpn_status_by(ip)
    data = load_data
    return { connected: false, error: 'Failed to load data', name: ip } unless data

    host = find_client_by_ip(data, ip)
    return { connected: false, error: 'Client not found', name: ip } unless host

    mac = host['mac']
    current_policy_id = find_client_policy(data, mac)
    vpn_policy_id = find_policy_id(data, policy_name)
    vpn_enabled = current_policy_id == vpn_policy_id

    {
      connected: vpn_enabled,
      current_policy: current_policy_id ? policy_name_by_id(data, current_policy_id) : nil,
      vpn_policy: policy_name,
      mac: mac,
      ip: host['ip'],
      name: host['name'] || host['hostname'] || host['ip']
    }
  end

  # Toggle VPN for a client by IP
  def toggle_vpn_for_client_by(ip)
    data = load_data
    return { success: false, error: 'Failed to load data' } unless data

    host = find_client_by_ip(data, ip)
    return { success: false, error: 'Client not found' } unless host

    mac = host['mac']
    vpn_policy_id = find_policy_id(data, policy_name)
    return { success: false, error: "Policy '#{policy_name}' not found" } unless vpn_policy_id

    current_policy_id = find_client_policy(data, mac)

    update_client_policy(mac, current_policy_id, vpn_policy_id)
  end

  # Enable VPN for a client by IP
  def enable_vpn_for_client_by(ip)
    data = load_data
    return { success: false, error: 'Failed to load data' } unless data

    host = find_client_by_ip(data, ip)
    return { success: false, error: 'Client not found' } unless host

    vpn_policy_id = find_policy_id(data, policy_name)
    return { success: false, error: "Policy '#{policy_name}' not found" } unless vpn_policy_id

    set_client_policy(host['mac'], vpn_policy_id)
  end

  # Disable VPN for a client by IP
  def disable_vpn_for_client_by(ip)
    data = load_data
    return { success: false, error: 'Failed to load data' } unless data

    host = find_client_by_ip(data, ip)
    return { success: false, error: 'Client not found' } unless host

    set_client_policy(host['mac'], { no: true })
  end

  def client_info
    response = client.post_rci({ show: { version: {} } })
    data = JSON.parse(response.body)

    {
      device_name: data.dig('show', 'version', 'description') || data.dig('show', 'version', 'device') || 'Keenetic Router',
      firmware: data.dig('show', 'version', 'title') || 'Unknown',
      model: data.dig('show', 'version', 'model') || 'Unknown'
    }
  end

  private

  def load_data
    body = [
      { 'show' => { 'sc' => { 'ip' => { 'policy' => {} } } } },
      { 'show' => { 'sc' => { 'ip' => { 'hotspot' => { 'host' => {} } } } } },
      { 'show' => { 'ip' => { 'hotspot' => {} } } }
    ]

    response = client.post_rci(body)
    return nil if response.code != 200

    data = JSON.parse(response.body)
    result = {}
    data.each { |el| deep_merge!(result, el) }
    result
  rescue StandardError
    nil
  end

  def deep_merge!(target, source)
    source.each do |key, value|
      if value.is_a?(Hash) && target[key].is_a?(Hash)
        deep_merge!(target[key], value)
      else
        target[key] = value
      end
    end
    target
  end

  def find_policy_id(data, name)
    policies = data.dig('show', 'sc', 'ip', 'policy') || {}

    policies.each do |policy_id, policy_data|
      return policy_id if policy_data['description'] == name
    end

    nil
  end

  def policy_name_by_id(data, id)
    policies = data.dig('show', 'sc', 'ip', 'policy') || {}
    policies.dig(id, 'description')
  end

  def find_client_by_ip(data, ip)
    hosts = data.dig('show', 'ip', 'hotspot', 'host') || []
    hosts = hosts.values if hosts.is_a?(Hash)

    hosts.find { |h| h['ip'] == ip }
  end

  def find_client_policy(data, mac)
    hosts = data.dig('show', 'sc', 'ip', 'hotspot', 'host') || []
    hosts = hosts.values if hosts.is_a?(Hash)

    host = hosts.find { |h| h['mac'] == mac }
    host&.dig('policy')
  end

  def update_client_policy(mac, current_policy_id, vpn_policy_id)
    # If client has policy, remove it; otherwise set VPN policy
    policy = current_policy_id ? { no: true } : vpn_policy_id
    enabled = !current_policy_id

    body = [
      { 'webhelp' => { 'event' => { 'push' => { 'data' => { 'type' => 'configuration_change', 'value' => { 'url' => '/policies/policy-consumers' } }.to_json } } } },
      { 'ip' => { 'hotspot' => { 'host' => { 'mac' => mac, 'permit' => true, 'policy' => policy } } } },
      { 'system' => { 'configuration' => { 'save' => {} } } }
    ]

    response = client.post_rci(body)

    {
      success: response.code == 200,
      message: enabled ? "VPN enabled" : "VPN disabled"
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def set_client_policy(mac, policy)
    body = [
      { 'webhelp' => { 'event' => { 'push' => { 'data' => { 'type' => 'configuration_change', 'value' => { 'url' => '/policies/policy-consumers' } }.to_json } } } },
      { 'ip' => { 'hotspot' => { 'host' => { 'mac' => mac, 'permit' => true, 'policy' => policy } } } },
      { 'system' => { 'configuration' => { 'save' => {} } } }
    ]

    response = client.post_rci(body)

    {
      success: response.code == 200,
      message: policy.is_a?(Hash) ? 'VPN disabled' : 'VPN enabled'
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
