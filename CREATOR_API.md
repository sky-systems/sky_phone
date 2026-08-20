# Sky Phone Creator API

This is the first-party integration contract for resources that integrate directly with `sky_phone`. It covers the shared, client, and server exports, native custom apps, and the Sky iframe bridge protocol.

The current native API version is `1.0.0`. The current custom-app schema and iframe protocol version is `1`.

> Provider compatibility is a separate surface. New integrations should call `exports["sky_phone"]` directly, not the provided `lb-phone`, `17mov_Phone`, `high-phone`, `qs-smartphone`, or `yseries` aliases.

## Quick start

Declare Sky Phone as a dependency so FiveM starts it before your resource. A custom app normally has both client and server code and exposes its web files:

~~~lua
fx_version "cerulean"
game "gta5"

dependency "sky_phone"

client_script "client.lua"
server_script "server.lua"

files {
    "web/index.html",
    "web/**/*",
}
~~~

The server must have both `Config.CustomApps.Enabled` and `Config.CustomApps.ExternalApps` enabled. Treat capability discovery as authoritative because a server can disable or tighten parts of this contract.

### Export context and ownership

Client and server exports are different runtimes even when they share a name. Call each export from the matching client or server script.

Native custom-app exports derive the owner from FiveM's `GetInvokingResource()`. Therefore:

- Call them directly as `exports["sky_phone"]:ExportName(...)`.
- Do not proxy creator calls through another resource; the proxy becomes the owner.
- Register the client app and server policy from the same resource name.
- Only the owner can update, remove, open, close, message, or notify its app.
- Owned client registrations and server policies are removed automatically when the owner resource stops.

All input from an iframe or game client remains untrusted. Perform permission, identity, money, inventory, and other consequential validation on the server.

## Readiness and capabilities

The client API is ready when its exports load. The server API becomes ready after Sky Phone's database migration and domain services are available.

| Side | Poll | Local event |
| --- | --- | --- |
| Client | `exports["sky_phone"]:IsApiReady()` | `sky_phone:client:apiReady` with `apiVersion` |
| Server | `exports["sky_phone"]:IsApiReady()` | `sky_phone:server:apiReady` with `apiVersion` |

The ready events are local events, not network events. Check first and subscribe second so your resource also works when the event has already fired:

~~~lua
local function on_sky_phone_ready()
    if not exports["sky_phone"]:IsApiReady() then
        return
    end

    local capabilities = exports["sky_phone"]:GetApiCapabilities()
    print(("[my_resource] Sky Phone API %s is ready on %s."):format(
        capabilities.apiVersion,
        capabilities.side
    ))
end

CreateThread(on_sky_phone_ready)
AddEventHandler("sky_phone:client:apiReady", on_sky_phone_ready) -- client.lua
-- Use sky_phone:server:apiReady in server.lua.
~~~

`GetApiCapabilities()` returns a fresh snapshot with `apiVersion`, `side`, `ready`, and `features`. The current client feature groups include calls, camera, custom apps, equipped phone number, navigation, custom-app notifications, phone game input, and phone state. The current server feature groups include calls, custom apps, device directory, custom-app notifications, and phone-number lookup.

`features.customApps` is an object with `enabled` and `external`. `features.notifications` is an object with `customApps = true` and `system = false`. There is intentionally no generic first-party system-notification export for creators.

For custom-app-specific export names, bridge methods, protocol version, and configured size limits, call `GetCustomAppCapabilities()` on the relevant side. Do not infer a feature from the API version alone.

## Return and error conventions

The API uses these conventions:

- Mutations normally return `true` on success or `false, errorCode` on rejection.
- Lookups normally return a value or `nil, errorCode`. State queries such as `GetActiveCall()` and identity shortcuts can return plain `nil` when no value exists.
- Predicates return a boolean and generally collapse invalid input into `false`.
- `TogglePhone()` returns only a boolean.
- Server `SendCustomAppNotification()` returns `true, { delivered = 1 }` on delivery or `false, errorCode`.
- Returned tables are snapshots. Mutating them does not update Sky Phone.
- Error codes are machine-readable strings. Handle unknown future codes as well as the documented common codes.

