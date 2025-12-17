# frozen_string_literal: true

require 'json'
require_relative 'keenetic_client'

class VpnManager
  attr_reader :client, :interface_name

  def initialize(client:, interface_name:)
    @client = client
    @interface_name = interface_name
  end

  # Get VPN status by identifier type (:ip or :hostname)
  def client_vpn_status_by(type, value)
    host = find_host_by(type, value)
    return { connected: false, error: 'Client not found', name: value } unless host

    current_policy = host['policy'] || host['internet'] || ''
    vpn_enabled = current_policy.downcase == interface_name.downcase

    # Get friendly name for current interface
    current_interface_name = if current_policy.empty?
      'По умолчанию'
    else
      get_interface_description(current_policy) || current_policy
    end

    # Get friendly name for VPN interface
    vpn_interface_friendly = get_interface_description(interface_name) || interface_name

    {
      connected: vpn_enabled,
      current_interface: current_interface_name,
      vpn_interface: vpn_interface_friendly,
      vpn_interface_id: interface_name,
      mac: host['mac'],
      ip: host['ip'],
      name: host['name'] || host['hostname'] || host['ip']
    }
  end

  # Enable VPN for a client by identifier
  def enable_vpn_for_client_by(type, value)
    host = find_host_by(type, value)
    return { success: false, error: 'Client not found' } unless host

    set_client_policy(host['mac'], interface_name)
  end

  # Disable VPN for a client by identifier
  def disable_vpn_for_client_by(type, value)
    host = find_host_by(type, value)
    return { success: false, error: 'Client not found' } unless host

    set_client_policy(host['mac'], '')
  end

  # Toggle VPN for a client by identifier
  def toggle_vpn_for_client_by(type, value)
    status = client_vpn_status_by(type, value)

    if status[:connected]
      disable_vpn_for_client_by(type, value)
    else
      enable_vpn_for_client_by(type, value)
    end
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

  # Get friendly name/description for an interface
  def get_interface_description(iface_name)
    return nil if iface_name.nil? || iface_name.empty?

    response = client.post_rci({ show: { interface: {} } })
    data = JSON.parse(response.body)

    interfaces = data.dig('show', 'interface') || {}
    iface = interfaces[iface_name]

    return nil unless iface

    # Try description first, then other name fields
    iface['description'] || iface['alias'] || nil
  rescue StandardError
    nil
  end

  def client_name_by_ip(ip_address)
    ip_address = '192.168.0.2'
    return nil if ip_address.nil? || ip_address.empty?

    # Try multiple Keenetic endpoints to find device name
    name = find_in_hotspot(ip_address) ||
           find_in_arp(ip_address)

    name || ip_address
  end

  def find_in_hotspot(ip_address)
    response = client.post_rci({ show: { 'ip' => { 'hotspot' => {} } } })
    data = JSON.parse(response.body)

    hosts_data = data.dig('show', 'ip', 'hotspot', 'host')
    hosts = normalize_to_array(hosts_data)

    device = hosts.find { |host| host['ip'] == ip_address }

    return device['name'] if device && device['name'].to_s.strip != ''
    return device['hostname'] if device && device['hostname'].to_s.strip != ''
    nil
  rescue StandardError
    nil
  end

  def find_in_arp(ip_address)
    response = client.post_rci({ show: { 'ip' => { 'arp' => {} } } })
    data = JSON.parse(response.body)

    # Try to get MAC from ARP, then look up by MAC in hotspot
    arp_data = data.dig('show', 'ip', 'arp')
    entries = normalize_to_array(arp_data)

    arp_entry = entries.find { |e| e['ip'] == ip_address }
    return nil unless arp_entry && arp_entry['mac']

    # Look up device by MAC in hotspot
    response = client.post_rci({ show: { 'ip' => { 'hotspot' => {} } } })
    data = JSON.parse(response.body)
    hosts = normalize_to_array(data.dig('show', 'ip', 'hotspot', 'host'))

    device = hosts.find { |h| h['mac']&.downcase == arp_entry['mac']&.downcase }

    return device['name'] if device && device['name'].to_s.strip != ''
    return device['hostname'] if device && device['hostname'].to_s.strip != ''
    nil
  rescue StandardError
    nil
  end

  def normalize_to_array(data)
    case data
    when Array then data
    when Hash then data.values
    else []
    end
  end

  private

  def find_host_by(type, value)
    return nil if value.nil? || value.to_s.empty?

    response = client.post_rci({ show: { 'ip' => { 'hotspot' => {} } } })
    data = JSON.parse(response.body)
    hosts = normalize_to_array(data.dig('show', 'ip', 'hotspot', 'host'))

    case type
    when :ip
      find_host_by_ip_in_list(hosts, value)
    when :hostname
      find_host_by_hostname_in_list(hosts, value)
    else
      nil
    end
  rescue StandardError
    nil
  end

  def find_host_by_ip_in_list(hosts, ip_address)
    host = hosts.find { |h| h['ip'] == ip_address }
    return host if host

    # Try to find by MAC via ARP
    mac = find_mac_by_ip(ip_address)
    return nil unless mac

    hosts.find { |h| h['mac']&.downcase == mac.downcase }
  end

  def find_host_by_hostname_in_list(hosts, hostname)
    # Try exact match first (case insensitive)
    host = hosts.find { |h| h['hostname']&.downcase == hostname.downcase }
    return host if host

    # Try partial match
    hosts.find { |h| h['hostname']&.downcase&.include?(hostname.downcase) }
  end

  def find_host_by_ip(ip_address)
    return nil if ip_address.nil? || ip_address.empty?

    response = client.post_rci({ show: { 'ip' => { 'hotspot' => {} } } })
    data = JSON.parse(response.body)

    hosts = normalize_to_array(data.dig('show', 'ip', 'hotspot', 'host'))
    find_host_by_ip_in_list(hosts, ip_address)
  rescue StandardError
    nil
  end

  def find_mac_by_ip(ip_address)
    response = client.post_rci({ show: { 'ip' => { 'arp' => {} } } })
    data = JSON.parse(response.body)

    entries = normalize_to_array(data.dig('show', 'ip', 'arp'))
    entry = entries.find { |e| e['ip'] == ip_address }

    entry&.dig('mac')
  rescue StandardError
    nil
  end

  def set_client_policy(mac, policy_interface)
    # Keenetic RCI to set client's internet policy/interface
    command = {
      'ip' => {
        'hotspot' => {
          'host' => {
            'mac' => mac,
            'policy' => policy_interface
          }
        }
      }
    }

    response = client.post_rci(command)

    {
      success: response.code == 200,
      message: policy_interface.empty? ? 'Using default routing' : "Using #{policy_interface}"
    }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
