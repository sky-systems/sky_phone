# Discord audit logging

Configure Discord logging in `config/WebHooks.lua`, then restart `sky_phone`,
or open **Phonepanel > Webhooks** to edit the settings in game.
The file and all logging code load exclusively through `server_scripts`.
Webhook URLs are separate from the public `Config` and Phone Configurator sync.
No additional resource is required. The additive migration automatically creates
`sky_phone_webhooks`, also included in the clean-install SQL.

```lua
WebHooks = {
    Enabled = true,
    Username = "Sky Phone",
    AvatarUrl = "", -- Optional HTTPS image URL; empty keeps Discord's webhook avatar
    Default = "", -- Optional fallback webhook
    Calls = "", -- Paste the webhook for your call audit channel
    Messages = "", -- Paste the webhook for your SMS audit channel
    Picstagram = "",
    Feather = "",
    FlipTok = "",
    SkyPic = "",
    -- Keep the other categories and delivery settings from the supplied file.
}
```

These are administrative audit channels. Entries can contain private messages,
mail, snap captions, media links, account IDs, phone numbers and device IMEIs.
The channels must be accessible only to the staff who should see that content.

## Routing and appearance

- Every category has its own URL in `config/WebHooks.lua`.
- An empty category (`""`) uses `Default`. With no default URL, it produces no logs.
- `false` explicitly disables a category, including its default fallback.
- `Enabled = false` disables all logging.
- `Username` and `AvatarUrl` apply to every webhook message. Leave `AvatarUrl`
  empty to preserve the avatar configured on the Discord webhook.
- `Actions` can override an individual action. Use its callback name without
  `sky_phone:`, for example `Actions["skypic:send-snap"]`. A URL overrides the
  category, `false` disables that action, and `""` inherits the category.
- Use a standard Discord incoming webhook URL in a text channel. URLs with query
  parameters and forum/thread destinations are not supported.

## Phonepanel editor

The **Webhooks** tab uses the existing `phonepanel` permission and requires
`Config.AdminPanel.Enabled`. Every read and save checks permission and rate limits
on the server. It works independently of `Config.PhoneConfigurator.Enabled`.

- Edit the logging toggle, webhook name, avatar URL, queue limit and retry limit.
- Choose app channels or filter individual actions, including the prepared SkyPic
  actions and server-owned call/media events.
- **Own webhook** lets you enter a replacement URL. Previously saved URLs are
  never returned to NUI, even for admins; leaving the input empty retains the
  existing URL. A route without its own stored URL requires a new URL.
- **Inherit** uses the action's category or the category's default channel.
  **Disabled** stops that route. **File setting** removes the SQL override and
  restores the corresponding value from `WebHooks.lua`.
- Use Phonepanel's top save button. Closing or reloading with unsaved changes
  shows the existing discard confirmation. On a revision conflict, reload the
  saved settings and apply the edit again.

Only changed settings are stored as overrides in `sky_phone_webhooks`. They take
effect for newly queued records immediately and survive restarts. Existing queued
records keep their original destination and appearance. File edits take effect
after a restart for settings without a SQL override. General settings have a
button to restore their file values, too. The admin audit records changed field
names and revision only; it never includes the submitted URLs.

The database payload contains the webhook secrets, so include this table only in
server/admin backups. It is never included in public configuration broadcasts.
The only client-to-server submission of a URL is an explicitly edited field in
an authorized admin save; stored URLs are not distributed to clients.

## Coverage

