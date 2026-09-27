// Seeds the LOCAL Firebase emulators with fictional demo data for
// screenshots and manual testing. Refuses to run against anything else.
//
//   npm run emulators        # terminal 1
//   npm run seed             # terminal 2
//
// Demo sign-in: demo@fleetops.test / demo-password-123 (emulator only).
// Every name, VIN, plate and code below is invented.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

const PROJECT_ID = 'demo-fleet-ops';
for (const v of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[v])) {
    throw new Error(`${v} must point at a local emulator, got "${process.env[v]}"`);
  }
}

initializeApp({ projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

const DEMO_EMAIL = 'demo@fleetops.test';
const DEMO_PASSWORD = 'demo-password-123';

async function demoUser() {
  try {
    return await auth.getUserByEmail(DEMO_EMAIL);
  } catch {
    return auth.createUser({ email: DEMO_EMAIL, password: DEMO_PASSWORD, displayName: 'Demo Manager' });
  }
}

const daysAgo = (n) => Timestamp.fromDate(new Date(Date.now() - n * 86_400_000));

const vehicles = [
  { id: 'demo-veh-01', make: 'Toyota', model: 'Camry', year: 2022, color: 'White', plate: 'DMO-1001', owner: 'Harbor Demo LLC', odo: 38_400, status: 'Active', op: 'Available' },
  { id: 'demo-veh-02', make: 'Honda', model: 'CR-V', year: 2021, color: 'Blue', plate: 'DMO-1002', owner: 'Harbor Demo LLC', odo: 51_900, status: 'Active', op: 'On a trip' },
  { id: 'demo-veh-03', make: 'Ford', model: 'Transit Connect', year: 2020, color: 'Gray', plate: 'DMO-1003', owner: 'Example Partner Co', odo: 74_250, status: 'In Shop', op: 'Available' },
  { id: 'demo-veh-04', make: 'Hyundai', model: 'Elantra', year: 2023, color: 'Red', plate: 'DMO-1004', owner: 'Harbor Demo LLC', odo: 21_080, status: 'Active', op: 'Available' },
  { id: 'demo-veh-05', make: 'Tesla', model: 'Model 3', year: 2022, color: 'Black', plate: 'DMO-1005', owner: 'Example Partner Co', odo: 44_700, status: 'Recall', op: 'Available' },
  { id: 'demo-veh-06', make: 'Nissan', model: 'Rogue', year: 2019, color: 'Silver', plate: 'DMO-1006', owner: 'Harbor Demo LLC', odo: 96_300, status: 'Out of Service', op: 'Available' },
];

const templates = [
  { id: 'demo-tpl-oil', serviceName: 'Oil Change', mileageInterval: 5000 },
  { id: 'demo-tpl-tires', serviceName: 'Tire Rotation', mileageInterval: 7500 },
  { id: 'demo-tpl-brakes', serviceName: 'Brake Inspection', mileageInterval: 15000 },
];

async function main() {
  const user = await demoUser();
  const batch = db.batch();

  batch.set(db.doc(`staff/${user.uid}`), { name: 'Demo Manager', addedAt: daysAgo(90) });

  vehicles.forEach((v, i) => {
    batch.set(db.doc(`vehicles/${v.id}`), {
      id: v.id, make: v.make, model: v.model, year: v.year,
      vin: `DEMO${String(i + 1).padStart(13, '0')}`,
      licensePlate: v.plate, addedBy: user.uid, serviceInterval: 5000,
      status: v.status, owner: v.owner, color: v.color,
      lockboxCode: String(1000 + i * 111), qrCode: `00000000-0000-4000-8000-${String(i + 1).padStart(12, '0')}`,
      operationalStatus: v.op,
    });
  });

  templates.forEach((t) => {
    batch.set(db.doc(`serviceTemplates/${t.id}`), { ...t, assignedVehicleIDs: vehicles.map((v) => v.id) });
  });

  // Service history: oil changes at staggered mileages so badges show a mix
  // of OK, due soon and overdue.
  const lastOilOffset = [1200, 4700, 6100, 300, 3900, 9000];
  vehicles.forEach((v, i) => {
    const logs = [
      { svc: 'Oil Change', miles: v.odo - lastOilOffset[i], cost: 64.99, days: 20 + i * 9, notes: 'Full synthetic' },
      { svc: 'Tire Rotation', miles: v.odo - lastOilOffset[i] - 2500, cost: 29.0, days: 60 + i * 7, notes: '' },
      { svc: 'Brake Inspection', miles: v.odo - 11_000, cost: 0, days: 140, notes: 'Pads at 60%' },
    ];
    logs.forEach((l, j) => {
      const id = `demo-log-${i + 1}-${j + 1}`;
      batch.set(db.doc(`logs/${id}`), {
        id, vehicleID: v.id, serviceType: l.svc, date: daysAgo(l.days),
        mileage: l.miles, cost: l.cost, notes: l.notes, isSkipped: false,
      });
    });
    // Latest odometer reading so mileage-based status reflects v.odo.
    batch.set(db.doc(`logs/demo-log-${i + 1}-odo`), {
      id: `demo-log-${i + 1}-odo`, vehicleID: v.id, serviceType: 'Inspection',
      date: daysAgo(2 + i), mileage: v.odo, cost: 0, notes: 'Odometer check', isSkipped: false,
    });
  });

  // One trip in progress (vehicle 2) and a few completed trips.
  batch.set(db.doc('trips/demo-trip-active'), {
    id: 'demo-trip-active', vehicleID: 'demo-veh-02', dateStart: daysAgo(1),
    mileageStart: 51_900, status: 'Active', isOngoing: true, notes: 'Weekend rental',
  });
  [['demo-veh-01', 8, 37_950, 38_400], ['demo-veh-04', 5, 20_700, 21_080], ['demo-veh-05', 12, 44_100, 44_700]]
    .forEach(([vid, d, start, end], k) => {
      const id = `demo-trip-done-${k + 1}`;
      batch.set(db.doc(`trips/${id}`), {
        id, vehicleID: vid, dateStart: daysAgo(d), dateEnd: daysAgo(d - 3),
        mileageStart: start, mileageEnd: end, status: 'Completed', isOngoing: false,
      });
    });

  await batch.commit();
  console.log(`Seeded ${vehicles.length} vehicles, ${templates.length} templates, ` +
    `${vehicles.length * 4} logs, 4 trips for ${DEMO_EMAIL} (uid ${user.uid}).`);
}

main().catch((err) => { console.error(err); process.exit(1); });
