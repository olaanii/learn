# Fix "App not installed as package appear to be invalid"

## 1. Uninstall any existing app first

If you had a **previous version** of the app on the phone (debug build, or from Play, or different signing), **uninstall it**:

- Settings → Apps → find the app → Uninstall  
- Or long-press the app icon → App info → Uninstall  

Then try installing the new APK again. Signature mismatch often causes "invalid".

---

## 2. Sign the release APK with a release key (recommended)

Release builds were using the **debug** keystore. Some devices reject debug-signed APKs when installing manually. Use a **release keystore** so the APK is valid.

### One-time setup

**1. Create a keystore** (from the project root or `frontend` folder):

```bash
cd frontend/android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Use a password you’ll remember; set the rest (name, etc.) as you like.

**2. Create `key.properties`** in `frontend/android/`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

Replace `YOUR_STORE_PASSWORD` and `YOUR_KEY_PASSWORD` with the passwords you set for the keystore.

**3. Rebuild the APK** (from `frontend`):

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://equb-db.vercel.app/api --dart-define=WALLETCONNECT_PROJECT_ID=10aaa86fb2c0d5a86ee20ce532834485 --dart-define=CHAIN_ID=102031 --dart-define=RPC_URL=https://rpc.cc3-testnet.creditcoin.network
```

**4. Install the new APK** on the phone (copy `build/app/outputs/flutter-apk/app-release.apk` and open it, or use `adb install`).

---

## 3. If it still fails

- **Transfer:** Copy the APK again (or use USB/ADB) in case the file was corrupted.
- **Storage:** Ensure "Install from unknown sources" (or "Install unknown apps") is allowed for the app you use to open the APK (e.g. Files, Chrome).
- **Device:** Try another device or user profile to rule out device-specific restrictions.
