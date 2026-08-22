local COMPATIBILITY_MAX_BYTES = 8192
local JSON_MAX_DEPTH = 12
local JSON_MAX_VALUES = 4096
local MAX_QUEUED_MESSAGES = 64
local NOTIFICATION_TEXT_MAX_LENGTH = 2000
local NOTIFICATION_TITLE_MAX_LENGTH = 160

local NOTIFICATION_SOUNDS = {
    chime = true,
    signal = true,
    soft = true,
}

local HOOK_NAMES = {
    onClose = true,
    onDelete = true,
    onInstall = true,
    onOpen = true,
    onReady = true,
}

local apps_by_id = {}
local app_ids_by_adapter = {}
local app_ids_by_owner = {}
local current_resource = GetCurrentResourceName()
local active_app_id = nil
local active_app_ready = false
local phone_open = false
local queued_messages = {}
local default_icon_url = ("https://cfx-nui-%s/img/custom-app.svg"):format(current_resource)

local function debug_custom_app(area, message, ...)
    if Config.CustomApps.Debug ~= true then
        return
    end

    local formatted = select("#", ...) > 0 and message:format(...) or message
    Bridge.Debug(
        "debug",
        ("[sky_phone][custom-apps][%s] %s"):format(area, formatted),
        { notice = true }
    )
end

SkyPhoneApps.Debug = debug_custom_app

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function is_callable(value)
    if type(value) == "function" then
        return true
    end
    if type(value) ~= "table" then
        return false
    end

    local value_metatable = getmetatable(value)
    return type(value_metatable) == "table" and type(value_metatable.__call) == "function"
end

local function validate_owner_resource_name(owner_resource)
    if type(owner_resource) ~= "string"
        or #owner_resource == 0
        or #owner_resource > 64
        or not owner_resource:match("^[%w][%w._-]*$")
    then
        return false, "invalid_owner_resource"
    end
    return true
end

local function validate_owner_resource(owner_resource, allow_stopping)
    local valid_owner, owner_error = validate_owner_resource_name(owner_resource)
    if not valid_owner then
        return false, owner_error
    end
    local state = GetResourceState(owner_resource)
    if state == "started" or state == "starting" or (allow_stopping and state == "stopping") then
        return true
    end

    return false, "owner_resource_not_running"
end

