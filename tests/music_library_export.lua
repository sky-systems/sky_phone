-- Run from the sky_phone repository with Lua 5.4.
-- Exercise the actual public export, including a phone/account swap during DB reads.
local file = assert(io.open("sky_phone/source/server/music.lua", "r"))
local source = file:read("*a")
file:close()
local start = assert(source:find('exports("GetMusicLibrary"', 1, true))
local finish = assert(source:find("\nlocal function owned_playlist", start, true))
local handler
exports = function(name, callback)
    assert(name == "GetMusicLibrary")
    handler = callback
end
local current = { imei = "test-phone", accountId = "test-account" }
local after_read
SkyPhoneDeviceDirectory = {
    GetOnlineBySource = function(player)
        assert(player == 42)
        return current, "device_not_found"
    end,
}
local expected = { serverTracks = {}, youtubeTracks = {}, playlists = {} }
local function read_library(account, imei)
    assert(account == "test-account" and imei == "test-phone")
    if after_read then after_read() end
    return expected
end
assert(load("local bootstrap = ...\n" .. source:sub(start, finish - 1)))(read_library)
assert(handler(42) == expected)
after_read = function() current = { imei = "different-phone", accountId = "test-account" } end
local library, reason = handler(42)
assert(library == nil and reason == "device_changed")
current = { imei = "test-phone", accountId = "test-account" }
after_read = function() current = { imei = "test-phone", accountId = "different-account" } end
library, reason = handler(42)
assert(library == nil and reason == "device_changed")
current = nil
library, reason = handler(42)
assert(library == nil and reason == "device_not_found")
print("PASS: Music library export validates equipped device and account before and after reads.")
