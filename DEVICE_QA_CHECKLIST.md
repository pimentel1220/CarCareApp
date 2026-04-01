# Device QA Checklist

## Test Setup
- Test a clean install on a physical iPhone.
- Test at least one follow-up session after relaunch.
- Keep notifications enabled for the reminder checks.
- Use one realistic demo vehicle with VIN, mileage, service data, parts, reminders, and a receipt photo.

## Clean Install
- Delete any previous build from the device.
- Install the current build fresh from Xcode or TestFlight.
- Confirm the app opens without stale data.
- Confirm Garage starts in the correct first-use empty state.

## First Launch
- Verify the empty garage message is clear and reassuring.
- Verify the main action is obviously to add a vehicle.
- Confirm there is no technical or developer-facing wording in the normal flow.

## Add First Vehicle
- Add a vehicle with only the minimum fields.
- Save successfully.
- Reopen and edit the same vehicle.
- Confirm the app still feels clear even if optional details are skipped.

## VIN Decode
- Add a valid VIN.
- Run VIN lookup.
- Confirm year, make, model, trim, and engine populate when available.
- Confirm VIN errors are understandable if the VIN is invalid or lookup fails.

## Mileage Update
- Update mileage from the Info tab.
- Confirm lower mileage is blocked.
- Confirm the success message feels clear and reassuring.

## Vehicle Overview
- Open the vehicle and review the Overview tab.
- Confirm it feels like the main payoff screen.
- Confirm reminder urgency is visible at a glance.
- Tap recent service, recent part, and reminder rows to confirm they open correctly.

## Add Service
- Add a service with date, mileage, cost, shop, and notes.
- Attach a receipt photo.
- Reopen the service and confirm receipt viewing, zooming, replacing, and sharing still work.
- Confirm the service save message feels trustworthy.

## Add Part
- Add a part replacement.
- Link it to a service if available.
- Confirm the part list shows linked service context and miles-since-replacement text.

## Add Reminder
- Create a reminder from the reminder screen.
- Create a reminder from a service flow if available.
- Confirm due date and/or mileage logic is shown clearly.
- Confirm the reminder appears in the correct section.

## Complete Reminder
- Mark a reminder complete.
- Confirm it moves to Completed.
- Confirm its notification is removed.

## Overdue Reminder Check
- Create one reminder due in the past.
- Create one reminder due soon by date or mileage.
- Confirm both appear in the urgent section.
- Confirm urgency badges and wording feel obvious and useful.

## Backup Export
- Save a backup copy from the Info screen.
- Confirm the share/export sheet appears correctly on device.
- Confirm the backup wording feels understandable for a non-technical user.
- Confirm the filename looks clean and non-technical.

## Backup Import
- Restore from a valid backup.
- Confirm merge-style restore works without losing current records.
- Confirm restored services, reminders, parts, notes, and photos appear correctly.

## Replace Import Mode
- Open Advanced Settings.
- Turn on replace-mode restore.
- Confirm the warning clearly explains that current history will be removed first.
- Run one replace restore using test data only.

## Edit / Delete Flows
- Edit a vehicle, service, part, and reminder.
- Delete a vehicle and confirm the warning is clear.
- Delete a service, part, and reminder and confirm each warning explains what will happen.

## Notification Permission
- Confirm permission prompt appears at an appropriate moment.
- Create a reminder with a due date.
- Confirm a notification is scheduled.
- Confirm the reminder notification still behaves after app relaunch.

## Background / Relaunch Behavior
- Put the app in the background and return.
- Force-quit and relaunch.
- Confirm saved vehicles, services, parts, reminders, and backup timestamps still appear correctly.
- Confirm navigation and selected vehicle detail flow still feel stable after relaunch.

## Real-Device UI Behavior
- Verify sheets open and dismiss cleanly.
- Verify keyboard behavior in longer forms.
- Verify scrolling remains smooth in service and part forms.
- Verify no clipped buttons or broken navigation on smaller phones.
- Verify receipt photo full-screen view behaves well with gestures.

## Final Submission Confidence Checks
- No obviously technical wording in the normal user flow.
- No debug actions visible outside Advanced Settings.
- No broken empty states.
- No dead-end screens on first use.
- No modal or navigation glitches after repeated add/edit/delete actions.
