import React, { useEffect, useMemo, useState } from 'react'

const SERVICE_GROUPS = [
  {
    name: 'Delivery Chain',
    description: 'GitOps control plane and job orchestration',
    services: ['ArgoCD', 'Nomad'],
  },
  {
    name: 'Observability',
    description: 'Metrics, alerting, and node visibility',
    services: ['Prometheus'],
  },
  {
    name: 'Connectivity',
    description: 'Secure network path into the fleet',
    services: ['WireGuard'],
  },
  {
    name: 'Compute',
    description: 'Edge Kubernetes runtime',
    services: ['K3s'],
  },
]

function formatLabel(name) {
  return name.replace(/([a-z])([A-Z])/g, '$1 $2')
}

function countHealthyServices(statusMap) {
  return Object.values(statusMap).filter(({ status }) => status === 'up').length
}

function StatusBadge({ status }) {
  return <span className={`status-badge status-${status}`}>{status}</span>
}

function ServiceCard({ name, status, details }) {
  return (
    <article className={`service-card service-${status}`}>
      <div className="service-card__header">
        <div>
          <p className="eyebrow">Platform service</p>
          <h3>{formatLabel(name)}</h3>
        </div>
        <StatusBadge status={status} />
      </div>
      <p className="service-card__details">{details}</p>
    </article>
  )
}

function GroupPanel({ name, description, services, statusMap }) {
  const onlineCount = services.filter((service) => statusMap[service]?.status === 'up').length

  return (
    <section className="group-panel">
      <div className="group-panel__header">
        <div>
          <p className="eyebrow">Operational domain</p>
          <h3>{name}</h3>
        </div>
        <span className="group-panel__count">
          {onlineCount}/{services.length} online
        </span>
      </div>
      <p className="group-panel__description">{description}</p>
      <div className="group-panel__list">
        {services.map((service) => {
          const current = statusMap[service]
          return (
            <div key={service} className="group-panel__item">
              <span>{formatLabel(service)}</span>
              {current ? <StatusBadge status={current.status} /> : <span className="status-badge status-unknown">unknown</span>}
            </div>
          )
        })}
      </div>
    </section>
  )
}

export default function App() {
  const [status, setStatus] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const controller = new AbortController()

    fetch('/status.json', { signal: controller.signal })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Failed to load status snapshot (${response.status})`)
        }
        return response.json()
      })
      .then((payload) => {
        setStatus(payload)
        setError('')
      })
      .catch((loadError) => {
        if (loadError.name !== 'AbortError') {
          setError(loadError instanceof Error ? loadError.message : 'Failed to load status snapshot')
        }
      })
      .finally(() => setLoading(false))

    return () => controller.abort()
  }, [])

  const summary = useMemo(() => {
    if (!status) return null

    const services = Object.values(status)
    const healthy = countHealthyServices(status)
    const degraded = services.length - healthy
    const readiness = services.length > 0 ? Math.round((healthy / services.length) * 100) : 0

    return {
      total: services.length,
      healthy,
      degraded,
      readiness,
    }
  }, [status])

  return (
    <main className="dashboard-shell">
      <section className="hero-panel">
        <div className="hero-panel__content">
          <p className="eyebrow">EdgeOps Fleet Command</p>
          <h1>Flagship DevOps control plane for an IoT edge fleet.</h1>
          <p className="hero-panel__lede">
            Executive-grade visibility for delivery, observability, secure connectivity, and edge compute in one place.
          </p>
        </div>

        <div className="hero-panel__status">
          <div className="hero-panel__status-chip">
            <span className="hero-panel__pulse" />
            Live status snapshot
          </div>
          <p>Source: <code>/status.json</code></p>
          <p className="hero-panel__muted">Designed for fast command-center scanning, not toy status widgets.</p>
        </div>
      </section>

      {loading && <div className="state-banner">Loading fleet snapshot...</div>}
      {!loading && error && <div className="state-banner state-banner--error">{error}</div>}

      {!loading && !error && status && summary && (
        <>
          <section className="summary-grid">
            <article className="summary-card summary-card--accent">
              <p className="eyebrow">Fleet readiness</p>
              <strong>{summary.readiness}%</strong>
              <span>{summary.healthy} of {summary.total} services online</span>
            </article>
            <article className="summary-card">
              <p className="eyebrow">Healthy services</p>
              <strong>{summary.healthy}</strong>
              <span>Control plane and runtime layers are green</span>
            </article>
            <article className="summary-card">
              <p className="eyebrow">Degraded signals</p>
              <strong>{summary.degraded}</strong>
              <span>Investigate only if this number moves above zero</span>
            </article>
          </section>

          <section className="content-grid">
            <div className="content-grid__primary">
              <div className="section-heading">
                <div>
                  <p className="eyebrow">Platform health</p>
                  <h2>Operational services</h2>
                </div>
                <StatusBadge status={summary.degraded === 0 ? 'up' : 'warning'} />
              </div>

              <div className="service-grid">
                {Object.entries(status).map(([name, details]) => (
                  <ServiceCard key={name} name={name} status={details.status} details={details.details} />
                ))}
              </div>
            </div>

            <aside className="content-grid__sidebar">
              <div className="section-heading">
                <div>
                  <p className="eyebrow">Domains</p>
                  <h2>Coverage map</h2>
                </div>
              </div>

              <div className="group-stack">
                {SERVICE_GROUPS.map((group) => (
                  <GroupPanel key={group.name} {...group} statusMap={status} />
                ))}
              </div>
            </aside>
          </section>
        </>
      )}
    </main>
  )
}