A missing resource or export is a FiveM invocation error rather than one of these return values. The manifest dependency avoids the normal load-order case.

## Shared exports

These exports exist in both client and server scripts.

| Export | Signature | Result |
| --- | --- | --- |
| `GetApiVersion` | `()` | `"1.0.0"` |
| `NormalizePhoneNumber` | `(value)` | Configured normalized number, or `nil, "invalid_phone_number"` |
| `FormatPhoneNumber` | `(value)` | Configured display format, or `nil, "invalid_phone_number"` |
| `IsValidImei` | `(value)` | Boolean |

Normalization uses the server's configured SIM prefix and length; formatting uses its configured number groups.

## Client exports

### Phone state and focus

| Export | Signature | Result |
| --- | --- | --- |
| `TogglePhone` | `(open?, noFocus?)` | Boolean |
| `GetPhoneState` | `()` | Phone-state snapshot |
| `GetEquippedPhoneNumber` | `()` | Authoritative normalized number or `nil` |
| `SetPhoneGameInputEnabled` | `(enabled)` | `true` or `false, errorCode` |

`TogglePhone(nil)` toggles. `TogglePhone(true, true)` requests an open phone without cursor focus. A successful open request is asynchronous; observe `sky_phone:client:phoneToggled` or read `GetPhoneState()` for the confirmed UI state.

The phone-state snapshot is:

~~~lua
{
    inCall = boolean,
    onScreen = boolean, -- compatibility alias of open
    open = boolean,
    phoneNumber = string | nil,
}
~~~

`SetPhoneGameInputEnabled(true)` allows game input while the phone is open; `false` applies the external override in the other direction. The claim is associated with the invoking resource and is cleared when that resource stops or the phone closes. It can return `resource_required`, `invalid_focus_claim`, or `phone_closed`.

### Navigation

| Export | Signature | Result |
| --- | --- | --- |
| `OpenApp` | `(appId)` | `true` or `false, errorCode` |
| `CloseApp` | `(appId?)` | `true` or `false, errorCode` |
| `GetNavigationState` | `()` | Navigation snapshot |
| `GetCurrentApp` | `()` | Active app ID, `"home"`, or `nil` if the phone is closed |
| `GetCurrentApp` | `(appId)` | Boolean |
| `IsAppDataLoaded` | `()` | Boolean |
| `IsAppInstalled` | `(appId)` | Boolean |

`OpenApp` requires an open phone and an installed app. `CloseApp` optionally verifies the expected active app before closing it.

~~~lua
local state = exports["sky_phone"]:GetNavigationState()
-- {
--     currentApp = string | nil,
--     dataLoaded = boolean,
--     installedApps = { [appId] = true },
-- }
~~~

API readiness and app-data readiness are separate. Wait for `IsAppDataLoaded()` before assuming the installed-app catalog is populated.

Common navigation errors are `invalid_app_id`, `phone_closed`, `app_not_installed`, and `app_not_active`.

### Calls

| Export | Signature | Result |
| --- | --- | --- |
| `Dial` | `(phoneNumber?, companyId?)` | `true` or `false, errorCode` |
| `AnswerCall` | `()` | `true` or `false, errorCode` |
| `DeclineCall` | `()` | `true` or `false, errorCode` |
| `HangupCall` | `()` | `true` or `false, errorCode` |
| `TerminateCall` | `()` | `true` or `false, errorCode` |
| `GetActiveCall` | `()` | Call snapshot or `nil` |
| `IsInCall` | `()` | Boolean |

At least one non-empty dial target is required. Use `Dial("5550100")` for a number or `Dial(nil, "police")` for a company service line. If a valid company ID is supplied, its service line takes precedence.

`AnswerCall` and `DeclineCall` require an incoming ringing call. `HangupCall` and `TerminateCall` accept a ringing or connected call. Normal hangup/decline semantics can reroute an unanswered company call; termination force-finishes it.

A client call snapshot contains:

~~~lua
{
    id = string,
    state = "ringing" | "connected",
    direction = "incoming" | "outgoing",
    otherNumber = string,
    startedAt = number,
    answeredAt = number | nil,
    channel = number | nil,
    speakerEnabled = boolean,
    speakerSupported = boolean,
    muted = boolean,
    muteSupported = boolean,

    -- Outgoing payphone calls can also contain:
    elapsedSeconds = number | nil,
    totalCost = number | nil,
}
~~~

