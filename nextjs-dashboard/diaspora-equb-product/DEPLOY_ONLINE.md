# Deploy everything online (contracts + backend + frontend)

This guide gets **contracts**, **backend**, and **frontend** all running online so the app works end-to-end.

---

## 1. Contracts (already on-chain)

Contracts are deployed on **Creditcoin testnet** (chain 102031). Addresses are in:

- `contracts/deployments/creditcoinTestnet.json`
- Root `.env` (used by backend)

No action needed unless you want to redeploy:

```bash
cd contracts
npx hardhat run scripts/deploy.ts --network creditcoinTestnet
```

Then update root `.env` (and backend env) with the new addresses.

---

## 2. Backend online (Vercel or Docker)

### Option A: Vercel (recommended – no Docker)

Deploy the Nest backend as a **serverless function** on Vercel. You need a **hosted Postgres** (e.g. [Vercel Postgres](https://vercel.com/storage/postgres), [Neon](https://neon.tech), [Supabase](https://supabase.com)).

1. Create a **new Vercel project** for the backend; set **Root Directory** to `nextjs-dashboard/diaspora-equb-product/backend` (or `backend` if your repo root is this product).
2. Add **Environment Variables** (see **backend/VERCEL_DEPLOY.md**): at least **DATABASE_URL** (or DATABASE_HOST/PORT/USER/PASSWORD/NAME), **JWT_SECRET**, **RPC_URL**, **CORS_ORIGINS** (your frontend URL), and contract addresses from `.env`.
3. Deploy (Git push or from `backend` folder: `npx vercel --prod`).
4. Backend URL will be like `https://your-backend.vercel.app`. Set the frontend’s **API_BASE_URL** = `https://your-backend.vercel.app/api`.

Full steps: **backend/VERCEL_DEPLOY.md**.

### Option B: Docker (local or VPS)

Run the Nest backend + Postgres + Redis via Docker. You can do this on your own machine (for testing) or on a **VPS** (so it’s online 24/7).

### Option B1: Local (for testing)

From **project root** (where `docker-compose.yml` is), with `.env` in place:

```bash
docker compose up -d
```

- API: **http://localhost:3002** (or `DOCKER_BACKEND_PORT` from `.env`)
- For the frontend, use **API_BASE_URL** = `http://localhost:3002/api` only when testing on the same machine.

### Option B2: VPS (everything online)

1. Rent a small VPS (e.g. **DigitalOcean**, **Hetzner**, **AWS EC2**, **Railway** “Docker”).
2. Install Docker and Docker Compose on the server.
3. Clone the repo (or copy `backend/`, `docker-compose.yml`, `.env`) onto the server.
4. In `.env` on the server, set:
   - `CORS_ORIGINS` = your frontend URL, e.g. `https://e-equb-xxx.vercel.app`
   - Other vars same as local (DB, JWT, RPC, contract addresses).
5. Run from the project root on the server:

   ```bash
   docker compose up -d
   ```

6. Expose the backend (e.g. nginx in front of port 3001/3002, or open firewall to the backend port). Get the public URL (e.g. `https://api.yourdomain.com` or `http://YOUR_SERVER_IP:3002`).
7. **API base URL for the frontend** = that URL + `/api`, e.g. `https://api.yourdomain.com/api`.

---

## 3. Frontend online (Vercel)

### Fix the “path does not exist” error (if you deploy from `frontend` via CLI)

1. Open **https://vercel.com/olaaniis-projects/e-equb/settings**
2. **General** → **Build & Development Settings** → **Root Directory**
3. **Clear** Root Directory (leave empty) or set to `.`
4. Save

### Deploy

From the **frontend** folder:

```bash
cd frontend
npx vercel --prod
```

On first run, link to project **e-equb** if asked. Ensure in **Settings → Environment Variables** you have at least:

- `API_BASE_URL` = backend API URL from step 2 (e.g. `https://api.yourdomain.com/api` or `http://YOUR_SERVER_IP:3002/api`)
- `PRIVY_APP_ID`
- `PRIVY_APP_CLIENT_ID`
- `CHAIN_ID` = `102031`
- `RPC_URL` = `https://rpc.cc3-testnet.creditcoin.network`

Redeploy after changing env vars.

---

## 4. Checklist (everything online)

| Piece      | Where it runs              | URL you use |
|-----------|----------------------------|-------------|
| Contracts | Creditcoin testnet        | RPC + chain 102031 (already in app) |
| Backend   | Vercel (or Docker on VPS) | e.g. `https://your-backend.vercel.app` → **API_BASE_URL** = `https://your-backend.vercel.app/api` |
| Frontend  | Vercel                     | e.g. `https://e-equb-xxx.vercel.app` → set in backend **CORS_ORIGINS** |

1. **Contracts** – Done (or redeploy and update `.env`).
2. **Backend** – Deploy to Vercel (see **backend/VERCEL_DEPLOY.md**; use hosted Postgres + env vars). Or run Docker on a VPS; set **CORS_ORIGINS** to your frontend URL.
3. **Frontend** – In Vercel, clear Root Directory if using CLI from `frontend`, set **API_BASE_URL** to backend `/api` URL, then `npx vercel --prod` from `frontend`.

After that, the app (frontend + backend + contracts) is fully online.
