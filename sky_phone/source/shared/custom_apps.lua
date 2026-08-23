local APP_ID_MAX_LENGTH = 64
local DESCRIPTION_MAX_LENGTH = 320
local DEVELOPER_MAX_LENGTH = 96
local NAME_MAX_LENGTH = 64
local PATH_MAX_LENGTH = 512
local VERSION_MAX_LENGTH = 32

local ALLOWED_CATEGORIES = {
    games = true,
    productivity = true,
    shopping = true,
    social = true,
    utilities = true,
}

local ALLOWED_ORIENTATIONS = {
    any = true,
    landscape = true,
    portrait = true,
}

local ALLOWED_PERMISSIONS = {
    ["app.close"] = true,
    ["app.open"] = true,
    ["camera.capture"] = true,
    ["contacts.pick"] = true,
    ["device.storage"] = true,
    ["locale.read"] = true,
    ["location.read"] = true,
    ["media.pick"] = true,
    ["notifications"] = true,
    ["notifications.critical"] = true,
    ["nui.fetch"] = true,
    ["theme.read"] = true,
}

local RESERVED_APP_IDS = {
    admin = true,
    ["app-store"] = true,
    banking = true,
    crypto = true,
    billing = true,
    calculator = true,
    calendar = true,
    camera = true,
    citymarkt = true,
    clock = true,
    companies = true,
    crewlink = true,
    darkchat = true,
    feather = true,
    flare = true,
    fliptok = true,
    garage = true,
    house = true,
    ["local-pages"] = true,
    mail = true,
    map = true,
    memory = true,
    messages = true,
    minesweeper = true,
    music = true,
    ["neon-drop"] = true,
    notes = true,
    memos = true,
    ["number-merge"] = true,
    phone = true,
    photos = true,
    picstagram = true,
    radio = true,
    settings = true,
    ["sky-flappy"] = true,
    skyride = true,
    snake = true,
    ["tower-stack"] = true,
    weather = true,
}

local bundled_manifests = {}
local bundled_manifests_by_id = {}

SkyPhoneApps = SkyPhoneApps or {}
SkyPhoneApps.ProtocolVersion = 1

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function validate_app_id(app_id)
    if type(app_id) ~= "string" then
        return false, "invalid_app_id"
    end

    if #app_id == 0 or #app_id > APP_ID_MAX_LENGTH then
        return false, "invalid_app_id"
    end

    if not app_id:match("^[a-z0-9][a-z0-9._-]+$") then
        return false, "invalid_app_id"
    end

    return true
end