Listen to the local `sky_phone:client:callChanged` event for state transitions. Its payload is the latest call snapshot, a terminal call-state payload, or `nil` when state is reset.

### Camera claims

| Export | Signature | Result |
| --- | --- | --- |
| `GetCameraState` | `()` | Camera-state snapshot |
| `SetFlashlight` | `(enabled)` | `true` or `false, errorCode` |
| `SetSelfieCamera` | `(enabled)` | `true` or `false, errorCode` |
| `EnableWalkableCamera` | `(selfie?)` | `true` or `false, errorCode` |
| `DisableWalkableCamera` | `()` | `true` or `false, errorCode` |
| `SetCameraFrozen` | `(frozen)` | `true, state` or `false, errorCode` |
| `ToggleCameraFrozen` | `()` | `true, state` or `false, errorCode` |
| `ReleaseCamera` | `()` | `true` or `false, errorCode` |

The first state-changing call that needs camera control claims it for the invoking resource. A second resource receives `camera_claimed`. If the built-in camera is already active before an external claim, the caller receives `camera_in_use`.

~~~lua
local ok, err = exports["sky_phone"]:EnableWalkableCamera(true)
if not ok then
    print(("Could not claim the phone camera: %s"):format(err))
    return
end

exports["sky_phone"]:SetFlashlight(true)

-- Always release on the normal completion/cancel path.
exports["sky_phone"]:ReleaseCamera()
~~~

`ReleaseCamera` disables walkable mode, flashlight, and selfie mode and releases the claim. `DisableWalkableCamera` performs the same full release for the caller's claimed session. Sky Phone also performs this cleanup automatically if the owning resource stops. `SetCameraFrozen` and `ToggleCameraFrozen` require an active camera and can return `camera_not_active`.

The state snapshot is:

~~~lua
{
    active = boolean,
    flashEnabled = boolean,
    frozen = boolean,
    selfie = boolean,
    walkable = boolean,
}
~~~

Other common errors are `resource_required` and `invalid_state`. Observe `sky_phone:client:cameraActiveChanged` for active-state changes.

## Native custom apps

A complete server-backed app normally registers a client definition and a matching server policy. The app ID and permission list should match on both sides.

### Client registration

~~~lua
local APP_ID = "my-resource-app"
local PERMISSIONS = {
    "app.close",
    "app.open",
    "device.storage",
    "locale.read",
    "notifications",
    "theme.read",
}

local registered = false

local function register_app()
    if registered or not exports["sky_phone"]:IsApiReady() then
        return
    end

    local capabilities = exports["sky_phone"]:GetCustomAppCapabilities()
    if not capabilities.externalApps then
        print("[my_resource] External Sky Phone apps are disabled.")
        return
    end

    local ok, err = exports["sky_phone"]:AddCustomApp({
        schemaVersion = 1,
        id = APP_ID,
        name = { en = "My App", de = "Meine App" },
        description = {
            en = "An example Sky Phone app.",
            de = "Eine Sky-Phone-Beispiel-App.",
        },
        developer = "My Studio",
        category = "utilities",
        ui = "web/index.html",
        icon = "web/icon.png",
        permissions = PERMISSIONS,
        orientation = "portrait",
        defaultInstalled = false,
        removable = true,
        bridgeMode = "sky",

        onInstall = function(data) end,
        onDelete = function(data) end,
        onOpen = function(data) end,
        onReady = function(data) end,
        onClose = function(data) end,
    })

    if not ok then
        print(("[my_resource] AddCustomApp failed: %s"):format(err))
        return
    end
    registered = true
end

CreateThread(register_app)
AddEventHandler("sky_phone:client:apiReady", register_app)
~~~

Set `bridgeMode = "sky"` explicitly for new apps. The default for external definitions is `legacy` for compatibility.

#### Definition fields

