# iFruit Calendar

## Product goal

Calendar is the personal scheduling app for `sky_phone`. Players can plan appointments on a day,
give them a start and end time, attach a note, and receive a phone notification before the event.
The app is account-backed so the same appointments follow the signed-in iFruit account across its
phones instead of living only in one browser session.

## Main experience

- **Month view:** a continuously navigable month grid with today, the selected day, and days that
  contain appointments clearly marked.
- **Day agenda:** appointments for the selected day are ordered by start time and show their time
  span, title, note preview, and reminder state.
- **Create and edit:** title, date, start time, end time, optional note, and a reminder choice of
  none, at start, 10 minutes, 30 minutes, 1 hour, or 1 day before.
- **Detail view:** presents the complete appointment and offers edit/delete actions.
- **Automatic data flow:** the visible month is loaded when the app opens or the month changes;
  create, edit, and delete operations refresh the authoritative server result immediately.

## Persistence and ownership

Appointments are stored in `sky_phone_calendar_events` and belong to an iFruit account. A calendar
therefore requires an authenticated phone account. The server validates ownership, input limits,
time ordering, reminder values, and revisions. Clients never decide which database row they own.

The table stores UTC-style Unix timestamps through MariaDB `DATETIME` values. The NUI formats them
in the player's local phone/browser time zone. Optimistic revisions prevent one phone from silently
overwriting a newer edit made on another phone.

## Reminder delivery

The server checks due reminders in a low-frequency scheduler. It atomically marks each reminder as
delivered before notifying every currently carried phone belonging to the account. Delivery uses
the existing `sky_phone` notification path, including each device's notification and sound
preferences. A reminder contains the event title and formatted start time.

Changing an event resets its delivery marker. Deleting an event removes its pending reminder.
Events without a reminder never enter the scheduler query.

## Limits and safety

- Title: 1-120 characters.
- Note: optional, up to 2,000 characters.
- End must be after start; maximum appointment duration is seven days.
- Events may be created at most five years ahead and edited only within the supported time range.
- Reminder values use a server allowlist.
- Writes are rate-limited and SQL uses parameter placeholders.
- Month queries use a bounded range and result limit.

## Integration points

- App id and route: `calendar` / `/apps/calendar`.
- NUI callbacks: `calendar:list`, `calendar:create`, `calendar:update`, `calendar:delete`.
- Server notification event: `sky_phone:calendar:reminder`.
- Notification settings are automatically available beside the other phone apps.
- Runtime migration and `sql/install.sql` both own the new table definition.
