local calls,handlers,timers={}, {}, {}
local result,status={sessionId="test-session"},200
local env=setmetatable({Config={Realtime={TurnEnabled=false,MaxDurationMinutes=120},RealtimeSecrets={AppId="app-id",AppSecret="server-secret",TurnKeyId="turn-id",ApiToken="turn-token"}},
    json={encode=function(value) return value end,decode=function(value) return value end},
    promise={new=function() return {resolve=function(self,value) self.value=value end} end},
    Citizen={Await=function(pending) return pending.value end},SetTimeout=function(_,fn) timers[#timers+1]=fn end,
    PerformHttpRequest=function(url,callback,method,body,headers)
        calls[#calls+1]={url=url,method=method,body=body,headers=headers};callback(status,result)
    end,
    AddEventHandler=function(name,fn) handlers[name]=fn end,GetCurrentResourceName=function() return "sky_phone" end,
},{__index=_G})
assert(loadfile("sky_phone/source/server/realtime_cloudflare.lua","t",env))()
local cf=env.SkyPhoneRealtimeCloudflare
assert(cf.Ice(1)[1].urls=="stun:stun.l.google.com:19302" and #calls==0,"default must not contact Cloudflare")
assert(cf.Sfu(nil,"create").sessionId=="test-session")
assert(calls[1].url=="https://rtc.live.cloudflare.com/v1/apps/app-id/sessions/new")
assert(calls[1].headers.Authorization=="Bearer server-secret")
assert(not cf.Sfu("../other","publish",{}));assert(#calls==1)
status=403;assert(not cf.Sfu(nil,"create"));status=200
result={errorCode="invalid_session"};assert(not cf.Sfu(nil,"create"))
result={iceServers={{urls="turn:example.invalid",username="expiring_user",credential="short-lived"}}}
env.Config.Realtime.TurnEnabled=true
assert(cf.Ice(1)[1].credential=="short-lived")
assert(calls[#calls].body.ttl==7800 and calls[#calls].headers.Authorization=="Bearer turn-token")
local count=#calls;assert(cf.Ice(1) and #calls==count,"reuse valid temporary credentials")
cf.Revoke(1);assert(calls[#calls].url:match("/credentials/expiring_user/revoke$"))
print("Cloudflare optional default, fixed API paths, errors, credentials and revocation passed")

local server_config=setmetatable({Config={},IsDuplicityVersion=function() return true end,
    vector3=function() return {} end,GetConvar=function(name) return "server-only:"..name end,
},{__index=_G})
assert(loadfile("sky_phone/config/config.lua","t",server_config))()
-- SQL mode ignores convars; exercise file mode with the same shipped source.
local file=assert(io.open("sky_phone/config/config.lua","r"));local source=file:read("*a");file:close()
-- Simulate the supported file configuration mode before its server block executes.
source=source:gsub("if IsDuplicityVersion%(%) then", "Config.PhoneConfigurator.Enabled = false\nif IsDuplicityVersion() then",1)
assert(load(source,"file-config","t",server_config))()
assert(server_config.Config.RealtimeSecrets.AppSecret=="server-only:sky_phone_cf_sfu_app_secret")
server_config.IsDuplicityVersion=function() return false end;server_config.Config={}
assert(load(source,"client-config","t",server_config))()
assert(server_config.Config.RealtimeSecrets==nil,"client must never read secret convars")
print("Realtime file configuration uses non-replicated server convars only")