local function validate_text(value, error_code, maximum_length, required)
    if value == nil and not required then
        return nil
    end

    if type(value) ~= "string" then
        return nil, error_code
    end

    local normalized = trim(value)
    if (required and #normalized == 0) or #normalized > maximum_length then
        return nil, error_code
    end

    return normalized
end

local function validate_localized_text(value, error_code, maximum_length, required)
    if type(value) == "string" then
        return validate_text(value, error_code, maximum_length, required)
    end

    if type(value) ~= "table" then
        return nil, error_code
    end

    local normalized = {}
    local count = 0
    for locale, text in pairs(value) do
        if type(locale) ~= "string" or not locale:match("^[a-zA-Z][a-zA-Z0-9_-]*$") then
            return nil, error_code
        end

        local normalized_text = validate_text(text, error_code, maximum_length, true)
        if not normalized_text then
            return nil, error_code
        end

        count = count + 1
        if count > 16 then
            return nil, error_code
        end

        normalized[locale:lower():gsub("_", "-")] = normalized_text
    end

    if count == 0 then
        return nil, error_code
    end

    return normalized
end

local function validate_local_path(path, required)
    if path == nil and not required then
        return nil
    end

    if type(path) ~= "string" or #path == 0 or #path > PATH_MAX_LENGTH then
        return nil, "invalid_local_path"
    end

    if path:sub(1, 1) == "/" or path:find("\\", 1, true) or path:find(":", 1, true) then
        return nil, "invalid_local_path"
    end

    if not path:match("^web/[%w%._%-%/]+$") then
        return nil, "invalid_local_path"
    end

    for segment in path:gmatch("[^/]+") do
        if segment == "." or segment == ".." then
            return nil, "invalid_local_path"
        end
    end

    return path
end

local function validate_string_array(value, error_code, maximum_items, validator)
    if value == nil then
        return {}
    end

    if type(value) ~= "table" then
        return nil, error_code
    end

    local normalized = {}
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return nil, error_code
        end
        count = count + 1
    end

    if count ~= #value or count > maximum_items then
        return nil, error_code
    end

    for index = 1, count do
        local item = value[index]
        if type(item) ~= "string" then
            return nil, error_code
        end

        local normalized_item, validation_error = validator(item)
        if not normalized_item then
            return nil, validation_error or error_code
        end

        normalized[index] = normalized_item
    end

    return normalized
end

local function validate_permissions(value)
    local permissions, error_code = validate_string_array(
        value,
        "invalid_permissions",
        32,
        function(permission)
            if not ALLOWED_PERMISSIONS[permission] then
                return nil, "unknown_permission"
            end
            return permission
        end
    )
    if not permissions then
        return nil, error_code
    end

    local seen = {}
    for index = 1, #permissions do
        local permission = permissions[index]
        if seen[permission] then
            return nil, "duplicate_permission"
        end
        seen[permission] = true
    end

    return permissions
end

local function validate_grid_order(value)
    if value == nil then
        return nil
    end

    if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value > 9999 then
        return nil, "invalid_grid_order"
    end

    return value
end

local function validate_icon_background(value)
    if value == nil then
        return nil
    end

    if type(value) ~= "string" or #value == 0 or #value > 64 then
        return nil, "invalid_icon_background"
    end

    if value:find("[\r\n;{}]") then
        return nil, "invalid_icon_background"
    end

    return value
end

local function normalize_manifest(folder, definition)
    if type(folder) ~= "string" or type(definition) ~= "table" then
        return nil, "invalid_manifest"
    end

    if definition.schemaVersion ~= SkyPhoneApps.ProtocolVersion then
        return nil, "unsupported_schema_version"
    end

    local app_id = definition.id
    local valid_id, id_error = validate_app_id(app_id)
    if not valid_id then
        return nil, id_error
    end
    if RESERVED_APP_IDS[app_id] then
        return nil, "reserved_app_id"
    end
    if folder ~= app_id then
        return nil, "folder_id_mismatch"
    end

    if definition.defaultInstalled ~= nil and type(definition.defaultInstalled) ~= "boolean" then
        return nil, "invalid_default_installed"
    end
    if definition.removable ~= nil and type(definition.removable) ~= "boolean" then
        return nil, "invalid_removable"
    end

    local version, version_error = validate_text(
        definition.version or "1.0.0",
        "invalid_version",
        VERSION_MAX_LENGTH,
        true
    )
    if not version then
        return nil, version_error
    end
    if not version:match("^[%w%._+-]+$") then
        return nil, "invalid_version"
    end

    local name, name_error = validate_localized_text(
        definition.name,
        "invalid_name",
        NAME_MAX_LENGTH,
        true
    )
    if not name then
        return nil, name_error
    end

    local description, description_error = validate_localized_text(
        definition.description,
        "invalid_description",
        DESCRIPTION_MAX_LENGTH,
        true
    )
    if not description then
        return nil, description_error
    end

    local developer, developer_error = validate_text(
        definition.developer,
        "invalid_developer",
        DEVELOPER_MAX_LENGTH,
        false
    )
    if definition.developer ~= nil and not developer then
        return nil, developer_error
    end

    local category = definition.category or "utilities"
    if not ALLOWED_CATEGORIES[category] then
        return nil, "invalid_category"
    end

    local entry, entry_error = validate_local_path(definition.entry, true)
    if not entry then
        return nil, entry_error
    end

    local icon, icon_error = validate_local_path(definition.icon, false)
    if definition.icon ~= nil and not icon then
        return nil, icon_error
    end

    local screenshots, screenshots_error = validate_string_array(
        definition.screenshots,
        "invalid_screenshots",
        8,
        function(path)
            return validate_local_path(path, true)
        end
    )
    if not screenshots then
        return nil, screenshots_error
    end

    local permissions, permissions_error = validate_permissions(definition.permissions)
    if not permissions then
        return nil, permissions_error
    end

    local orientation = definition.orientation or "portrait"
    if not ALLOWED_ORIENTATIONS[orientation] then
        return nil, "invalid_orientation"
    end

    local grid_order, grid_order_error = validate_grid_order(definition.gridOrder)
    if definition.gridOrder ~= nil and not grid_order then
        return nil, grid_order_error
    end

    local icon_background, background_error = validate_icon_background(definition.iconBackground)
    if definition.iconBackground ~= nil and not icon_background then
        return nil, background_error
    end

    local bridge_mode = definition.bridgeMode or "sky"
    if bridge_mode ~= "sky" and bridge_mode ~= "legacy" then
        return nil, "invalid_bridge_mode"
    end

    return {
        bridgeMode = bridge_mode,
        category = category,
        defaultInstalled = definition.defaultInstalled == true,
        description = description,
        developer = developer,
        entry = entry,
        folder = folder,
        gridOrder = grid_order,
        icon = icon,
        iconBackground = icon_background,
        id = app_id,
        name = name,
        orientation = orientation,
        permissions = permissions,
        removable = definition.removable ~= false,
        schemaVersion = SkyPhoneApps.ProtocolVersion,
        screenshots = screenshots,
        version = version,
    }
end

---@param folder string App folder relative to custom_apps.
---@param definition table Declarative bundled app manifest.
function SkyPhoneApps.RegisterManifest(folder, definition)
    local manifest, error_code = normalize_manifest(folder, definition)
    if not manifest then
        error(("[sky_phone] Invalid custom app manifest '%s': %s"):format(tostring(folder), error_code), 2)
    end

    if bundled_manifests_by_id[manifest.id] then
        error(("[sky_phone] Duplicate bundled custom app id '%s'."):format(manifest.id), 2)
    end

    bundled_manifests[#bundled_manifests + 1] = manifest
    bundled_manifests_by_id[manifest.id] = manifest
end

function SkyPhoneApps.GetBundledManifests()
    return bundled_manifests
end

function SkyPhoneApps.GetBundledManifest(app_id)
    return bundled_manifests_by_id[app_id]
end

SkyPhoneApps.AllowedCategories = ALLOWED_CATEGORIES
SkyPhoneApps.AllowedOrientations = ALLOWED_ORIENTATIONS
SkyPhoneApps.AllowedPermissions = ALLOWED_PERMISSIONS
SkyPhoneApps.ReservedAppIds = RESERVED_APP_IDS
SkyPhoneApps.ValidateAppId = validate_app_id
SkyPhoneApps.ValidateLocalizedText = validate_localized_text
SkyPhoneApps.ValidatePermissions = validate_permissions
