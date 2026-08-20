local compatibility = assert(SkyPhoneCompatibility, "Phone compatibility shared core must load before the LB provider")
local providers = assert(compatibility.Providers, "Phone compatibility providers are unavailable")
local normalize_at_resource_url = assert(
    compatibility.NormalizeAtResourceUrl,
    "Phone compatibility URL validator is unavailable"
)

local function resolve_lb_asset_resource(owner_resource, app_data)
    local ui = app_data.ui
    if type(ui) ~= "string" then
        return nil
    end

    local explicit_ui_resource = ui:match("^https://cfx%-nui%-([^/]+)/")
        or ui:match("^nui://([^/]+)/")
    local asset_resource = explicit_ui_resource or ui:match("^([%w][%w._-]*)/")
    if not asset_resource or asset_resource == owner_resource then
        return nil
    end

    if explicit_ui_resource or app_data.resource == asset_resource then
        return asset_resource
    end

    local icon = app_data.icon
    local icon_resource = type(icon) == "string" and (
        icon:match("^https://cfx%-nui%-([^/]+)/") or icon:match("^nui://([^/]+)/")
    ) or nil
    if icon_resource == asset_resource then
        return asset_resource
    end

    return nil
end

local function combine_lifecycle_hooks(first_hook, second_hook)
    if first_hook == nil then
        return second_hook
    end
    if second_hook == nil or second_hook == first_hook then
        return first_hook
    end

    return function(...)
        local first_result = table.pack(pcall(first_hook, ...))
        local second_result = table.pack(pcall(second_hook, ...))

        if not first_result[1] then
            error(first_result[2], 0)
        end
        if not second_result[1] then
            error(second_result[2], 0)
        end
    end
end

function compatibility.BuildLbDefinition(owner_resource, app_data)
    if type(app_data) ~= "table" or type(app_data.identifier) ~= "string" then
        return nil, "invalid_app_data"
    end

    local ui, ui_error = normalize_at_resource_url(owner_resource, app_data.ui, "ui")
    if not ui then
        return nil, ui_error
    end

    return {
        schemaVersion = 1,
        id = app_data.identifier,
        name = app_data.name,
        description = app_data.description,
        developer = app_data.developer,
        category = app_data.game and "games" or "utilities",
        ui = ui,
        assetResource = resolve_lb_asset_resource(owner_resource, app_data),
        bridgeMode = "legacy",
        icon = app_data.icon,
        defaultInstalled = app_data.defaultApp or false,
        removable = not app_data.defaultApp,
        orientation = app_data.landscape and "landscape" or "portrait",
        onInstall = app_data.onInstall,
        onDelete = app_data.onDelete,
        onOpen = combine_lifecycle_hooks(app_data.onOpen, app_data.onUse),
        onClose = app_data.onClose,
        compatibility = {
            provider = providers.lb,
            apiVersion = 1,
            fixBlur = app_data.fixBlur == true,
            resourceName = type(app_data.resource) == "string" and app_data.resource or owner_resource,
        },
    }
end
