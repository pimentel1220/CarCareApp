# Dark Mode Notes

## What Changed
- Replaced bright blue placeholder surfaces with adaptive system backgrounds for vehicle image fallbacks.
- Updated overview metric cards to use adaptive system card backgrounds.
- Strengthened due-soon reminder visibility by using orange instead of yellow in the overview status strip.
- Improved urgency detail text so overdue and due-soon reminders stay readable in both Light and Dark Mode.
- Kept the receipt photo viewer intentionally dark for focus and consistent photo viewing.

## Screens That Needed Custom Fixes
- `CarCareApp/Views/VehicleRowView.swift`
- `CarCareApp/Views/VehicleOverviewView.swift`
- `CarCareApp/Views/RemindersView.swift`
- `CarCareApp/Views/PartsView.swift`

## Current Dark Mode Status
- The app continues to follow the system appearance.
- Light Mode and Dark Mode now use cleaner adaptive surfaces for key cards and placeholders.
- Reminder urgency remains visible without relying on low-contrast text.
- No forced appearance override was added.

## Recommended Final Check
- Run `DARK_MODE_QA_CHECKLIST.md` on a physical iPhone and switch appearance manually in Settings or Control Center.
