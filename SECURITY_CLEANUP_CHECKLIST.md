# Security Cleanup Checklist

## Scope
Audit completed for the SwiftUI iOS project at `CarCareApp` with focus on:
- secrets and provider credentials
- auth/config storage
- backup/export/import privacy
- notification/VIN/provider sync privacy
- debug/admin surface area
- repository hygiene and tracked metadata

## Overall Status
- High-priority secret storage issues were fixed.
- No hardcoded production API keys or live tokens were found in tracked source.
- The biggest remaining risks are privacy-oriented rather than “credential leaked in git” issues.

## Issues Found

### 1. Provider credentials were stored in `UserDefaults`
- Severity: High
- File: `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/ManufacturerScheduleSync.swift:71`
- Risk: `UserDefaults` is not appropriate for bearer tokens, partner tokens, or provider auth credentials. Values can be recovered from device backups and are easier to inspect during local debugging.
- Fix applied:
  - Moved `authToken` and `partnerToken` to Keychain.
  - Added migration to pull any legacy values out of `UserDefaults` and remove them.
  - Added `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/KeychainService.swift`.
- Follow-up:
  - Add a user-facing “Clear Stored Provider Credentials” action in Advanced settings.

### 2. Raw VIN was embedded in sync cache keys
- Severity: High
- File: `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/ManufacturerScheduleSync.swift:500`
- Risk: Even if cached payloads are local-only, using raw VINs in storage keys leaks sensitive vehicle identifiers into app preferences metadata.
- Fix applied:
  - Cache keys now use a SHA-256 hash fragment instead of the raw VIN.

### 3. Advanced provider debug details were too easy to expose
- Severity: Medium
- Files:
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:120`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:362`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:971`
- Risk: Copying connection diagnostics to the clipboard can leak provider setup details through paste history, screenshots, or support sharing.
- Fix applied:
  - Debug copy action is now hidden behind `#if DEBUG`.
  - Endpoint preview is redacted.
  - VIN is no longer represented as a length-based debug field; only `VIN Present` is shown.
- Later improvement:
  - Consider a dedicated developer mode toggle for all provider test/debug actions.

### 4. Backup export filenames exposed vehicle names
- Severity: Medium
- File: `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:616`
- Risk: Backup files are frequently shared or stored outside the app sandbox. Including vehicle nicknames or identifying names in filenames leaks metadata immediately.
- Fix applied:
  - Export filename changed to generic timestamped format: `carcare-backup-YYYY-MM-DD-HHmm.json`.

### 5. Backup export is readable JSON containing sensitive owner/vehicle data
- Severity: Medium
- Files:
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:981`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:1060`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:1172`
- Risk: Exported backups contain VIN, plate, notes, maintenance history, reminders, part history, and optional photos/receipts in plaintext JSON.
- Current state:
  - Warning text now tells the user that backups are readable JSON and may include sensitive data.
- Recommended fix:
  - Add optional encrypted backup export/import, ideally password-protected.
  - At minimum, allow “exclude photos/receipts from export”.

### 6. Backup import replace mode is intentionally destructive
- Severity: Medium
- Files:
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:723`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:1084`
- Risk: Replace mode deletes logs, reminders, and parts for the selected vehicle before import. The current confirmation UX is good, but there is no rollback if the imported file is wrong.
- Current state:
  - There is a visible replace warning and item counts before import.
- Recommended fix:
  - Create a temporary pre-import snapshot for one-tap undo.
  - Validate payload version and expected schema more strictly before destructive replace.

### 7. UserDefaults still stores non-secret but privacy-relevant metadata
- Severity: Medium
- Files:
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:571`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:626`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:638`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:811`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/ManufacturerScheduleSync.swift:183`
- Risk: Undo snapshots, backup timing metadata, and synced schedule cache are not secrets, but they are still user data and can reveal usage patterns and vehicle-related content.
- Recommended fix:
  - Leave low-risk preferences in `UserDefaults`.
  - For larger synced provider payloads, move storage to an app-support file with file protection.
  - Consider retention limits for undo snapshots and sync cache.

