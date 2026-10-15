-- Run from the repository root with Lua 5.4.
local file = assert(io.open("sky_phone/source/server/realtime.lua", "rb"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local function edge(", 1, true))
local last = assert(source:find("local function public_config(", first, true))
local snapshot_first = assert(source:find("local function snapshot_matches(", 1, true))
local snapshot_last = assert(source:find("local function release(", snapshot_first, true))
local sent = 0
local environment = setmetatable({
    nearby_distance = function() return true end,
    TriggerClientEvent = function() sent = sent + 1 end,
    json = { encode = function() error("Snapshots must not serialize unchanged state for comparison") end },
}, { __index = _G })
local snapshot, broadcast = assert(load(source:sub(first, last - 1)
    .. source:sub(snapshot_first, snapshot_last - 1) .. "\nreturn snapshot, broadcast", "realtime_snapshot", "t", environment))()

local room = { id = "stream", kind = "live", app = "picstagram", title = "Test", hostName = "Example",
    profileId = 1, host = 1, transport = "cloudflare", members = {}, messages = {} }
room.members[1] = { role = "host", ready = true, session = "host-session", tracks = {
    { trackName = "camera", kind = "video" }, { trackName = "microphone", kind = "audio" } } }
for viewer = 2, 33 do room.members[viewer] = { role = "viewer", ready = true, tracks = {} } end
for message = 1, 50 do
    room.messages[message] = { id = message, text = string.rep("x", 300), at = message }
end
broadcast(room)
local original = snapshot(room, 2)
local original_revision = original.revision
sent = 0
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 20 do broadcast(room) end
local allocated = (collectgarbage("count") - before) / 20
collectgarbage("restart")
assert(allocated < 8, ("Unchanged realtime ticks allocated %.2f KiB"):format(allocated))
assert(sent == 0 and snapshot(room, 2) == original and original.revision == original_revision)

room.messages = { table.unpack(room.messages) }
room.messages[#room.messages + 1] = { id = 51, text = "new", at = 51 }
table.remove(room.messages, 1)
broadcast(room)
local chatted = snapshot(room, 2)
assert(chatted.revision > original_revision and chatted.messages[50].id == 51)
assert(original.messages[1].id == 1 and original.messages[50].id == 50,
    "Later chats must not mutate snapshots already in flight")
room.members[1].tracks[1].trackName = "replacement-camera"
room.members[1].session = "replacement-session"
local tracks = snapshot(room, 2)
assert(tracks.revision > chatted.revision and tracks.peers[1].tracks[1].trackName == "replacement-camera")
assert(tracks.peers[1].tracks[1].sessionId == "replacement-session")
assert(chatted.peers[1].tracks[1].trackName == "camera", "Older track snapshots must remain immutable")

room.members[34] = { role = "nearby", ready = true, tracks = {}, gain = 0.71 }
local near = snapshot(room, 34)
assert(#near.messages == 0 and #near.peers == 1 and near.peers[1].sends)
local host = snapshot(room, 1)
room.members[34].gain = 0.72
assert(snapshot(room, 1) == host, "Changes below the transmitted gain step must reuse the snapshot")
room.members[34].gain = 0.8
local louder = snapshot(room, 1)
assert(louder.revision > host.revision, "Audible gain changes must invalidate the host snapshot")
room.members[34].ready = false
local disconnected = snapshot(room, 1)
assert(disconnected.revision > louder.revision and #disconnected.peers == #louder.peers - 1)
room.members[33] = nil
local fewer = snapshot(room, 2)
assert(fewer.viewers == tracks.viewers - 1 and fewer.revision > tracks.revision)
room.title = "Changed title"
assert(snapshot(room, 2).title == "Changed title")
print(("PASS: realtime immutable chat/tracks, gain, readiness, viewers and metadata; unchanged 33-member ticks %.2f KiB/tick"):format(allocated))
