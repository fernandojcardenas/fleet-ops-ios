# Building against a real Firebase project

For demo data, you don't need any of this. Use the emulator path in [firebase/README.md](../firebase/README.md).

## Requirements

- Xcode 26.5 or later (deployment target iOS 26.5)
- A Firebase project with Email/Password sign-in, Cloud Firestore and Cloud Storage enabled
- Swift packages resolve from the committed `Package.resolved` (Firebase iOS SDK 12.13.0)

## Steps

1. In the Firebase console, add an iOS app with bundle ID `FAJ.Fleet-Maintenance-Tracker` (or your own) and download `GoogleService-Info.plist`.
2. Put it at `Fleet Maintenance Tracker/GoogleService-Info.plist`. It's gitignored; never commit it.
3. Create the Info.plist link the project expects (known issue 2):
   ```sh
   ln -s "Fleet Maintenance Tracker/Fleet-Maintenance-Tracker-Info.plist" Fleet-Maintenance-Tracker-Info.plist
   ```
4. Deploy the rules and create `/staff/{uid}` documents in the order given in [the hardening runbook](security/firestore-rules-hardening.md#deploy-runbook-production).
5. In Firebase Auth → Settings → User actions, keep **Enable create (sign-up)** off. Create staff accounts in the console.
6. Open `Fleet Maintenance Tracker.xcodeproj`, select your team for signing, build and run.
