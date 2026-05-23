# Fleet Maintenance Tracker

A SwiftUI iOS app for tracking vehicle maintenance across a fleet. Built with a Firebase backend (Auth + Firestore + Storage) and modern Swift concurrency.

## Features

### Authentication & Onboarding
- Email/password sign-in with Firebase Auth
- Onboarding flow capturing company profile (name, logo, contact info)
- Account deletion with re-authentication handling

### Vehicle Management
- Add, edit, and remove vehicles with photos, VIN, license plate, year/make/model
- Vehicle ownership fields (owner name, registration details)
- Persistent QR tokens per vehicle for fast lookup
- Vehicle check-in workflow

### Maintenance Logs
- Add, edit, and delete maintenance log entries with date, mileage, cost, and notes
- Attach and view receipts (image picker + in-app viewer)
- Logs cascade-delete when their parent vehicle is removed
- Export full vehicle history as a PDF report

### Service Templates
- Define reusable service templates (e.g., oil change, tire rotation) with mileage/time intervals
- Operational status badges show when a service is due, overdue, or up to date
- Template detail view with associated log history

### Trips
- Dedicated Trips tab
- Start/end trip flow capturing odometer and notes
- Manual trip entry form
- Edit existing trips

### Analytics
- Analytics tab summarizing fleet activity, costs, and service status

### QR Code Workflow
- Generate per-vehicle QR codes
- In-app QR scanner that routes scanned codes to the correct action (check-in, log, view)

### Notifications
- Local notifications for upcoming and overdue services via `NotificationManager`

### Home & Navigation
- Customizable, reorderable home screen
- Tab-based navigation: Home, Maintenance, Trips, Analytics, Settings

## Architecture

- **UI**: SwiftUI views, one file per screen
- **State**: `@State`, `@StateObject`, and a central `FleetViewModel` as the source of truth
- **Concurrency**: Swift `async/await` (no Combine)
- **Backend**: Firebase (Auth, Firestore, Storage) with `firestore.rules` for access control
- **Auth flow**: `AuthManager` + `RootView` gate between `LoginView`, `OnboardingView`, and `MainTabView`

## Project Structure

```
Fleet Maintenance Tracker/
├── Fleet_Maintenance_TrackerApp.swift   # App entry, Firebase init
├── RootView.swift / MainTabView.swift    # Top-level routing
├── AuthManager.swift / LoginView.swift   # Authentication
├── FleetViewModel.swift                  # Central state
├── Vehicle.swift / MaintenanceLog.swift  # Data models
├── ServiceTemplate.swift / Trip.swift
├── CompanyProfile.swift
├── HomeView.swift / SettingsView.swift
├── MaintenanceTabView.swift / TripsTabView.swift
├── AnalyticsTabView.swift
├── QRGenerator.swift / QRScannerView.swift
├── NotificationManager.swift
└── VehicleHistoryPDF.swift
```

## Requirements

- Xcode 15+
- iOS 17+
- A Firebase project with `GoogleService-Info.plist` placed in the app target

## Setup

1. Clone the repo
2. Drop your `GoogleService-Info.plist` into `Fleet Maintenance Tracker/`
3. Open `Fleet Maintenance Tracker.xcodeproj` in Xcode
4. Build and run on a device or simulator

## Tech Stack

SwiftUI · Swift Concurrency · Firebase Auth · Firestore · Firebase Storage · UserNotifications · PDFKit · AVFoundation (QR scanning)
