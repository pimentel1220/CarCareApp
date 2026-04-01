# App Store Metadata Draft

## Official Branding
- Official app name: `CarCare Maintenance`
- Brand word: `CarCare`
- Product name: `CarCare Maintenance`

## App Name
- CarCare Maintenance

## Alternate Naming Ideas (Do Not Use As Primary Release Name)
- CarCare Maintenance Log
- CarCare Maintenance Tracker
- CarCare Maintenance Reminder
- CarCare Vehicle Maintenance

## Subtitle Options
- Keep service, parts, and reminders together
- Track vehicle care with confidence
- Your car history in one place
- Stay ahead of maintenance and repairs
- Simple car maintenance tracking

## Promotional Text Draft
Keep vehicle details, service history, part replacements, reminders, and backup copies all in one calm place.

## App Store Description Draft
CarCare Maintenance helps you stay organized every time your vehicle needs attention.

Save vehicle details, keep a clear service history, track replaced parts, and set reminders for what comes next. Whether you want a simple place to log oil changes or a more complete record of repairs and replacement parts, CarCare Maintenance keeps everything connected to the vehicle so it is easy to find later.

With CarCare Maintenance you can:
- Add and manage multiple vehicles
- Log service visits with date, mileage, cost, shop, notes, and receipt photos
- Track replaced parts and link them to service records
- Create reminders for future service by date or mileage
- See overdue and due-soon reminders at a glance
- Keep mileage and vehicle details up to date
- Fill in vehicle details from VIN when available
- Save and restore backup copies of your vehicle history

CarCare Maintenance is designed to feel simple, clear, and dependable from the first vehicle you add.

## Keyword Ideas
- car maintenance
- vehicle maintenance
- service log
- oil change
- mileage tracker
- repair history
- car reminder
- parts tracker
- garage log
- vehicle records

## Category Recommendation
- Primary: `Utilities`
- Alternate option: `Productivity`

## URL Placeholders
- Privacy Policy URL: `https://YOUR-DOMAIN.com/privacy`
- Support URL: `https://YOUR-DOMAIN.com/support`
- Marketing URL: `https://YOUR-DOMAIN.com`

## What's New For Version 1.0
Version 1.0 gives you a simple way to keep your vehicle history together.

- Add vehicles and save important details in one place
- Log service visits with mileage, costs, notes, and receipt photos
- Track replaced parts and link them to service history
- Set reminders by date or mileage
- View overdue and due-soon reminders at a glance
- Save and restore backup copies of your records

## App Privacy Preparation Notes
Likely App Privacy disclosure categories based on current app behavior:
- Contact Info: likely `No`, unless support or account features are added later
- Location: `No`
- Financial Info: `No`
- User Content: likely `Yes`, because the app stores notes, receipt photos, and vehicle photos locally
- Identifiers: likely `Yes`, because VIN and license plate are user-provided identifiers stored locally
- Usage Data: likely `No`, unless analytics are added later
- Diagnostics: likely `No`, unless crash reporting or analytics SDKs are added later
- Purchases: `No`
- Search History: `No`
- Sensitive Info: likely `No` under Apple's category definitions, but manually confirm how you want to describe VIN and license plate data

Likely data stored locally:
- vehicle nickname, make, model, year, trim, and engine
- VIN
- license plate
- mileage
- notes
- service history
- part replacement history
- reminders
- receipt photos
- vehicle photos
- backup timing metadata
- advanced provider configuration preferences

Whether data appears linked to user:
- Likely `Yes` for App Store Connect disclosure purposes, because the saved data belongs to a specific user's vehicles on their device.

Whether tracking appears present:
- `No` tracking is currently evident in the app.

Manual confirmation needed before App Store Connect submission:
- Confirm VIN lookup and manufacturer schedule sync disclosures match the actual provider setup you plan to ship.
- Confirm receipt photos and vehicle photos are not sent off-device in any release path other than user-initiated backup/export.
- Confirm no third-party analytics, crash reporting, or remote logging SDKs were added outside this repo.
- Confirm backup files are only saved or shared by the user and are not uploaded to your servers.
