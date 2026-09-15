local events, callbacks, threads, duis, deleted, draws = {}, {}, {}, {}, {}, {}
local clock, next_dui = 1000, 0
local nui, sent, selected_frame = {}, {}, nil
local phone_open, own_prop = false, nil
local polygons, pending_poses, poses, refreshed, matrix_reads = {}, {}, {}, {}, {}
local on_screen, camera = true, nil
local position = { [1] = 0, [2] = 1, [3] = 2 }
local V = {}
V.__add = function(a,b) return setmetatable({x=a.x+b.x,y=a.y+b.y,z=a.z+b.z},V) end
V.__mul = function(a,b) return setmetatable({x=a.x*b,y=a.y*b,z=a.z*b},V) end
V.__sub = function(a,b) return setmetatable({ x=a.x-b.x,y=a.y-b.y,z=a.z-b.z },V) end
V.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
local function v(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
joaat = function(s) return s end
GetCurrentResourceName = function() return 'sky_phone' end
PlayerId, PlayerPedId = function() return 1 end, function() return 1 end
GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed = function(p) return p end, function(p) return p end, function(p) return p end
GetGameTimer = function() return clock end
NetworkDoesEntityExistWithNetworkId = function(net) return net == 101 or net == 102 or net == 103 end
ObjToNet = function(prop) return prop end
NetToObj = function(net) return net end
GetEntityModel = function() return 'sky_phone_prop' end
GetEntityAttachedTo = function(net) return net - 100 end
DoesEntityExist = function() return true end
GetEntityCoords = function(p) return v(position[p] or 0,0,0) end
GetOffsetFromEntityInWorldCoords = function() error('Each polygon must use one current entity matrix') end
ProcessEntityAttachments = function(ped)
    assert(type(ped)=='number', 'OAL receives a scalar ped handle')
    local net=100+ped
    poses[net]=pending_poses[net] or {position=v(),forward=v(0,1,0),right=v(1,0,0),up=v(0,0,1)}
    refreshed[net]=true
end
GetEntityMatrix = function(net)
    assert(refreshed[net], 'Refresh the hand attachment before sampling the prop')
    refreshed[net]=nil
    matrix_reads[net]=(matrix_reads[net] or 0)+1
    local p=poses[net]
    return p.forward,p.right,p.up,p.position
end
GetFinalRenderedCamCoord = function() return camera or v(0,-1,0) end
IsEntityOnScreen = function() return on_screen end
HasEntityClearLosToEntity = function() error('Body-to-prop LOS must not override camera depth testing') end
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
SendNUIMessage = function(message) nui[#nui+1]=message end
TriggerServerEvent = function(...) sent[#sent+1]={...} end
TriggerLatentServerEvent = function(...) sent[#sent+1]={...} end
DrawTexturedPoly = function(...)
    local a={...}
    for i=1,13 do assert(type(a[i])=='number','OAL receives scalar coordinates/colors') end
    draws[a[14]]=true
    polygons[#polygons+1]=a
end
json = {encode=function() return '{}' end}
Bridge = {Debug=function() end}
SkyPhoneClient = {GetState=function() return {open=phone_open} end}
SkyPhoneAnimations = {GetProp=function() return own_prop end,SetFrame=function(frame) selected_frame=frame end}
dofile('sky_phone/source/shared/phone_prop.lua')
dofile('sky_phone/source/client/world_display.lua')
local frame=events['sky_phone:display:frame']
phone_open, own_prop = true, 101
assert(coroutine.resume(threads[1]))
assert(coroutine.resume(threads[1]))
frame(2,1,102,1,'disabled pixels')
events['sky_phone:display:permit'](1,101)
assert(next_dui==0 and #sent==0 and nui[#nui].token==false, 'No DUI or capture requests with missing configuration')
Config={Animations={WorldDisplayEnabled=false}}
assert(coroutine.resume(threads[1]))
frame(2,1,102,1,'disabled pixels')
assert(next_dui==0 and #sent==0, 'Disabled displays stay inactive with an open phone prop')
callbacks['worldDisplay:color']({frame='gold'},function(r) assert(r.success) end)
assert(selected_frame=='gold', 'Frame colors remain usable while DUI is off')
phone_open, own_prop = false, nil
Config.Animations.WorldDisplayEnabled=true
frame(2,1,102,1,'pixels')
frame(3,2,103,1,'other pixels')
assert(next_dui==2,'Two phones allocate two browsers')
assert(coroutine.resume(threads[1]))
assert(coroutine.resume(threads[1]))
assert(coroutine.resume(threads[2]))
assert(draws.sky_phone_display_1 and draws.sky_phone_display_2,'Independent texture dictionaries per phone')

assert(matrix_reads[102]==1 and matrix_reads[103]==1, 'One matrix sample per phone and render frame')
local screen=SkyPhoneProp.Screen
assert(screen.y < -0.00521, 'DUI must clear the outer front camera/glass at -0.00471 by at least 0.5 mm')
local function close(a,b) return math.abs(a-b)<0.000001 end
-- Simulate translation and turning with a deliberately stale attachment until refreshed.
for step=1,5 do
    pending_poses[102]={position=v(step*.15,step*.20,step*.03),forward=v(-1,0,0),right=v(0,1,0),up=v(0,0,1)}
    camera=v(10,-10,2)
    polygons={}
    local ok,wait=coroutine.resume(threads[2]);assert(ok and wait==0)
    local seen=0
    for _,poly in ipairs(polygons) do
        if poly[14]=='sky_phone_display_1' then
            seen=seen+1
            local pos=pending_poses[102].position
            assert(close(poly[1],pos.x-screen.y) and close(poly[2],pos.y) and close(poly[3],pos.z),
                'The overlay center must follow the current sprint/turn pose, not the previous attachment')
            for _,indices in ipairs({{4,5,6,19,20},{7,8,9,22,23}}) do
                local x=(poly[indices[4]]-.5)*screen.width
                local z=(.5-poly[indices[5]])*screen.height
                assert(close(poly[indices[1]],pos.x-screen.y) and close(poly[indices[2]],pos.y+x)
                    and close(poly[indices[3]],pos.z+z), 'All vertices use the same current transform and UV orientation')
            end
        end
    end
    assert(seen==28 and matrix_reads[102]==step+1)
end
on_screen=false;polygons={}
local ok,wait=coroutine.resume(threads[2]);assert(ok and wait==0 and #polygons==0,
    'A temporarily off-screen active phone must retain frame-rate updates')
on_screen=true;camera=v(-10,10,0);polygons={}
ok,wait=coroutine.resume(threads[2]);assert(ok and wait==0 and #polygons==0,
    'Back-facing screens stay hidden without a 100 ms pause')
camera=v(10,-10,2);polygons={}
ok,wait=coroutine.resume(threads[2]);assert(ok and wait==0 and #polygons>0,
    'A screen that turns toward the camera must return on the next frame')

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
local idle_ok,idle_wait=coroutine.resume(threads[2]);assert(idle_ok and idle_wait==100)
assert(next(draws)==nil,'No drawing after cleanup')
local replies=0
callbacks['worldDisplay:frame']({},function(r) assert(not r.success);replies=replies+1 end)
callbacks['worldDisplay:color']({frame='invalid'},function(r) assert(not r.success);replies=replies+1 end)
assert(replies==2,'Rejected NUI callbacks always respond')
-- Disable both the local publisher and spectator browsers without waiting for a polling tick.
position[2],position[3]=1,2
phone_open,own_prop,clock=true,101,2000
assert(coroutine.resume(threads[1]))
assert(sent[#sent][1]=='sky_phone:display:begin' and sent[#sent][2]==101)
events['sky_phone:display:permit'](10,101)
assert(nui[#nui].token==10)
frame(1,10,101,1,'local pixels')
frame(2,11,102,1,'nearby pixels')
frame(3,12,103,1,'another screen')
assert(next_dui==6)
Config.Animations.WorldDisplayEnabled=false
events['sky_phone:configurator:updated']()
assert(next(duis)==nil and #deleted==6, 'Disabling destroys every local and spectator browser immediately')
assert(nui[#nui].token==false and sent[#sent][1]=='sky_phone:display:end')
local before=#sent
frame(2,11,102,2,'late pixels')
events['sky_phone:display:permit'](10,101)
callbacks['worldDisplay:frame']({token=10,sequence=2,jpeg='pixels'},function(r) assert(not r.success) end)
assert(coroutine.resume(threads[1]))
assert(next_dui==6 and #sent==before and nui[#nui].token==false, 'Late frames and permits cannot reactivate disabled displays')
polygons={}
local disabled_ok,disabled_wait=coroutine.resume(threads[2])
assert(disabled_ok and disabled_wait==100 and #polygons==0)
Config.Animations.WorldDisplayEnabled=true
events['sky_phone:configurator:updated']()
clock=3000
assert(coroutine.resume(threads[1]))
assert(sent[#sent][1]=='sky_phone:display:begin', 'Re-enabling requests a session for the still-open phone')
events['sky_phone:display:permit'](13,101)
assert(nui[#nui].token==13)
frame(2,14,102,1,'resumed pixels')
assert(next_dui==7, 'Spectator browsers can resume after re-enabling')
print('PASS: default-off capture and DUI gating, independent colors, immediate disable/re-enable, current transforms and idle cleanup')
