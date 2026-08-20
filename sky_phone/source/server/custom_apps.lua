local policies_by_id = {}
local policy_ids_by_adapter = {}
local policy_ids_by_owner = {}
local current_resource = GetCurrentResourceName()

local function validate_owner_resource(owner_resource, allow_stopping)
    if type(owner_resource) ~= "string"
        or #owner_resource == 0
        or #owner_resource > 64
        or not owner_resource:match("^[%w][%w._-]*$")
    then
        return false, "invalid_owner_resource"
    end

    local state = GetResourceState(owner_resource)
    if state == "started" or state == "starting" or (allow_stopping and state == "stopping") then
        return true
    end

    return false, "owner_resource_not_running"
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

local function build_permission_set(permissions)
    local permission_set = {}
    for index = 1, #permissions do
        permission_set[permissions[index]] = true
    end
    return permission_set
end

local function register_policy(policy)
    local app_id = policy.id
    local existing = policies_by_id[app_id]
    if existing then
        Bridge.Debug(
            "warn",
            "[sky_phone] Rejected duplicate custom app policy '%s' from '%s'; it is already owned by '%s'.",
            app_id,
            policy.ownerResource,
            existing.ownerResource
        )
        return false, "duplicate_app_id"
    end

    policies_by_id[app_id] = policy
    add_owner_index(policy_ids_by_owner, policy.ownerResource, app_id)
    if policy.adapterResource then
        add_owner_index(policy_ids_by_adapter, policy.adapterResource, app_id)
    end
    return true
end

local function remove_policy(app_id)
    local policy = policies_by_id[app_id]
    if not policy then
        return false, "app_not_found"
    end

    policies_by_id[app_id] = nil
    remove_owner_index(policy_ids_by_owner, policy.ownerResource, app_id)
    if policy.adapterResource then
        remove_owner_index(policy_ids_by_adapter, policy.adapterResource, app_id)
    end
    return true
end

local function get_direct_owner()
    local owner_resource = GetInvokingResource()
    if not owner_resource then
        return nil, "missing_invoking_resource"
    end

    local valid_owner, owner_error = validate_owner_resource(owner_resource, false)
    if not valid_owner then
        return nil, owner_error
    end

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

local function normalize_policy(owner_resource, adapter_resource, definition)
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

    local permissions, permissions_error = SkyPhoneApps.ValidatePermissions(definition.permissions)
    if not permissions then
        return nil, permissions_error
    end

    return {
        adapterResource = adapter_resource,
        bundled = false,
        id = definition.id,
        ownerResource = owner_resource,
        permissions = build_permission_set(permissions),
    }
end