| Field | Required | Contract |
| --- | --- | --- |
| `schemaVersion` | Recommended | If present, must be `1` |
| `id` | Yes | 2-64 lowercase characters matching `^[a-z0-9][a-z0-9._-]+$`; built-in IDs are reserved |
| `name` | Yes | Non-empty string or locale map, maximum 64 UTF-8 bytes per value |
| `description` | No | String or locale map, maximum 320 UTF-8 bytes per value |
| `developer` | No | Non-empty string, maximum 96 UTF-8 bytes |
| `category` | No | `games`, `productivity`, `shopping`, `social`, or `utilities`; default `utilities` |
| `ui` | Yes | Relative resource asset or HTTPS URL |
| `icon` | No | Relative resource asset or HTTPS URL; omitted uses the default icon |
| `permissions` | No | Unique permission array; default empty |
| `orientation` | No | `portrait`, `landscape`, or `any`; default `portrait` |
| `defaultInstalled` | No | Boolean; default `false` |
| `removable` | No | Boolean; default `true` |
| `gridOrder` | No | Integer from 0 through 9999 |
| `iconBackground` | No | Non-empty string up to 64 UTF-8 bytes; CR/LF, semicolons, and braces are rejected |
| `bridgeMode` | No | `sky` or `legacy`; external default `legacy` |
| lifecycle hooks | No | Callable `onInstall`, `onDelete`, `onOpen`, `onReady`, and `onClose` |

Relative `ui` and `icon` values resolve to the calling resource's `https://cfx-nui-RESOURCE/...` origin. Path traversal, unsupported schemes, and cross-resource CFX-NUI ownership are rejected. Add every local asset to the creator resource's `files` list.

Registration is not the same as installation. `onInstall` and `onDelete` represent the user's App Store lifecycle. `onReady` occurs after the Sky bridge handshake (or frame load in legacy mode). Hook payloads are JSON-safe data or `nil`. Keep authoritative mutations on the server.

`UpdateCustomApp(definition)` takes a complete definition with the same owned ID. `RemoveCustomApp(appId)` removes the owned registration and closes it if active. Resource-stop cleanup is automatic.

### Permissions

| Permission | Current native effect |
| --- | --- |
| `app.close` | Enables iframe method `app.close` |
| `app.open` | Enables iframe method `app.open` |
| `device.storage` | Enables iframe methods `device.storage.get` and `device.storage.set` |
| `locale.read` | Adds `locale.read` capability and conditionally exposes `language` and `locale` in context |
| `notifications` | Enables iframe method `notification.create` and owner-validated Lua notifications |
| `notifications.critical` | Enables `critical = true` only for the client Lua notification export |
| `theme.read` | Adds `theme.read` capability and conditionally exposes `colorScheme` in context |

`camera.capture`, `contacts.pick`, `location.read`, `media.pick`, and `nui.fetch` are accepted permission identifiers, but the current v1 iframe bridge exposes no method or context field for them. Do not infer support from the permission list; inspect `GetCustomAppCapabilities().bridgeMethods` and the context `capabilities` array.

### Client lifecycle exports

| Export | Signature | Notes |
| --- | --- | --- |
| `AddCustomApp` | `(definition)` | Register a new app owned by the caller |
| `UpdateCustomApp` | `(definition)` | Replace the complete owned definition |
| `RemoveCustomApp` | `(appId)` | Remove the owned app |
| `OpenCustomApp` | `(appId, payload?)` | Requires an open phone and an owned registered app |
| `CloseCustomApp` | `(appId)` | Requires that owned app to be active |
| `SendAppMessage` | `(appId, payload)` | Canonical host-to-iframe message export |
| `SendCustomAppMessage` | `(appId, payload)` | Exact compatibility alias of `SendAppMessage` |
| `SendCustomAppNotification` | `(appId, notification)` | Owner- and permission-validated local notification |
| `GetCustomAppCapabilities` | `()` | Custom-app ABI, methods, export names, and configured limits |

Client message dispatch requires the owned app to be active. If its frame is active but has not completed readiness, up to 64 messages are queued and flushed after readiness. An inactive app returns `app_not_active`. Payloads must be JSON-safe and fit `maximumMessageBytes`.

~~~lua
local ok, err = exports["sky_phone"]:SendAppMessage(APP_ID, {
    type = "job:update",
    data = { available = true },
})
~~~

