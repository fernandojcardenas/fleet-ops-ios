# ADR 0001: One observable view model owns all fleet state

- **Status:** Accepted (reflects the shipped design, recorded retroactively 2026-09-27)
- **Context date:** May 2026

## Context

Almost every screen needs data from more than one collection:

- The Fleet list needs vehicles, logs (for health) and trips (for "on a trip").
- Analytics needs logs, vehicles and owners.
- The QR scanner needs vehicles and trips.

Staff use the app on several devices at once, often with weak signal in a lot. Changes on one phone must appear on the others, and writes made offline must not be lost.

Options considered:

1. **One view model per screen**, each querying Firestore on appear.
2. **Repository layer + per-screen view models** (the textbook layering).
3. **One app-wide `@Observable` view model** holding live snapshots of every collection.

## Decision

Use one `FleetViewModel`, marked `@Observable` and `@MainActor`. It is created once in `MainTabView` and passed to each tab. It owns four Firestore snapshot listeners and exposes plain arrays plus derived values (`fleetHealth`, `serviceStatus`, `ongoingTripsCount`, `totalSpent`). Views call intent methods (`addLog`, `startTrip`, …). Writes go to Firestore, and the listeners deliver the result back.

## Consequences

**Good**
- A single source of truth, so the tabs can't disagree.
- Real-time sync and offline support come from Firestore's cache for free. There is no hand-written merge logic.
- Cross-collection rules, like notifications that need both vehicles and logs, have one obvious home.
- For a fleet of tens of vehicles, holding everything in memory is cheap.

**Bad**
- `FleetViewModel.swift` is about 850 lines and mixes Firestore I/O with business rules. That makes the health math hard to unit test without Firebase.
- Every signed-in client downloads the whole fleet. That's fine for one small company, and it assumes the security rules restrict *who* is signed in (see ADR 0002).
- `@MainActor` decoding is fine at this size but won't scale to thousands of logs.

**Follow-up:** extract the pure calculations (`serviceHealth`, `fleetHealth`, `serviceStatus`, `totalSpent`) into a Firebase-free type so they can be covered by XCTest. Tracked in [known issues](../known-issues.md).
