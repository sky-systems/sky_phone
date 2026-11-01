# Compatibility lifecycle

Sky Phone registers the `lb-phone`, `17mov_Phone`, `high-phone`, `qs-smartphone`
and `yseries` compatibility aliases. It does not emit built-in resource lifecycle
events for these aliases. Those events belong to the FiveM resource manager and
can run unrelated scripts' cleanup or initialization handlers.

## Readiness

- `sky_phone:client:compatReady` is a local client event emitted after the client
  alias handlers have been registered.
- `sky_phone:server:compatReady` is a local server event emitted after database
  migration and server alias registration.
- Existing provider-specific notifications, including `17mov_Phone:Client:Ready`
  and the High Phone application snapshot, remain available.

Readiness is a notification, not a cache reset. Register listeners before Phone
starts; start external app resources after Phone. The earlier native
`sky_phone:client:apiReady` event does not establish compatibility-alias readiness.

## Restarting Phone

Schedule maintenance with players disconnected. Restart Phone, then restart
resources that consume its compatibility aliases in their normal startup order,
then reconnect players. A complete server restart with the same startup order
also refreshes those consumers. Phone does not restart other resources itself.

The Lua runtime caches exports inside each consuming resource under the requested
resource name. An alias such as `lb-phone` has a different cache entry from
`sky_phone`; a real Phone stop does not clear that alias entry. A readiness event
or another registration attempt cannot repair the consumer's stale reference.
There is no supported public cache-reset API in the inspected runtime.

## Verification

Official Cfx source inspected at revision
[`9f0e34e1cbdfc34fd05079416791f01938279097`](https://github.com/citizenfx/fivem/tree/9f0e34e1cbdfc34fd05079416791f01938279097):

- [`scheduler.lua:656–660`](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/data/shared/citizen/scripting/lua/scheduler.lua#L656)
  registers the client/server resource-stop cache listener.
- [`scheduler.lua:692–718`](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/data/shared/citizen/scripting/lua/scheduler.lua#L692)
  indexes and invokes cached exports by the requested resource name.
- [`ResourceEventComponent.cpp:185–235`](https://github.com/citizenfx/fivem/blob/9f0e34e1cbdfc34fd05079416791f01938279097/code/components/citizen-resources-core/src/ResourceEventComponent.cpp#L185)
  dispatches local events to other resource listeners. See also the official
  [`TriggerEvent` contract](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/TriggerEvent/).

`tests/custom_app_compat_client.lua` and `tests/custom_app_compat_server.lua`
exercise real lifecycle listeners and reject fabricated built-in lifecycle
events during Phone startup and shutdown. These fixtures do not prove that a
particular customer's GTA session disconnect is resolved.