The `sky-phone-app:message` iframe envelope is documented below.

### Client custom-app notifications

The invoking resource must own the registered client app, and that definition must include `notifications`.

~~~lua
local ok, err = exports["sky_phone"]:SendCustomAppNotification(APP_ID, {
    title = "My App",       -- optional; defaults to the registered app name
    text = "The job is ready.",
    subtitle = "Dispatch",
    sound = "chime",        -- chime, signal, or soft
    persistent = false,
    critical = false,
    route = "/apps/" .. APP_ID,
})
~~~

`text` and `content` are aliases. Title and subtitle allow up to 160 UTF-8 bytes; text allows up to 2000 UTF-8 bytes. If supplied, `route` must be exactly `/apps/APP_ID`. `critical = true` additionally requires `notifications.critical`.

### Server policy registration

Register a policy even if the client definition already lists permissions. Server-backed storage, server messages, and server notifications use the server-owned policy.

~~~lua
local APP_ID = "my-resource-app"
local PERMISSIONS = {
    "app.close",
    "app.open",
    "device.storage",
    "locale.read",
    "notifications",
    "theme.read",
}

local registered = false

local function register_policy()
    if registered or not exports["sky_phone"]:IsApiReady() then
        return
    end

    local ok, err = exports["sky_phone"]:AddCustomAppPolicy({
        schemaVersion = 1,
        id = APP_ID,
        permissions = PERMISSIONS,
    })
    if not ok then
        print(("[my_resource] AddCustomAppPolicy failed: %s"):format(err))
        return
    end
    registered = true
end

CreateThread(register_policy)
AddEventHandler("sky_phone:server:apiReady", register_policy)
~~~

| Export | Signature | Result |
| --- | --- | --- |
| `AddCustomAppPolicy` | `(definition)` | `true` or `false, errorCode` |
| `UpdateCustomAppPolicy` | `(definition)` | `true` or `false, errorCode` |
| `RemoveCustomAppPolicy` | `(appId)` | `true` or `false, errorCode` |
| `GetCustomAppPolicy` | `(appId)` | Policy snapshot or `nil` |
| `HasCustomAppPermission` | `(appId, permission)` | Boolean |
| `GetCustomAppCapabilities` | `()` | Custom-app server capabilities |

A policy snapshot is:

~~~lua
{
    bundled = boolean,
    id = string,
    ownerResource = string,
    permissions = { "sorted", "permission.list" },
}
~~~

### Server-to-player messages

`SendAppMessage(playerSource, appId, payload)` is canonical. `SendCustomAppMessage(playerSource, appId, payload)` is its exact compatibility alias.

~~~lua
local ok, err = exports["sky_phone"]:SendAppMessage(player_source, APP_ID, {
    type = "server:update",
    data = { status = "ready" },
})
~~~

The export validates the direct policy owner, player source, online player, JSON payload, and configured message-size limit. `true` means the server accepted and dispatched the event. It does not acknowledge iframe delivery. The target client still needs the matching owned app to be registered and active; otherwise it rejects the message locally.

### Server custom-app notifications

The server form is `SendCustomAppNotification(playerSource, appId, notification)`. It verifies that the invoking resource owns the policy and that the policy contains `notifications`.

~~~lua
local ok, result_or_error =
    exports["sky_phone"]:SendCustomAppNotification(player_source, APP_ID, {
        title = "My App",
        text = "The job is ready.", -- content is also accepted
    })

if ok then
    print(("Delivered %d notification."):format(result_or_error.delivered))
else
    print(("Notification failed: %s"):format(result_or_error))
end
~~~

The server form supports a required title (up to 160 UTF-8 bytes) and required `text` or `content` (up to 2000 UTF-8 bytes). It delivers only to an online player whose equipped device can be revalidated. Success is `true, { delivered = 1 }`. There is no offline queue. Use the client export for subtitle, sound, persistence, critical state, or an explicit app route.

## Sky iframe protocol v1

Use `bridgeMode = "sky"`. Sky Phone appends `skyPhoneAppId=APP_ID` to the iframe URL.

### Secure handshake

