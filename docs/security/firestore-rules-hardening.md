# Hardening the Firestore and Storage rules

**Found:** 2026-09-27, while preparing this repository for publication
**Severity:** High impact, low likelihood at the time of discovery (see below)
**Status:** Fixed rules and tests in this repo. Production deploy follows the runbook at the end.

## What the app stores

Every vehicle document holds a VIN, license plate, owner name, color and **lockbox code**. That's enough to find a car and get its keys. Maintenance logs hold costs and receipt photos. This data belongs to one company, FAJ Management, and should be visible only to its staff.

## What was live

The Firestore rules in production, last published 2026-05-14, were:

```
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

Storage allowed any signed-in user to read or overwrite any file under `receipts/`.

Any account that can sign in can therefore read every lockbox code, change it, or delete the fleet. The repository contained a stricter `firestore.rules`, but it was never deployed. It also had no rule for `trips`, so the Trips tab would have stopped working if it had been.

### Why it hadn't been exploited

Firebase Auth's **Enable create (sign-up)** setting was already off, so the in-app *Sign Up* button fails and nobody outside the company can create an account. At discovery there were two accounts: the owner's, and the demo login provided to Apple App Review.

That is one control, a single checkbox in a console. Rules are the layer that actually holds the data. If sign-up is ever re-enabled, if another sign-in provider is turned on, or if any credential leaks, the old rules would hand over everything.

### Reproduced

`firebase/tests/legacy.test.mjs` loads a verbatim copy of the old rules into the emulator and shows that an account with no staff role can read and rewrite a lockbox code:

```
✓ tests/legacy.test.mjs > legacy live rules (before hardening) > a non-staff account can read the lockbox code
✓ tests/legacy.test.mjs > legacy live rules (before hardening) > a non-staff account can change the lockbox code
```

(From [the first full run](../evidence/rules-tests-2026-09-27.txt).)

## The fix

**Access model: a staff allowlist.** A user may touch fleet data only if a document exists at `/staff/{uid}`. No client can create, change or delete `/staff` documents. The owner manages them in the Firebase console. See [ADR 0002](../adr/0002-staff-allowlist-security-model.md) for why this beats both "any signed-in user" and full per-user scoping for a single-company app.

On top of that:

| Rule | Why |
|---|---|
| Field types validated on every write to vehicles, logs, trips, templates | A buggy or tampered client can't write strings where the app expects numbers, which would crash decoding for everyone |
| `addedBy` must equal the writer on create and can never change | Keeps an honest record of who added each vehicle |
| Logs and trips must reference a vehicle that exists | No orphan records |
| `mileage >= 0`, `cost >= 0`, `mileageInterval > 0`, trip status limited to `Active` / `Completed` | Values the app can never legitimately produce are rejected |
| `/users/{uid}` readable and writable only by that user | Account deletion still cleans up its own record |
| Everything else denied | New collections are closed until someone writes a rule for them |
| Storage: staff only, images only, under 15 MB | Receipts can't be read by outsiders or replaced with HTML or oversized files |

`storage.rules` checks the same `/staff` documents using a cross-service `firestore.exists()` lookup, so there is one allowlist to maintain.

## Evidence

28 tests, run against the Firestore and Storage emulators with payloads shaped exactly like the Swift app's writes (`firebase/tests/`):

- **Staff can do everything the app does:** add and edit vehicles, status changes, per-vehicle intervals, logs including skipped services, start and end trips, templates and assignments, receipt upload, cascade delete.
- **A signed-in non-staff account can do none of it:** it can't read, write, delete, or add itself to `/staff`.
- **Unauthenticated clients and unknown collections are denied.**
- **The two legacy tests above.**

CI runs the suite on every push. Denials in the verbose log name the rule line that refused them, for example `false for 'create' @ L56`.

## Deploy runbook (production)

> **Order matters.** If the rules go live before the `/staff` documents exist, every staff member, the owner included, is locked out of the app until the documents are added.

1. **Collect UIDs.** Firebase console → Authentication → Users. Copy the User UID of each person who should have access.
2. **Create the allowlist.** Firestore → Data → *Start collection* `staff`. For each UID add a document whose **Document ID is the UID**, with one field `name` (string). Decide deliberately whether the App Review demo login belongs here (see the threat model, E-2).
3. **Publish Firestore rules.** Firestore → Rules → paste `firebase/firestore.rules` → *Publish*. Or from `firebase/` run `npx firebase deploy --only firestore:rules --project <project-id>`.
4. **Publish Storage rules.** Storage → Rules → paste `firebase/storage.rules` → *Publish*. On first use of `firestore.exists()` the console asks to let Storage read Firestore. Accept, or every receipt read fails.
5. **Verify in the app** while signed in as staff:
   - fleet loads
   - edit a vehicle
   - add a log with a receipt photo
   - start and end a trip
   - export a PDF
6. **Verify the denial.** Firestore → Rules → *Rules Playground*: simulate `get` on `/vehicles/<any id>` authenticated as a made-up UID. Expect **Denied**.
7. **Rollback if anything breaks.** Both Rules tabs keep a version history, and you can re-publish the previous version with one click. Existing documents that don't match the new validation (for example a year stored as text) would fail on *update* only. Reads are unaffected.