### 8. VIN decoding uses a public third-party government API
- Severity: Low
- File: `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/VINDecoder.swift:35`
- Risk: VINs are sent over the network to NHTSA vPIC. This is expected behavior, but still a privacy event.
- Recommended fix:
  - Add a short in-app disclosure near VIN decode explaining that VIN lookup sends the VIN to an external service.
  - Update privacy policy/app store disclosures accordingly.

### 9. Provider sync sends VINs and auth headers to user-configured endpoints
- Severity: Medium
- Files:
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/ManufacturerScheduleSync.swift:267`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:924`
- Risk: The app can send VINs plus authentication headers to arbitrary user-entered URLs. This is a feature, but it expands the threat surface if misconfigured.
- Recommended fix:
  - Validate scheme is `https` before allowing sync.
  - Consider warning when endpoint host is unknown or non-HTTPS.
  - Consider domain allowlisting if you move toward a managed consumer product.
- Current state:
  - Custom provider sync/testing now rejects non-HTTPS endpoints.

### 10. Repository hygiene had gaps for Xcode/macOS clutter
- Severity: Low
- Files:
  - `/Users/carlos/Documents/New project/CarCareApp/.gitignore`
  - `/Users/carlos/Documents/New project/CarCareApp/BETA_RELEASE_CHECKLIST.md:4`
- Risk: Xcode user state, archives, macOS clutter, and machine-local paths can accidentally end up tracked.
- Fix applied:
  - Expanded `.gitignore` to cover common Xcode/macOS/generated artifacts.
  - Removed local absolute path from release checklist.
- Verified:
  - No tracked `/Users/...` or local username strings remain in normal source files after cleanup.

## Secrets Scan Result
- No hardcoded production API keys found.
- No committed bearer tokens or partner tokens found.
- No VIN provider credentials found in tracked source.
- Public endpoint references found but these are configuration/examples, not secrets:
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/VINDecoder.swift:35`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Services/ManufacturerScheduleSync.swift:98`
  - `/Users/carlos/Documents/New project/CarCareApp/CarCareApp/Views/VehicleInfoView.swift:957`

## UserDefaults Review

### Appropriate to keep in `UserDefaults`
- recommendation style
- auto-backup mode and threshold
- non-sensitive UI timestamps like “last backup exported”
- non-secret provider mode/header-name/query-key preferences

### Should not live in `UserDefaults`
- provider auth token
- partner token
- any future API secret, refresh token, or account credential

### Moved to Keychain
- `schedule.provider.authToken`
- `schedule.provider.partnerToken`

## Advanced / Debug Surface Review
The biggest surface-area concern is still the Advanced toolset in the vehicle flow. It is much better now that it sits behind the Advanced screen, but from a product-security angle it still exposes:
- provider endpoint configuration
- provider auth entry
- provider test tooling
- manufacturer sync controls
- import/export tooling

Recommended product refactor:
- keep this hidden behind Advanced, which is already much better than the old Info-tab overload
- later, move provider testing and backup repair tooling into an explicit Settings/Advanced area outside the main ownership loop

## Quick Wins
- Done: move provider credentials to Keychain.
- Done: stop using raw VINs in storage keys.
- Done: redact and hide debug-copy tooling in release builds.
- Done: use generic backup filenames.
- Done: expand `.gitignore`.
- Done: add `https`-only validation for custom provider endpoints.
- Done: add “Clear Stored Provider Credentials”.

## Later Improvements
- Add encrypted backup export/import.
- Add “exclude receipt photos / vehicle photos from export” option.
- Move synced provider cache out of `UserDefaults` into a file with data protection.
- Add explicit privacy disclosure before VIN decode and provider sync.
- Add rollback support for destructive replace-import.
- Add retention/expiration for undo snapshots and sync cache.

## Build Verification
- Audit fixes compiled successfully with:
  - `xcodebuild -project '/Users/carlos/Documents/New project/CarCareApp/CarCareApp.xcodeproj' -scheme CarCareApp -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath '/Users/carlos/Documents/New project/.DerivedData' CODE_SIGNING_ALLOWED=NO build`
- Result: `BUILD SUCCEEDED`
