# EdgeOps Frontend

Minimal React (Vite) app to visualize component statuses. Uses a static `status.json` in `public/` as a placeholder for real telemetry.

Run locally:

```bash
cd frontend
npm install
npm run dev
```

Build:

```bash
npm run build
npm run preview
```

Replace `public/status.json` with a real API endpoint or proxy to central Prometheus / ArgoCD endpoints for live data.
