-- Focused tests of the real receive and deep-link seams. Run with Lua 5.4.
local callbacks, queries, events, encoded = {}, {}, {}, {}
local counter = 0
local function noop() end
local env = setmetatable({ Config = {}, IsDuplicityVersion = function() return true end,
    vector3 = noop, AddEventHandler = noop, RegisterNetEvent = noop,
    TriggerClientEvent = function(name,source,data) events[#events+1]={name=name,source=source,data=data} end,
    SetTimeout = noop,
    json = { encode = function(value) encoded[#encoded+1]=value;return tostring(#encoded) end,
        decode = function(value) return encoded[tonumber(value)] end },
}, { __index = _G })
assert(loadfile("sky_phone/config/config.lua","t",env))()
env.Bridge = { Callbacks = { Register = function(name,fn) callbacks[name]=fn end }, Database = {
    AfterMigration = function(_,fn) fn() end,
    Query = function(sql,params)
        queries[#queries+1]={sql=sql,params=params}
        counter=counter+1
        if sql:find("SELECT UUID",1,true) then return {{id="new-"..counter}} end
        if sql:find("INSERT INTO `sky_phone_media`",1,true) then return {insertId=counter} end
        return {}
    end,
} }
env.SkyPhone = { LoadDevice = function() return {imei="recipient-device",account_id=20} end,
    RefreshAccount = noop, RefreshDevice = noop }
assert(loadfile("sky_phone/source/server/easyshare.lua","t",env))()
local visited = {}
local function seam(fn,target)
    if visited[fn] then return end
    visited[fn]=true
    for i=1,200 do
        local name,value=debug.getupvalue(fn,i)
        if not name then break end
        if name==target then return value end
        if type(value)=="function" then local found=seam(value,target);if found then return found end end
    end
end
local function find(name)
    visited={}
    for _, fn in pairs(callbacks) do local found=seam(fn,name);if found then return found end end
    error("missing test seam "..name)
end
local receive,for_source,row_transfer = find("apply_received_payload"),find("transfer_for_source"),find("row_transfer")
for _,kind in ipairs({"contact","note","text","document","location","photo","video","media","profile","post","track","playlist","link"}) do
    local before=#queries
    local transfer={id="transfer-"..kind,recipient_imei="recipient-device",recipient_source=2,sender_source=1,
        sender_name="Sender",recipient_name="Recipient",status="completed",progress=100,
        payload={appId="calendar",id="original-id",kind=kind,title="Shared item",copyText="Body",
            link="skyphone://calendar/event/original-id",meta={name="Luna",phoneNumber="1443456011",body="Saved body",
                x=1,y=2,z=3,url="https://example.invalid/media",remoteId="asset",items={
                    {url="https://example.invalid/a",mediaType="photo"},{url="https://example.invalid/b",mediaType="video"}}}}}
    assert(receive(transfer),"receive failed for "..kind)
    local incoming=for_source(transfer,2).payload
    local outgoing=for_source(transfer,1).payload
    assert(outgoing.id=="original-id","sender must retain original target")
    if kind=="note" or kind=="text" or kind=="document" then
        assert(incoming.appId=="notes" and incoming.kind=="note" and incoming.id~="original-id" and incoming.link==nil)
    elseif kind=="location" then assert(incoming.appId=="map" and incoming.id~="original-id")
    elseif kind=="photo" or kind=="video" or kind=="media" then
        assert(incoming.appId=="photos" and type(incoming.id)=="number")
        local inserts=0
        for i=before+1,#queries do
            local query=queries[i]
            if query.sql:find("INSERT INTO `sky_phone_media`",1,true) then
                inserts=inserts+1;assert(query.params[1]==20,"media owner must be recipient")
            end
        end
        assert(inserts==(kind=="media" and 2 or 1),"every album item must arrive")
    elseif kind=="contact" then assert(incoming.meta.phoneNumber=="1443456011")
    else assert(incoming.link==transfer.payload.link) end
    local persisted=env.json.encode(transfer.payload)
    local row={id=transfer.id,payload=persisted,recipient_imei="recipient-device",status="completed",progress=100}
    assert(row_transfer(row,"recipient-device").payload.id==incoming.id,"history must reopen received copy")
    assert(row_transfer(row,"sender-device").payload.id==outgoing.id)
end
local sanitized=find("sanitize_payload")
local rejected,reason=sanitized(1,{imei="attacker",account_id=99},{appId="notes",kind="note",id="not-owned",title="Test",copyText="forged"})
assert(rejected==nil and reason=="not_owned")
print("EasyShare receive targets and history passed for all 13 supported content kinds")

local music_receive=find("receive_music")
local music_payload={appId="music",kind="playlist",id="sender-list",title="Shared mix",meta={songs={
    {source="server",song_id="server-song"},
    {source="youtube",song_id="sender-song",video_id="abcdefghijk",title="Song",artist="Artist"},
}}}
local before=#queries
assert(music_receive({imei="recipient-device",account_id=20},music_payload))
assert(music_payload.meta.received.id~="sender-list")
assert(music_payload.meta.received.link=="skyphone://music/playlist/"..music_payload.meta.received.id)
local song_id
for i=before+1,#queries do
    local query=queries[i]
    if query.sql:find("INSERT INTO `sky_phone_music_youtube_songs`",1,true) then
        assert(query.params[2]==20);song_id=query.params[1];assert(song_id~="sender-song")
    elseif query.sql:find("INSERT INTO `sky_phone_music_playlist_items`",1,true) and query.params[2]=="youtube" then
        assert(query.params[3]==song_id,"playlist must reference recipient's song copy")
    end
end
assert(song_id)
local max=env.Config.Music.MaximumPlaylists;env.Config.Music.MaximumPlaylists=0
before=#queries
assert(not music_receive({imei="recipient-device",account_id=20},music_payload))
for i=before+1,#queries do assert(not queries[i].sql:find("INSERT",1,true),"limits must be checked before writes") end
env.Config.Music.MaximumPlaylists=max
print("EasyShare music copy ownership, playlist remapping and limits passed")