Install the message listener before announcing readiness. In production the parent NUI origin is `https://cfx-nui-sky_phone`. If you use a development host, inject its expected parent origin explicitly rather than accepting every origin.

~~~js
const appId = new URL(window.location.href).searchParams.get("skyPhoneAppId");
const protocolVersion = 1;
const phoneOrigin = "https://cfx-nui-sky_phone";

function postToPhone(message) {
  window.parent.postMessage(
    { ...message, appId, protocolVersion },
    phoneOrigin,
  );
}

window.addEventListener("message", (event) => {
  if (event.source !== window.parent || event.origin !== phoneOrigin) return;
  const message = event.data;
  if (
    !message ||
    message.appId !== appId ||
    message.protocolVersion !== protocolVersion
  ) return;

  if (message.type === "sky-phone-app:context") {
    // Read only fields allowed by message.context.capabilities.
  } else if (message.type === "sky-phone-app:open") {
    // Handle message.data.
  } else if (message.type === "sky-phone-app:message") {
    // Handle message.payload.
  } else if (message.type === "sky-phone-app:response") {
    // Resolve the matching message.requestId.
  }
});

postToPhone({ type: "sky-phone-app:ready" });
~~~

Sky Phone validates the iframe window, exact iframe origin, app ID, and protocol version before accepting a message.

### Host-to-iframe messages

| Type | Payload |
| --- | --- |
| `sky-phone-app:context` | `{ appId, protocolVersion, context }` |
| `sky-phone-app:open` | `{ appId, protocolVersion, data }` |
| `sky-phone-app:message` | `{ appId, protocolVersion, payload }` |
| `sky-phone-app:response` | `{ appId, protocolVersion, requestId, success, data?, error? }` |

The v1 context is:

~~~ts
type SkyPhoneAppContextV1 = {
  appId: string;
  capabilities: string[];
  phoneScale: number;
  protocolVersion: 1;
  safeArea: { top: number; right: number; bottom: number; left: number };

  colorScheme?: "dark" | "light"; // only with theme.read
  language?: string;              // only with locale.read
  locale?: { name?: string; description?: string }; // only with locale.read
};
~~~

`colorScheme` is not present without `theme.read`. `language` and `locale` are not present without `locale.read`. Treat all permission-gated fields as optional and use the returned `capabilities` array as the authority.

### Iframe requests

A request has this envelope:

~~~js
postToPhone({
  type: "sky-phone-app:request",
  requestId: crypto.randomUUID(),
  method: "device.storage.get",
  payload: { key: "preferences" },
});
~~~

`requestId` must be unique, non-empty, and at most 128 characters. `method` must be non-empty and at most 64 characters. Duplicate request IDs are ignored without another response.

| Method | Required permission | Request payload | Success data |
| --- | --- | --- | --- |
| `app.close` | `app.close` | Omit | None |
| `app.open` | `app.open` | `{ appId, data? }` | `{ appId }` |
| `device.storage.get` | `device.storage` | `{ key }` | `{ exists, revision, value? }` |
| `device.storage.set` | `device.storage` | `{ key, revision, value }` | `{ revision }` |
| `notification.create` | `notifications` | `{ title, text, subtitle?, sound? }` | `{ notificationId }` |

`app.open` accepts an app ID up to 64 characters. Optional `data` must be a JSON object and is supported only when the target is an external app; its absolute v1 limit is 16384 bytes.

Storage is scoped to the equipped device IMEI and app ID. Keys match `^[A-Za-z0-9._-]{1,64}$`. A get for a missing key returns `{ exists = false, revision = 0 }`. Set requires a non-null JSON value and the revision returned by the latest get/set. New keys use revision `0`; a successful insert returns `1`. A stale write returns:

~~~js
{
  success: false,
  error: "storage_conflict",
  data: { exists: true, revision: 3, value: currentValue },
}
~~~

The absolute v1 value ceiling is 65536 bytes, but the server can configure a lower per-value limit, total app quota, key count, key length, and request rate. Read the client custom-app capabilities instead of hardcoding server policy.

Iframe notifications require non-empty `title` (maximum 80 characters) and `text` (maximum 240). Optional `subtitle` is at most 80. `sound` is `chime`, `signal`, or `soft`. The route is always the source app. This iframe method does not expose critical or persistent notifications.

