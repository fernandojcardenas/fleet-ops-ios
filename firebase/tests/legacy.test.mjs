// Demonstrates why the rules were hardened: under the rules that were live
// until 2026-09, ANY signed-in account (not staff) could read lockbox codes
// and rewrite fleet data. These tests are expected to PASS, because they
// assert the old weakness exists in the old file.
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import { assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { OUTSIDER_UID, VEHICLE_ID, vehicle } from './helpers.mjs';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fleet-ops-legacy',
    firestore: {
      rules: readFileSync(new URL('./fixtures/legacy-live.firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

afterAll(async () => { await env?.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'vehicles', VEHICLE_ID), vehicle());
  });
});

describe('legacy live rules (before hardening)', () => {
  test('a non-staff account can read the lockbox code', async () => {
    const db = env.authenticatedContext(OUTSIDER_UID).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, 'vehicles', VEHICLE_ID)));
    expect(snap.data().lockboxCode).toBe('0000');
  });

  test('a non-staff account can change the lockbox code', async () => {
    const db = env.authenticatedContext(OUTSIDER_UID).firestore();
    await assertSucceeds(updateDoc(doc(db, 'vehicles', VEHICLE_ID), { lockboxCode: '9999' }));
  });
});
