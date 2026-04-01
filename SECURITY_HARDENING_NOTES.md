# Security Hardening Notes

## What Changed
- Moved provider auth secrets out of `UserDefaults` and into Keychain-backed storage.
- Added a reusable `SecureKeychainService` and kept compatibility with the existing `KeychainService` name.
- Removed clipboard-based provider debug export from the user flow.
- Enforced `https` for custom provider sync/test endpoints.
- Simplified `VehicleInfoView` so normal users see only vehicle info, mileage, notes, VIN decode, and safe backup actions.
- Kept provider setup, destructive import mode, auto-backup behavior, style tools, and manufacturer sync in a separate Developer Settings screen.
- Reduced backup privacy exposure by excluding provider settings, notification IDs, and other internal reminder metadata from exported JSON.
- Added backup validation, size limits, safer error handling, and rollback on failed import.
- Added photo sanitization/compression for exported backup images to reduce oversized plaintext exports.

## Sensitive Storage Moved To Keychain
- `schedule.provider.authToken`
- `schedule.provider.partnerToken`

## What Stayed In UserDefaults
These values remain in `UserDefaults` because they are app preferences or low-risk local metadata rather than secrets:
- provider type / auth mode / endpoint template / header name / query key
- recommendation style preference
- style-apply undo snapshot metadata
- last style-apply timestamp
- backup last-export timestamp
- backup record-count snapshot
- auto-backup mode and threshold
- manufacturer schedule cache payloads

## What Moved To Developer Settings
The following features no longer sit on the normal Info screen surface:
- manufacturer schedule sync controls
- provider endpoint/auth configuration
- provider connection testing
- style apply / undo / history tools
- replace-existing import mode
- auto-backup behavior controls

## What VehicleInfoView Now Focuses On
- overview
- vehicle details
- notes
- mileage update
- edit vehicle
- VIN decode
- normal backup export/import

## Backup Privacy Notes
Backups still include ownership data by design, including:
- VIN
- plate
- mileage
- maintenance history
- reminders
- parts
- notes
- optional vehicle and receipt photos

Backups do **not** include:
- provider tokens
- provider auth headers/values
- provider endpoint credentials
- debug/provider connection state
- notification IDs

## Remaining Privacy Exposure By Design
- VIN decode sends the VIN to an external vehicle lookup service.
- Provider sync sends VIN plus configured auth to the selected provider endpoint.
- Backups are still readable JSON files, even though they are smaller and cleaner now.
- Some non-secret local usage metadata still lives in `UserDefaults`.

## Future Recommended Improvements
- Add password-protected encrypted backup export/import.
- Move synced schedule cache from `UserDefaults` to protected files on disk.
- Add an option to export without photos/receipts.
- Add a pre-import temporary restore point for destructive replace mode.
- Add a short in-app privacy notice before VIN decode and provider sync.
- Consider moving Developer Settings to a global app settings area instead of per-vehicle navigation.