Bridge JSON values are bounded to depth 8, 512 nodes, 128 entries per array/object, and 64 characters per object key. Functions, cyclic objects, non-finite numbers, and prototype-sensitive keys are rejected.

### Legacy mode

`bridgeMode = "legacy"` exists for provider compatibility. It becomes ready on iframe load, sends host-message payloads without the Sky v1 envelope, and does not provide the native handshake/context/request-response contract above. New first-party apps should always select `sky`.

## Server phone and device API

Server exports are for trusted server resources. Do not relay unrestricted device-directory results to clients.

### Phone identity

| Export | Signature | Result |
| --- | --- | --- |
| `GetEquippedPhoneNumber` | `(playerSourceOrIdentifier)` | Normalized number, `nil`, or `nil, "api_not_ready"` |
| `GetSourceFromPhoneNumber` | `(phoneNumber)` | Online player source, `nil`, or `nil, "api_not_ready"` |

`GetEquippedPhoneNumber` accepts a positive numeric player source or a non-empty framework identifier. It revalidates the equipped device. `GetSourceFromPhoneNumber` normalizes the input and resolves only an online source currently equipped with that number.

### Device directory

| Export | Input | Scope |
| --- | --- | --- |
| `GetOnlineDeviceBySource` | player source | Online and currently equipped |
| `GetOnlineDeviceByPhoneNumber` | phone number | Online and currently equipped |
| `GetOnlineDeviceByIdentifier` | framework identifier | Online and currently equipped |
| `GetOnlineDeviceByImei` | IMEI | Online and currently equipped |
| `GetStoredDeviceByImei` | IMEI | Persistent device record |
| `GetStoredDeviceByPhoneNumber` | phone number | Persistent device record |
| `GetStoredDeviceByIdentifier` | framework identifier | Persistent character device in non-unique-phone mode only |
| `GetStoredSimByPhoneNumber` | phone number | Persistent SIM record |

Device lookups return a snapshot or `nil, errorCode`:

~~~lua
{
    accountId = number | nil,
    deviceName = string,
    equipped = boolean,
    imei = string,
    mappedIdentifier = string | nil,
    online = boolean,
    phoneNumber = string | nil,
    registeredIdentifier = string | nil,
    simId = string | nil,
    simType = string | nil,
    source = number | nil,

    identifier = string | nil, -- added to applicable identifier/online results
}
~~~

Stored device results always report `online = false`, `equipped = false`, and `source = nil`. Online lookups revalidate framework identity and inventory ownership before returning. `GetStoredDeviceByIdentifier` returns `identity_scope_unsupported` when `Config.Phone.Unique` is enabled.

A SIM snapshot is:

~~~lua
{
    deviceImei = string | nil,
    phoneNumber = string,
    registeredIdentifier = string | nil,
    simId = string,
    simType = string | nil,
}
~~~

Common directory errors include `invalid_source`, `invalid_identifier`, `invalid_imei`, `invalid_phone_number`, `player_unavailable`, `device_not_found`, `device_not_equipped`, `equipped_device_ambiguous`, `identifier_ambiguous`, `device_holder_ambiguous`, `identity_inconsistent`, `identity_scope_unsupported`, and `sim_not_found`.

## Server call API

| Export | Signature | Result |
| --- | --- | --- |
| `GetActiveCallBySource` | `(playerSource)` | Server call snapshot or `nil, errorCode` |
| `GetActiveCallById` | `(callId)` | Server call snapshot or `nil, errorCode` |
| `IsPlayerInCall` | `(playerSource)` | Boolean |
| `EndCallForSource` | `(playerSource)` | `true` or `false, errorCode` |
| `TerminateCallForSource` | `(playerSource)` | `true` or `false, errorCode` |

The server snapshot contains the client call fields plus:

~~~lua
{
    anonymous = false,
    caller = { source = number, number = string },
    callee = { source = number | nil, number = string },
    companyId = string | nil,
    payphone = boolean,
    video = false,
}
~~~

