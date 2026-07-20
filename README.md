# Auto Maintenance Tracker

A standalone mobile app for drivers to track vehicle maintenance — gas fillups
and service records (oil changes, brakes, filters, tires, etc.) — with
maintenance reminders and basic stats. All data is stored locally on the
device; there is no account, login, or backend.

Built with Flutter · Riverpod (iOS & Android). The app lives in
[`client/`](client/).

## Features

- Multiple vehicles, with a vehicle switcher
- Log gas fillups (date, odometer, gallons, price)
- Log service records (type, cost, notes)
- History views for fillups and services
- **Maintenance reminders**: due/overdue per service type, by mileage and/or
  time, with sensible defaults
- **Stats dashboard**: average MPG (computed from consecutive fillups),
  MPG-over-time chart, cost-per-mile, total spend, and a monthly
  fuel-vs-service breakdown

Units are US throughout (miles, gallons, USD).

## Quick start

```bash
cd client
flutter pub get
flutter run
```

The app persists data as a JSON file in the device's documents directory. No
server or network connection is required.

## Status

The Flutter client passes `flutter analyze` and its widget test.

## Not yet included

- Edit (PATCH) UI for existing records — the app currently supports create +
  swipe-to-delete
- Push notifications for reminders (status is computed/shown in-app)
