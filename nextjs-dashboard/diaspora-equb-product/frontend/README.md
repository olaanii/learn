# diaspora_equb_frontend

Flutter mobile app for Diaspora Equb (DeFi).

## Android build (APK under 30 MB)

If you get **"unsupported Gradle project"**, run once from **frontend**: `.\repair_android_gradle.bat` (or `flutter create . --project-name diaspora_equb_frontend`). Then from the **frontend** directory run:

If Android Studio or VS Code shows a `dev.flutter.flutter-plugin-loader` failure with `metadata.bin` / `Buffer underflow`, the same repair script also clears the corrupted Gradle Kotlin DSL cache before regenerating `android/`.

- **Windows:** From frontend folder run `.\build_android_under_30mb.bat` (PowerShell) or `build_android_under_30mb.bat` (CMD). From repo root: `frontend\build_android_under_30mb.bat`
- **Or:** `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols`

APKs are in `build/app/outputs/flutter-apk/`. See [ANDROID_BUILD_UNDER_30MB.md](ANDROID_BUILD_UNDER_30MB.md) for details.