`GetActiveCallBySource` calculates `direction` and `otherNumber` for that participant. `GetActiveCallById` uses the caller perspective. `EndCallForSource` preserves normal company rerouting/decline behavior; `TerminateCallForSource` force-finishes the call. Common errors are `invalid_source`, `invalid_call_id`, and `call_not_found`.

## Useful client events

These are local observation events. They are not authorization boundaries.

| Event | Payload |
| --- | --- |
| `sky_phone:client:apiReady` | `apiVersion` |
| `sky_phone:client:phoneToggled` | `open` boolean |
| `sky_phone:client:phoneNumberChanged` | normalized number or `nil` |
| `sky_phone:client:callChanged` | call state table or `nil` |
| `sky_phone:client:cameraActiveChanged` | `active` boolean |

The server readiness event is `sky_phone:server:apiReady` with `apiVersion`.

## Common custom-app errors

This list is intentionally not closed.

| Area | Common error codes |
| --- | --- |
| Readiness/config | `api_not_ready`, `external_apps_disabled` |
| Caller/owner | `missing_invoking_resource`, `resource_required`, `owner_resource_not_running`, `app_owner_mismatch` |
| Registration | `invalid_definition`, `unsupported_schema_version`, `invalid_app_id`, `reserved_app_id`, `duplicate_app_id`, `app_not_found`, `bundled_app` |
| Definition | `invalid_name`, `invalid_description`, `invalid_developer`, `invalid_category`, `invalid_asset_url`, `asset_owner_mismatch`, `invalid_permissions`, `unknown_permission`, `duplicate_permission`, `invalid_orientation`, `invalid_bridge_mode` |
| State/message | `phone_closed`, `app_not_active`, `invalid_payload`, `payload_too_large`, `message_queue_full` |
| Notification | `permission_denied`, `invalid_notification`, `invalid_notification_title`, `invalid_notification_text`, `invalid_notification_subtitle`, `invalid_notification_sound`, `invalid_notification_route`, `invalid_title`, `invalid_text`, `invalid_app_id`, `device_not_equipped` |
| Iframe request | `permission_denied`, `unsupported_method`, `invalid_storage_request`, `invalid_notification`, `invalid_app_open`, `app_not_found`, `open_data_not_supported`, `open_failed`, `request_failed` |
| Storage | `storage_not_allowed`, `rate_limited`, `invalid_storage_key`, `invalid_storage_value`, `invalid_storage_revision`, `storage_value_too_large`, `storage_conflict`, `storage_quota_exceeded`, `storage_key_limit` |

## Trusted adapter API

This section is not the normal Creator API. It exists only for isolated phone-provider compatibility adapters.

Only a resource explicitly listed in `Config.CustomApps.TrustedAdapters` can call a `FromAdapter` export. The adapter passes the original owner resource explicitly; Sky Phone validates the adapter, the original owner, resource state, and the existing adapter/owner binding.

~~~lua
Config.CustomApps.TrustedAdapters = {
    ["my_phone_adapter"] = true,
}
~~~

Client-only trusted adapter exports:

- `AddCustomAppFromAdapter(ownerResource, definition)`
- `UpdateCustomAppFromAdapter(ownerResource, definition)`
- `RemoveCustomAppFromAdapter(ownerResource, appId)`
- `OpenCustomAppFromAdapter(ownerResource, appId, payload?)`
- `CloseCustomAppFromAdapter(ownerResource, appId)`
- `CloseActiveCustomAppFromAdapter(ownerResource)`
- `SendCustomAppMessageFromAdapter(ownerResource, appId, payload)`
- `SendCustomAppNotificationFromAdapter(ownerResource, appId, notification)`

Server-only trusted adapter exports:

- `AddCustomAppPolicyFromAdapter(ownerResource, definition)`
- `UpdateCustomAppPolicyFromAdapter(ownerResource, definition)`
- `RemoveCustomAppPolicyFromAdapter(ownerResource, appId)`

There is currently no server `SendAppMessageFromAdapter` or `SendCustomAppNotificationFromAdapter` export. `assetResource` and `compatibility` are adapter mapping fields, not part of the native first-party creator schema.

Normal app resources must use the direct exports and must never pass an owner resource themselves. Provider aliases and their provider-specific signatures are compatibility contracts, not aliases for every native export documented here.
