# Deploy Nest backend to Netlify

The backend runs as a **serverless function** on Netlify. All routes are under `/api`. Use a **separate Netlify site** from your frontend (same repo, different base directory).

## 1. Create a new Netlify site for the backend

1. In [Netlify](https://app.netlify.com), click **Add new site** → **Import an existing project**.
2. Connect the **same Git repo** as your frontend (e.g. `olaanii/learn`).
3. **Base directory**: set to  
   `nextjs-dashboard/diaspora-equb-product/backend`  
   so Netlify uses this folder and its `netlify.toml`.
4. **Build command** and **Publish directory**: leave empty (they are set in `netlify.toml`).

## 2. Environment variables

In the backend site **Site configuration** → **Environment variables**, add the same vars as for Vercel (see **VERCEL_DEPLOY.md**), at least:

- **DATABASE_URL** (or DATABASE_HOST, DATABASE_PORT, DATABASE_USERNAME, DATABASE_PASSWORD, DATABASE_NAME)
- **JWT_SECRET** (32+ chars)
- **RPC_URL**
- **CORS_ORIGINS** (your frontend URL(s), e.g. your Netlify or Vercel frontend URL)
- Contract addresses if you use them (e.g. EQUB_POOL_ADDRESS, IDENTITY_REGISTRY_ADDRESS, …)

## 3. Deploy

Push to the connected branch or trigger **Deploy site** from the Netlify dashboard. The build runs `npm ci && npm run build`, then the function at `netlify/functions/server.js` is deployed. All requests are redirected to that function, so **GET /api** and **GET /api/health** work at your Netlify backend URL.

## 4. Point the frontend at this backend

In your frontend env (or build args), set **API_BASE_URL** to:

`https://<your-backend-site-name>.netlify.app/api`

Example: if the backend site is `equb-api`, use `https://equb-api.netlify.app/api`.

## Notes

- This uses the same Nest app as Vercel (`src/vercel.ts`); the Netlify function wraps it with `serverless-http`.
- If the function fails to start (e.g. missing module or DB), check **Functions** → **server** logs in the Netlify dashboard.
- For database, use a hosted Postgres (e.g. [Neon](https://neon.tech), [Supabase](https://supabase.com), or Vercel Postgres) and set **DATABASE_URL** (or the separate DB vars).
