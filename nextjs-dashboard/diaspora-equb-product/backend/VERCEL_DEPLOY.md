# Deploy Nest backend to Vercel

The backend runs as a **serverless function** on Vercel. All routes are under `/api`. **GET /api** returns a short JSON response; **GET /api/health** is the health check. If you see 404, try **/api/health** and check Vercel function logs (env or DB errors can cause 500).

## 1. Database (required)

Vercel does not run Postgres. Use a hosted Postgres and set **one** of:

- **DATABASE_URL** (recommended): full URL, e.g. from [Vercel Postgres](https://vercel.com/storage/postgres), [Neon](https://neon.tech), or [Supabase](https://supabase.com).  
  Example: `postgres://user:pass@host:5432/dbname?sslmode=require`

- **Or** set **DATABASE_HOST**, **DATABASE_PORT**, **DATABASE_USERNAME**, **DATABASE_PASSWORD**, **DATABASE_NAME** (e.g. from a provider’s dashboard).

### Where to get a Neon DB connection URL

1. Go to **[neon.tech](https://neon.tech)** and sign up or log in.
2. Create a **new project** (e.g. “e-equb-backend”), choose region, and create the project.
3. On the project **Dashboard**, open the **Connection details** (or “Connection string”) section.
4. Copy the **connection string**. It looks like:

  ```text
  postgresql://USER:PASSWORD@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require
  ```  

  Use this as **DATABASE_URL** in your Vercel backend project (Environment Variables). If Neon shows separate host/port/user/password, you can use those as **DATABASE_HOST**, **DATABASE_PORT**, **DATABASE_USERNAME**, **DATABASE_PASSWORD**, **DATABASE_NAME** instead.
5. (Optional) Run your migrations against this DB once (e.g. from your machine with `DATABASE_URL` set, run `npm run migration:run` from the backend folder).

Create the database and run migrations locally against that DB (or from CI) before deploying. On Vercel the app uses `migrationsRun: true` in production if you rely on that.

## 2. Create a Vercel project for the backend

1. On [Vercel](https://vercel.com), click **Add New** → **Project**.
2. Import the **same repo** that contains this backend.
3. Set **Root Directory** to the backend folder:  
   `nextjs-dashboard/diaspora-equb-product/backend`  
   (or `backend` if the repo root is `diaspora-equb-product`).
4. **Framework Preset**: Other.

## 3. Environment variables

In the backend project **Settings → Environment Variables**, add (for **Production** and optionally Preview):

| Name | Required | Example / note |
| ---- | -------- | -------------- |
| **DATABASE_URL** or **DATABASE_*** | Yes | Postgres URL or host/port/user/password/database |
| **JWT_SECRET** | Yes | 32+ characters |
| **RPC_URL** | Yes | e.g. `https://rpc.cc3-testnet.creditcoin.network` |
| **CHAIN_ID** | No | `102031` (testnet) |
| **CORS_ORIGINS** | Yes (prod) | Your frontend URL(s), comma-separated, e.g. `https://e-equb-xxx.vercel.app` |
| **IDENTITY_REGISTRY_ADDRESS** | No | Contract address (defaults in code) |
| **TIER_REGISTRY_ADDRESS** | No | … |
| **CREDIT_REGISTRY_ADDRESS** | No | … |
| **COLLATERAL_VAULT_ADDRESS** | No | … |
| **PAYOUT_STREAM_ADDRESS** | No | … |
| **EQUB_POOL_ADDRESS** | No | … |
| **EQUB_GOVERNOR_ADDRESS** | No | … |
| **SWAP_ROUTER_ADDRESS** | No | … |
| **ACHIEVEMENT_BADGE_ADDRESS** | No | … |
| **TEST_USDC_ADDRESS** / **TEST_USDT_ADDRESS** | No | If you use test tokens |
| **FAYDA_API_URL** / **FAYDA_API_KEY** | No | For identity; leave empty for mock |
| **FIREBASE_PROJECT_ID** | Yes for Firebase auth | `e-equbdigital` |
| **FIREBASE_CLIENT_EMAIL** | Yes for Firebase auth | From Firebase service account |
| **FIREBASE_PRIVATE_KEY** | Yes for Firebase auth | Full private key, preserve newlines |
| **SENTRY_DSN** | No | Optional error tracking |
| **NODE_ENV** | No | `production` |

Copy values from your root `.env` (contract addresses, RPC, JWT, etc.). Set **CORS_ORIGINS** to your frontend origin (e.g. the Vercel frontend URL).

For Firebase email/password and Google sign-in to work in production, the backend Vercel project must have all three Firebase Admin variables:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Vercel environment variable formatting for `FIREBASE_PRIVATE_KEY`:

- Paste the full key exactly as one value.
- If you store it with escaped newlines like `\n`, the backend already converts them back to real newlines at runtime.
- The values should match the Firebase service account for the same project as the frontend app, currently `e-equbdigital`.

## 4. Deploy

- **From Git**: push to the connected branch; Vercel builds and deploys.
- **From CLI** (from the **backend** directory):

  ```bash
  cd nextjs-dashboard/diaspora-equb-product/backend
  npx vercel --prod
  ```

  Link to the backend project when prompted. Ensure **Root Directory** for this project is the `backend` folder (or deploy from inside `backend` so the project root is correct).

## 5. API URL for the frontend

After deploy, the backend URL is like:

`https://your-backend-project.vercel.app`

The frontend must call the **API base URL** = that URL + **`/api`** (Nest global prefix), e.g.:

**API_BASE_URL** = `https://your-backend-project.vercel.app/api`

Set **API_BASE_URL** in the **frontend** Vercel project (e-equb) to this value and redeploy the frontend.

## 6. Build and entry

- **Build**: `npm run build` (runs `nest build`, outputs to `dist/`).
- **Entry**: `dist/vercel.js` (serverless handler). `vercel.json` routes all requests to it.

No Docker; the backend runs as a single serverless function on Vercel.

**Do not remove `builds` from `vercel.json`.** The Nest serverless handler (`dist/vercel.js`) needs it. If you remove `builds`, Vercel will not run your API and you may see 404 or "no serverless function" behavior. The warning *"Build and Development Settings will not apply"* is expected and safe to ignore.
