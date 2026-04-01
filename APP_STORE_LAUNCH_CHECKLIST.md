# App Store Launch Checklist

## Product Surface
- Confirm `VehicleInfoView` stays user-focused:
  - overview
  - vehicle details
  - notes
  - mileage update
  - VIN decode
  - normal backup export/import
- Confirm advanced provider and sync tools are only reachable through Developer Settings.
- Confirm destructive import options are not shown in the main ownership flow.

## Security & Privacy
- Verify provider auth tokens are stored in Keychain, not `UserDefaults`.
- Verify provider debug copy/clipboard actions are not present in release UX.
- Verify provider endpoints require `https`.
- Verify exported backups do not include provider credentials or debug/provider state.
- Verify reminder `notificationID` is not exported in backup payloads.
- Verify backup import rejects oversized or corrupt payloads.
- Verify photo export compression works and backup size stays reasonable.
- Verify VIN decode disclosure text is visible to the user.

## Core Flows
- Add a vehicle manually.
- Edit a vehicle after creation.
- Decode VIN and verify make/model/year population.
- Update mileage and verify lower values are blocked.
- Add a service log.
- Add a part replacement.
- Create and complete a reminder.
- Open Vehicle Detail and verify overview usefulness.

## Backup & Restore
- Export a backup for a populated vehicle.
- Import backup in merge mode.
- Import backup in replace mode from Developer Settings.
- Verify service logs, reminders, parts, VIN, plate, and notes restore correctly.
- Verify provider credentials are not changed by import.

## Notifications
- Grant notification permission.
- Create a reminder with a due date.
- Verify a notification is scheduled.
- Import a backup and verify active reminders are rescheduled.

## Release Readiness
- Run a clean build in Xcode.
- Test on simulator.
- Test on at least one physical iPhone.
- Review privacy disclosures in App Store Connect.
- Review screenshots and metadata before submission.
