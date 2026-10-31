# Disabled apps and storage startup

`Config.Apps` controls starting app modules and accepting new app operations.
App-only storage is migrated when its app is enabled. Existing rows are retained
when an app is disabled. A first enable keeps callback responses in
`server_initializing` until schema work and module registration finish; it does
not report an absent callback as a normal request failure.

Some storage remains essential even when its app icon is off:

- Notes and music stores support Sky Cloud account linking and device reset.
- Music, notes and map markers are receive targets for EasyShare.
- SMS storage supplies Phonepanel statistics and message history.
- FlipTok sessions participate in device reset.
- Flare profile photos and SkyPic media references protect gallery deletion.
- SkyRide storage and its recovery owner retain paid ride/refund obligations.

The startup filter also retains referenced parent tables. For example, Local
Pages posts have a foreign key to CityMarkt listings, so enabling Local Pages
requires that parent storage even if CityMarkt remains disabled. The same
dependency closure applies when an app is enabled after startup. Retaining a
dependency's storage does not start that dependency's disabled app module.

Disabled social platforms return `app_disabled` for Phonepanel content reads
and removals, including SkyPic Stories through the SkyPic switch. Global
administration and activity history remain available. EasyShare rejects a
disabled source app before looking up its optional tables. The explicit test
data command prepares all of its seeded domains before changing device,
account or SIM state. Explicit LB Phone imports can likewise prepare their
selected domains without turning the app on.

Disabling new work does not suspend cleanup. Registered Radio disconnect and
Garage valet completion/cancellation requests remain available. SkyRide retains
current-ride reads, arrival/start/completion, cancellation, rating and switching
a driver offline; new quotes, paid requests and acceptances remain blocked.
Existing ownership, role and payment checks still run in the owning handlers.
SkyRide refund recovery continues while disabled, including after a resource
restart. Health activity reports and new memo uploads stop while disabled;
memo upload terminal/cancellation handling remains available for accepted work.

Crypto configuration validation uses the candidate app switch. Enabling an app
with retained markets must reject incompatible scales or issued supply before
the Configurator saves the new configuration. A first enable with no Crypto
storage reads only schema metadata until its initialization creates that storage.

`tests/app_database.lua` includes cold full-schema dependency checks, core
administration, all six disabled social keys, lazy enable and retry/readiness
checks, Crypto candidate validation, test-data preflight, disabled direct events
and paid SkyRide settlement/recovery. `tests/player_restrictions.lua` covers
Radio disable cleanup. These are source/spec tests; restarted FiveM/OAL and
database-runtime evidence must be recorded separately.
