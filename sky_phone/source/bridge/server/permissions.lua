-- Standalone ACE registration. No framework role/job fallback and no external Sky state.
local resource_name = GetCurrentResourceName()
local resource_principal = "resource." .. resource_name
local owned_grants = {}
local registered_permissions = {}
local permissions_ready = false

function Bridge.Framework.HasPermission(source, permission)
    if type(permission) ~= "string" or not permission:match("^[%w_-]+$") then
        error("[sky_phone] Permission identifiers must be non-empty command keys.")
    end
    local player_source = tonumber(source)
    if not player_source or player_source % 1 ~= 0 or player_source < 0 then
        Bridge.Debug("warn", "Rejected permission check with invalid player source: " .. tostring(source))
        return false
    end
    if player_source == 0 then return true end
    if not permissions_ready or not registered_permissions[permission] then return false end
    return IsPlayerAceAllowed(tostring(player_source), "sky_phone." .. permission)
end

local function remove_owned_grants()
    permissions_ready = false
    for _, grant in ipairs(owned_grants) do
        ExecuteCommand(("remove_ace %s %s allow"):format(grant.principal, grant.object))
    end
    owned_grants = {}
end

AddEventHandler("onResourceStop", function(stopped_resource)
    if stopped_resource == resource_name then remove_owned_grants() end
end)

local function register_permissions()
    if type(Config.CommandPermissions) ~= "table" then
        error("[sky_phone] Config.CommandPermissions must be a table of ACE group lists.")
    end
    local grants = {}
    local prefixes = Bridge.Framework.Name == "qb" and { "group.", "qbcore." } or { "group." }
    for permission, groups in pairs(Config.CommandPermissions) do
        if type(permission) ~= "string" or not permission:match("^[%w_-]+$") or type(groups) ~= "table" then
            error("[sky_phone] Invalid CommandPermissions entry: " .. tostring(permission))
        end
        local count = 0
        for index, group in pairs(groups) do
            if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #groups
                or type(group) ~= "string" or not group:match("^[%w_.-]+$") then
                error(("[sky_phone] Invalid ACE group at CommandPermissions.%s[%s]: %s")
                    :format(permission, tostring(index), tostring(group)))
            end
            count = count + 1
            for _, prefix in ipairs(prefixes) do
                grants[#grants + 1] = { principal = prefix .. group, object = "sky_phone." .. permission }
            end
        end
        if count ~= #groups then error("[sky_phone] ACE group lists must be contiguous: " .. permission) end
        registered_permissions[permission] = count > 0
    end

    for _, command in ipairs({ "add_ace", "remove_ace" }) do
        if not IsPrincipalAceAllowed(resource_principal, "command." .. command) then
            print(("^1[sky_phone] Command permissions are unavailable. Add 'add_ace %s command.%s allow' "
                .. "before 'ensure sky_phone' in server.cfg, then restart sky_phone.^0")
                :format(resource_principal, command))
            return
        end
    end

    for _, grant in ipairs(grants) do
        -- Do not rewrite effective server-owned allows. Newly installed principal/object
        -- pairs are managed by Phone; remove_ace removes all matching allow entries.
        if not IsPrincipalAceAllowed(grant.principal, grant.object) then
            ExecuteCommand(("add_ace %s %s allow"):format(grant.principal, grant.object))
            owned_grants[#owned_grants + 1] = grant
        end
    end
    permissions_ready = true
end

register_permissions()
