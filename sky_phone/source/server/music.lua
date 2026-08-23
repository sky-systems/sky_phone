Bridge.Database.AfterMigration("sky_phone", function()
local server_tracks = {}
local server_tracks_by_id = {}
local configured_track_ids = {}
local music_asset_directory = "config/music"
local music_asset_prefix = music_asset_directory .. "/"
local music_asset_extensions = {
    audio = { "ogg", "mp3" },
    artwork = { "webp", "png", "jpg", "jpeg" },
}
local music_asset_types = {}

for kind, extensions in pairs(music_asset_extensions) do
    for _, extension in ipairs(extensions) do
        music_asset_types[extension] = kind
    end
end

local function trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or nil
end

local function text_length(value)
    return type(value) == "string" and utf8.len(value) or nil
end

local function optional_text(value)
    local normalized = trim(value)
    return normalized ~= "" and normalized or nil
end

local function safe_music_asset_name(name)
    return type(name) == "string"
        and name ~= ""
        and name ~= "."
        and name ~= ".."
        and not name:find("[/\\]")
        and not name:find("%c")
end

local function add_music_asset(index, relative_path, file_name)
    local stem, extension = file_name:match("^(.+)%.([^.]+)$")
    extension = extension and extension:lower() or nil
    local kind = extension and music_asset_types[extension] or nil
    if not stem or not kind then
        return
    end

    local id = stem:lower()
    local by_id = index[kind][id]
    if not by_id then
        by_id = {}
        index[kind][id] = by_id
    end

    local candidates = by_id[extension]
    if not candidates then
        candidates = {}
        by_id[extension] = candidates
    end
    candidates[#candidates + 1] = music_asset_prefix .. relative_path
end

local function discover_music_assets()
    local index = { audio = {}, artwork = {} }
    if type(io.readdir) ~= "function" then
        Bridge.Debug(
            "error",
            "[sky_phone] Automatic music discovery requires io.readdir. Update the FXServer artifacts.",
            { always = true }
        )
        return nil
    end

    local mount_root = ("@%s/%s"):format(GetCurrentResourceName(), music_asset_directory)
    local visited_entries = 0
    local failure_reason = nil

    local function walk(mount_path, relative_directory, depth)
        if failure_reason then
            return true
        end
        if depth > 32 then
            failure_reason = "directory nesting exceeds 32 levels"
            return true
        end

        local directory = io.readdir(mount_path)
        if not directory then
            failure_reason = ("could not read '%s'"):format(mount_path)
            return true
        end

        local names = {}
        local has_entries = false
        for name in directory:lines() do
            has_entries = true
            if safe_music_asset_name(name) then
                names[#names + 1] = name
            else
                Bridge.Debug(
                    "warn",
                    "[sky_phone] Skipped unsafe music path entry '%s'.",
                    tostring(name),
                    { always = true }
                )
            end
        end
        directory:close()
        table.sort(names)

        for _, name in ipairs(names) do
            if visited_entries >= 10000 then
                failure_reason = "more than 10000 files and directories were found"
                return true
            end
            visited_entries = visited_entries + 1
            local relative_path = relative_directory == ""
                and name
                or (relative_directory .. "/" .. name)
            local asset_path = mount_path .. "/" .. name

            -- Cfx returns an empty directory listing for regular files. Walking every
            -- entry is portable; io.open cannot distinguish directories on Linux.
            if not walk(asset_path, relative_path, depth + 1) then
                add_music_asset(index, relative_path, name)
            end
        end

        return has_entries
    end

    local success, scan_error = pcall(walk, mount_root, "", 0)
    if not success then
        failure_reason = tostring(scan_error)
    end
    if failure_reason then
        Bridge.Debug(
            "error",
            "[sky_phone] Music asset discovery failed; no server tracks were loaded: %s",
            failure_reason,
            { always = true }
        )
        return nil
    end

    return index
end

local function resolve_music_asset(index, id, kind)
    local by_extension = index[kind][id:lower()]
    if not by_extension then
        return nil, "missing"
    end

    for _, extension in ipairs(music_asset_extensions[kind]) do
        local candidates = by_extension[extension]
        if candidates then
            table.sort(candidates)
            if #candidates > 1 then
                return nil, "ambiguous", candidates
            end
            return candidates[1]
        end
    end

    return nil, "missing"
end

local function music_asset_url(path)
    local encoded_path = path:gsub("([^A-Za-z0-9%-%._~/])", function(character)
        return ("%%%02X"):format(character:byte())
    end)
    return ("https://cfx-nui-%s/%s"):format(GetCurrentResourceName(), encoded_path)
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local playlist_add_locks = {}

local function with_playlist_add_lock(playlist_id, callback)
    local previous_lock = playlist_add_locks[playlist_id]
    local current_lock = promise.new()
    playlist_add_locks[playlist_id] = current_lock

    if previous_lock then
        Citizen.Await(previous_lock)
    end

    local success, result = xpcall(callback, debug.traceback)
    current_lock:resolve(true)
    if playlist_add_locks[playlist_id] == current_lock then
        playlist_add_locks[playlist_id] = nil
    end
    if not success then
        error(result, 0)
    end
    return result
end

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = rows[1] and rows[1].id
    if type(id) ~= "string" then
        error("[sky_phone] Database did not generate a music id.")
    end
    return id
end

local function normalize_server_tracks()
    local music_assets = discover_music_assets()
    if not music_assets then
        return
    end

    server_tracks = {}
    server_tracks_by_id = {}
    configured_track_ids = {}

    for index, configured in ipairs(Config.Music.Tracks or {}) do
        local id = type(configured) == "table" and trim(configured.Id) or nil
        local title = type(configured) == "table" and trim(configured.Title) or nil
        local artist = type(configured) == "table" and trim(configured.Artist) or nil
        local title_length = text_length(title)
        local artist_length = text_length(artist)

        if not id
            or not id:match("^[A-Za-z0-9_-]+$")
            or #id > 48
            or not title_length
            or title_length < 1
            or title_length > 160
            or not artist_length
            or artist_length < 1
            or artist_length > 120
        then
            Bridge.Debug(
                "error",
                "[sky_phone] Ignored invalid Config.Music.Tracks entry at index %s. Only Id, Title, and Artist are required.",
                tostring(index),
                { always = true }
            )
        elseif configured_track_ids[id:lower()] then
            Bridge.Debug(
                "error",
                "[sky_phone] Ignored duplicate Config.Music.Tracks Id '%s' at index %s. IDs are case-insensitive.",
                id,
                tostring(index),
                { always = true }
            )
        else
            configured_track_ids[id:lower()] = true
            local file, file_error, file_candidates = resolve_music_asset(music_assets, id, "audio")
            local artwork, artwork_error, artwork_candidates = resolve_music_asset(music_assets, id, "artwork")

            if file_error == "missing" then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Ignored music track '%s': no %s.ogg or %s.mp3 was found under config/music.",
                    id,
                    id,
                    id,
                    { always = true }
                )
            elseif file_error == "ambiguous" then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Ignored music track '%s': multiple equally preferred audio files were found: %s",
                    id,
                    table.concat(file_candidates, ", "),
                    { always = true }
                )
            else
                if artwork_error == "ambiguous" then
                    Bridge.Debug(
                        "warn",
                        "[sky_phone] Music track '%s' was loaded without artwork because multiple equally preferred images were found: %s",
                        id,
                        table.concat(artwork_candidates, ", "),
                        { always = true }
                    )
                    artwork = nil
                end

                local track = {
                    id = id,
                    source = "server",
                    title = title,
                    artist = artist,
                    url = music_asset_url(file),
                    artwork = artwork and music_asset_url(artwork) or nil,
                }
                server_tracks[#server_tracks + 1] = track
                server_tracks_by_id[id] = track
            end
        end
    end
end

normalize_server_tracks()

AddEventHandler("sky_phone:configurator:serverUpdated", normalize_server_tracks)

local function session_owner(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, nil, error_response
    end
    local account = SkyPhone.RequireAccount(source)
    return account and account.id or nil, session.imei
end

local function owner_condition(account_id, imei, alias)
    local prefix = alias and ("`" .. alias .. "`.") or ""
    if account_id then
        return prefix .. "`account_id` = ?", { account_id }
    end
    return prefix .. "`account_id` IS NULL AND " .. prefix .. "`device_imei` = ?", { imei }
end

local function append_params(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function youtube_track_dto(row)
    local video_id = row.video_id
    return {
        id = row.id,
        source = "youtube",
        videoId = video_id,
        title = row.title,
        artist = row.artist,
        artwork = "https://i.ytimg.com/vi/" .. video_id .. "/hqdefault.jpg",
        createdAt = (tonumber(row.created_at_unix) or 0) * 1000,
    }
end

local function list_youtube_tracks(account_id, imei)
    local condition, params = owner_condition(account_id, imei)
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `video_id`, `title`, `artist`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_music_youtube_songs`
        WHERE %s
        ORDER BY `created_at` DESC, `id`
    ]]):format(condition), params)
    local tracks = {}
    for index, row in ipairs(rows) do
        tracks[index] = youtube_track_dto(row)
    end
    return tracks
end

local function list_playlists(account_id, imei)
    local condition, params = owner_condition(account_id, imei)
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `name`, UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_music_playlists`
        WHERE %s
        ORDER BY `updated_at` DESC, `created_at` DESC
    ]]):format(condition), params)
    local playlists = {}
    local playlists_by_id = {}
    for index, row in ipairs(rows) do
        local playlist = {
            id = row.id,
            name = row.name,
            entries = {},
            createdAt = (tonumber(row.created_at_unix) or 0) * 1000,
        }
        playlists[index] = playlist
        playlists_by_id[row.id] = playlist
    end

    if #rows == 0 then
        return playlists
    end

    local item_condition, item_params = owner_condition(account_id, imei, "p")
    local items = Bridge.Database.Query(([[
        SELECT `i`.`playlist_id`, `i`.`source`, `i`.`song_id`
        FROM `sky_phone_music_playlist_items` AS `i`
        INNER JOIN `sky_phone_music_playlists` AS `p` ON `p`.`id` = `i`.`playlist_id`
        WHERE %s
        ORDER BY `i`.`position`, `i`.`id`
    ]]):format(item_condition), item_params)
    for _, item in ipairs(items) do
        local playlist = playlists_by_id[item.playlist_id]
        if playlist then
            playlist.entries[#playlist.entries + 1] = {
                source = item.source,
                songId = item.song_id,
            }
        end
    end
    return playlists
