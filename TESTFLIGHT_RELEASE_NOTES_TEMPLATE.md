# CarCareApp TestFlight Notes (Template)

## What To Test
- Add vehicle and decode VIN.
- Configure provider and run provider connection test.
- Sync manufacturer schedule and verify source label updates.
- Add service, verify reminder defaults, and save.
- Apply recommendation style to active reminders and undo.
- Export backup and import it back (merge + replace).

## New In This Build
- VIN-based schedule sync with provider abstraction.
- Provider connection test with clear status output.
- CarMD preset support and flexible auth modes.
- Reminder recommendation confidence/source improvements.
- Backup/import safety improvements and auto-backup prompts.

## Known Issues
- Provider schedule quality varies by endpoint payload completeness.
- If provider is unreachable, auto mode can fallback to local baseline.
