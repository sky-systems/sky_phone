# KnoWay autonomous rides

KnoWay is an optional built-in Sky Phone app for booking a robotaxi. It uses the
phone's own framework, callback, configuration and database bridges. SkyRide
continues to match passengers with real player drivers; KnoWay has its own
bookings and fare journal.

The app is **disabled by default**. Its vehicle model is deliberately empty until
an administrator installs and verifies a suitable vehicle resource. A browser
demo or a successful frontend build does not establish FiveM vehicle acceptance.

## Before enabling the service

1. Enable OneSync on the test server and retain the phone's experimental OAL
   setting. Check the configured phone framework and its payment account.
2. Obtain the [original KnoWay Ocelot E-Stride mod](https://www.gta5-mods.com/vehicles/knoway-ocelot-e-stride)
   separately. The author's page permits FiveM use with credits, excludes
   paywalled redistribution and names The Kortz Center Heist DLC as a dependency.
   Sky Phone does not include or install that vehicle package. Do not add it to
   a paid bundle or assume that the phone's license covers the model or textures.
3. Prepare and install the model as a separate FiveM vehicle resource using its
   own metadata and manifest. The author's single-player `dlcpacks` instructions
   are not a ready-made FiveM resource installation.
4. Read the installed `vehicles.meta` and use its exact `modelName`. The public
   description names the DLC folder `knowayest`; it does **not** establish that
   this is the spawn/model name. The exact spawn name and minimum numeric game
   build have not been verified for this implementation. Check the actual
   package, its referenced assets and a server build that includes its required
   DLC content before publishing the service. Do not guess a build number or
   silently substitute a different vehicle.
5. Start the vehicle resource before testing KnoWay. Confirm the model loads,
   passengers can use its seats and its handling/collision work on that build.
   Keep its credits with the separately installed resource. The original page
   credits Rockstar Games, Roost4R, sirstirfry, Suzuka/a_asdf556, JsH and HexR.
6. Configure the verified model and enable the app using the configuration owner
   below, then complete the multiplayer acceptance checklist.

## Choose the existing configuration owner

KnoWay follows the same source-selection rules as other phone features. There is
no second KnoWay override mechanism. See the [Phone Configurator guide](phone-configurator.md).

| Setting                                    | Configuration source                                                                                                                                                                                                                                                                                         |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Config.PhoneConfigurator.Enabled = true`  | Use `/phonepanel` → Phone configurator. Set the verified **Vehicle model** in **KnoWay**, then enable **KnoWay** under **Apps** and save the shared draft. SQL values override the shipped generated defaults. Changes to the managed part of `config.lua` have no runtime effect, including on first start. |
| `Config.PhoneConfigurator.Enabled = false` | Edit `Config.Knoway` and `Config.Apps.knoway` in `config/config.lua`, then restart the phone resource. The panel's configuration editor is read-only in this mode.                                                                                                                                           |

Enabling the app with an empty model is rejected by panel validation. In file
mode, set the model before changing `Config.Apps.knoway` to `true`. KnoWay is
optional in the App Store once enabled; it is not forced onto existing phones.
The app needs no `sky_base` or `sky_jobs_base` resource.

Never edit `source/shared/config_default.lua` by hand or delete saved SQL
configuration to enable KnoWay. The frontend build generates the default
snapshot. Switching off the Configurator does not export SQL values to the Lua
file, and switching it on again restores its saved values.

### Available settings

Every option below is available in both the file and panel configuration. Field
labels and help are provided in English and German. New accepted bookings take
a snapshot of their settings; later price or refund-policy edits do not change
that booking's agreement.

| Configuration key                                                        | Shipped default and purpose                                                                                                                              |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Apps.knoway`                                                            | `false`; enable after installing and verifying the vehicle. Disabling rejects new work while accepted rides and payment recovery remain available.       |
| `Knoway.VehicleModel`, `DriverModel`                                     | Empty required vehicle model; invisible AI driver `s_m_m_autoshop_01`. Model names accept letters, digits, underscores and hyphens, up to 64 bytes.      |
| `PaymentAccount`, `Currency`                                             | `bank`, `$`. The account must be supported by the selected framework. The currency is a display symbol; it does not convert balances.                    |
| `BaseFare`, `PricePerKilometer`, `MinimumFare`                           | `12`, `18`, `15`. Fare values may be zero for a free service.                                                                                            |
| `RouteDistanceMultiplier`                                                | `1.25`; scales the straight-line distance for an estimate. It is not the length of a fully routed navigation path.                                       |
| `AverageSpeedMetersPerSecond`                                            | `12`; estimates travel time independently from the actual cruise-speed cap.                                                                              |
| `QuoteLifetimeSeconds`                                                   | `120`; validity of an unaccepted quote.                                                                                                                  |
| `MinimumDistanceMeters`, `MaximumDistanceMeters`                         | `250`, `40000`; bounds on the estimated trip distance.                                                                                                   |
| `MaxActiveRides`                                                         | `10` across the server; each character can have one active booking.                                                                                      |
| `RequestCooldownSeconds`                                                 | `60` between accepted bookings per character; `0` disables the cooldown.                                                                                 |
| `BoardingTimeoutSeconds`, `ApproachTimeoutSeconds`, `MaximumRideSeconds` | `120`, `180`, `1800`; boarding, approach and journey deadlines.                                                                                          |
| `MaxSpeedKmh`, `DrivingStyle`                                            | `80`, `786603`; cruise-speed cap and GTA driving-behaviour flags. Traffic and road geometry still affect the AI. Test custom flag combinations in FiveM. |
| `ArrivalRadius`                                                          | `20` metres; arrival also requires the taxi to slow down.                                                                                                |
| `SpawnMinimumDistance`, `SpawnMaximumDistance`                           | `100`, `150` metres; nearby spawn search rather than a simulated journey from a distant depot.                                                           |
| `RoadSnapDistance`                                                       | `100` metres; maximum offset to a usable road point.                                                                                                     |
| `StuckTimeoutSeconds`, `MaximumReplans`                                  | `45`, `2`; bounded route retries before a technical failure. No vehicle teleportation is used to complete the trip.                                      |
| `RefundBeforeStart`, `RefundAfterStart`, `RefundTechnicalFailure`        | `true`, `false`, `true`; refund policy stored with each accepted booking.                                                                                |

## Passenger workflow

1. Stand outside near an accessible road. Open KnoWay and choose a destination
   on its map, or use the existing GTA GPS waypoint.
2. Request a fixed-price quote. Review the snapped pickup/destination, estimated
   distance, travel time, payment amount and refund terms. Move to the displayed
   pickup point before confirming; moving away may require a new quote.
3. Book the ride. The configured account is charged once when the booking is
   accepted. The map shows the taxi approaching; the GTA map receives its blip.
4. Take a passenger seat. Friends may use remaining passenger seats. The
   invisible AI driver reserves the driver seat; passengers are not given
   personal keys or a garage-owned vehicle.
5. The player who booked the taxi presses **Start ride** after everyone has
   boarded. Only that player may start or cancel the booking. The taxi waits
   until the boarding deadline rather than departing when a friend enters first.
6. Put the phone away if desired. The Lua/networked vehicle lifecycle continues
   independently of the app. Reopening the app reloads the active booking.
7. At the destination, or after choosing **End ride**, wait for the vehicle to
   stop before leaving. Empty vehicles and drivers are cleaned up; occupied
   vehicles are not simply deleted underneath passengers.

New quotes and bookings normally require reception. Reading an existing booking,
starting its assigned taxi and cancelling it remain available without mobile
signal. These exceptions still validate the booking owner and server-side state.
No-reception cleanup and the app's enabled/disabled switch are separate checks.

With shipped refund settings, cancellation before departure returns the full
fare; cancellation after departure keeps the agreed fixed price. Death,
disconnect, leaving the booked taxi after departure or changing routing bucket
ends the passenger's booking under that cancellation policy. Server-verified
technical failures follow `RefundTechnicalFailure` instead. Client-provided
reasons cannot authorize a technical refund.

KnoWay uses GTA's driving AI, not a guarantee of collision-free navigation.
Interiors, inaccessible terrain and blocked roads can be rejected or end in a
bounded technical failure. The estimate and fixed fare do not increase if the
AI takes longer than expected.

## Payment journal and recovery

The additive runtime migration and clean-install SQL create the resource-owned
`sky_phone_knoway_rides` journal. It records the booking identity, agreed amount,
account, currency, settings snapshot, lifecycle decision and payment state. A
unique active-owner lease and server-side operation locking prevent duplicate
accepted bookings. Do not clear or repurpose this table when disabling the app.

| Payment state       | Meaning and operator action                                                                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `debit_processing`  | The framework debit may be in flight. Do not repeat it. If startup finds this unresolved, it moves to `review`.                                                    |
| `not_charged`       | The framework rejected the debit or the identity changed before it was attempted; no accepted paid ride is dispatched.                                             |
| `charged`           | The accepted fare was confirmed. A live booking may continue or reach its terminal settlement/refund decision.                                                     |
| `settled`           | The booking is complete and no refund is due under its stored policy.                                                                                              |
| `refund_pending`    | A refund is due. The recovery worker retries when the correct character is online; disconnected characters are not refunded through an unrelated reused player ID. |
| `refund_processing` | A refund has been claimed and the framework credit is being resolved. An interrupted/ambiguous credit is not automatically replayed.                               |
| `refunded`          | The framework confirmed the refund.                                                                                                                                |
| `review`            | The framework result is ambiguous. Automatic replay is intentionally stopped to avoid a second debit or credit. An authorized operator must reconcile it.          |

At startup, previously charged journeys that could not finish are ended rather
than silently resumed. Their stored technical-failure policy determines whether
to queue a refund. A resource stop cannot safely await arbitrary database calls;
unfinished charged rows are therefore reconciled on the next startup. Payment
and refund recovery continue when KnoWay is disabled. The worker checks pending
refunds periodically; it does not require an open phone screen.

For a `review` case, collect the ride ID, timestamp, configured account and
amount, the phone's concise server diagnostic, and the framework's authoritative
account transaction evidence. An authorized operator should establish whether
the original debit/credit occurred and reconcile it once using the server's
approved accounting process. Keep the journal evidence. Do not ask a player to
rebook, delete the row, change it back to a processing state, or blindly issue a
second refund. Sky Phone does not expose a self-service accounting repair button
for these cases.

## Runtime acceptance status

**Pending:** the vehicle package, exact model/build compatibility and a restarted
FiveM multiplayer session have not been accepted by this implementation record.
Automated Lua, store, configuration, mock and browser checks are separate from
these native/physics tests. Record the tested game build, resource commit, model
and results before enabling the service for players.

- [ ] Verify the original vehicle's credits, exact `modelName`, asset dependencies
      and working enforced game build on the intended FiveM client platform.
- [ ] Test activation and persistence in file mode and `/phonepanel` mode without
      changing unrelated saved settings. Missing models must not produce a paid ride.
- [ ] With two clients, book from the map and a GTA waypoint; verify the agreed
      pickup, fixed price, one debit, arrival indication and boarding deadline.
- [ ] Confirm the driver is invisible to both clients, the driver seat remains
      reserved, friends can board and only the booking owner controls the ride.
- [ ] Start, close/reopen the phone, complete a road journey and let all
      passengers exit before cleanup. Test streaming and network-ownership changes.
- [ ] Test a busy road, an unreachable target, a blocked route, route retries and
      the technical timeout without teleporting the taxi.
- [ ] Test cancellation before/after departure, no reception, leaving the taxi,
      death, disconnect and routing-bucket changes against the stored refund policy.
- [ ] Test destroyed/lost entities and a resource restart; verify passenger
      safety, empty-entity cleanup, deferred offline refunds and no duplicate credit.
- [ ] Disable KnoWay with an accepted booking/refund pending; new work must stop
      while existing lifecycle and recovery actions remain authorized and available.
- [ ] Exercise ambiguous framework payment results on a test account and confirm
      they become review cases instead of repeated charges/refunds.
