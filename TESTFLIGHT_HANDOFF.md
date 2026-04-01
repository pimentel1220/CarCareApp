# TestFlight Handoff

## Before Uploading The Build
- Confirm the app display name shows as `CarCare Maintenance`.
- Confirm the version and build number are correct in Xcode.
- Confirm release branding matches the current App Store metadata draft.
- Run one clean archive build.
- Review the latest launch docs for consistency before upload.

## After Uploading The Build
- Confirm the build appears in App Store Connect.
- Confirm TestFlight processing completes without warnings that need action.
- Confirm the build uses the expected version and build number.
- Confirm tester notes match the current feature set and branding.

## What To Test On A Physical iPhone
- Clean install and first launch
- Add first vehicle
- VIN lookup
- Mileage update
- Add service and receipt photo flow
- Add reminder and confirm reminder urgency
- Add part and linked service flow
- Backup save and restore
- Replace-mode restore using test data only
- Edit and delete flows
- Notification permission and reminder scheduling
- Background, relaunch, and stability checks

## Screenshots And Metadata Still Needed
- Final portrait iPhone screenshots listed in `APP_STORE_SCREENSHOT_PLAN.md`
- Final App Store title, subtitle, and description from `APP_STORE_METADATA_DRAFT.md`
- Final privacy policy URL
- Final support URL
- Final marketing URL
- Final version 1.0 release notes text

## Go / No-Go Checklist For TestFlight
- App launches cleanly on a physical iPhone
- No broken first-use flow
- No obvious technical wording in the normal user experience
- Overview tab still feels like the main payoff screen
- Reminder urgency is easy to notice
- Backups feel understandable and trustworthy
- Advanced Settings stays separate from the normal ownership flow
- No blocking crashes, dead-end screens, or broken save flows found in device QA

## Recommended Handoff Order
1. Run `DEVICE_QA_CHECKLIST.md` on a physical iPhone.
2. Capture screenshots using `APP_STORE_SCREENSHOT_PLAN.md`.
3. Finalize metadata using `APP_STORE_METADATA_DRAFT.md`.
4. Archive and upload the build.
5. Do one quick TestFlight smoke pass before inviting wider testers.
