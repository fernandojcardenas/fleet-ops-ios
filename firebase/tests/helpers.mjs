// Shared fixtures. Payloads mirror what the Swift app writes (see
// FleetViewModel.swift): Int -> integer, Double -> double, Date -> Timestamp.
import { Timestamp } from 'firebase/firestore';

export const PROJECT_ID = 'demo-fleet-ops';
export const STAFF_UID = 'staff-alice';
export const OUTSIDER_UID = 'outsider-mallory';
export const VEHICLE_ID = 'veh-demo-1';

export function vehicle(addedBy = STAFF_UID) {
  return {
    id: VEHICLE_ID,
    make: 'Toyota',
    model: 'Corolla',
    year: 2021,
    vin: 'DEMO0000000000001',
    licensePlate: 'DEMO-001',
    addedBy,
    serviceInterval: 5000,
    status: 'Active',
    owner: 'Demo Owner LLC',
    color: 'Silver',
    lockboxCode: '0000',
    qrCode: '00000000-0000-0000-0000-000000000001',
  };
}

export function log(overrides = {}) {
  return {
    id: 'log-demo-1',
    vehicleID: VEHICLE_ID,
    serviceType: 'Oil Change',
    date: Timestamp.fromDate(new Date('2026-05-01T12:00:00Z')),
    mileage: 42000,
    cost: 59.99,
    notes: 'Synthetic 0W-20',
    isSkipped: false,
    ...overrides,
  };
}

export function trip(overrides = {}) {
  return {
    id: 'trip-demo-1',
    vehicleID: VEHICLE_ID,
    dateStart: Timestamp.fromDate(new Date('2026-05-02T09:00:00Z')),
    mileageStart: 42010,
    status: 'Active',
    isOngoing: true,
    ...overrides,
  };
}

export function template(overrides = {}) {
  return {
    id: 'tpl-demo-1',
    serviceName: 'Oil Change',
    mileageInterval: 5000,
    assignedVehicleIDs: [VEHICLE_ID],
    ...overrides,
  };
}
