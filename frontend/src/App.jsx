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
        throw new Error(data.error || 'Не удалось получить статус')
      }
      const data = await response.json()
      setStatus(data)
      setError(null)
    } catch (err) {
      setError(err.message)
    }
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    
    const loadData = async () => {
      setLoading(true)
      try {
        const response = await fetch(`${API_BASE}/status`, { signal: controller.signal })
        if (!response.ok) {
          const data = await response.json()
          throw new Error(data.error || 'Не удалось получить статус')
        }
        const data = await response.json()
        setStatus(data)
        setError(null)
      } catch (err) {
        if (err.name !== 'AbortError') {
          setError(err.message)
        }
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false)
        }
      }
    }
    loadData()
    
    return () => controller.abort()
  }, [])

  const handleToggle = async () => {
    setToggling(true)
    try {
      const response = await fetch(`${API_BASE}/toggle`, { method: 'POST' })
      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.error || 'Не удалось переключить VPN')
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
          <p>Подключение к роутеру...</p>
        </div>
      </div>
    )
  }

  const vpnEnabled = status?.vpn?.enabled
  const vpnConnected = status?.vpn?.connected

  return (
    <div className="app">
      <main className="main">
        {error && (
          <div className="error-banner">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
              <path d="M12 8V12" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              <circle cx="12" cy="16" r="1" fill="currentColor"/>
            </svg>
            <span>{error}</span>
            <button onClick={fetchStatus} className="retry-btn">Повторить</button>
          </div>
        )}

        <div className="status-card-container">
          <div className={`status-card ${vpnConnected ? 'enabled' : 'disabled'}`}>
            <div className="status-indicator">
              <div className={`indicator-ring ${vpnConnected ? 'active' : ''}`}>
                <div className="indicator-core">
                  {vpnConnected ? (
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
              <p className="client-name">{status?.requester?.name || status?.requester?.ip || 'Неизвестный клиент'}</p>
              <h2 className="status-title">
                {vpnConnected ? 'VPN подключён' : 'VPN отключён'}
              </h2>
            </div>

            <button 
              className={`toggle-button ${vpnConnected ? 'active' : ''} ${toggling ? 'toggling' : ''}`}
              onClick={handleToggle}
              disabled={toggling}
            >
              <span className="toggle-text">
                {toggling ? 'Обработка...' : vpnConnected ? 'Отключить VPN' : 'Включить VPN'}
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
    </div>
  )
}

export default App