end

local function bootstrap(account_id, imei)
    return {
        serverTracks = server_tracks,
        youtubeTracks = list_youtube_tracks(account_id, imei),
        playlists = list_playlists(account_id, imei),
    }
end

local function owned_playlist(account_id, imei, playlist_id)
    local condition, owner_params = owner_condition(account_id, imei)
    local params = { playlist_id }
    append_params(params, owner_params)
    local rows = Bridge.Database.Query(([[
        SELECT `id` FROM `sky_phone_music_playlists`
        WHERE `id` = ? AND %s LIMIT 1
    ]]):format(condition), params)
    return rows[1] ~= nil
end

local function valid_personal_song(account_id, imei, song_id)
    local condition, owner_params = owner_condition(account_id, imei)
    local params = { song_id }
    append_params(params, owner_params)
    local rows = Bridge.Database.Query(([[
        SELECT `id` FROM `sky_phone_music_youtube_songs`
        WHERE `id` = ? AND %s LIMIT 1
    ]]):format(condition), params)
    return rows[1] ~= nil
end

Bridge.Callbacks.Register("sky_phone:music:bootstrap", function(source)
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:add-youtube", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local payload = type(data) == "table" and data or {}
    local video_id = SkyPhoneYouTube.ParseId(payload.url)
    if not video_id then
        return { success = false, error = "invalid_youtube_url" }
    end
    local custom_title = optional_text(payload.title)
    local custom_artist = optional_text(payload.artist)
    local custom_title_length = text_length(custom_title)
    local custom_artist_length = text_length(custom_artist)
    if (custom_title and (not custom_title_length or custom_title_length > 160))
        or (custom_artist and (not custom_artist_length or custom_artist_length > 120))
    then
        return { success = false, error = "invalid_song_metadata" }
    end

    local condition, owner_params = owner_condition(account_id, imei)
    local duplicate_params = { video_id }
    append_params(duplicate_params, owner_params)
    local duplicate = Bridge.Database.Query(([[
        SELECT `id` FROM `sky_phone_music_youtube_songs`
        WHERE `video_id` = ? AND %s LIMIT 1
    ]]):format(condition), duplicate_params)
    if duplicate[1] then
        return { success = false, error = "song_exists" }
    end
    local count_rows = Bridge.Database.Query(([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_music_youtube_songs` WHERE %s
    ]]):format(condition), owner_params)
    if (tonumber(count_rows[1] and count_rows[1].count) or 0) >= Config.Music.MaximumPersonalSongs then
        return { success = false, error = "song_limit" }
    end

    local metadata = (not custom_title or not custom_artist)
        and SkyPhoneYouTube.FetchMetadata(video_id)
        or nil
    local title = custom_title or metadata and metadata.title or "YouTube " .. video_id
    local artist = custom_artist or metadata and metadata.artist or "YouTube"
    local id = uuid()
    if account_id then
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_music_youtube_songs`
                (`id`, `account_id`, `device_imei`, `video_id`, `title`, `artist`)
            VALUES (?, ?, NULL, ?, ?, ?)
        ]], { id, account_id, video_id, title, artist })
    else
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_music_youtube_songs`
                (`id`, `account_id`, `device_imei`, `video_id`, `title`, `artist`)
            VALUES (?, NULL, ?, ?, ?, ?)
        ]], { id, imei, video_id, title, artist })
    end
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:remove-youtube", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local song_id = type(data) == "table" and data.id or nil
    if type(song_id) ~= "string" or not valid_personal_song(account_id, imei, song_id) then
        return { success = false, error = "song_not_found" }
    end

    local condition, owner_params = owner_condition(account_id, imei, "p")
    local item_params = { song_id }
    append_params(item_params, owner_params)
    Bridge.Database.Query(([[
        DELETE `i` FROM `sky_phone_music_playlist_items` AS `i`
        INNER JOIN `sky_phone_music_playlists` AS `p` ON `p`.`id` = `i`.`playlist_id`
        WHERE `i`.`source` = 'youtube' AND `i`.`song_id` = ? AND %s
    ]]):format(condition), item_params)

    local song_condition, song_owner_params = owner_condition(account_id, imei)
    local delete_params = { song_id }
    append_params(delete_params, song_owner_params)
    Bridge.Database.Query(([[
        DELETE FROM `sky_phone_music_youtube_songs` WHERE `id` = ? AND %s
    ]]):format(song_condition), delete_params)
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:create-playlist", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local name = trim(type(data) == "table" and data.name or nil)
    local name_length = text_length(name)
    if not name_length or name_length < 1 or name_length > Config.Music.PlaylistNameMaxLength then
        return { success = false, error = "invalid_playlist" }
    end

    local condition, owner_params = owner_condition(account_id, imei)
    local count_rows = Bridge.Database.Query(([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_music_playlists` WHERE %s
    ]]):format(condition), owner_params)
    if (tonumber(count_rows[1] and count_rows[1].count) or 0) >= Config.Music.MaximumPlaylists then
        return { success = false, error = "playlist_limit" }
    end

    local id = uuid()
    if account_id then
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_music_playlists` (`id`, `account_id`, `device_imei`, `name`)
            VALUES (?, ?, NULL, ?)
        ]], { id, account_id, name })
    else
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_music_playlists` (`id`, `account_id`, `device_imei`, `name`)
            VALUES (?, NULL, ?, ?)
        ]], { id, imei, name })
    end
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:rename-playlist", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local playlist_id = type(data) == "table" and data.id or nil
    local name = trim(type(data) == "table" and data.name or nil)
    local name_length = text_length(name)
    if type(playlist_id) ~= "string"
        or not name_length
        or name_length < 1
        or name_length > Config.Music.PlaylistNameMaxLength
    then
        return { success = false, error = "invalid_playlist" }
    end

    if not owned_playlist(account_id, imei, playlist_id) then
        return { success = false, error = "playlist_not_found" }
    end
    local condition, owner_params = owner_condition(account_id, imei)
    local params = { name, playlist_id }
    append_params(params, owner_params)
    Bridge.Database.Query(([[
        UPDATE `sky_phone_music_playlists` SET `name` = ?
        WHERE `id` = ? AND %s
    ]]):format(condition), params)
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:delete-playlist", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local playlist_id = type(data) == "table" and data.id or nil
    if type(playlist_id) ~= "string" then
        return { success = false, error = "invalid_playlist" }
    end
    local condition, owner_params = owner_condition(account_id, imei)
    local params = { playlist_id }
    append_params(params, owner_params)
    local result = Bridge.Database.Query(([[
        DELETE FROM `sky_phone_music_playlists` WHERE `id` = ? AND %s
    ]]):format(condition), params)
    if affected_rows(result) ~= 1 then
        return { success = false, error = "playlist_not_found" }
    end
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:add-to-playlist", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local playlist_id = type(data) == "table" and data.playlistId or nil
    local source_type = type(data) == "table" and data.source or nil
    local song_id = type(data) == "table" and data.songId or nil
    if type(playlist_id) ~= "string"
        or type(song_id) ~= "string"
        or not owned_playlist(account_id, imei, playlist_id)
        or (source_type ~= "server" and source_type ~= "youtube")
        or (source_type == "server" and not server_tracks_by_id[song_id])
        or (source_type == "youtube" and not valid_personal_song(account_id, imei, song_id))
    then
        return { success = false, error = "invalid_song" }
    end

    local mutation_error = with_playlist_add_lock(playlist_id, function()
        local counts = Bridge.Database.Query([[
            SELECT COUNT(*) AS `count`, COALESCE(MAX(`position`), 0) AS `last_position`,
                COALESCE(MAX(`source` = ? AND `song_id` = ?), 0) AS `already_exists`
            FROM `sky_phone_music_playlist_items` WHERE `playlist_id` = ?
        ]], { source_type, song_id, playlist_id })
        if tonumber(counts[1] and counts[1].already_exists) == 1 then
            return "song_already_in_playlist"
        end
        if (tonumber(counts[1] and counts[1].count) or 0) >= Config.Music.MaximumPlaylistSongs then
            return "playlist_song_limit"
        end
        local insert_result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_music_playlist_items`
                (`playlist_id`, `source`, `song_id`, `position`)
            VALUES (?, ?, ?, ?)
        ]], {
            playlist_id,
            source_type,
            song_id,
            (tonumber(counts[1] and counts[1].last_position) or 0) + 1,
        })
        if affected_rows(insert_result) ~= 1 then
            return "song_already_in_playlist"
        end
        Bridge.Database.Query(
            "UPDATE `sky_phone_music_playlists` SET `updated_at` = CURRENT_TIMESTAMP WHERE `id` = ?",
            { playlist_id }
        )
        return nil
    end)
    if mutation_error then
        return { success = false, error = mutation_error }
    end
    return { success = true, data = bootstrap(account_id, imei) }
end)

Bridge.Callbacks.Register("sky_phone:music:remove-from-playlist", function(source, data)
    if not SkyPhone.AllowOperation(source, "music_write", Config.Music.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    local playlist_id = type(data) == "table" and data.playlistId or nil
    local source_type = type(data) == "table" and data.source or nil
    local song_id = type(data) == "table" and data.songId or nil
    if type(playlist_id) ~= "string"
        or type(song_id) ~= "string"
        or (source_type ~= "server" and source_type ~= "youtube")
        or not owned_playlist(account_id, imei, playlist_id)
    then
        return { success = false, error = "invalid_song" }
    end
    Bridge.Database.Query([[
        DELETE FROM `sky_phone_music_playlist_items`
        WHERE `playlist_id` = ? AND `source` = ? AND `song_id` = ?
    ]], { playlist_id, source_type, song_id })
    return { success = true, data = bootstrap(account_id, imei) }
end)
end)