local function add_custom_app_policy(definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local policy, policy_error = normalize_policy(owner_resource, nil, definition)
    if not policy then
        return false, policy_error
    end
    return register_policy(policy)
end

local function add_custom_app_policy_from_adapter(owner_resource, definition)
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

    local policy, policy_error = normalize_policy(owner_resource, adapter_resource, definition)
    if not policy then
        return false, policy_error
    end
    return register_policy(policy)
end

local function verify_owned_policy(owner_resource, app_id, adapter_resource)
    local valid_id, id_error = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id then
        return nil, id_error
    end

    local policy = policies_by_id[app_id]
    if not policy then
        return nil, "app_not_found"
    end
    if policy.ownerResource ~= owner_resource then
        return nil, "app_owner_mismatch"
    end
    if adapter_resource and policy.adapterResource ~= adapter_resource then
        return nil, "app_adapter_mismatch"
    end

    return policy
end

local function replace_policy(policy, adapter_resource)
    local existing, policy_error = verify_owned_policy(
        policy.ownerResource,
        policy.id,
        adapter_resource
    )
    if not existing then
        return false, policy_error
    end
    if existing.bundled then
        return false, "bundled_app"
    end

    policies_by_id[policy.id] = policy
    return true
end

local function update_custom_app_policy(definition)
    if not Config.CustomApps.Enabled or not Config.CustomApps.ExternalApps then
        return false, "external_apps_disabled"
    end

    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local policy, policy_error = normalize_policy(owner_resource, nil, definition)
    if not policy then
        return false, policy_error
    end
    return replace_policy(policy, nil)
end

local function update_custom_app_policy_from_adapter(owner_resource, definition)
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

    local policy, policy_error = normalize_policy(owner_resource, adapter_resource, definition)
    if not policy then
        return false, policy_error
    end
    return replace_policy(policy, adapter_resource)
end

local function remove_custom_app_policy(app_id)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local policy, policy_error = verify_owned_policy(owner_resource, app_id)
    if not policy then
        return false, policy_error
    end
    if policy.bundled then
        return false, "bundled_app"
    end

    return remove_policy(app_id)
end

local function remove_custom_app_policy_from_adapter(owner_resource, app_id)
    local adapter_resource, adapter_error = get_trusted_adapter()
    if not adapter_resource then
        return false, adapter_error
    end

    local policy, policy_error = verify_owned_policy(owner_resource, app_id, adapter_resource)
    if not policy then
        return false, policy_error
    end
    return remove_policy(app_id)
end

local function has_custom_app_permission(app_id, permission)
    local valid_id = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id or type(permission) ~= "string" or not SkyPhoneApps.AllowedPermissions[permission] then
        return false
    end

    local policy = policies_by_id[app_id]
    return policy ~= nil and policy.permissions[permission] == true
end

local function get_custom_app_policy(app_id)
    local valid_id = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id then
        return nil
    end

    local policy = policies_by_id[app_id]
    if not policy then
        return nil
    end

    local permissions = {}
    for permission in pairs(policy.permissions) do
        permissions[#permissions + 1] = permission
    end
    table.sort(permissions)
    return {
        bundled = policy.bundled,
        id = policy.id,
        ownerResource = policy.ownerResource,
        permissions = permissions,
    }
end

local function get_custom_app_capabilities()
    return {
        abiVersion = 1,
        enabled = Config.CustomApps.Enabled == true,
        exports = {
            "AddCustomAppPolicy",
            "GetCustomAppCapabilities",
            "GetCustomAppPolicy",
            "HasCustomAppPermission",
            "RemoveCustomAppPolicy",
            "SendAppMessage",
            "SendCustomAppMessage",
            "SendCustomAppNotification",
            "UpdateCustomAppPolicy",
        },
        externalApps = Config.CustomApps.Enabled == true
            and Config.CustomApps.ExternalApps == true,
        messageDispatch = true,
        notificationDispatch = true,
        policyRegistration = true,
        policyUpdate = true,
        protocolVersion = SkyPhoneApps.ProtocolVersion,
    }
end

local function normalize_player_source(player_source)
    if type(player_source) ~= "number"
        or player_source ~= player_source
        or player_source <= 0
        or player_source >= math.huge
        or player_source ~= math.floor(player_source)
    then
        return nil
    end
    return player_source
end

local function normalize_message_payload(payload)
    local encoded_success, encoded = pcall(json.encode, payload)
    if not encoded_success or type(encoded) ~= "string" then
        return nil, "invalid_payload"
    end
    if #encoded > Config.CustomApps.MaximumMessageBytes then
        return nil, "payload_too_large"
    end

    local decoded_success, decoded = pcall(json.decode, encoded)
    if not decoded_success then
        return nil, "invalid_payload"
    end
    return decoded
end

local function send_custom_app_message(player_source, app_id, payload)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local policy, policy_error = verify_owned_policy(owner_resource, app_id)
    if not policy then
        return false, policy_error
    end

    player_source = normalize_player_source(player_source)
    if not player_source then
        return false, "invalid_source"
    end
    if not Bridge.Framework.GetIdentifier(player_source) then
        return false, "player_unavailable"
    end

    local normalized_payload, payload_error = normalize_message_payload(payload)
    if payload_error then
        return false, payload_error
    end

    TriggerClientEvent(
        "sky_phone:custom-app:message",
        player_source,
        owner_resource,
        app_id,
        normalized_payload
    )
    return true
end

local function send_custom_app_notification(player_source, app_id, notification)
    local owner_resource, owner_error = get_direct_owner()
    if not owner_resource then
        return false, owner_error
    end

    local policy, policy_error = verify_owned_policy(owner_resource, app_id)
    if not policy then
        return false, policy_error
    end
    if not policy.permissions.notifications then
        return false, "permission_denied"
    end

    player_source = normalize_player_source(player_source)
    if not player_source then
        return false, "invalid_source"
    end
    if type(notification) ~= "table" then
        return false, "invalid_notification"
    end
    if notification.appId ~= nil and notification.appId ~= app_id then
        return false, "invalid_app_id"
    end
    if notification.app_id ~= nil and notification.app_id ~= app_id then
        return false, "invalid_app_id"
    end

    local notifications = SkyPhoneNotifications
    if type(notifications) ~= "table" or type(notifications.Send) ~= "function" then
        return false, "api_not_ready"
    end

    local result, notification_error = notifications.Send(
        { kind = "source", value = player_source },
        {
            appId = app_id,
            text = notification.text or notification.content,
            title = notification.title,
        }
    )
    if not result then
        return false, notification_error
    end
    if result.delivered ~= 1 then
        return false, "device_not_equipped"
    end
    return true, result
end

SkyPhoneApps.GetPolicy = get_custom_app_policy
SkyPhoneApps.HasPermission = has_custom_app_permission
SkyPhoneApps.ServerPublicApi = {
    AddCustomAppPolicy = add_custom_app_policy,
    AddCustomAppPolicyFromAdapter = add_custom_app_policy_from_adapter,
    GetCustomAppCapabilities = get_custom_app_capabilities,
    GetCustomAppPolicy = get_custom_app_policy,
    HasCustomAppPermission = has_custom_app_permission,
    RemoveCustomAppPolicy = remove_custom_app_policy,
    RemoveCustomAppPolicyFromAdapter = remove_custom_app_policy_from_adapter,
    SendAppMessage = send_custom_app_message,
    SendCustomAppMessage = send_custom_app_message,
    SendCustomAppNotification = send_custom_app_notification,
    UpdateCustomAppPolicy = update_custom_app_policy,
    UpdateCustomAppPolicyFromAdapter = update_custom_app_policy_from_adapter,
}

if Config.CustomApps.Enabled and Config.CustomApps.BundledApps then
    local bundled = SkyPhoneApps.GetBundledManifests()
    for index = 1, #bundled do
        local manifest = bundled[index]
        local registered, register_error = register_policy({
            adapterResource = nil,
            bundled = true,
            id = manifest.id,
            ownerResource = current_resource,
            permissions = build_permission_set(manifest.permissions),
        })
        if not registered then
            error(("[sky_phone] Could not register bundled custom app policy '%s': %s"):format(
                manifest.id,
                register_error
            ))
        end
    end
end

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == current_resource then
        return
    end

    local app_ids = {}
    local owner_policies = policy_ids_by_owner[resource_name]
    if owner_policies then
        for app_id in pairs(owner_policies) do
            app_ids[app_id] = true
        end
    end

    local adapter_policies = policy_ids_by_adapter[resource_name]
    if adapter_policies then
        for app_id in pairs(adapter_policies) do
            app_ids[app_id] = true
        end
    end

    for app_id in pairs(app_ids) do
        remove_policy(app_id)
    end
end)
