# Vitamin Tracker — iOS

SwiftUI + SwiftData implementation of the Vitamin Tracker prototype
(see `../project/Vitamin Tracker.html`).

- **Phase 1a**: all core screens wired against mock data.
- **Phase 1b**: onboarding A1–A8 + RootGate.

No camera, no DSLD, no RevenueCat, no HealthKit yet — those slices land
in later phases per the tech spec.

## Xcode setup

1. `File → New → Project → iOS App`
   - Product name: **VitaminTracker**
   - Interface: SwiftUI
   - Bundle identifier: **app.vitamintracker**
   - Deployment target: iOS 17.0
2. Delete the auto-generated `ContentView.swift` and `VitaminTrackerApp.swift`.
3. Drag every folder under this directory into the project navigator
   (choose "Create groups", not "Create folder references"), except this
   README.
4. Add Google Fonts:
   - Download [Instrument Serif](https://fonts.google.com/specimen/Instrument+Serif)
     and [Inter](https://fonts.google.com/specimen/Inter).
   - Drag the `.ttf` files into `Resources/Fonts/`.
   - In the target's Info tab, add **Fonts provided by application**
     (`UIAppFonts`) with entries:
     - `InstrumentSerif-Regular.ttf`
     - `InstrumentSerif-Italic.ttf`
     - `Inter-Regular.ttf`
     - `Inter-Medium.ttf`
     - `Inter-SemiBold.ttf`
     - `Inter-Bold.ttf`
5. Capabilities: add **App Groups** with identifier
   `group.app.vitamintracker` (needed for the widget extension in a later
   phase; harmless now).
6. Build and run. Launches into the Today tab with seeded mock data.

## Structure

```
App/                  app entry + ModelContainer
Design/               colors, typography, reusable components
Models/               @Model SwiftData types + enums
Mock/                 seeded fixtures for previews and first launch
Features/
  Root/               TabView
  Today/              Today screen (3 variants)
  Stack/              grid + empty state
  Detail/             supplement detail
  Insights/           locked + unlocked
  Paywall/            subscription
  Profile/            settings
  Modals/             Add / Streak / Search sheets
Resources/            nutrients.json
```

## What's working

- First launch: onboarding A1–A8 (auto-advancing splash, welcome hero,
  permissions preview, camera mock, parsing animation, confirm list,
  schedule grouping, all-set screen). On A8 the flow inserts the mock
  profile + seeded stack and transitions to the Today tab.
- Subsequent launches go straight to the TabView
  (Today · Stack · Insights · Profile).
- Today: three variants (morning / midday / evening) driven by mock
  `IntakeLog` state; tap check to mark taken; add custom time slot.
- Stack: grid with Active / Paused / All segments; empty state.
- Detail: hero + schedule + ingredients + cost + adherence + notes.
- Insights: locked sheet over blurred content; unlocked variant.
- Paywall: yearly / monthly plan cards.
- Profile: header + streak + subscription + integrations + app rows.
- Sheets: Add supplement, Streak heatmap, Search.

Each onboarding screen also ships a `#Preview` so you can QA them in
isolation in the Xcode canvas.

## What's stubbed

- Camera / Vision parsing: A4 shows the capture chrome but there's no
  `AVCaptureSession` or `LabelParser` yet.
- Permissions: A3 is informational only — real `AVCaptureDevice`,
  `UNUserNotificationCenter`, and `HKHealthStore` requests land with the
  feature that needs them.
- DSLD / Claude API: `SupplementCatalog` model exists, no network layer.
- RevenueCat: paywall is visual only — no SDK calls.
- HealthKit write on intake: no-op.
- Widgets / Watch: not in this slice.
- Notifications: `Schedule.notificationIds` stored but not scheduled.

## Replaying onboarding

On device, delete the app and reinstall (SwiftData store lives in the
App Group container). In Xcode canvas, use
`#Preview("Fresh install")` on `RootGate`.
