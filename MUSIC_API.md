# Music library export

`exports.sky_phone:GetMusicLibrary(source)` is a server-only, read-only export for integrations
such as vehicle CarPlay. It returns the Music library of the player's currently equipped phone.
An authenticated account owns its library; otherwise the device IMEI owns the library.

On success the result contains:

- `serverTracks`: configured local audio, with `id`, `title`, `artist`, `url` and optional `artwork`.
- `youtubeTracks`: saved YouTube tracks, with `id`, `videoId`, `title`, `artist` and optional `artwork`.
- `playlists`: `id`, `name` and ordered `entries` of `{ source = "server" | "youtube", songId = "..." }`.

The UI does not have to be open. Phone ownership/equipped-device resolution is performed before
and after the asynchronous reads. Missing devices return `nil, reason`; a device/account switch
during the reads returns `nil, "device_changed"`. There is no callback accepting arbitrary account IDs
or IMEIs. Calling resources must authorize and rate-limit their own player-facing requests.

```lua
local library, reason = exports.sky_phone:GetMusicLibrary(source)
if not library then
    print(("[my_resource] Music library unavailable: %s"):format(reason))
    return
end
-- Resolve each entry against its source-specific track array before playback.
```

Playlist writes continue through the Music app. This export introduces no dependency from
Sky Phone to its callers. `tests/music_library_export.lua` exercises the export's device/account checks.
