local function new_housing()
    local state = { logs = {}, permission_calls = 0 }
    local properties = {
        { id = 10, name = "Owner home", owner = "char:actor",
            metadata = { enter = { x = 10, y = 20, z = 30 } } },
        { id = 20, name = "Other home", owner = "char:other",
            metadata = { enter = { x = 40, y = 50, z = 60 } } },
    }
    local provider = {}
    function provider:GetAllProperties() return properties end
    function provider:GetPlayerProperties(source)
        assert(source == 1)
        return { properties[1] }
    end
    function provider:GetProperty(id)
        for _, property in ipairs(properties) do
            if tostring(property.id) == tostring(id) then return property end
        end
    end
    function provider:HasKeys(source, identifier, id)
        assert(source == 1 and identifier == "char:actor" and tostring(id) == "20")
        if state.fail_keys then error("fixture key lookup failed") end
        return state.keys
    end
    function provider:HasAnyPermission(id, identifier)
        assert(tostring(id) == "20" and identifier == "char:actor")
        state.permission_calls = state.permission_calls + 1
        return state.permissions
    end
    local environment = setmetatable({
        Config = { Housing = { System = "vms", MaximumProperties = 50 } },
        exports = { vms_housing = provider },
        GetResourceState = function(name)
            assert(name == "vms_housing")
            return "started"
        end,
        AddEventHandler = function() end,
    }, { __index = _G })
    local function load_script(path)
        assert(loadfile("sky_phone/source/" .. path, "t", environment))()
    end
    load_script("bridge/shared.lua")
    environment.Bridge.Debug = function(level, message, ...)
        if level == "error" then
            state.logs[#state.logs + 1] = message:format(...)
        end
    end
    environment.Bridge.Framework.GetIdentifier = function(source)
        assert(source == 1)
        return "char:actor"
    end
    load_script("bridge/server/housing.lua")
    load_script("bridge/server/housing/vms.lua")
    state.bridge = environment.Bridge.Housing
    state.permissions = false
    return state
end

local count = 0
local function test(name, run)
    run(new_housing())
    count = count + 1
    print("PASS " .. name)
end

test("nil key results do not abort the owned property list", function(state)
    local overview, reason = state.bridge.GetOverview(1)
    assert(overview and reason == nil and overview.provider == "vms")
    assert(#overview.properties == 1 and overview.properties[1].id == "vms:10")
    assert(state.permission_calls == 1 and #state.logs == 0)
    local prepared, error_code = state.bridge.Prepare(1, "set_waypoint", { propertyId = "vms:20" })
    assert(prepared == nil and error_code == "property_access_denied")
end)

test("nil keys still allow separately assigned permissions", function(state)
    state.permissions = true
    local overview = assert(state.bridge.GetOverview(1))
    assert(#overview.properties == 2 and overview.properties[2].access == "keyholder")
    local prepared = assert(state.bridge.Prepare(1, "set_waypoint", { propertyId = "vms:20" }))
    assert(prepared.coords.x == 40 and prepared.provider == "vms")
    assert(#state.logs == 0)
end)

test("boolean key results preserve granted and denied access", function(state)
    state.keys = true
    assert(#assert(state.bridge.GetOverview(1)).properties == 2)
    assert(state.permission_calls == 0)
    state.keys = false
    assert(#assert(state.bridge.GetOverview(1)).properties == 1)
end)

test("unexpected key return types remain provider errors", function(state)
    for _, value in ipairs({ 0, 1, "false", {} }) do
        state.keys, state.logs = value, {}
        local overview, reason = state.bridge.GetOverview(1)
        assert(overview == nil and reason == "provider_error")
        assert(#state.logs == 1 and state.logs[1]:find("got " .. type(value), 1, true))
    end
end)

test("key export exceptions remain visible failures", function(state)
    state.fail_keys = true
    local overview, reason = state.bridge.GetOverview(1)
    assert(overview == nil and reason == "provider_error")
    assert(#state.logs == 1 and state.logs[1]:find("fixture key lookup failed", 1, true))
end)

test("nil permissions are not treated as a valid provider result", function(state)
    state.permissions = nil
    local overview, reason = state.bridge.GetOverview(1)
    assert(overview == nil and reason == "provider_error")
    assert(#state.logs == 1 and state.logs[1]:find("HasAnyPermission", 1, true))
end)

print(("VMS Housing: %d tests passed"):format(count))
