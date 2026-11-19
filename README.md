# Student Election (Flutter)

Native Android & iOS client for the Student Election system, written in **Dart + Flutter** with a Kotlin platform channel for BLE polling-node presence verification and election notifications.

## Features
- **Authentication**: Sign in, register (two-step with emailed 6-character code), and password recovery.
- **Home / News / Elections**: Live 10-second polling feed with server-skew-corrected countdowns in `Africa/Accra`.
- **Presence-gated Voting**: BLE polling-node scan, ballot selection (single & multi-seat, abstain), live authorisation countdown, review, and receipt.
- **Results**: Live vote counts, winner & tie/runoff indicators.
- **Settings**: Profile editor (`fullName`, `level`, `semester`), Bluetooth status, and sign out.

## Building the APK
GitHub Actions (`.github/workflows/release.yml`) automatically runs `flutter analyze`, builds `build/app/outputs/flutter-apk/app-release.apk`, and publishes it as a GitHub Release on every push.

To build locally with Flutter installed:
```bash
flutter pub get
flutter build apk --release
```

## BLE Polling-Node Format
`MainActivity.kt` scans for manufacturer-specific data under `BEACON_MANUFACTURER_ID = 0xFFFF` with a 16-byte little-endian payload (`uint32 beaconId`, `8-byte bootNonce`, `uint32 counter`). Update `BEACON_MANUFACTURER_ID` in `android/app/src/main/kotlin/com/studentelection/vote/MainActivity.kt` if your hardware beacon uses a different company ID.
