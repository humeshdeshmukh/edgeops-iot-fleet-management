import React, { useEffect, useState } from 'react'

function StatusCard({ name, status, details }) {
  return (
    <div className={`card ${status}`}>
      <h3>{name}</h3>
      <p>Status: <strong>{status}</strong></p>
      {details && <pre>{details}</pre>}
    </div>
  )
}

export default function App() {
  const [status, setStatus] = useState(null)

  useEffect(() => {
    fetch('/status.json')
      .then(r => r.json())
      .then(setStatus)
      .catch(() => setStatus(null))
  }, [])

  if (!status) return <div className="container">Loading status...</div>

  return (
    <div className="container">
      <h1>EdgeOps: Components Status</h1>
      <div className="grid">
        {Object.entries(status).map(([k, v]) => (
          <StatusCard key={k} name={k} status={v.status} details={v.details} />
        ))}
      </div>
    </div>
  )
}
