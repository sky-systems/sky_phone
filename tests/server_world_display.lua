local events, sent, handlers, threads = {}, {}, {}, {}
local clock, owned, inventory = 1000, true, true
local locations = { [1] = 0, [2] = 2, [3] = 8, [4] = 1, [5] = 1 }
local buckets = { [1] = 0, [2] = 0, [3] = 0, [4] = 1, [5] = 0 }
local vec = {}
vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x }, vec) end
vec.__len = function(a) return math.abs(a.x) end
joaat = function(value) return value end
GetGameTimer = function() return clock end
GetPlayerRoutingBucket = function(id) return buckets[id] end
GetPlayerPed = function(id) return locations[id] and id or 0 end
GetEntityCoords = function(id) return setmetatable({ x = locations[id] or 0 }, vec) end
NetworkGetEntityFromNetworkId = function(id) return id == 101 and 10 or 0 end
NetworkGetEntityOwner = function() return owned and 1 or 2 end
GetEntityModel = function() return 'sky_phone_prop' end
DoesEntityExist = function(entity) return entity == 10 end
GetPlayers = function() return { '1', '2', '3', '4', '5' } end
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
TriggerClientEvent = function(name, target, ...) sent[#sent + 1] = { name, target, ... } end
TriggerLatentClientEvent = function(name, target, bps, ...) sent[#sent + 1] = { name, target, ... } end
SkyPhone = { RequireDeviceSession = function() return inventory and {} or nil end }
dofile('sky_phone/source/shared/phone_prop.lua')
dofile('sky_phone/source/server/world_display.lua')
local function invoke(name, ...)
    source = 1
    events['sky_phone:display:' .. name](...)
end
local function frame_count()
    local count = 0
    for _, e in ipairs(sent) do if e[1] == 'sky_phone:display:frame' then count = count + 1 end end
    return count
end
local function base64(bytes)
    local abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local out = {}
    for i = 1, #bytes, 3 do
        local a, b, c = bytes:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = abc:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = abc:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = b and abc:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or '='
        out[#out + 1] = c and abc:sub(n % 64 + 1, n % 64 + 1) or '='
    end
    return table.concat(out)
end
local jpeg = 'data:image/jpeg;base64,' .. base64(string.char(255,216,255,192,0,11,8,3,12,1,104,1,1,17,0) .. string.rep('\0',90))
assert(SkyPhoneProp.ValidFrame(jpeg))
assert(not SkyPhoneProp.ValidFrame('https://example.com'))
assert(not SkyPhoneProp.ValidFrame(jpeg .. string.rep('A',64000)))
assert(SkyPhoneProp.Model('red','sky_phone_prop') == 'sky_phone_prop_red')
assert(SkyPhoneProp.Model('red','custom_phone') == 'custom_phone')

-- Missing and non-boolean settings must never grant capture permission.
for _, config in ipairs({ {}, { Animations = {} }, { Animations = { WorldDisplayEnabled = false } },
    { Animations = { WorldDisplayEnabled = "true" } } }) do
    Config = config
    invoke('begin', 101)
    invoke('frame', 1, 1, jpeg)
    assert(#sent == 0, 'Disabled or missing configuration cannot authorize a display')
end
Config = { Animations = { WorldDisplayEnabled = true } }
inventory = false
invoke('begin', 101)
assert(#sent == 0, 'No streaming without a device session')
inventory, owned, clock = true, false, 2000
invoke('begin', 101)
assert(#sent == 0, 'Cannot publish another player prop')
owned, clock = true, 3000
invoke('begin', 101)
local permit = sent[#sent]
assert(permit[1] == 'sky_phone:display:permit' and permit[4] == 101)
local token = permit[3]
invoke('frame', token + 1, 1, jpeg)
assert(frame_count() == 0, 'Forged generation rejected')
invoke('frame', token, 1, jpeg)
assert(frame_count() == 2, 'Only same-bucket nearby spectators receive pixels')
for _, e in ipairs(sent) do
    if e[1] == 'sky_phone:display:frame' then assert(e[2] == 2 or e[2] == 5) end
end
invoke('frame', token, 2, jpeg)
assert(frame_count() == 2, 'Rate limit rejects floods')
clock = 3600
invoke('frame', token, 1, jpeg)
assert(frame_count() == 2, 'Out-of-order image rejected')
locations[2] = 9
invoke('frame', token, 2, jpeg)
assert(frame_count() == 3, 'Departed spectator receives no new image')
local stopped = false
for _, e in ipairs(sent) do
    if e[1] == 'sky_phone:display:stop' and e[2] == 2 then stopped = true; assert(e[5] == 2) end
end
assert(stopped, 'Departed spectator is cleared with sequence watermark')
invoke('end', token + 1)
clock = 4200
invoke('frame', token, 3, jpeg)
assert(frame_count() == 4, 'Stale end cannot stop active session')
invoke('end', token)
clock = 4800
invoke('frame', token, 4, jpeg)
assert(frame_count() == 4, 'Late latent frames cannot reopen a closed session')
clock = 5800
invoke('begin', 101)
local new_token = sent[#sent][3]
assert(new_token > token)
inventory = false
clock = 6400
invoke('frame', new_token, 1, jpeg)
assert(frame_count() == 4, 'Inventory loss revokes publishing')
inventory, clock = true, 7400
invoke('begin', 101)
local active_token = sent[#sent][3]
invoke('frame', active_token, 1, jpeg)
assert(frame_count() == 5)
local before = #sent
Config.Animations.WorldDisplayEnabled = false
handlers['sky_phone:configurator:serverUpdated']()
assert(#sent == before + 2, 'Disabling immediately stops the spectator and revokes the publisher')
assert(sent[#sent-1][1] == 'sky_phone:display:stop' and sent[#sent-1][2] == 5)
assert(sent[#sent][1] == 'sky_phone:display:permit' and sent[#sent][3] == nil)
clock = 8400
before = #sent
invoke('begin', 101)
invoke('frame', active_token, 2, jpeg)
assert(#sent == before, 'Disabled publishers cannot start or send delayed frames')
Config.Animations.WorldDisplayEnabled = true
handlers['sky_phone:configurator:serverUpdated']()
invoke('begin', 101)
local resumed_token = sent[#sent][3]
assert(resumed_token > active_token, 'Re-enabling grants a fresh generation')
invoke('frame', active_token, 3, jpeg)
assert(frame_count() == 5, 'Old session stays invalid after re-enabling')
invoke('frame', resumed_token, 1, jpeg)
assert(frame_count() == 6, 'New session can publish after re-enabling')
print('PASS: world display default-off gating, live disable/re-enable, ownership, palette, JPEG bounds, proximity and lifecycle')
