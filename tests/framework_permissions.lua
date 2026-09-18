Config = {
    Bridge = {
        Framework = "qbox",
    },
    CommandPermissions = {
        phonepanel = { "god", "superadmin", "admin" },
    },
}

Bridge = {
    Framework = {},
}

function GetResourceState(resource)
    assert(resource == "qbx_core")
    return "started"
end

function GetPlayers()
    return { "1" }
end

local ace_permissions = {}
local framework_permission = false

function IsPlayerAceAllowed(source, permission)
    assert(source == "1")
    return ace_permissions[permission] == true
end

exports = {
    qbx_core = {
        GetPlayer = function(_, source)
            if tonumber(source) ~= 1 then
                return nil
            end
            return {
                PlayerData = {
                    citizenid = "test-citizen",
                },
            }
        end,
        HasGroup = function(_, source, groups)
            assert(source == 1)
            assert(groups == Config.CommandPermissions.phonepanel)
            return framework_permission
        end,
    },
}

dofile("sky_phone/source/bridge/server/framework.lua")
dofile("sky_phone/source/bridge/server/frameworks/qbox.lua")

ace_permissions.admin = true
assert(Bridge.Framework.HasPermission(1, "phonepanel"), "Qbox ACE permissions must grant access")

ace_permissions.admin = false
framework_permission = true
assert(Bridge.Framework.HasPermission(1, "phonepanel"), "Qbox framework groups must remain supported")

local success = pcall(Bridge.Framework.HasPermission, 1, "missing")
assert(not success, "Missing fixed permission definitions must fail loudly")

print("framework permission tests passed")
