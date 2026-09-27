# Known issues and tech debt

Found while documenting the app on 2026-09-27. Listed honestly so the state of the code is clear. Security items are tracked in the [threat model](threat-model.md).

## Next up

| # | Item | Why it matters |
|---|---|---|
| 1 | **No unit tests.** The health and status math lives inside `FleetViewModel` next to Firestore calls | It's the logic that decides when a car gets serviced. Extract it into a pure type and cover it with XCTest (ADR 0001 follow-up) |
| 2 | **Info.plist path depends on a local symlink.** `INFOPLIST_FILE` points at the repo root, where a gitignored symlink to the real file lives | A fresh clone doesn't build until the symlink exists. CI creates it. Fix: point the build setting at `Fleet Maintenance Tracker/Fleet-Maintenance-Tracker-Info.plist` and exclude it from the synced group's resources |
| 3 | **`AnalyticsTabView.swift` sits at the repo root**, outside the app folder, referenced explicitly in the project | Inconsistent layout. Move it into the app folder in Xcode (which updates the project file) |
| 4 | **Screenshots** | To be captured from the emulator with seed data |

## Behavior

- **Two service-due systems.** Template-based health (current) and a legacy check using a single `serviceInterval` with hard-coded "oil change" and "brake service". They can disagree about whether a vehicle is due.
- **Current mileage is the newest log by date, not the highest reading.** Back-dating a log with a higher odometer won't move it. Ending a trip records `mileageEnd` on the trip but doesn't update the vehicle's mileage.
- **Service matching is by substring.** A log's `serviceType` counts toward any template whose name it contains, so "Brake Inspection" doesn't match a template named "Brake Service".
- **`qrCode` token is stored but not printed.** QR images encode the vehicle's document ID. The scanner accepts either, so printed codes keep working, but the separate token is currently unused.
- **Receipts are never deleted from Storage** when a log is edited or deleted, a vehicle is deleted, or an account is deleted.
- **Calendar-based service intervals** are not implemented. Intervals are mileage-only.

## Hygiene

- `print` statements log sign-in emails and UIDs in Release builds (threat model I-4).
- Flat source folder of ~37 files. Group by feature (Vehicles, Maintenance, Trips, Analytics, Auth) in Xcode.
- `SWIFT_VERSION = 5.0`. Adopting Swift 6 strict concurrency would catch main-actor mistakes at compile time.
- README-level doc previously claimed iOS 17+. The deployment target is iOS 26.5, matching the App Store listing.
