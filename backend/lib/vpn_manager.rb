# frozen_string_literal: true

require 'json'
require_relative 'keenetic_client'

class VpnManager
  attr_reader :client, :interface_name

  def initialize(client:, interface_name:)
    @client = client
    @interface_name = interface_name
  end

  def status
    response = client.post_rci({ show: { interface: {} } })
    data = JSON.parse(response.body)

    interface_data = find_interface(data)

    {
      interface_name: interface_name,
      enabled: interface_data ? interface_enabled?(interface_data) : false,
      connected: interface_data ? interface_connected?(interface_data) : false,
      exists: !interface_data.nil?,
      details: interface_data
    }
  end

  def enable
    set_interface_state(true)
  end

  def disable
    set_interface_state(false)
  end

  def toggle
    current_status = status
    if current_status[:enabled]
      disable
    else
      enable
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

  def available_interfaces
    response = client.post_rci({ show: { interface: {} } })
    data = JSON.parse(response.body)

    interfaces = data.dig('show', 'interface') || {}
    
    interfaces.select do |_name, info|
      # Filter for VPN-like interfaces
      info['type']&.match?(/wireguard|openvpn|pptp|l2tp|ipsec|sstp/i) ||
        info['description']&.match?(/vpn/i)
    end.map do |name, info|
      {
        name: name,
        type: info['type'],
        description: info['description'],
        enabled: interface_enabled?(info),
        connected: interface_connected?(info)
      }
    end
  end

  private

  def find_interface(data)
    interfaces = data.dig('show', 'interface') || {}
    interfaces[interface_name]
  end

  def interface_enabled?(interface_data)
    # Check various fields that might indicate enabled state
    interface_data['up'] == true ||
      interface_data['state'] == 'up' ||
      interface_data['link'] == 'up' ||
      (interface_data['global'] != false && interface_data['disabled'] != true)
  end

  def interface_connected?(interface_data)
    interface_data['connected'] == true ||
      interface_data['state'] == 'up' ||
      interface_data['link'] == 'up'
  end

  def set_interface_state(enabled)
    command = if enabled
      { interface: { name: interface_name, up: true } }
    else
      { interface: { name: interface_name, down: true } }
    end

    response = client.post_rci(command)
    
    # Keenetic RCI might need a different approach for enabling/disabling
    # Try the standard interface up/down command first
    if response.code != 200 || response.body.include?('error')
      # Alternative approach using interface configuration
      alternative_command = {
        interface: {
          name: interface_name,
          enabled ? 'global' : 'no global' => enabled ? true : nil
        }.compact
      }
      response = client.post_rci(alternative_command)
    end

    {
      success: response.code == 200,
      message: enabled ? 'Interface enabled' : 'Interface disabled'
    }
  end
end

