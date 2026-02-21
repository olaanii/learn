# Android build under 30 MB

This project is set up to produce **per-ABI release APKs under ~30 MB** each.

## If you see "unsupported Gradle project"

You can fix it **without moving to a new project** by regenerating the Android folder in place:

**From the `frontend` folder run:**

- **Windows:** `.\repair_android_gradle.ps1` or `repair_android_gradle.bat`
- **Or manually:** `flutter create . --project-name diaspora_equb_frontend`

This updates `android/` to the current Flutter Gradle template and **keeps** your `lib/`, `pubspec.yaml`, and assets. Then run the build commands below.

---

## Quick build (recommended)

From the **frontend** folder:

**Windows (PowerShell):**
```powershell
.\build_android_under_30mb.ps1
```

**Windows (CMD):**
```cmd
build_android_under_30mb.bat
```

**Any OS (from frontend):**
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

## Output

APKs are written to:

`frontend/build/app/outputs/flutter-apk/`

- **app-armeabi-v7a-release.apk** – 32-bit ARM (~25–30 MB)
- **app-arm64-v8a-release.apk** – 64-bit ARM, most phones (~25–30 MB)
- **app-x86_64-release.apk** – 64-bit x86 (emulators / some tablets)

Install **app-arm64-v8a-release.apk** on most current Android phones.

## Single APK under 30 MB (arm64 only)

If you need **one** APK file under 30 MB and only support 64-bit ARM:

```bash
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (single file, ~20–28 MB).  
Does not run on 32-bit-only devices.

## Optional: extra shrinking in Android

To enable R8 code shrinking and resource shrinking in the Android build, ensure your `android/app/build.gradle` has in the `release` buildType:

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

Then run the same Flutter command as above. If `minifyEnabled` causes build or runtime issues, remove it and keep `--split-per-abi` and `--obfuscate`; that is usually enough to stay under 30 MB per ABI.

## If build fails with "Address already in use: bind"

The build script **`build_android_under_30mb.bat`** avoids this by using a **project-local Gradle home** and **no daemon**, so it doesn’t conflict with Android Studio or other Gradle processes.

**Use the batch file to build (recommended):**
- From **repo root:** `frontend\build_android_under_30mb.bat`
- From **frontend folder (PowerShell):** `.\build_android_under_30mb.bat` (the `.\` is required in PowerShell)
- From **frontend folder (CMD):** `build_android_under_30mb.bat`

If you build with `flutter build apk ...` directly and see the error:

1. **Stop Gradle daemons:** From the `frontend` folder run:
   ```cmd
   cd android
   gradlew.bat --stop
   cd ..
   ```

2. **Or** set a project-local Gradle home and no daemon before running Flutter:
   ```cmd
   set GRADLE_USER_HOME=%CD%\android\.gradle-user-home
   set GRADLE_OPTS=-Dorg.gradle.daemon=false
   flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
   ```

3. Close **Android Studio** (or any other window building this project) and retry.

## If release build fails with lint errors (BuiltinIssueRegistry / PsiMember)

The project already disables release lint in `android/app/build.gradle.kts` and `android/build.gradle.kts` so plugin lint tasks don’t fail the build. If you still see lint failures, run the build skipping lint:

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols -x lintVitalAnalyzeRelease -x lintVitalReportRelease
```

## Requirements

- Flutter SDK in PATH
- Android SDK (Android Studio or command-line tools)
- Run from the **frontend** directory (where `pubspec.yaml` is)
