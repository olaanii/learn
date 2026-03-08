# Deploy e-Equb (Flutter web) to Vercel

Deploy this app to your Vercel project so it replaces the previous deployment and appears as **e-Equb**.

---

## Flutter web: backend URL + WalletConnect

The app is configured to talk to the backend at **`https://equb-db.vercel.app/api`** (set in `vercel.json`). WalletConnect is included when you set `WALLETCONNECT_PROJECT_ID` in Vercel.

**1. Environment variables (Vercel dashboard)**  
In your **frontend** project: **Settings → Environment Variables**. Add for **Production** (and Preview if you want):

| Name | Value |
|------|--------|
| `API_BASE_URL` | `https://equb-db.vercel.app/api` *(optional: already in vercel.json)* |
| `WALLETCONNECT_PROJECT_ID` | Your project ID from [WalletConnect Cloud](https://cloud.walletconnect.com) |
| `FIREBASE_API_KEY` | Firebase web app API key |
| `FIREBASE_APP_ID` | Firebase web app ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase messaging sender ID |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_AUTH_DOMAIN` | Usually `your-project.firebaseapp.com` |
| `FIREBASE_STORAGE_BUCKET` | Usually `your-project.firebasestorage.app` or `.appspot.com` |
| `GOOGLE_WEB_CLIENT_ID` | Google web OAuth client ID used for sign-in |
| `FIREBASE_MEASUREMENT_ID` | Optional |
| `FIREBASE_ANDROID_CLIENT_ID` | Optional |
| `FIREBASE_IOS_CLIENT_ID` | Optional |
| `FIREBASE_IOS_BUNDLE_ID` | Optional |

**2. Deploy**

- **From Git:** push to the connected branch; Vercel builds from `vercel.json` and `scripts/vercel_build.sh` (which uses `API_BASE_URL` and `WALLETCONNECT_PROJECT_ID` in the Flutter build).
- **From CLI (frontend folder):**
  ```bash
  cd frontend
  npx vercel --prod
  ```
  If you hit the file-count limit: `npx vercel --prod --archive=tgz`

**Result:** Flutter web build uses `https://equb-db.vercel.app/api` for all API calls, includes your WalletConnect project ID for wallet pairing, and loads Firebase auth configuration securely from Vercel env variables passed into Flutter at build time.

---

## Android APK on Vercel (host for download)

Vercel doesn’t **build** Android apps; it serves the **Flutter web** build. You can still **host an Android APK** on the same deployment so users can download it:

1. **Build the APK** locally (or in CI):
   ```bash
   cd frontend
   flutter build apk --release
   ```
2. **Copy the APK** into the `public` folder so it’s included in the deploy:
   ```bash
   mkdir -p public
   cp build/app/outputs/flutter-apk/app-release.apk public/app-release.apk
   ```
3. **Deploy** (Git push or `npx vercel --prod`). The build script copies `public/` into the web output.
4. **Download URL**: `https://your-app.vercel.app/app-release.apk`

You can add a “Download Android app” link in your web app that points to `/app-release.apk`. Re-run the steps above and redeploy whenever you want to publish a new APK.

---

## Fix: “The provided path … does not exist” when using CLI

If you run `npx vercel --prod` **from the `frontend` folder** and see:

`Error: The provided path "...\frontend\nextjs-dashboard\diaspora-equb-product\frontend" does not exist`

**Cause:** The **e-equb** project has **Root Directory** set to `nextjs-dashboard/diaspora-equb-product/frontend` (for Git deploys from the repo root). When you deploy via CLI from inside `frontend`, Vercel still uses that setting and resolves the path as `(current dir)\nextjs-dashboard\diaspora-equb-product\frontend`, which does not exist.

**Fix (when deploying from the `frontend` folder):**

1. Open **https://vercel.com/olaaniis-projects/e-equb/settings**
2. Go to **General** → **Build & Development Settings**
3. Find **Root Directory** and **clear it** (leave the field empty), then **Save**.
4. In your terminal, from the `frontend` folder, run again: `npx vercel --prod`

If you later deploy via **Git** from the full repo, set Root Directory back to `nextjs-dashboard/diaspora-equb-product/frontend`.

### Using a different Vercel project (same GitHub repo)

You can use **another Vercel project** and still point it at the **same GitHub repo**. Each project has its own URL and settings:

1. In Vercel: **Add New Project** (or use an existing one), and **import the same GitHub repository**.
2. Give the project a name (e.g. **e-Equb**). That name determines the default URL (e.g. `e-equb-xxx.vercel.app`).
3. **Root Directory** is what matters: set it to `nextjs-dashboard/diaspora-equb-product/frontend` so this project builds the Flutter app from that folder. The rest of the repo is ignored for this project’s build.
4. Set **Environment Variables** for this project (each project has its own env vars).

Same code in GitHub → different Vercel projects = different URLs and different env/config per project. You can have one project for “e-Equb” and another for “learn” (or staging), both from the same repo.

---

## 1. Open your Vercel project

Go to your chosen project (e.g. **https://vercel.com/olaaniis-projects/learn/** or your new **e-Equb** project).

## 2. Replace the current app with e-Equb

- In the project **Settings**, open **General**.
- Set **Project Name** to `e-Equb` (this will change the URL to something like `e-equb-xxx.vercel.app` unless you use a custom domain).
- Under **Build & Development Settings**:
  - **Root Directory**: set to `nextjs-dashboard/diaspora-equb-product/frontend`  
    (so Vercel uses this Flutter app and its `vercel.json`).
  - **Framework Preset**: leave as **Other** (or **None**).
  - **Install Command** and **Build Command**: leave empty so the repo’s `vercel.json` is used. The build runs `scripts/vercel_build.sh` (keeps the command under Vercel’s 256-character limit).

If this repo is not the one connected to the “learn” project:

- In **Settings → Git**, disconnect the current repository.
- Connect the repo that contains this path: `nextjs-dashboard/diaspora-equb-product/frontend`.
- Set **Root Directory** to `nextjs-dashboard/diaspora-equb-product/frontend`.

## 3. Environment variables

Vercel does **not** read your local `.env` file automatically. You must add each variable in the dashboard, or use the [Vercel CLI](https://vercel.com/docs/cli#commands/env) (e.g. `vercel env pull` to pull from the project, or add from a file manually). **Note:** `API_BASE_URL` is for the frontend only (where the app calls the backend); it is not in your backend `.env`, so set it in Vercel to your deployed Nest API URL (see below).

In **Settings → Environment Variables**, add these for **Production** (and optionally for Preview):

| Vercel name               | What to use / copy from |
|---------------------------|-------------------------|
| `API_BASE_URL`            | See **“How to set API_BASE_URL”** below. |
| `WALLETCONNECT_PROJECT_ID`| From your root `.env`: `WALLETCONNECT_PROJECT_ID` (e.g. `10aaa86fb2c0d5a86ee20ce532834485`). |
| `CHAIN_ID`                | From `.env`: `CHAIN_ID` → use `102031` (testnet) or `102030` (mainnet). |
| `RPC_URL`                 | From `.env`: `RPC_URL` → e.g. `https://rpc.cc3-testnet.creditcoin.network`. |
| `SENTRY_DSN`              | From `.env`: `SENTRY_DSN` (optional; leave empty to disable). |
| `FIREBASE_API_KEY`        | From your Firebase web app config. Store only in Vercel env, not in git. |
| `FIREBASE_APP_ID`         | From your Firebase web app config. |
| `FIREBASE_MESSAGING_SENDER_ID` | From your Firebase web app config. |
| `FIREBASE_PROJECT_ID`     | Firebase project ID. |
| `FIREBASE_AUTH_DOMAIN`    | Usually `your-project.firebaseapp.com`. |
| `FIREBASE_STORAGE_BUCKET` | Usually `your-project.firebasestorage.app` or `.appspot.com`. |
| `GOOGLE_WEB_CLIENT_ID`    | Google web OAuth client ID for browser sign-in. |
| `FIREBASE_MEASUREMENT_ID` | Optional. |
| `FIREBASE_ANDROID_CLIENT_ID` | Optional. |
| `FIREBASE_IOS_CLIENT_ID`  | Optional. |
| `FIREBASE_IOS_BUNDLE_ID`  | Optional. |

These are passed into the Flutter build by `scripts/vercel_build.sh` via `--dart-define` at deploy time. This keeps Firebase configuration env-backed and out of source control.

### How to set `API_BASE_URL`

`API_BASE_URL` is the **full base URL of your NestJS backend**, including the `/api` path. The Nest app uses `setGlobalPrefix('api')`, so all routes are under `/api` and the base URL must **end with `/api`**.

- **Local backend:**  
  `http://localhost:3001/api`
- **Backend deployed elsewhere:**  
  Use the URL where the backend is reachable, e.g.  
  - `https://your-backend.vercel.app/api`  
  - `https://api.yourdomain.com/api`  
  - `https://diaspora-equb-api.railway.app/api` (or whatever host you use)

**How to know which URL to use:**

1. If the Nest backend is **not deployed yet**, deploy it first (e.g. Railway, Render, Fly.io, or a VPS), then use that base URL + `/api`.
2. If you already have a backend URL, append `/api` if it doesn’t already end with it.  
   Example: backend at `https://my-api.com` → use `https://my-api.com/api`.
3. For **testing the Vercel frontend against your local machine**, you can use a tunnel (e.g. ngrok: `https://abc123.ngrok.io` → `https://abc123.ngrok.io/api`). Do not use `http://localhost:3001/api` in Vercel, because the browser would try to call your localhost from the user’s device, which won’t work.

### Copy-paste from your `.env`

From your project root `.env` you can use:

- `WALLETCONNECT_PROJECT_ID` → same name in Vercel, same value.
- `CHAIN_ID` → same name in Vercel, same value (e.g. `102031`).
- `RPC_URL` → same name in Vercel, same value (e.g. `https://rpc.cc3-testnet.creditcoin.network`).
- `SENTRY_DSN` → same name in Vercel, same value or leave empty.

For Firebase, do not rely on committing generated config or secrets. Instead:

- Keep Firebase values in your local root `.env` for local development if needed.
- Add the same Firebase values manually in the Vercel project Environment Variables UI for Production and Preview.
- Let the Vercel build script inject them into Flutter as dart-defines during the build.

`API_BASE_URL` is **not** in your backend `.env`; it’s the URL **of** the backend that the frontend calls, so you set it in Vercel to wherever that backend is hosted (see above).

## 4. Deploy

- **Redeploy**: **Deployments** → open the latest deployment → **⋯** → **Redeploy** (no cache if you changed Root Directory or env).
- **New deploy from Git**: push your branch; Vercel will build from `nextjs-dashboard/diaspora-equb-product/frontend` and replace the previous deployment with e-Equb.

The first build can take several minutes because the config installs the Flutter SDK in the install step.

## 5. (Optional) Custom domain

In **Settings → Domains**, add your domain and follow Vercel’s DNS instructions so e-Equb is served on your chosen domain.

## Summary

- **Project**: https://vercel.com/olaaniis-projects/learn/
- **Project name**: set to **e-Equb** in Settings → General.
- **Root Directory**: `nextjs-dashboard/diaspora-equb-product/frontend`.
- **Build**: uses `bash scripts/vercel_build.sh` so the build command stays under 256 characters.
- **Previous app**: once you deploy with the above, the new e-Equb build becomes the production deployment; no need to “delete” the old app—overwriting by redeploy is enough.

---

## Full-stack deployment (frontend + backend + contracts)

To run the whole app online (Flutter frontend, NestJS backend, and contracts on-chain), deploy in this order:

### 1. Contracts (once per network)

Contracts live on the blockchain. Deploy them once to your target network (e.g. Creditcoin testnet):

- `cd nextjs-dashboard/diaspora-equb-product/contracts`
- Set `RPC_URL`, `CHAIN_ID`, and deployer key (see `hardhat.config.ts`).
- Run: `npx hardhat run scripts/deploy.ts --network creditcoinTestnet` (or your network name).
- Save the printed contract addresses for the backend env.

### 2. Backend (NestJS)

Deploy the backend on a platform that runs Node + PostgreSQL (e.g. Railway, Render, Fly.io):

- Connect the same GitHub repo, set **Root Directory** to `nextjs-dashboard/diaspora-equb-product/backend`.
- Add PostgreSQL (add-on or external) and set env vars from your `.env` (e.g. `DATABASE_*`, `JWT_SECRET`, `RPC_URL`, `CHAIN_ID`, contract addresses, `CORS_ORIGINS`).
- Set `CORS_ORIGINS` to your frontend URL (e.g. `https://e-equb-xxx.vercel.app`).
- Note the backend URL; the API base for the frontend is that URL + `/api`.

### 3. Frontend (Vercel)

- Deploy the frontend to Vercel as above.
- Set **`API_BASE_URL`** in Vercel to the backend API URL from step 2 (e.g. `https://your-app.railway.app/api`).
- Set `WALLETCONNECT_PROJECT_ID`, `CHAIN_ID`, `RPC_URL` (same network as contracts). Redeploy.

Result: users open the Vercel URL; the app calls the backend at `API_BASE_URL`; backend and wallets use the chain where contracts are deployed.

### Deploy from command line

**Contracts (already done once; re-run to redeploy):**
```bash
cd nextjs-dashboard/diaspora-equb-product/contracts
npx hardhat run scripts/deploy.ts --network creditcoinTestnet
```
Update root `.env` (and backend env) with the addresses printed or in `contracts/deployments/creditcoinTestnet.json`.

**Frontend (Vercel CLI):**
1. Install and log in: `npm install -g vercel` then `vercel login`.
2. In Vercel project **Settings → Environment Variables**, add `API_BASE_URL`, `WALLETCONNECT_PROJECT_ID`, `CHAIN_ID`, `RPC_URL`, `SENTRY_DSN` (or they are used from the project when you deploy).
3. From the **frontend** directory:
   ```bash
   cd nextjs-dashboard/diaspora-equb-product/frontend
   npx vercel --prod
   ```
   If you see *"files should NOT have more than 15000 items"*, use an archive deploy:
   ```bash
   npx vercel --prod --archive=tgz
   ```
   On first run, link to an existing project or create one; the build uses `scripts/vercel_build.sh`. Large or high-file-count uploads are reduced by `.vercelignore` (platform dirs like `android/`, `ios/` are excluded for web-only deploy).

**One script (PowerShell, from repo root):**
```powershell
.\scripts\deploy-fullstack.ps1              # contracts + frontend
.\scripts\deploy-fullstack.ps1 -SkipContracts   # frontend only
.\scripts\deploy-fullstack.ps1 -FrontendOnly    # frontend only (same)
```
Requires Vercel CLI installed and `vercel login` done. Set `API_BASE_URL` (and other env) in the Vercel project or pass for the run: `$env:API_BASE_URL='https://your-backend.railway.app/api'; .\scripts\deploy-fullstack.ps1 -FrontendOnly`.
