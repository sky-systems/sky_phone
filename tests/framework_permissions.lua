local function server(framework, permissions, allowed_commands, existing_aces)
    local events, commands, messages = {}, {}, {}
    local aces = existing_aces or {}
    local membership, denied = {}, {}
    local env = setmetatable({
        Config = { CommandPermissions = permissions },
        Bridge = { Framework = { Name = framework }, Debug = function(_, message) messages[#messages + 1] = message end },
        GetCurrentResourceName = function() return "sky_phone" end,
        AddEventHandler = function(event, callback) events[event] = callback end,
        print = function(message) messages[#messages + 1] = message end,
        IsPrincipalAceAllowed = function(principal, object)
            if principal == "resource.sky_phone" then return allowed_commands[object] end
            return aces[principal .. " " .. object] and not denied[principal .. " " .. object] or false
        end,
        IsPlayerAceAllowed = function(source, object)
            for principal in pairs(membership[source] or {}) do
                if denied[principal .. " " .. object] then return false end
            end
            for principal in pairs(membership[source] or {}) do
                if aces[principal .. " " .. object] then return true end
            end
            return false
        end,
        ExecuteCommand = function(command)
            commands[#commands + 1] = command
            local action, principal, object = command:match("^(%S+) (%S+) (%S+) allow$")
            assert(action == "add_ace" or action == "remove_ace", "Phone must not change player principals")
            aces[principal .. " " .. object] = action == "add_ace" or nil
        end,
    }, { __index = _G })
    assert(loadfile("sky_phone/source/bridge/server/permissions.lua", "t", env))()
    return { env = env, aces = aces, membership = membership, denied = denied,
        commands = commands, messages = messages, stop = events.onResourceStop }
end

local allowed = { ["command.add_ace"] = true, ["command.remove_ace"] = true }
for _, framework in ipairs({ "esx", "qb", "qbox" }) do
    local runtime = server(framework, { phonepanel = { "admin" }, phonetestdata = {} }, allowed)
    runtime.membership["1"] = { ["group.admin"] = true }
    runtime.membership["2"] = { ["qbcore.admin"] = true }
    assert(runtime.env.Bridge.Framework.HasPermission(1, "phonepanel"))
    assert(runtime.env.Bridge.Framework.HasPermission(2, "phonepanel") == (framework == "qb"))
    assert(not runtime.env.Bridge.Framework.HasPermission(3, "phonepanel"), "Framework/job roles cannot bypass ACE")
    assert(not runtime.env.Bridge.Framework.HasPermission(1, "missing"))
    assert(not runtime.env.Bridge.Framework.HasPermission(1, "phonetestdata"), "Empty groups must deny players")
    assert(runtime.env.Bridge.Framework.HasPermission(0, "phonepanel"), "Console remains supported")
    runtime.denied["group.admin sky_phone.phonepanel"] = true
    assert(not runtime.env.Bridge.Framework.HasPermission(1, "phonepanel"), "Explicit ACE denial wins")
    runtime.denied["group.admin sky_phone.phonepanel"] = nil
    runtime.membership["1"] = {}
    assert(not runtime.env.Bridge.Framework.HasPermission(1, "phonepanel"), "Revocation applies to the next action")
    runtime.stop("unrelated")
    assert(runtime.aces["group.admin sky_phone.phonepanel"])
    runtime.stop("sky_phone")
    assert(next(runtime.aces) == nil, "Owned grants must not survive a resource stop")
    assert(not runtime.env.Bridge.Framework.HasPermission(1, "phonepanel"))
end

local preexisting = { ["group.admin sky_phone.phonepanel"] = true }
local runtime = server("esx", { phonepanel = { "admin", "superadmin" } }, allowed, preexisting)
runtime.stop("sky_phone")
assert(preexisting["group.admin sky_phone.phonepanel"], "Server-owned ACE grants must be preserved")
assert(not preexisting["group.superadmin sky_phone.phonepanel"])

for _, missing in ipairs({ "command.add_ace", "command.remove_ace" }) do
    local privileges = { ["command.add_ace"] = true, ["command.remove_ace"] = true }
    privileges[missing] = nil
    runtime = server("qbox", { phonepanel = { "admin" } }, privileges)
    assert(#runtime.commands == 0, "Missing setup must not install partial grants")
    assert(#runtime.messages == 1 and runtime.messages[1]:find(missing, 1, true))
    assert(not runtime.env.Bridge.Framework.HasPermission(1, "phonepanel"))
end

for _, value in ipairs({ 'admin;quit', 'admin\nquit', 'admin"', '', 12 }) do
    assert(not pcall(server, "esx", { phonepanel = { value } }, allowed), "Invalid group must not reach ExecuteCommand")
end
assert(not pcall(server, "esx", { ['phonepanel;quit'] = { "admin" } }, allowed))
assert(not pcall(server, "esx", { phonepanel = { admin = true } }, allowed))
print("framework permission tests passed (ACE registration, denial, revocation, cleanup, setup and command injection)")
