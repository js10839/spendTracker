import { useEffect, useState } from 'react'
import './App.css'
import { getApiHealth } from './services/api'

type ConnectionStatus = 'checking' | 'connected' | 'disconnected'

function App() {
  const [connectionStatus, setConnectionStatus] =
    useState<ConnectionStatus>('checking')
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()

    getApiHealth(controller.signal)
      .then(() => setConnectionStatus('connected'))
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === 'AbortError') return
        setConnectionStatus('disconnected')
      })

    return () => controller.abort()
  }, [attempt])

  return (
    <main className="app-shell">
      <section className="status-card" aria-live="polite">
        <p className="eyebrow">Spending Tracker</p>
        <h1>개발 환경 연결 확인</h1>
        <p className="description">
          React 프론트엔드에서 FastAPI 백엔드의 상태를 확인합니다.
        </p>

        <div className={`connection-status ${connectionStatus}`}>
          <span className="status-dot" aria-hidden="true" />
          {connectionStatus === 'checking' && '백엔드 연결 확인 중'}
          {connectionStatus === 'connected' && '백엔드 연결됨'}
          {connectionStatus === 'disconnected' && '백엔드에 연결할 수 없음'}
        </div>

        {connectionStatus === 'disconnected' && (
          <button
            type="button"
            onClick={() => {
              setConnectionStatus('checking')
              setAttempt((value) => value + 1)
            }}
          >
            다시 확인
          </button>
        )}
      </section>
    </main>
  )
}

export default App