local function resolve_localized_text(value)
    if type(value) == "string" then
        return value
    end

    local locale = Config.Bridge.Locale:lower():gsub("_", "-")
    if value[locale] then
        return value[locale]
    end

    local base_locale = locale:match("^([a-z]+)-")
    if base_locale and value[base_locale] then
        return value[base_locale]
    end
    if value.en then
        return value.en
    end
    if value.de then
        return value.de
    end

    local locales = {}
    for available_locale in pairs(value) do
        locales[#locales + 1] = available_locale
    end
    table.sort(locales)
    return value[locales[1]]
end

local function validate_asset_path(path)
    if #path == 0
        or #path > 1024
        or path:find("\\", 1, true)
        or path:find("[%c]")
        or path:lower():find("%2e", 1, true)
    then
        return false
    end

    local path_only = path:match("^[^?#]+") or path
    for segment in path_only:gmatch("[^/]+") do
        if segment == "." or segment == ".." then
            return false
        end
    end

    return true
end

local function normalize_asset_url(value, original_owner, adapter_resource, asset_resource, required)
    if value == nil and not required then
        return nil
    end
    if type(value) ~= "string" then
        return nil, "invalid_asset_url"
    end

    local url = trim(value)
    if not validate_asset_path(url) then
        return nil, "invalid_asset_url"
    end

    local allowed_owners = {
        [original_owner] = true,
    }
    if adapter_resource then
        allowed_owners[adapter_resource] = true
    end
    if asset_resource then
        allowed_owners[asset_resource] = true
    end

    local cfx_owner = url:match("^https://cfx%-nui%-([^/]+)/")
    if cfx_owner then
        if not allowed_owners[cfx_owner] then
            return nil, "asset_owner_mismatch"
        end
        return url
    end

    local nui_owner, nui_path = url:match("^nui://([^/]+)/(.+)$")
    if nui_owner then
        if not allowed_owners[nui_owner] then
            return nil, "asset_owner_mismatch"
        end
        return ("https://cfx-nui-%s/%s"):format(nui_owner, nui_path)
    end

    if url:sub(1, 8) == "https://" then
        return url
    end

    if url:match("^[%a][%w+.-]*:") or url:sub(1, 2) == "//" or url:sub(1, 1) == "/" then
        return nil, "invalid_asset_url"
    end

    local asset_owner = original_owner
    local asset_path = url
    local original_prefix = original_owner .. "/"
    if url:sub(1, #original_prefix) == original_prefix then
        asset_path = url:sub(#original_prefix + 1)
    elseif adapter_resource then
        local adapter_prefix = adapter_resource .. "/"
        if url:sub(1, #adapter_prefix) == adapter_prefix then
            asset_owner = adapter_resource
            asset_path = url:sub(#adapter_prefix + 1)
        end
    end
    if asset_resource then
        local asset_prefix = asset_resource .. "/"
        if url:sub(1, #asset_prefix) == asset_prefix then
            asset_owner = asset_resource
            asset_path = url:sub(#asset_prefix + 1)
        end
    end

    if not validate_asset_path(asset_path) then
        return nil, "invalid_asset_url"
    end

    return ("https://cfx-nui-%s/%s"):format(asset_owner, asset_path)
end

local function validate_json_value(value, depth, seen, counter)
    local value_type = type(value)
    if value_type == "nil" or value_type == "boolean" then
        return true
    end
    if value_type == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    if value_type == "string" then
        return #value <= Config.CustomApps.MaximumMessageBytes
    end
    if value_type ~= "table" or depth >= JSON_MAX_DEPTH or seen[value] then
        return false
    end

    seen[value] = true
    local key_type = nil
    local numeric_keys = 0
    local value_count = 0
    for key, nested_value in pairs(value) do
        counter.count = counter.count + 1
        value_count = value_count + 1
        if counter.count > JSON_MAX_VALUES then
            seen[value] = nil
            return false
        end

        local current_key_type = type(key)
        if current_key_type == "number" then
            if key < 1 or key % 1 ~= 0 then
                seen[value] = nil
                return false
            end
            numeric_keys = numeric_keys + 1
        elseif current_key_type ~= "string" or #key > 128 then
            seen[value] = nil
            return false
        end

        if key_type and key_type ~= current_key_type then
            seen[value] = nil
            return false
        end
        key_type = current_key_type

        if not validate_json_value(nested_value, depth + 1, seen, counter) then
            seen[value] = nil
            return false
        end
    end

    if key_type == "number" and (numeric_keys ~= value_count or #value ~= value_count) then
        seen[value] = nil
        return false
    end

    seen[value] = nil
    return true
end

local function normalize_json_payload(payload, maximum_bytes)
    if not validate_json_value(payload, 0, {}, { count = 0 }) then
        return nil, "invalid_payload"
    end

    local encoded_success, encoded = pcall(json.encode, payload)
    if not encoded_success or type(encoded) ~= "string" then
        return nil, "invalid_payload"
    end
    if #encoded > maximum_bytes then
        return nil, "payload_too_large"
    end

    local decoded = json.decode(encoded)
    return decoded
end

local function validate_optional_text(value, error_code, maximum_length)
    if value == nil then
        return nil
    end
    if type(value) ~= "string" then
        return nil, error_code
    end

    local normalized = trim(value)
    if #normalized == 0 or #normalized > maximum_length then
        return nil, error_code
    end

    return normalized
end

local function normalize_external_definition_value(owner_resource, adapter_resource, definition)
    if type(definition) ~= "table" then
        return nil, "invalid_definition"
    end
    if definition.schemaVersion ~= nil and definition.schemaVersion ~= SkyPhoneApps.ProtocolVersion then
        return nil, "unsupported_schema_version"
    end
    local valid_id, id_error = SkyPhoneApps.ValidateAppId(definition.id)
    if not valid_id then
        return nil, id_error
    end
    if SkyPhoneApps.ReservedAppIds[definition.id] then
        return nil, "reserved_app_id"
    end

    local name, name_error = SkyPhoneApps.ValidateLocalizedText(
        definition.name,
        "invalid_name",
        64,
        true
    )
    if not name then
        return nil, name_error
    end

    local description, description_error = SkyPhoneApps.ValidateLocalizedText(
        definition.description,
        "invalid_description",
        320,
        false
    )
    if definition.description ~= nil and not description then
        return nil, description_error
    end

    local developer, developer_error = validate_optional_text(definition.developer, "invalid_developer", 96)
    if definition.developer ~= nil and not developer then
        return nil, developer_error
    end

    local category = definition.category or "utilities"
    if not SkyPhoneApps.AllowedCategories[category] then
        return nil, "invalid_category"
    end

    local asset_resource = definition.assetResource
    if asset_resource ~= nil then
        if definition.compatibility == nil then
            return nil, "asset_resource_not_allowed"
        end
        local valid_asset_resource, asset_resource_error = validate_owner_resource(asset_resource, false)
        if not valid_asset_resource then
            return nil, asset_resource_error
        end
    end

    local ui, ui_error = normalize_asset_url(
        definition.ui,
        owner_resource,
        adapter_resource,
        asset_resource,
        true
    )
    if not ui then
        return nil, ui_error
    end

    local icon, icon_error = normalize_asset_url(
        definition.icon,
        owner_resource,
        adapter_resource,
        asset_resource,
        false
    )
    if definition.icon ~= nil and not icon then
        if definition.compatibility == nil then
            return nil, icon_error
        end
        Bridge.Debug(
            "warn",
            "[sky_phone] Custom app '%s' from '%s' uses an unavailable icon (%s); using the default icon.",
            definition.id,
            owner_resource,
            icon_error
        )
    end

    local permissions, permissions_error = SkyPhoneApps.ValidatePermissions(definition.permissions)
    if not permissions then
        return nil, permissions_error
    end

    local orientation = definition.orientation or "portrait"
    if not SkyPhoneApps.AllowedOrientations[orientation] then
        return nil, "invalid_orientation"
    end

    if definition.defaultInstalled ~= nil and type(definition.defaultInstalled) ~= "boolean" then
        return nil, "invalid_default_installed"
    end
    if definition.removable ~= nil and type(definition.removable) ~= "boolean" then
        return nil, "invalid_removable"
    end

    local grid_order = definition.gridOrder
    if grid_order ~= nil
        and (type(grid_order) ~= "number" or grid_order ~= math.floor(grid_order) or grid_order < 0 or grid_order > 9999)
    then
        return nil, "invalid_grid_order"
    end

    local icon_background = validate_optional_text(definition.iconBackground, "invalid_icon_background", 64)
    if definition.iconBackground ~= nil and not icon_background then
        return nil, "invalid_icon_background"
    end
    if icon_background and icon_background:find("[\r\n;{}]") then
        return nil, "invalid_icon_background"
    end

    local bridge_mode = definition.bridgeMode or "legacy"
    if bridge_mode ~= "sky" and bridge_mode ~= "legacy" then
        return nil, "invalid_bridge_mode"
    end

    local compatibility = nil
    if definition.compatibility ~= nil then
        if type(definition.compatibility) ~= "table" or next(definition.compatibility) == nil then
            return nil, "invalid_compatibility"
        end
        compatibility, permissions_error = normalize_json_payload(definition.compatibility, COMPATIBILITY_MAX_BYTES)
        if not compatibility then
            return nil, permissions_error
        end
    end

    local hooks = {}
    for hook_name in pairs(HOOK_NAMES) do
        local hook = definition[hook_name]
        if hook ~= nil and not is_callable(hook) then
            return nil, "invalid_" .. hook_name
        end
        hooks[hook_name] = hook
    end

    return {
        adapterResource = adapter_resource,
        catalog = {
            bridgeMode = bridge_mode,
            bundled = false,
            category = category,
            compatibility = compatibility,
            defaultInstalled = definition.defaultInstalled == true,
            description = description and resolve_localized_text(description) or nil,
            developer = developer,
            gridOrder = grid_order,
            icon = icon or default_icon_url,
            iconBackground = icon_background,
            id = definition.id,
            kind = "external",
            name = resolve_localized_text(name),
            orientation = orientation,
            ownerResource = owner_resource,
            permissions = permissions,
            readyTimeoutMs = Config.CustomApps.ReadyTimeoutMs,
            removable = definition.removable ~= false,
            ui = ui,
        },
        hooks = hooks,
        ownerResource = owner_resource,
    }
end

local function normalize_external_definition(owner_resource, adapter_resource, definition)
    local requested_id = type(definition) == "table" and definition.id or "<invalid>"
    debug_custom_app(
        "normalize",
        "begin id=%s owner=%s adapter=%s definition_type=%s",
        tostring(requested_id),
        tostring(owner_resource),
        tostring(adapter_resource),
        type(definition)
    )

    local app, definition_error = normalize_external_definition_value(owner_resource, adapter_resource, definition)
    if not app then
        debug_custom_app(
            "normalize",
            "rejected id=%s owner=%s error=%s",
            tostring(requested_id),
            tostring(owner_resource),
            tostring(definition_error)
        )
        return nil, definition_error
    end

    debug_custom_app(
        "normalize",
        "accepted id=%s owner=%s provider=%s ui=%s icon=%s default_installed=%s removable=%s",
        app.catalog.id,
        app.ownerResource,
        app.catalog.compatibility and tostring(app.catalog.compatibility.provider) or "native",
        app.catalog.ui,
        app.catalog.icon,
        tostring(app.catalog.defaultInstalled),
        tostring(app.catalog.removable)
    )
    return app
end

local function normalize_bundled_manifest(manifest)
    local resource_base_path = ("custom_apps/%s/"):format(manifest.folder)
    local base_url = ("https://cfx-nui-%s/%s"):format(current_resource, resource_base_path)
    if LoadResourceFile(current_resource, resource_base_path .. manifest.entry) == nil then
        error(("[sky_phone] Bundled custom app '%s' entry file is missing: %s"):format(
            manifest.id,
            manifest.entry
        ))
    end
    if manifest.icon and LoadResourceFile(current_resource, resource_base_path .. manifest.icon) == nil then
        error(("[sky_phone] Bundled custom app '%s' icon file is missing: %s"):format(
            manifest.id,
            manifest.icon
        ))
    end
    for index = 1, #manifest.screenshots do
        if LoadResourceFile(current_resource, resource_base_path .. manifest.screenshots[index]) == nil then
            error(("[sky_phone] Bundled custom app '%s' screenshot file is missing: %s"):format(
                manifest.id,
                manifest.screenshots[index]
            ))
        end
    end

    return {
        adapterResource = nil,
        catalog = {
            bridgeMode = manifest.bridgeMode,
            bundled = true,
            category = manifest.category,
            defaultInstalled = manifest.defaultInstalled,
            description = resolve_localized_text(manifest.description),
            developer = manifest.developer,
            gridOrder = manifest.gridOrder,
            icon = manifest.icon and (base_url .. manifest.icon) or default_icon_url,
            iconBackground = manifest.iconBackground,
            id = manifest.id,
            kind = "external",
            name = resolve_localized_text(manifest.name),
            orientation = manifest.orientation,
            ownerResource = current_resource,
            permissions = manifest.permissions,
            readyTimeoutMs = Config.CustomApps.ReadyTimeoutMs,
            removable = manifest.removable,
            ui = base_url .. manifest.entry,
        },
        hooks = {},
        ownerResource = current_resource,
    }
end

local function get_catalog()
    local catalog = {}
    for _, app in pairs(apps_by_id) do
        catalog[#catalog + 1] = app.catalog
    end
    table.sort(catalog, function(left, right)
        return left.id < right.id
    end)
    return catalog
end

local function send_catalog()
    local catalog = get_catalog()
    local entries = {}
    for index = 1, #catalog do
        local app = catalog[index]
        entries[index] = ("%s(owner=%s,default=%s)"):format(
            app.id,
            app.ownerResource,
            tostring(app.defaultInstalled)
        )
    end
    debug_custom_app(
        "catalog",
        "sending %s app(s) to NUI: %s",
        #catalog,
        #entries > 0 and table.concat(entries, ", ") or "<empty>"
    )
    SendNUIMessage({
        type = "custom-apps:catalog",
        data = {
            apps = catalog,
            debug = Config.CustomApps.Debug == true,
        },
    })
end

local function sync_catalog()
    debug_custom_app(
        "catalog",
        "synchronizing catalog phone_open=%s",
        tostring(phone_open)
    )
    send_catalog()
end

local function add_owner_index(index, resource_name, app_id)
    local app_ids = index[resource_name]
    if not app_ids then
        app_ids = {}
        index[resource_name] = app_ids
    end
    app_ids[app_id] = true
end

local function remove_owner_index(index, resource_name, app_id)
    local app_ids = index[resource_name]
    if not app_ids then
        return
    end

    app_ids[app_id] = nil
    if not next(app_ids) then
        index[resource_name] = nil
    end
end

local function register_app(app)
    local app_id = app.catalog.id
    local existing = apps_by_id[app_id]
    if existing then
        debug_custom_app(
            "register",
            "duplicate id=%s requested_owner=%s existing_owner=%s",
            app_id,
            app.ownerResource,
            existing.ownerResource
        )
        Bridge.Debug(
            "warn",
            "[sky_phone] Rejected duplicate custom app '%s' from '%s'; it is already owned by '%s'.",
            app_id,
            app.ownerResource,
            existing.ownerResource
        )
        return false, "duplicate_app_id"
    end

    apps_by_id[app_id] = app
    add_owner_index(app_ids_by_owner, app.ownerResource, app_id)
    if app.adapterResource then
        add_owner_index(app_ids_by_adapter, app.adapterResource, app_id)
    end
    debug_custom_app(
        "register",
        "success id=%s owner=%s adapter=%s provider=%s default_installed=%s phone_open=%s",
        app_id,
        app.ownerResource,
        tostring(app.adapterResource),
        app.catalog.compatibility and tostring(app.catalog.compatibility.provider) or "native",
        tostring(app.catalog.defaultInstalled),
        tostring(phone_open)
    )
    sync_catalog()
    return true
end

local function invoke_hook(app, hook_name, payload)
    local hook = app.hooks[hook_name]
    if not hook then
        return true
    end

    local success, hook_error = xpcall(function()
        hook(payload)
    end, debug.traceback)
    if success then
        return true
    end

    Bridge.Debug("error", "[sky_phone] Custom app '%s' hook '%s' failed: %s",
        app.catalog.id,
        hook_name,
        tostring(hook_error)
    )
    return false
end

local function invoke_or_defer_hook(app, hook_name, payload, deferred_hooks)
    if not app.catalog.compatibility then
        return invoke_hook(app, hook_name, payload)
    end

    deferred_hooks[#deferred_hooks + 1] = {
        app = app,
        hookName = hook_name,
        payload = payload,
    }
    return true
end

local function invoke_deferred_hooks(deferred_hooks)
    for index = 1, #deferred_hooks do
        local deferred_hook = deferred_hooks[index]
        CreateThread(function()
            invoke_hook(deferred_hook.app, deferred_hook.hookName, deferred_hook.payload)
        end)
    end
end

local function clear_active_app(invoke_close_hook, deferred_hooks)
    if not active_app_id then
        return
    end

    local app = apps_by_id[active_app_id]
    if app and invoke_close_hook then
        if deferred_hooks then
            invoke_or_defer_hook(app, "onClose", nil, deferred_hooks)
        else
            invoke_hook(app, "onClose")
        end
    end
    queued_messages[active_app_id] = nil
    active_app_id = nil
    active_app_ready = false
end

local function remove_registered_app(app_id, invoke_close_hook, synchronize)
    local app = apps_by_id[app_id]
    if not app then
        debug_custom_app("remove", "rejected id=%s error=app_not_found", tostring(app_id))
        return false, "app_not_found"
    end

    if active_app_id == app_id then
        SendNUIMessage({ type = "custom-app:close", data = { appId = app_id } })
        clear_active_app(invoke_close_hook)
    end

    apps_by_id[app_id] = nil
    remove_owner_index(app_ids_by_owner, app.ownerResource, app_id)
    if app.adapterResource then
        remove_owner_index(app_ids_by_adapter, app.adapterResource, app_id)
    end
    TriggerEvent("sky_phone:client:customAppRemoved", app.ownerResource, app_id)
    if synchronize then
        sync_catalog()
    end
    debug_custom_app(
        "remove",
        "success id=%s owner=%s synchronize=%s",
        app_id,
        app.ownerResource,
        tostring(synchronize)
    )
    return true
end

local function get_direct_owner()
    local owner_resource = GetInvokingResource()
    if not owner_resource then
        debug_custom_app("owner", "rejected export call: GetInvokingResource returned nil")
        return nil, "missing_invoking_resource"
    end

    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        debug_custom_app(
            "owner",
            "rejected invoking_resource=%s state=%s error=%s",
            owner_resource,
            tostring(GetResourceState(owner_resource)),
            tostring(owner_error)
        )
        return nil, owner_error
    end

    debug_custom_app(
        "owner",
        "accepted invoking_resource=%s state=%s",
        owner_resource,
        tostring(GetResourceState(owner_resource))
    )
    return owner_resource
end

local function get_trusted_adapter()
    local adapter_resource = GetInvokingResource()
    if not adapter_resource or not Config.CustomApps.TrustedAdapters[adapter_resource] then
        return nil, "untrusted_adapter"
    end

    local valid_adapter, adapter_error = validate_owner_resource(adapter_resource, false)
    if not valid_adapter then
        return nil, adapter_error
    end

    return adapter_resource
end

local function verify_owned_app(owner_resource, app_id, adapter_resource)
    local valid_id, id_error = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id then
        return nil, id_error
    end

    local app = apps_by_id[app_id]
    if not app then
        return nil, "app_not_found"
    end
    if app.ownerResource ~= owner_resource then
        return nil, "app_owner_mismatch"
    end
    if adapter_resource and app.adapterResource ~= adapter_resource then
        return nil, "app_adapter_mismatch"
    end

    return app
end

local function add_custom_app(definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local app, definition_error = normalize_external_definition(owner_resource, nil, definition)
    if not app then
        return false, definition_error
    end

    return register_app(app)
end

local function add_custom_app_from_adapter(owner_resource, definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end

    local app, definition_error = normalize_external_definition(owner_resource, adapter_resource, definition)
    if not app then
        return false, definition_error
    end

    return register_app(app)
end

local function add_compatibility_app(owner_resource, definition)
    local app_id = type(definition) == "table" and definition.id or "<invalid>"
    debug_custom_app(
        "compat-core",
        "add requested id=%s owner=%s",
        tostring(app_id),
        tostring(owner_resource)
    )
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        debug_custom_app("compat-core", "add rejected id=%s error=external_apps_disabled", tostring(app_id))
        return false, "external_apps_disabled"
    end

    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        debug_custom_app(
            "compat-core",
            "add rejected id=%s owner=%s state=%s error=%s",
            tostring(app_id),
            tostring(owner_resource),
            tostring(GetResourceState(owner_resource)),
            tostring(owner_error)
        )
        return false, owner_error
    end

    local app, definition_error = normalize_external_definition(owner_resource, nil, definition)
    if not app then
        debug_custom_app(
            "compat-core",
            "add rejected id=%s owner=%s error=%s",
            tostring(app_id),
            tostring(owner_resource),
            tostring(definition_error)
        )
        return false, definition_error
    end

    local success, register_error = register_app(app)
    debug_custom_app(
        "compat-core",
        "add result id=%s owner=%s success=%s error=%s",
        tostring(app_id),
        tostring(owner_resource),
        tostring(success),
        tostring(register_error)
    )
    return success, register_error
end

local function normalize_server_authorized_app(owner_resource, provider, definition)
    local valid_owner, owner_error = validate_owner_resource_name(owner_resource)
    if not valid_owner then
        return nil, owner_error
    end
    if type(provider) ~= "string" or provider == "" or #provider > 64 then
        return nil, "invalid_provider"
    end
    if type(definition) ~= "table"
        or type(definition.compatibility) ~= "table"
        or definition.compatibility.provider ~= provider
    then
        return nil, "app_provider_mismatch"
    end

    local app, definition_error = normalize_external_definition(owner_resource, nil, definition)
    if not app then
        return nil, definition_error
    end
    app.authority = {
        provider = provider,
        side = "server",
    }
    return app
end

local function add_server_authorized_compatibility_app(owner_resource, provider, definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local app, app_error = normalize_server_authorized_app(owner_resource, provider, definition)
    if not app then
        return false, app_error
    end
    return register_app(app)
end

local function replace_registered_app(app, adapter_resource, allow_server_promotion)
    local app_id = app.catalog.id
    local existing = apps_by_id[app_id]
    if not existing then
        return false, "app_not_found"
    end
    if existing.catalog.bundled then
        return false, "bundled_app"
    end
    if existing.ownerResource ~= app.ownerResource then
        return false, "app_owner_mismatch"
    end
    if existing.adapterResource ~= adapter_resource then
        return false, "app_adapter_mismatch"
    end
    local existing_authority = existing.authority
    local next_authority = app.authority
    local same_authority = type(existing_authority) == "table"
        and type(next_authority) == "table"
        and existing_authority.side == next_authority.side
        and existing_authority.provider == next_authority.provider
    local server_promotion = allow_server_promotion == true
        and existing_authority == nil
        and type(next_authority) == "table"
        and next_authority.side == "server"
        and type(existing.catalog.compatibility) == "table"
        and existing.catalog.compatibility.provider == next_authority.provider
    if (existing_authority ~= nil or next_authority ~= nil)
        and not same_authority
        and not server_promotion
    then
        return false, "app_authority_mismatch"
    end

    apps_by_id[app_id] = app
    debug_custom_app(
        "update",
        "success id=%s owner=%s adapter=%s default_installed=%s",
        app_id,
        app.ownerResource,
        tostring(adapter_resource),
        tostring(app.catalog.defaultInstalled)
    )
    sync_catalog()
    return true
end

local function update_custom_app(definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local app, definition_error = normalize_external_definition(owner_resource, nil, definition)
    if not app then
        return false, definition_error
    end
    return replace_registered_app(app, nil)
end

local function update_custom_app_from_adapter(owner_resource, definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end

    local app, definition_error = normalize_external_definition(owner_resource, adapter_resource, definition)
    if not app then
        return false, definition_error
    end
    return replace_registered_app(app, adapter_resource)
end

local function update_compatibility_app(owner_resource, definition)
    local app_id = type(definition) == "table" and definition.id or "<invalid>"
    debug_custom_app(
        "compat-core",
        "update requested id=%s owner=%s",
        tostring(app_id),
        tostring(owner_resource)
    )
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end

    local app, definition_error = normalize_external_definition(owner_resource, nil, definition)
    if not app then
        debug_custom_app(
            "compat-core",
            "update rejected id=%s owner=%s error=%s",
            tostring(app_id),
            tostring(owner_resource),
            tostring(definition_error)
        )
        return false, definition_error
    end
    local success, update_error = replace_registered_app(app, nil)
    debug_custom_app(
        "compat-core",
        "update result id=%s owner=%s success=%s error=%s",
        tostring(app_id),
        tostring(owner_resource),
        tostring(success),
        tostring(update_error)
    )
    return success, update_error
end

local function update_server_authorized_compatibility_app(owner_resource, provider, definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local app, app_error = normalize_server_authorized_app(owner_resource, provider, definition)
    if not app then
        return false, app_error
    end
    return replace_registered_app(app, nil, true)
end

local function remove_custom_app(app_id)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local app, app_error = verify_owned_app(owner_resource, app_id)
    if not app then
        return false, app_error
    end
    if app.catalog.bundled then
        return false, "bundled_app"
    end
    if app.authority then
        return false, "app_authority_mismatch"
    end

    return remove_registered_app(app_id, true, true)
end

local function remove_custom_app_from_adapter(owner_resource, app_id)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end

    local app, app_error = verify_owned_app(owner_resource, app_id, adapter_resource)
    if not app then
        return false, app_error
    end

    return remove_registered_app(app_id, true, true)
end

local function remove_compatibility_app(owner_resource, app_id)
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end

    local app, app_error = verify_owned_app(owner_resource, app_id)
    if not app then
        return false, app_error
    end
    if app.catalog.bundled then
        return false, "bundled_app"
    end
    if app.authority then
        return false, "app_authority_mismatch"
    end

    return remove_registered_app(app_id, true, true)
end

local function remove_server_authorized_compatibility_app(owner_resource, provider, app_id)
    local valid_owner, owner_error = validate_owner_resource_name(owner_resource)
    if not valid_owner then
        return false, owner_error
    end
    if type(provider) ~= "string" or provider == "" or #provider > 64 then
        return false, "invalid_provider"
    end

    local app, app_error = verify_owned_app(owner_resource, app_id)
    if not app then
        return false, app_error
    end
    local authority = app.authority
    if type(authority) ~= "table"
        or authority.side ~= "server"
        or authority.provider ~= provider
    then
        return false, "app_authority_mismatch"
    end
    if type(app.catalog.compatibility) ~= "table"
        or app.catalog.compatibility.provider ~= provider
    then
        return false, "app_provider_mismatch"
    end
    return remove_registered_app(app_id, true, true)
end

local function deliver_custom_app_message(app_id, payload)
    SendNUIMessage({
        type = "custom-app:message",
        data = {
            appId = app_id,
            payload = payload,
        },
    })
end

local function send_owned_custom_app_message(owner_resource, app_id, payload, adapter_resource)
    local app, app_error = verify_owned_app(owner_resource, app_id, adapter_resource)
    if not app then
        return false, app_error
    end
    if not phone_open or active_app_id ~= app_id then
        return false, "app_not_active"
    end

    local normalized_payload, payload_error = normalize_json_payload(
        payload,
        Config.CustomApps.MaximumMessageBytes
    )
    if payload_error then
        return false, payload_error
    end

    if active_app_ready then
        deliver_custom_app_message(app_id, normalized_payload)
        return true
    end

    local pending = queued_messages[app_id] or {}
    if #pending >= MAX_QUEUED_MESSAGES then
        return false, "message_queue_full"
    end
    pending[#pending + 1] = { payload = normalized_payload }
    queued_messages[app_id] = pending
    return true
end

local function send_custom_app_message(app_id, payload)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end
    return send_owned_custom_app_message(owner_resource, app_id, payload)
end

local function send_custom_app_message_from_adapter(owner_resource, app_id, payload)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    return send_owned_custom_app_message(owner_resource, app_id, payload, adapter_resource)
end

local function send_compatibility_app_message(owner_resource, app_id, payload)
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end
    return send_owned_custom_app_message(owner_resource, app_id, payload)
end

local function open_owned_custom_app(owner_resource, app_id, payload, adapter_resource)
    local app, app_error = verify_owned_app(owner_resource, app_id, adapter_resource)
    if not app then
        return false, app_error
    end
    if not phone_open then
        return false, "phone_closed"
    end

    local normalized_payload, payload_error = normalize_json_payload(
        payload,
        Config.CustomApps.MaximumMessageBytes
    )
    if payload_error then
        return false, payload_error
    end

    SendNUIMessage({
        type = "custom-app:open",
        data = {
            appId = app_id,
            data = normalized_payload,
        },
    })
    return true
end

local function open_custom_app(app_id, payload)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end
    return open_owned_custom_app(owner_resource, app_id, payload)
end

local function open_custom_app_from_adapter(owner_resource, app_id, payload)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    return open_owned_custom_app(owner_resource, app_id, payload, adapter_resource)
end

local function open_compatibility_app(owner_resource, app_id, payload)
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end
    return open_owned_custom_app(owner_resource, app_id, payload)
end

local function close_owned_custom_app(owner_resource, app_id, adapter_resource)
    local app, app_error = verify_owned_app(owner_resource, app_id, adapter_resource)
    if not app then
        return false, app_error
    end
    if active_app_id ~= app_id then
        return false, "app_not_active"
    end

    SendNUIMessage({ type = "custom-app:close", data = { appId = app_id } })
    return true
end

local function close_custom_app(app_id)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end
    return close_owned_custom_app(owner_resource, app_id)
end

local function close_custom_app_from_adapter(owner_resource, app_id)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    return close_owned_custom_app(owner_resource, app_id, adapter_resource)
end

local function close_active_custom_app_from_adapter(owner_resource)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    if not active_app_id then
        return false, "app_not_active"
    end

    local app, app_error = verify_owned_app(owner_resource, active_app_id, adapter_resource)
    if not app then
        return false, app_error
    end

    SendNUIMessage({ type = "custom-app:close", data = { appId = active_app_id } })
    return true
end

local function close_compatibility_app(owner_resource, app_id)
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end
    return close_owned_custom_app(owner_resource, app_id)
end

local function close_active_compatibility_app(owner_resource)
    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return false, owner_error
    end
    if not active_app_id then
        return false, "app_not_active"
    end

    local app, app_error = verify_owned_app(owner_resource, active_app_id)
    if not app then
        return false, app_error
    end

    SendNUIMessage({ type = "custom-app:close", data = { appId = active_app_id } })
    return true
end

local function has_permission(app, permission)
    local permissions = app.catalog.permissions
    for index = 1, #permissions do
        if permissions[index] == permission then
            return true
        end
    end
    return false
end

local function normalize_notification(app, notification)
    if type(notification) ~= "table" then
        return nil, "invalid_notification"
    end
    if not has_permission(app, "notifications") then
        return nil, "permission_denied"
    end

    local title = notification.title
    if title == nil then
        title = app.catalog.name
    end
    title = validate_optional_text(title, "invalid_notification_title", NOTIFICATION_TITLE_MAX_LENGTH)
    if not title then
        return nil, "invalid_notification_title"
    end

    local text = validate_optional_text(
        notification.text or notification.content,
        "invalid_notification_text",
        NOTIFICATION_TEXT_MAX_LENGTH
    )
    if not text then
        return nil, "invalid_notification_text"
    end

    local subtitle = validate_optional_text(notification.subtitle, "invalid_notification_subtitle", 160)
    if notification.subtitle ~= nil and not subtitle then
        return nil, "invalid_notification_subtitle"
    end

    if notification.critical ~= nil and type(notification.critical) ~= "boolean" then
        return nil, "invalid_notification_critical"
    end
    if notification.critical and not has_permission(app, "notifications.critical") then
        return nil, "permission_denied"
    end
    if notification.persistent ~= nil and type(notification.persistent) ~= "boolean" then
        return nil, "invalid_notification_persistent"
    end
    if notification.sound ~= nil and not NOTIFICATION_SOUNDS[notification.sound] then
        return nil, "invalid_notification_sound"
    end

    local app_route = "/apps/" .. app.catalog.id
    local route = notification.route or app_route
    if type(route) ~= "string"
        or route ~= app_route
        or route:find("[\r\n]")
        or #route > 512
    then
        return nil, "invalid_notification_route"
    end

    return {
        appId = app.catalog.id,
        critical = notification.critical == true,
        persistent = notification.persistent == true,
        route = route,
        sound = notification.sound,
        subtitle = subtitle,
        text = text,
        title = title,
    }
end

local function send_owned_custom_app_notification(owner_resource, app_id, notification, adapter_resource)
    local app, app_error = verify_owned_app(owner_resource, app_id, adapter_resource)
    if not app then
        return false, app_error
    end

    local normalized_notification, notification_error = normalize_notification(app, notification)
    if not normalized_notification then
        return false, notification_error
    end

    send_catalog()
    SendNUIMessage({ type = "notification:show", data = normalized_notification })
    return true
end

local function send_custom_app_notification(app_id, notification)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end
    return send_owned_custom_app_notification(owner_resource, app_id, notification)
end

local function send_custom_app_notification_from_adapter(owner_resource, app_id, notification)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end
    return send_owned_custom_app_notification(owner_resource, app_id, notification, adapter_resource)
end

local function get_custom_app_capabilities()
    return {
        abiVersion = 1,
        enabled = Config.CustomApps.Enabled == true,
        bridgeMethods = {
            "app.close",
            "app.open",
            "device.storage.get",
            "device.storage.set",
            "notification.create",
        },
        contextCapabilities = {
            "locale.read",
            "theme.read",
        },
        exports = {
            "AddCustomApp",
            "AddCustomAppFromAdapter",
            "CloseActiveCustomAppFromAdapter",
            "CloseCustomApp",
            "CloseCustomAppFromAdapter",
            "OpenCustomApp",
            "OpenCustomAppFromAdapter",
            "RemoveCustomApp",
            "RemoveCustomAppFromAdapter",
            "SendAppMessage",
            "SendCustomAppMessage",
            "SendCustomAppMessageFromAdapter",
            "SendCustomAppNotification",
            "SendCustomAppNotificationFromAdapter",
            "UpdateCustomApp",
            "UpdateCustomAppFromAdapter",
        },
        externalApps = Config.CustomApps.Enabled == true
            and Config.CustomApps.ExternalApps == true,
        maximumMessageBytes = Config.CustomApps.MaximumMessageBytes,
        maximumStorageBytesPerApp = Config.CustomApps.MaximumStorageBytesPerApp,
        maximumStorageKeyLength = math.min(Config.CustomApps.MaximumStorageKeyLength, 64),
        maximumStorageValueBytes = math.min(Config.CustomApps.MaximumStorageValueBytes, 65536),
        messageDispatch = true,
        protocolVersion = SkyPhoneApps.ProtocolVersion,
    }
end

local function set_phone_open(is_open)
    phone_open = is_open
    debug_custom_app(
        "phone",
        "state changed open=%s active_app=%s registered_apps=%s",
        tostring(phone_open),
        tostring(active_app_id),
        #get_catalog()
    )
    if phone_open then
        send_catalog()
        return
    end

    clear_active_app(true)
end

local function register_bundled_client_hooks(app_id, hooks)
    local valid_id, id_error = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id then
        return false, id_error
    end

    local app = apps_by_id[app_id]
    if not app then
        return false, "app_not_found"
    end
    if not app.catalog.bundled then
        return false, "external_app"
    end
    if type(hooks) ~= "table" then
        return false, "invalid_hooks"
    end

    local normalized_hooks = {}
    for hook_name, hook in pairs(hooks) do
        if not HOOK_NAMES[hook_name] or type(hook) ~= "function" then
            return false, "invalid_hook"
        end
        normalized_hooks[hook_name] = hook
    end

    app.hooks = normalized_hooks
    return true
end

function SkyPhoneApps.CanReceiveNotification(app_id)
    local valid_id = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id then
        return false
    end
    return SkyPhoneApps.ReservedAppIds[app_id] == true or apps_by_id[app_id] ~= nil
end

SkyPhoneApps.SendCatalog = send_catalog
SkyPhoneApps.SetPhoneOpen = set_phone_open
SkyPhoneApps.RegisterClientHooks = register_bundled_client_hooks

local function refresh_bundled_apps()
    local manifests = Config.CustomApps.Enabled and Config.CustomApps.BundledApps
        and SkyPhoneApps.GetBundledManifests()
        or {}
    local desired_ids = {}
    for index = 1, #manifests do
        desired_ids[manifests[index].id] = true
    end

    local removals = {}
    for app_id, app in pairs(apps_by_id) do
        if app.catalog.bundled and not desired_ids[app_id] then
            removals[#removals + 1] = app_id
        end
    end
    for index = 1, #removals do
        remove_registered_app(removals[index], true, false)
    end

    for index = 1, #manifests do
        local manifest = manifests[index]
        local existing = apps_by_id[manifest.id]
        local normalized = normalize_bundled_manifest(manifest)
        if existing and existing.catalog.bundled then
            normalized.hooks = existing.hooks
            apps_by_id[manifest.id] = normalized
        elseif not existing then
            local registered, register_error = register_app(normalized)
            if not registered then
                error(("[sky_phone] Could not register bundled custom app '%s': %s"):format(
                    manifest.id,
                    register_error
                ))
            end
        end
    end
    sync_catalog()
end

refresh_bundled_apps()

AddEventHandler("sky_phone:configurator:updated", refresh_bundled_apps)

SkyPhoneApps.CompatibilityCore = {
    Add = add_compatibility_app,
    AddServerAuthorized = add_server_authorized_compatibility_app,
    Close = close_compatibility_app,
    CloseActive = close_active_compatibility_app,
    Open = open_compatibility_app,
    Remove = remove_compatibility_app,
    RemoveServerAuthorized = remove_server_authorized_compatibility_app,
    SendMessage = send_compatibility_app_message,
    Update = update_compatibility_app,
    UpdateServerAuthorized = update_server_authorized_compatibility_app,
}

SkyPhoneApps.ClientPublicApi = {
    AddCustomApp = add_custom_app,
    AddCustomAppFromAdapter = add_custom_app_from_adapter,
    CloseActiveCustomAppFromAdapter = close_active_custom_app_from_adapter,
    CloseCustomApp = close_custom_app,
    CloseCustomAppFromAdapter = close_custom_app_from_adapter,
    GetCustomAppCapabilities = get_custom_app_capabilities,
    OpenCustomApp = open_custom_app,
    OpenCustomAppFromAdapter = open_custom_app_from_adapter,
    RemoveCustomApp = remove_custom_app,
    RemoveCustomAppFromAdapter = remove_custom_app_from_adapter,
    SendAppMessage = send_custom_app_message,
    SendCustomAppMessage = send_custom_app_message,
    SendCustomAppMessageFromAdapter = send_custom_app_message_from_adapter,
    SendCustomAppNotification = send_custom_app_notification,
    SendCustomAppNotificationFromAdapter = send_custom_app_notification_from_adapter,
    UpdateCustomApp = update_custom_app,
    UpdateCustomAppFromAdapter = update_custom_app_from_adapter,
}

RegisterNetEvent("sky_phone:custom-app:message", function(owner_resource, app_id, payload)
    if source ~= 65535 then
        Bridge.Debug("warn", "[sky_phone] Rejected a client-triggered custom app message.")
        return
    end

    local success, message_error = send_compatibility_app_message(
        owner_resource,
        app_id,
        payload
    )
    if not success then
        Bridge.Debug(
            "warn",
            "[sky_phone] Server custom app message for %s could not be delivered: %s.",
            tostring(app_id),
            tostring(message_error)
        )
    end
end)

RegisterNUICallback("custom-app:catalog-debug", function(data, cb)
    local accepted_ids = type(data) == "table" and data.acceptedIds or nil
    local ids = {}
    if type(accepted_ids) == "table" then
        for index = 1, #accepted_ids do
            if type(accepted_ids[index]) == "string" then
                ids[#ids + 1] = accepted_ids[index]
            end
        end
    end

    debug_custom_app(
        "nui",
        "catalog applied received=%s accepted=%s ids=%s",
        type(data) == "table" and tostring(data.receivedCount) or "invalid",
        type(data) == "table" and tostring(data.acceptedCount) or "invalid",
        #ids > 0 and table.concat(ids, ", ") or "<empty>"
    )
    cb({ success = true })
end)

RegisterNUICallback("custom-app:lifecycle", function(data, cb)
    local requested_app_id = type(data) == "table" and data.appId or nil
    local requested_event = type(data) == "table" and data.event or nil
    local function respond(success, error_message)
        debug_custom_app(
            "lifecycle",
            "result app=%s event=%s success=%s error=%s active_app=%s ready=%s phone_open=%s",
            tostring(requested_app_id),
            tostring(requested_event),
            tostring(success),
            tostring(error_message),
            tostring(active_app_id),
            tostring(active_app_ready),
            tostring(phone_open)
        )
        local response = { success = success }
        if error_message then
            response.error = error_message
        end
        cb(response)
    end

    debug_custom_app(
        "lifecycle",
        "request app=%s event=%s phone_open=%s active_app=%s ready=%s",
        tostring(requested_app_id),
        tostring(requested_event),
        tostring(phone_open),
        tostring(active_app_id),
        tostring(active_app_ready)
    )
    if type(data) ~= "table" then
        respond(false, "invalid_lifecycle_request")
        return
    end

    local valid_id, id_error = SkyPhoneApps.ValidateAppId(data.appId)
    if not valid_id then
        respond(false, id_error)
        return
    end

    local lifecycle_event = data.event
    if lifecycle_event ~= "install"
        and lifecycle_event ~= "delete"
        and lifecycle_event ~= "open"
        and lifecycle_event ~= "ready"
        and lifecycle_event ~= "close"
    then
        respond(false, "invalid_lifecycle_event")
        return
    end

    local app = apps_by_id[data.appId]
    if lifecycle_event == "close"
        and (not phone_open or not app or active_app_id ~= data.appId)
    then
        respond(true)
        return
    end
    if not phone_open then
        respond(false, "phone_closed")
        return
    end
    if not app then
        respond(false, "app_not_found")
        return
    end

    local lifecycle_payload, payload_error = normalize_json_payload(
        data.data,
        Config.CustomApps.MaximumMessageBytes
    )
    if payload_error then
        respond(false, payload_error)
        return
    end

    local deferred_hooks = {}
    local hook_success = true
    if lifecycle_event == "install" then
        hook_success = invoke_or_defer_hook(app, "onInstall", lifecycle_payload, deferred_hooks)
    elseif lifecycle_event == "delete" then
        hook_success = invoke_or_defer_hook(app, "onDelete", lifecycle_payload, deferred_hooks)
    elseif lifecycle_event == "open" then
        if active_app_id and active_app_id ~= data.appId then
            clear_active_app(true, deferred_hooks)
        end
        active_app_id = data.appId
        active_app_ready = false
        queued_messages[data.appId] = {}
        hook_success = invoke_or_defer_hook(app, "onOpen", lifecycle_payload, deferred_hooks)
    elseif active_app_id ~= data.appId then
        respond(false, "app_not_active")
        return
    elseif lifecycle_event == "ready" then
        if active_app_ready then
            respond(true)
            return
        end
        active_app_ready = true
        local pending = queued_messages[data.appId] or {}
        queued_messages[data.appId] = {}
        for index = 1, #pending do
            deliver_custom_app_message(data.appId, pending[index].payload)
        end
        hook_success = invoke_or_defer_hook(app, "onReady", lifecycle_payload, deferred_hooks)
    else
        hook_success = invoke_or_defer_hook(app, "onClose", lifecycle_payload, deferred_hooks)
        clear_active_app(false)
    end

    if not hook_success then
        respond(false, "hook_failed")
        return
    end
    respond(true)
    invoke_deferred_hooks(deferred_hooks)
end)

AddEventHandler("onClientResourceStop", function(resource_name)
    if resource_name == current_resource then
        return
    end

    debug_custom_app(
        "resource",
        "stop detected resource=%s owner_apps=%s adapter_apps=%s",
        tostring(resource_name),
        tostring(app_ids_by_owner[resource_name] ~= nil),
        tostring(app_ids_by_adapter[resource_name] ~= nil)
    )

    local app_ids = {}
    local owner_apps = app_ids_by_owner[resource_name]
    if owner_apps then
        for app_id in pairs(owner_apps) do
            app_ids[app_id] = true
        end
    end

    local adapter_apps = app_ids_by_adapter[resource_name]
    if adapter_apps then
        for app_id in pairs(adapter_apps) do
            app_ids[app_id] = true
        end
    end

    local removed = false
    for app_id in pairs(app_ids) do
        local success = remove_registered_app(app_id, false, false)
        removed = success or removed
    end
    if removed then
        sync_catalog()
    end
    debug_custom_app(
        "resource",
        "stop cleanup resource=%s removed_any=%s",
        tostring(resource_name),
        tostring(removed)
    )
end)
