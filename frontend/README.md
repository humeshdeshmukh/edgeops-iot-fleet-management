# EdgeOps Frontend

Flagship React (Vite) dashboard for the EdgeOps fleet. It turns the static `status.json` snapshot in `public/` into an executive-style operations view with summary metrics, service health, and domain coverage.

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
