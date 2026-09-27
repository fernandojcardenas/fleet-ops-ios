import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';
import { PROJECT_ID, STAFF_UID, OUTSIDER_UID } from './helpers.mjs';

// storage.rules reads /staff from Firestore, so both emulators are needed.
let env;
const BUCKET = `${PROJECT_ID}.appspot.com`;
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46]);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
});

afterAll(async () => { await env?.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'staff', STAFF_UID), { name: 'Demo Staff' });
    await uploadBytes(ref(ctx.storage(BUCKET), 'receipts/existing.jpg'), jpeg, { contentType: 'image/jpeg' });
  });
});

const storageAs = (uid) => env.authenticatedContext(uid).storage(BUCKET);

describe('receipts', () => {
  test('staff can upload a JPEG receipt, as the app does', async () => {
    await assertSucceeds(uploadBytes(ref(storageAs(STAFF_UID), 'receipts/new.jpg'), jpeg, { contentType: 'image/jpeg' }));
  });

  test('staff can read and delete receipts', async () => {
    await assertSucceeds(getBytes(ref(storageAs(STAFF_UID), 'receipts/existing.jpg')));
    await assertSucceeds(deleteObject(ref(storageAs(STAFF_UID), 'receipts/existing.jpg')));
  });

  test('staff cannot upload non-images', async () => {
    await assertFails(uploadBytes(ref(storageAs(STAFF_UID), 'receipts/x.html'),
      new TextEncoder().encode('<script>'), { contentType: 'text/html' }));
  });

  test('staff cannot write outside receipts/', async () => {
    await assertFails(uploadBytes(ref(storageAs(STAFF_UID), 'other/new.jpg'), jpeg, { contentType: 'image/jpeg' }));
  });

  test('a signed-in non-staff account cannot read, upload or delete', async () => {
    await assertFails(getBytes(ref(storageAs(OUTSIDER_UID), 'receipts/existing.jpg')));
    await assertFails(uploadBytes(ref(storageAs(OUTSIDER_UID), 'receipts/evil.jpg'), jpeg, { contentType: 'image/jpeg' }));
    await assertFails(deleteObject(ref(storageAs(OUTSIDER_UID), 'receipts/existing.jpg')));
  });

  test('an unauthenticated client cannot read', async () => {
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(BUCKET), 'receipts/existing.jpg')));
  });
});