| Category                                                                   | Recorded actions                                                                                                                                                                                                                                                                                            |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Calls`                                                                    | Ringing, answered, rerouted and ended calls; busy/unavailable terminal results; cancellation, decline, missed/no-answer, disconnect and insufficient-funds outcomes; mute, speaker and blocking changes. Includes normal, company and payphone calls, both participants, timestamps and connected duration. |
| `Messages`, `Contacts`                                                     | Sent SMS, text and attachment metadata, read conversations, deleted conversations; created/edited/deleted contacts and favorites.                                                                                                                                                                           |
| `Picstagram`                                                               | Registration/login/logout, profiles, posts, edits, published/archived/removed states, comments, stories/views/removals, reactions, follows/requests, blocks, reports, moderation and verification commands.                                                                                                 |
| `Feather`                                                                  | Profiles, posts/replies/quotes, deletion, reactions/bookmarks, follows/connections, blocks and reports.                                                                                                                                                                                                     |
| `FlipTok`                                                                  | Accounts/profiles, publications/drafts, media links, captions, comments, reactions, follows, views/shares, deletion, reports, blocks and verification commands.                                                                                                                                             |
| `SkyPic`                                                                   | Profiles/account deletion, friends/requests/blocks, text messages/read/save/unsave/deletion, snaps with recipients/media/caption/overlay, open/replay, stories and Spotlight publications/comments/likes/views/removals/reports.                                                                            |
| `DarkChat`, `Flare`                                                        | Profiles, conversations/matches, text and attachment metadata, read state, reactions, deletions/clears, contacts, blocking/reporting and discovery/swipe changes.                                                                                                                                           |
| `Mail`                                                                     | Accounts, folders, drafts, sent mail with recipients/subject/body, read/unread, moves, trash/restore and deletion.                                                                                                                                                                                          |
| `Marketplace`, `Pages`                                                     | Profiles, listings/posts with content, edits/status changes, favorites/reactions, inquiries, messages, offers and their responses, blocks/reports and deletion.                                                                                                                                             |
| `Companies`                                                                | Service requests, messages, assignment/claim/cancellation/status changes, availability, profiles, opening hours, services and announcements. Calls also go to `Calls`.                                                                                                                                      |
| `Banking`, `Crypto`, `Billing`                                             | Transfers, trades/deposits/withdrawals, account actions, invoice reads/disputes/payments; invoice creation/cancellation and billing-account withdrawals through server exports.                                                                                                                             |
| `Uploads`, `Gallery`, `Memos`                                              | Verified media uploads/imports with links, gallery favorites/deletions, voice memo creation/edits/deletions with stored audio links.                                                                                                                                                                        |
| `Notes`, `Calendar`, `WeazelNews`, `CityWarn`                              | Creation, content edits, deletions and supported publication/resolution states.                                                                                                                                                                                                                             |
| `CrewLink`                                                                 | Accounts/profiles, groups/membership/invitations, ownership/roles, pings, including allowed external ping exports.                                                                                                                                                                                          |
| `SkyRide`, `Garage`, `Housing`                                             | Ride requests/status/rating/payment details, driver status, valet requests/cancellations/completion and housing action requests.                                                                                                                                                                            |
| `Radio`, `Health`, `Music`, `Map`                                          | Radio connections/settings, health profile/activity changes, music/playlists and map marker changes.                                                                                                                                                                                                        |
| `EasyShare`, `Account`, `Device`, `Security`, `Sim`, `Admin`, `CustomApps` | Share requests/responses, account/device actions, saved setting namespace/revision, factory resets, unlock/PIN action statuses, SIM changes, admin actions/config saves/tone changes and custom app storage keys.                                                                                           |

The complete callback catalog and accepted request fields are in
`source/server/logging_actions.lua`. Feed/bootstrap polling, upload chunks and
other purely read-only queries are excluded. `read`/`viewed` logs are included
where opening content changes an app's read/view state.

Callback logs mean the server handler returned `success = true`. Idempotent
actions can succeed without changing a row. Rejected requests and failed
transactions do not produce successful mutation logs. Call lifecycle and verified
uploads are recorded directly at their server state transitions, including paths
that do not originate in a NUI callback.

## Content and limits

Records include the server's actor identity, allowlisted accepted request fields,
the server result and, for the principal content editing/deletion operations,
persisted content before and after the action. Content lookups are parameterized
and failures retain the basic action log with an explicit diagnostic. Bulk
deletions include a bounded preview of up to 101 rows and a limit indication.

Password/PIN values, peppers, session tokens, API keys, webhook URLs, IP/license
fields and raw binary/base64 payloads are filtered. Administrative password
reveal actions log their occurrence without the revealed password. Device/config
saves log their metadata without serializing the complete configuration or
arbitrary storage payload. Discord mentions are disabled.

Phone calls record participants, status and duration. The voice bridge does not
provide call recordings or transcripts, so conversation audio is not logged.
Stored media links are logged when available. Inline voice-message binary data
is represented by its message type/duration/MIME metadata. Media links can stop
working after their source file is deleted. Scheduled expiration is represented
by the stored expiration timestamp; cleanup jobs do not emit individual expiry
events.

Long content is split into numbered Discord messages with a shared record ID,
respecting UTF-8 and embed limits. A record is bounded to 64 KB of string content,
2,000 values, depth 10 and 24 continuation parts; exceeding a limit is marked in
the content. Delivery is queued by webhook URL, so categories sharing a webhook
also share its cooldown. Rate limits and transient HTTP errors retry up to
`MaxAttempts`; permanent HTTP failures and full queues produce server warnings
without exposing URLs or response bodies. `QueueLimit` bounds pending Discord
messages. The queue is in memory, so pending records can be lost on a resource
stop or server crash; this is not a durable audit archive.

Implementation references:
[Discord webhooks](https://docs.discord.com/developers/resources/webhook),
[Discord rate limits](https://docs.discord.com/developers/topics/rate-limits),
[FiveM PerformHttpRequest](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/PerformHttpRequest/).

## SkyPic branch compatibility

This branch is based on `dev`. It does not copy or merge the app from
`feat/skypic`. The catalog already recognizes that branch's callback names, and
content lookups include its snap, story and Spotlight tables. Logging takes
effect automatically once the SkyPic app is merged and loaded. Without SkyPic,
no SkyPic database tables are queried.

## Verification

From the repository root:

```sh
lua5.4 tests/server_logging.lua
lua5.4 tests/server_webhooks.lua
lua5.4 tests/server_calls.lua
lua5.4 tests/client_nui_server_bridge.lua
```

To exercise the actual unmerged SkyPic server module, set
`SKY_PHONE_SKYPIC_SOURCE` to its `sky_phone/source/server/skypic.lua` path before
running `tests/server_logging.lua`. Once the feature is merged, this part of the
test runs automatically against the local module.

The tests stub HTTP, timers and storage. They verify channel/action routing,
appearance, credential filtering, failed mutations, snapshots, concurrent
callbacks, long UTF-8 content, rate limits/retries, queue overflow, the real
callback dispatcher and server-only manifest loading. The call tests cover
server API and timer termination, participant data and duplicate suppression.
They do not contact Discord.

The webhook editor tests cover permission/rate-limit checks, masked responses,
secret-free audit data, validation, atomic rejection, concurrent revisions,
file-value restoration and persistence after restart. Frontend store tests cover
draft retention on errors and clearing secrets after saving or reloading.

On a test server, configure two distinct webhook channels, restart the resource,
then create/edit/delete social content and send a message. Check an answered and
unanswered call, a company call, a payphone call and a verified upload/deletion.
After merging SkyPic, also send/open/replay/delete a snap and publish/remove a
story and Spotlight item. Live FiveM/Discord validation is still required before
production use.
