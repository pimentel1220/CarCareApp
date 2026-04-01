# CarCareApp Beta Release Checklist

## 1) Xcode/Signing
- Open `/Users/carlos/Documents/New project/CarCareApp/CarCareApp.xcodeproj`.
- Select target `CarCareApp` -> `Signing & Capabilities`.
- Confirm Team is selected.
- Confirm Bundle Identifier is unique and valid.
- Set Deployment Target to your intended minimum iOS version.

## 2) Build Metadata
- In target `General`, increment:
  - `Version` (marketing version), e.g. `1.0`
  - `Build` (internal build), e.g. `1`, then `2`, `3`, etc. for each upload.

## 3) Required QA Smoke Test (Real Device + Simulator)
- Create vehicle manually.
- Decode VIN successfully.
- Test provider connection (success and failure case).
- Sync manufacturer schedule.
- Add service and verify VIN-based reminder interval defaults.
- Add/edit/delete reminders.
- Apply style to reminders and undo.
- Export backup JSON.
- Import backup JSON in merge mode.
- Import backup JSON in replace mode.
- Verify notifications permission + scheduled reminder notification.
- Confirm mileage validation prevents decreasing mileage.

## 4) Archive and Upload
- In Xcode: `Product` -> `Archive`.
- In Organizer: `Distribute App` -> `App Store Connect` -> `Upload`.
- Wait for processing in App Store Connect.

## 5) TestFlight Setup
- Create Internal Testing group.
- Add release notes:
  - VIN decode and schedule sync
  - Provider connection test/status
  - Backup export/import (merge/replace)
  - Reminder style apply/undo
- Add known limitations:
  - Manufacturer schedule depends on provider response quality.

## 6) Beta Validation Pass
- Install from TestFlight on at least 2 physical devices.
- Validate critical flows from section 3.
- Confirm no launch crash after cold start.
- Confirm no data loss after app relaunch.

## 7) Pre-Prod Gate (Ship/No-Ship)
- `Ship` only if:
  - No crash in critical flows.
  - VIN sync + reminders + backup/restore all pass.
  - At least one successful provider sync with production credentials.

