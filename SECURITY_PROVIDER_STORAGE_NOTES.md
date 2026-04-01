# Security Provider Storage Notes

## Where Provider Credentials Are Stored
Sensitive provider credentials are stored in iOS Keychain through:
- `CarCareApp/Services/SecureKeychainService.swift`

Provider credential keys:
- `schedule.provider.authToken`
- `schedule.provider.partnerToken`

These are accessed through dedicated helper methods:
- `providerCredential(for:)`
- `setProviderCredential(_:for:)`
- `removeProviderCredential(_:)`
- `removeAllProviderCredentials()`

## What Moved From UserDefaults To Keychain
The following values are treated as secrets and are not persisted in `UserDefaults`:
- bearer token values
- custom header token values
- query token values
- CarScan authorization token values
- CarScan partner token values

All of those flow through:
- `authToken`
- `partnerToken`

and are saved to Keychain by:
- `CarCareApp/Services/ManufacturerScheduleSync.swift`

Legacy copies that may still exist in `UserDefaults` from older builds are migrated into Keychain during `ScheduleProviderSettings.load()` and then removed from `UserDefaults`.

## What Remains In UserDefaults
These values are intentionally non-sensitive and remain in `UserDefaults`:
- provider type
- auth mode
- endpoint template
- auth header name
- auth query key
- recommendation style preference
- backup timing metadata
- style history metadata
- synced schedule cache payloads

## How Credential Clearing Works
`clearStoredCredentials()` in `ScheduleProviderSettings` now removes all secret provider values by deleting both Keychain-backed entries:
- `authToken`
- `partnerToken`

It also removes any leftover legacy `UserDefaults` copies for those keys so older installs do not keep stale secret values around.

This clears credentials used for:
- bearer auth
- custom header auth value
- query token auth value
- CarScan authorization value
- CarScan partner token value

## What Is Not Exported
Provider credentials are not included in:
- `VehicleBackupCodec`
- `VehicleBackupPayload`
- backup JSON files
- provider status text
- clipboard/debug copy actions
- `AppFeedbackCenter`
- `AppErrorCenter`

## User-Facing Provider Status Safety
Provider test results shown in the UI do not include:
- raw endpoint URLs
- auth header names/values
- token presence details
- VIN values
- request headers
- query string secrets

They only return sanitized high-level states such as:
- connected
- auth failed
- invalid response
- connection failed

## Remaining Risks By Design
- Provider sync still sends VIN plus configured auth to the selected provider endpoint.
- Endpoint template remains in `UserDefaults` because it is configuration, not a secret.
- Synced schedule cache remains local app data and is not encrypted separately from normal app storage.

## Recommended Future Improvements
- Move synced schedule cache from `UserDefaults` to protected files.
- Add optional per-provider endpoint allowlisting.
- Add password-protected encrypted backups.
