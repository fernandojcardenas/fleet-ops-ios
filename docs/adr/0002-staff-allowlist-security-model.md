# ADR 0002: Staff allowlist as the access model

- **Status:** Accepted 2026-09-27. Rules and tests are in this repo; production deploy follows the runbook.

## Context

The app serves one company, FAJ Management. Every staff member should see the whole fleet, because anyone may service or drive any car. The data includes lockbox codes, so outsiders must see nothing.

The production rules granted access to any signed-in user, and disabling self sign-up was the only barrier (see [the write-up](../security/firestore-rules-hardening.md)).

Options considered:

1. **Keep "any signed-in user", rely on sign-up being off.** No code change, but one console checkbox guards everything, and any future auth provider or leaked credential exposes all data.
2. **Per-user ownership** (`resource.data.addedBy == request.auth.uid`). This is wrong for this business: staff need each other's vehicles and logs, and the app loads whole collections.
3. **Multi-tenant**, with a `companyId` on every document. It's correct if the app is ever sold to other fleets, but it needs a data migration and a new App Store build for a need that doesn't exist today.
4. **Staff allowlist**: access requires a document at `/staff/{uid}`, which only the owner can create.
5. **Custom claims** (`request.auth.token.staff == true`). This is equivalent to option 4, but setting claims needs the Admin SDK or a Cloud Function. There's no backend today, and the Firebase console can't set claims.

## Decision

Option 4. Every fleet collection and the `receipts/` bucket require `exists(/staff/{uid})`, and no client can write `/staff`. Storage checks the same documents through a cross-service lookup, so there is one list to maintain.

## Consequences

- It works with the current App Store build. No app update or data migration is needed.
- Staff are onboarded in two steps in the console: create the Auth user, then create the `staff` document. Offboarding is deleting either one.
- Each rules evaluation costs one extra document read (`exists`). That's negligible at this size.
- It doesn't separate roles. Every staff member can read lockbox codes and delete vehicles (threat model I-2). A `role` field on the staff document can add that later without changing the model.
- If the product is ever offered to other companies, option 3 replaces this.
