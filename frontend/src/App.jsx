import { useState, useEffect, useCallback } from 'react'
import './App.css'

const getApiBase = () => {
  const backendPort = import.meta.env.VITE_BACKEND_PORT || '4567'
  return `http://${window.location.hostname}:${backendPort}/api`
}

const API_BASE = getApiBase()

function App() {
  const [status, setStatus] = useState(null)
  const [loading, setLoading] = useState(true)
  const [toggling, setToggling] = useState(false)
  const [error, setError] = useState(null)

  const fetchStatus = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE}/status`)
      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.error || 'Failed to fetch status')
      }
      const data = await response.json()
      setStatus(data)
      setError(null)
    } catch (err) {
      setError(err.message)
    }
  }, [])

  useEffect(() => {
    const loadData = async () => {
      setLoading(true)
      await fetchStatus()
      setLoading(false)
    }
    loadData()
    
    const interval = setInterval(fetchStatus, 10000)
    return () => clearInterval(interval)
  }, [fetchStatus])

  const handleToggle = async () => {
    setToggling(true)
    try {
      const response = await fetch(`${API_BASE}/toggle`, { method: 'POST' })
      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.error || 'Failed to toggle VPN')
      }
      const data = await response.json()
      setStatus(prev => ({ ...prev, vpn: data.vpn }))
      setError(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setToggling(false)
    }
  }

  if (loading) {
    return (
      <div className="app">
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Connecting to router...</p>
        </div>
      </div>
    )
  }

  const vpnEnabled = status?.vpn?.enabled
  const vpnConnected = status?.vpn?.connected

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          <div className="logo">
            <div className="logo-icon">
              <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <span>VPN Manager</span>
          </div>
          {status?.client && (
            <div className="device-info">
              <span className="device-name">{status.client.device_name}</span>
              <span className="device-model">{status.client.model}</span>
            </div>
          )}
        </div>
      </header>

      <main className="main">
        {error && (
          <div className="error-banner">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
              <path d="M12 8V12" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              <circle cx="12" cy="16" r="1" fill="currentColor"/>
            </svg>
            <span>{error}</span>
            <button onClick={fetchStatus} className="retry-btn">Retry</button>
          </div>
        )}

        <div className="status-card-container">
          <div className={`status-card ${vpnEnabled ? 'enabled' : 'disabled'}`}>
            <div className="status-indicator">
              <div className={`indicator-ring ${vpnEnabled ? 'active' : ''}`}>
                <div className="indicator-core">
                  {vpnEnabled ? (
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M12 2L3 7V12C3 17.55 6.84 22.74 12 24C17.16 22.74 21 17.55 21 12V7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M9 12L11 14L15 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  ) : (
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M12 2L3 7V12C3 17.55 6.84 22.74 12 24C17.16 22.74 21 17.55 21 12V7L12 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                      <path d="M9 9L15 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                      <path d="M15 9L9 15" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                    </svg>
                  )}
                </div>
              </div>
            </div>

            <div className="status-info">
              <h2 className="status-title">
                {vpnEnabled ? 'VPN Active' : 'VPN Inactive'}
              </h2>
              <p className="status-subtitle">
                {status?.vpn?.interface_name || 'No interface selected'}
              </p>
              {vpnEnabled && (
                <div className="connection-status">
                  <span className={`connection-dot ${vpnConnected ? 'connected' : 'connecting'}`}></span>
                  <span>{vpnConnected ? 'Connected' : 'Establishing connection...'}</span>
                </div>
              )}
            </div>

            <button 
              className={`toggle-button ${vpnEnabled ? 'active' : ''} ${toggling ? 'toggling' : ''}`}
              onClick={handleToggle}
              disabled={toggling}
            >
              <span className="toggle-text">
                {toggling ? 'Processing...' : vpnEnabled ? 'Disable VPN' : 'Enable VPN'}
              </span>
              <span className="toggle-icon">
                <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M18.36 6.64A9 9 0 1 1 5.64 6.64" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                  <path d="M12 2V12" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                </svg>
              </span>
            </button>
          </div>
        </div>
      </main>

      <footer className="footer">
        <p>Keenetic VPN Manager • {status?.client?.firmware || 'Unknown firmware'}</p>
      </footer>
    </div>
  )
}

export default App

