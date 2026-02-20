# Local development and server instructions

Prerequisites

- Node.js and npm installed (Node v24+ recommended).

Quick start (preferred — Vite dev server)

1. From the project root, install dependencies (if not already):

```powershell
npm install
```

1. Start the dev server:

```powershell
npm run dev
```

The dev server uses Vite and typically serves at [http://localhost:5173].

Fallback static server (no build tools required)

- If you prefer a simple static server or Vite isn't available, run:

```powershell
npx http-server -p 5173 -c-1
```

This serves the repository root on port 5173 (I used this during setup).

Stopping servers

- In the terminal running the server, press Ctrl+C to stop.
- Or close/kill the terminal session.

Changing the port

- For `http-server`: change the `-p` value.
- For Vite (PowerShell):

```powershell
$env:PORT=3000; npm run dev
```

Useful npm scripts

- `npm run dev` — start Vite dev server
- `npm run build` — build production assets (Vite)
- `npm run preview` — preview built files with Vite

Notes and troubleshooting

- If `npm run dev` fails with "'vite' is not recognized", run `npm install` to ensure local devDependencies are installed.
- The site entry files are in the repository root (e.g., index.html) and `src/` contains `main.js` and `styles.css`.
