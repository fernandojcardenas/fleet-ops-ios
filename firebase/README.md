# firebase/

Security rules, rules tests and demo seed data for Fleet Ops. Everything here runs against the **local Firebase Emulator Suite**. Nothing in this folder talks to the production project.

| File | Purpose |
|---|---|
| `firestore.rules` | Firestore access control: staff allowlist + field validation |
| `storage.rules` | Receipt photo access, same allowlist via a cross-service lookup |
| `tests/` | 28 rules tests (Vitest + `@firebase/rules-unit-testing`) |
| `tests/fixtures/legacy-live.firestore.rules` | Copy of the rules that were live before hardening. Test fixture only, never deploy |
| `seed/seed.mjs` | Fills the emulators with fictional vehicles, logs and trips |

## Requirements

Node 22+, Java 21+ (the emulators are Java), then:

```sh
cd firebase
npm ci
```

## Run the rules tests

```sh
npm test
```

This starts the Firestore and Storage emulators, runs every suite, and shuts them down. CI runs the same command on every push.

## Run the app against demo data

1. Start the emulators (terminal 1):
   ```sh
   npm run emulators
   ```
2. Seed demo data (terminal 2):
   ```sh
   npm run seed
   ```
   Sign in with `demo@fleetops.test` / `demo-password-123`. That account exists only in the local Auth emulator.
3. In Xcode: **Product → Scheme → Edit Scheme → Run → Arguments**, add `-useFirebaseEmulators`, then run a **Debug** build on a simulator.

In that mode the app configures a placeholder `demo-fleet-ops` project in code and points Auth, Firestore and Storage at `127.0.0.1`. The production `GoogleService-Info.plist` is never read, and Release builds compile the emulator path out. The Emulator UI at http://127.0.0.1:4000 shows the data live.

## Deploying rules to production

Deploy order matters: the allowlist documents must exist **before** the new rules go live, or every staff member is locked out. Follow `docs/security/firestore-rules-hardening.md`.
