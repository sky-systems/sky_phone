-- Only this server module talks to Cloudflare. No client-controlled URL or secret.
SkyPhoneRealtimeCloudflare = {}
local credentials = {}
local base = "https://rtc.live.cloudflare.com/v1/"

function SkyPhoneRealtimeCloudflare.Request(path, method, payload, token)
    if type(token) ~= "string" or token == "" then return nil, "cloudflare_not_configured" end
    local pending, finished = promise.new(), false
    local function finish(value)
        if finished then return end
        finished = true
        pending:resolve(value)
    end
    SetTimeout(10000, function() finish(false) end)
    PerformHttpRequest(base .. path, function(status, body)
        if status < 200 or status >= 300 then
            print(("[sky_phone] Realtime Cloudflare request failed (HTTP %s)."):format(tostring(status)))
            finish(false)
            return
        end
        if not body or body == "" then finish({}) return end
        local ok, decoded = pcall(json.decode, body)
        finish(ok and type(decoded) == "table" and not decoded.errorCode and decoded or false)
    end, method, payload and json.encode(payload) or "", {
        ["Authorization"] = "Bearer " .. token,
        ["Content-Type"] = "application/json",
    })
    local result = Citizen.Await(pending)
    return result or nil, result and nil or "cloudflare_failed"
end

local function safe_id(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w_-]+$")
end

function SkyPhoneRealtimeCloudflare.Sfu(session, operation, payload, context)
    local secret = context or Config.RealtimeSecrets or {}
    if not safe_id(secret.AppId) or not secret.AppSecret or secret.AppSecret == "" then
        return nil, "cloudflare_not_configured"
    end
    local paths = {
        create = { "sessions/new", "POST" },
        publish = { "tracks/new", "POST" },
        pull = { "tracks/new", "POST" },
        renegotiate = { "renegotiate", "PUT" },
        close = { "tracks/close", "PUT" },
    }
    local action = paths[operation]
    if not action or (operation ~= "create" and not safe_id(session)) then return nil, "invalid_request" end
    local suffix = operation == "create" and action[1] or "sessions/" .. session .. "/" .. action[1]
    return SkyPhoneRealtimeCloudflare.Request("apps/" .. secret.AppId .. "/" .. suffix, action[2], payload, secret.AppSecret)
end

function SkyPhoneRealtimeCloudflare.Ice(source)
    if not Config.Realtime.TurnEnabled then
        return { { urls = "stun:stun.l.google.com:19302" } }
    end
    local cached = credentials[source]
    if cached and cached.expires > os.time() + Config.Realtime.MaxDurationMinutes * 60 + 60 then return cached.servers end
    local secret = Config.RealtimeSecrets or {}
    if not safe_id(secret.TurnKeyId) then return nil, "cloudflare_not_configured" end
    local ttl = math.min(86400, Config.Realtime.MaxDurationMinutes * 60 + 600)
    local result, err = SkyPhoneRealtimeCloudflare.Request(
        "turn/keys/" .. secret.TurnKeyId .. "/credentials/generate-ice-servers", "POST", { ttl = ttl }, secret.ApiToken
    )
    if not result or type(result.iceServers) ~= "table" then return nil, err or "cloudflare_failed" end
    credentials[source] = { servers = result.iceServers, expires = os.time() + ttl,
        key = secret.TurnKeyId, token = secret.ApiToken }
    return result.iceServers
end

function SkyPhoneRealtimeCloudflare.Revoke(source)
    local cached = credentials[source]
    credentials[source] = nil
    if not cached then return end
    local seen = {}
    for _, server in ipairs(cached.servers) do
        local username = server.username
        if type(username) == "string" and #username <= 1024 and username:match("^[%w_.%-]+$") and not seen[username] then
            seen[username] = true
            PerformHttpRequest(base .. "turn/keys/" .. cached.key .. "/credentials/" .. username .. "/revoke",
                function(status)
                    if status < 200 or status >= 300 then
                        print("[sky_phone] Could not revoke Realtime TURN credentials.")
                    end
                end, "POST", "", { ["Authorization"] = "Bearer " .. cached.token })
        end
    end
end

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    for source in pairs(credentials) do SkyPhoneRealtimeCloudflare.Revoke(source) end
end)
AddEventHandler("playerDropped", function() SkyPhoneRealtimeCloudflare.Revoke(source) end)
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for source in pairs(credentials) do SkyPhoneRealtimeCloudflare.Revoke(source) end
end)
