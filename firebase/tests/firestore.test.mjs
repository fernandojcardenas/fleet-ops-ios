import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc, doc, getDoc, getDocs, collection, setDoc, updateDoc,
  arrayUnion, Timestamp,
} from 'firebase/firestore';
import {
  PROJECT_ID, STAFF_UID, OUTSIDER_UID, VEHICLE_ID,
  vehicle, log, trip, template,
} from './helpers.mjs';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

afterAll(async () => { await env?.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'staff', STAFF_UID), { name: 'Demo Staff' });
    await setDoc(doc(db, 'vehicles', VEHICLE_ID), vehicle());
    await setDoc(doc(db, 'logs', 'log-demo-1'), log());
    await setDoc(doc(db, 'trips', 'trip-demo-1'), trip());
    await setDoc(doc(db, 'serviceTemplates', 'tpl-demo-1'), template());
  });
});

const staff = () => env.authenticatedContext(STAFF_UID).firestore();
const outsider = () => env.authenticatedContext(OUTSIDER_UID).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('staff member (listed in /staff)', () => {
  test('reads every fleet collection', async () => {
    for (const c of ['vehicles', 'logs', 'trips', 'serviceTemplates']) {
      await assertSucceeds(getDocs(collection(staff(), c)));
    }
  });

  test('adds a vehicle stamped with their own uid', async () => {
    await assertSucceeds(setDoc(doc(staff(), 'vehicles', 'veh-2'), { ...vehicle(), id: 'veh-2' }));
  });

  test('cannot add a vehicle attributed to someone else', async () => {
    await assertFails(setDoc(doc(staff(), 'vehicles', 'veh-3'), { ...vehicle('someone-else'), id: 'veh-3' }));
  });

  test('cannot rewrite addedBy on an existing vehicle', async () => {
    await assertFails(updateDoc(doc(staff(), 'vehicles', VEHICLE_ID), { addedBy: 'someone-else' }));
  });

  test('updates status and operational status (app updateData calls)', async () => {
    await assertSucceeds(updateDoc(doc(staff(), 'vehicles', VEHICLE_ID), { status: 'In Shop' }));
    await assertSucceeds(updateDoc(doc(staff(), 'vehicles', VEHICLE_ID), { operationalStatus: 'On a trip' }));
    await assertSucceeds(updateDoc(doc(staff(), 'vehicles', VEHICLE_ID), { customServiceIntervals: { 'tpl-demo-1': 7500 } }));
  });

  test('logs service, including a skipped service at zero cost', async () => {
    await assertSucceeds(setDoc(doc(staff(), 'logs', 'log-2'), log({ id: 'log-2' })));
    await assertSucceeds(setDoc(doc(staff(), 'logs', 'log-3'),
      log({ id: 'log-3', cost: 0, notes: 'Service Skipped', isSkipped: true })));
  });

  test('cannot log service for a vehicle that does not exist', async () => {
    await assertFails(setDoc(doc(staff(), 'logs', 'log-4'), log({ id: 'log-4', vehicleID: 'nope' })));
  });

  test('cannot write malformed logs', async () => {
    await assertFails(setDoc(doc(staff(), 'logs', 'log-5'), log({ id: 'log-5', mileage: '42000' })));
    await assertFails(setDoc(doc(staff(), 'logs', 'log-6'), log({ id: 'log-6', cost: -5 })));
  });

  test('starts and ends a trip the way the app does', async () => {
    await assertSucceeds(setDoc(doc(staff(), 'trips', 'trip-2'), trip({ id: 'trip-2' })));
    await assertSucceeds(updateDoc(doc(staff(), 'trips', 'trip-2'), {
      dateEnd: Timestamp.fromDate(new Date('2026-05-02T18:00:00Z')),
      mileageEnd: 42100,
      status: 'Completed',
      isOngoing: false,
    }));
  });

  test('cannot set an unknown trip status', async () => {
    await assertFails(setDoc(doc(staff(), 'trips', 'trip-3'), trip({ id: 'trip-3', status: 'Stolen' })));
  });

  test('manages service templates and assignments', async () => {
    await assertSucceeds(setDoc(doc(staff(), 'serviceTemplates', 'tpl-2'),
      template({ id: 'tpl-2', assignedVehicleIDs: [] })));
    await assertSucceeds(updateDoc(doc(staff(), 'serviceTemplates', 'tpl-2'),
      { assignedVehicleIDs: arrayUnion(VEHICLE_ID) }));
    await assertFails(setDoc(doc(staff(), 'serviceTemplates', 'tpl-3'),
      template({ id: 'tpl-3', mileageInterval: 0 })));
  });

  test('deletes a vehicle and its logs', async () => {
    await assertSucceeds(deleteDoc(doc(staff(), 'logs', 'log-demo-1')));
    await assertSucceeds(deleteDoc(doc(staff(), 'vehicles', VEHICLE_ID)));
  });

  test('cannot grant staff access to anyone, including themselves', async () => {
    await assertFails(setDoc(doc(staff(), 'staff', OUTSIDER_UID), { name: 'Mallory' }));
    await assertFails(deleteDoc(doc(staff(), 'staff', STAFF_UID)));
  });
});

describe('signed-in account that is NOT staff', () => {
  test('cannot read vehicles, lockbox codes included', async () => {
    await assertFails(getDoc(doc(outsider(), 'vehicles', VEHICLE_ID)));
    await assertFails(getDocs(collection(outsider(), 'vehicles')));
  });

  test('cannot read logs, trips or templates', async () => {
    await assertFails(getDocs(collection(outsider(), 'logs')));
    await assertFails(getDocs(collection(outsider(), 'trips')));
    await assertFails(getDocs(collection(outsider(), 'serviceTemplates')));
  });

  test('cannot modify or delete fleet data', async () => {
    await assertFails(updateDoc(doc(outsider(), 'vehicles', VEHICLE_ID), { lockboxCode: '9999' }));
    await assertFails(deleteDoc(doc(outsider(), 'vehicles', VEHICLE_ID)));
    await assertFails(setDoc(doc(outsider(), 'vehicles', 'veh-x'), { ...vehicle(OUTSIDER_UID), id: 'veh-x' }));
  });

  test('cannot add themselves to the staff allowlist', async () => {
    await assertFails(setDoc(doc(outsider(), 'staff', OUTSIDER_UID), { name: 'Mallory' }));
  });

  test('can still manage their own /users record (account deletion)', async () => {
    await assertSucceeds(setDoc(doc(outsider(), 'users', OUTSIDER_UID), { email: 'x@example.com' }));
    await assertSucceeds(deleteDoc(doc(outsider(), 'users', OUTSIDER_UID)));
    await assertFails(getDoc(doc(outsider(), 'users', STAFF_UID)));
  });
});

describe('unauthenticated client', () => {
  test('is denied everything', async () => {
    await assertFails(getDoc(doc(anon(), 'vehicles', VEHICLE_ID)));
    await assertFails(getDoc(doc(anon(), 'staff', STAFF_UID)));
    await assertFails(setDoc(doc(anon(), 'vehicles', 'veh-y'), vehicle()));
  });
});

describe('unknown collections', () => {
  test('are denied even to staff', async () => {
    await assertFails(setDoc(doc(staff(), 'anything', 'x'), { a: 1 }));
  });
});
