local events, callbacks, threads, duis, deleted, draws = {}, {}, {}, {}, {}, {}
local clock, next_dui = 1000, 0
local position = { [1] = 0, [2] = 1, [3] = 2 }
local V = {}
V.__sub = function(a,b) return setmetatable({ x=a.x-b.x,y=a.y-b.y,z=a.z-b.z },V) end
V.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
local function v(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
joaat = function(s) return s end
GetCurrentResourceName = function() return 'sky_phone' end
PlayerId, PlayerPedId = function() return 1 end, function() return 1 end
GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed = function(p) return p end, function(p) return p end, function(p) return p end
GetGameTimer = function() return clock end
NetworkDoesEntityExistWithNetworkId = function(net) return net == 102 or net == 103 end
NetToObj = function(net) return net end
GetEntityModel = function() return 'sky_phone_prop' end
GetEntityAttachedTo = function(net) return net - 100 end
DoesEntityExist = function() return true end
GetEntityCoords = function(p) return v(position[p] or 0,0,0) end
GetOffsetFromEntityInWorldCoords = function(_,x,y,z) return v(x,y,z) end
GetFinalRenderedCamCoord = function() return v(0,-1,0) end
IsEntityOnScreen, HasEntityClearLosToEntity = function() return true end, function() return true end
RegisterNetEvent, AddEventHandler = function(n,f) events[n]=f end, function(n,f) events[n]=f end
RegisterNUICallback = function(n,f) callbacks[n]=f end
CreateThread = function(f) threads[#threads+1]=coroutine.create(f) end
Wait = function(ms) return coroutine.yield(ms) end
CreateDui = function(url,w,h)
    assert(url=='https://cfx-nui-sky_phone/source/html/display.html' and w==360 and h==780)
    next_dui=next_dui+1;duis[next_dui]=true;return next_dui
end
DestroyDui = function(dui) assert(duis[dui]);duis[dui]=nil;deleted[#deleted+1]=dui end
IsDuiAvailable = function() return true end
GetDuiHandle = function(dui) return 'dui_'..dui end
CreateRuntimeTxd = function(name) return name end
CreateRuntimeTextureFromDuiHandle = function(txd,txn,handle) assert(txn=='screen' and handle:match('dui_'));return txd end
SendDuiMessage = function() end
SendNUIMessage, TriggerServerEvent, TriggerLatentServerEvent = function() end, function() end, function() end
DrawTexturedPoly = function(...)
    local a={...}
    for i=1,13 do assert(type(a[i])=='number','OAL receives scalar coordinates/colors') end
    draws[a[14]]=true
end
json = {encode=function() return '{}' end}
Bridge = {Debug=function() end}
SkyPhoneClient = {GetState=function() return {open=false} end}
SkyPhoneAnimations = {GetProp=function() end,SetFrame=function() end}
dofile('sky_phone/source/shared/phone_prop.lua')
dofile('sky_phone/source/client/world_display.lua')
local frame=events['sky_phone:display:frame']
frame(2,1,102,1,'pixels')
frame(3,2,103,1,'other pixels')
assert(next_dui==2,'Two phones allocate two browsers')
assert(coroutine.resume(threads[1]))
assert(coroutine.resume(threads[1]))
assert(coroutine.resume(threads[2]))
assert(draws.sky_phone_display_1 and draws.sky_phone_display_2,'Independent texture dictionaries per phone')
events['sky_phone:display:stop'](2,1,1)
frame(2,1,102,1,'late pixels')
assert(next_dui==2,'Stopped sequence cannot resurrect')
frame(2,1,102,2,'new pixels')
assert(next_dui==3,'Re-entering range with fresh sequence resumes')
events['sky_phone:display:stop'](3,1,99)
assert(#deleted==1,'Old generation cannot delete newer display')
position[2],position[3]=10,20
assert(coroutine.resume(threads[1]))
assert(#deleted==3,'Leaving range destroys DUI instances')
draws={}
assert(coroutine.resume(threads[2]))
assert(next(draws)==nil,'No drawing after cleanup')
local replies=0
callbacks['worldDisplay:frame']({},function(r) assert(not r.success);replies=replies+1 end)
callbacks['worldDisplay:color']({frame='invalid'},function(r) assert(not r.success);replies=replies+1 end)
assert(replies==2,'Rejected NUI callbacks always respond')
print('PASS: independent DUI textures, OAL scalars, stale frame rejection, re-entry and range cleanup')
