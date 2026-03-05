# Correct Flutter build commands

## Why you got 404 or wrong status

- **Backend:** `https://equb-db.vercel.app/api` – The backend now has a root route, so **GET /api** returns `{ "status": "ok", "message": "Diaspora Equb API", "health": "/api/health" }`. If you still see 404/500, check Vercel function logs (env, DATABASE_URL, etc.). Use **https://equb-db.vercel.app/api/health** for a full health check.
- **Flutter web:** Deploy from the `frontend` folder with env vars set in the **frontend** Vercel project, then run: `npx vercel --prod --archive=tgz`.

---

## Fix: Wrong `--dart-define` in your APK build

You had:
```text
--dart-define=10aaa86fb2c0d5a86ee20ce532834485
```
That is **wrong** – the variable **name** is missing. Dart expects `NAME=value`.

**Correct:** `--dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485`

---

## Android APK (PowerShell, one line)

From the **frontend** folder:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://equb-db.vercel.app/api --dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485 --dart-define=CHAIN_ID=102031 --dart-define=RPC_URL=https://rpc.cc3-testnet.creditcoin.network
```

Replace `10aaa86fb2c0d5a86ee20ce532834485` with your WalletConnect project ID if different.

---

## Android APK (Bash / Git Bash)

```bash
cd frontend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://equb-db.vercel.app/api \
  --dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485 \
  --dart-define=CHAIN_ID=102031 \
  --dart-define=RPC_URL=https://rpc.cc3-testnet.creditcoin.network
```

---

## Flutter web deployment (Vercel)

1. In the **frontend** Vercel project, set Environment Variables: **API_BASE_URL** = `https://equb-db.vercel.app/api`, **WALLETCONNECT_PROJECT_ID**, **CHAIN_ID**, **RPC_URL**.
2. From the **frontend** folder: `npx vercel --prod --archive=tgz`.
3. Or connect Git and push; Vercel will build using `vercel.json` and the env vars.
