SkyPhoneCompatibilityClient = {}

local RESOURCE_NAME = GetCurrentResourceName()
local providers = SkyPhoneCompatibility.Providers
local compatibility_core = SkyPhoneApps.CompatibilityCore
local debug_custom_app = SkyPhoneApps.Debug or function() end
local provider_apps = {}

if type(providers) ~= "table" or type(compatibility_core) ~= "table" then
    error("[sky_phone] Phone compatibility client core initialized before its shared dependencies.")
end
if type(SkyPhoneClient) ~= "table"
    or type(SkyPhoneCalls) ~= "table"
    or type(SkyPhoneCamera) ~= "table"
    or type(SkyPhoneNotifications) ~= "table"
then
    error("[sky_phone] Phone compatibility client core initialized before the neutral client modules.")
end

SkyPhoneCompatibilityClient.ResourceName = RESOURCE_NAME
SkyPhoneCompatibilityClient.Providers = providers
SkyPhoneCompatibilityClient.Core = compatibility_core
SkyPhoneCompatibilityClient.Phone = SkyPhoneClient
SkyPhoneCompatibilityClient.Calls = SkyPhoneCalls
SkyPhoneCompatibilityClient.Camera = SkyPhoneCamera
SkyPhoneCompatibilityClient.Notifications = SkyPhoneNotifications
SkyPhoneCompatibilityClient.Debug = debug_custom_app

function SkyPhoneCompatibilityClient.TrackProviderApp(provider, owner_resource, definition, vendor_data)
    provider_apps[definition.id] = {
        definition = definition,
        owner_resource = owner_resource,
        provider = provider,
        vendor_data = vendor_data,
    }
end

function SkyPhoneCompatibilityClient.GetCallingResource(export_name)
    local owner_resource = GetInvokingResource()
    if owner_resource then
        return owner_resource
    end

    Bridge.Debug(
        "warn",
        "[%s] %s rejected: the export must be called by another resource.",
        RESOURCE_NAME,
        export_name
    )
    return nil, "invalid_owner"
end

function SkyPhoneCompatibilityClient.CopyRecordData(value)
    if type(value) ~= "table" then
        return nil
    end

    local copied = {}
    for key, nested_value in pairs(value) do
        copied[key] = nested_value
    end
    return copied
end

function SkyPhoneCompatibilityClient.RegisterProviderApp(provider, owner_resource, definition, vendor_data)
    local app_id = definition.id
    local existing = provider_apps[app_id]
    debug_custom_app(
        "provider",
        "registration requested provider=%s id=%s owner=%s operation=%s",
        tostring(provider),
        tostring(app_id),
        tostring(owner_resource),
        existing and "update" or "add"
    )
    if existing and (existing.owner_resource ~= owner_resource or existing.provider ~= provider) then
        debug_custom_app(
            "provider",
            "registration rejected provider=%s id=%s owner=%s existing_provider=%s existing_owner=%s error=duplicate_app_id",
            tostring(provider),
            tostring(app_id),
            tostring(owner_resource),
            tostring(existing.provider),
            tostring(existing.owner_resource)
        )
        return false, "duplicate_app_id"
    end

    local success, error_message
    if existing then
        success, error_message = compatibility_core.Update(owner_resource, definition)
    else
        success, error_message = compatibility_core.Add(owner_resource, definition)
    end
    if success then
        SkyPhoneCompatibilityClient.TrackProviderApp(provider, owner_resource, definition, vendor_data)
    end
    debug_custom_app(
        "provider",
        "registration result provider=%s id=%s owner=%s success=%s error=%s",
        tostring(provider),
        tostring(app_id),
        tostring(owner_resource),
        tostring(success),
        tostring(error_message)
    )
    return success, error_message
end

function SkyPhoneCompatibilityClient.GetProviderApp(owner_resource, app_id, allowed_providers)
    if type(app_id) ~= "string" then
        return nil, "invalid_app_id"
    end

    local record = provider_apps[app_id]
    if not record then
        return nil, "app_not_found"
    end
    if record.owner_resource ~= owner_resource then
        return nil, "app_owner_mismatch"
    end
    if allowed_providers and not allowed_providers[record.provider] then
        return nil, "app_provider_mismatch"
    end
    return record
end

function SkyPhoneCompatibilityClient.FindProviderApp(app_id)
    return provider_apps[app_id]
end

function SkyPhoneCompatibilityClient.GetProviderApps(provider)
    local app_ids = {}
    for app_id, record in pairs(provider_apps) do
        if record.provider == provider then
            app_ids[#app_ids + 1] = app_id
        end
    end
    table.sort(app_ids)

    local records = {}
    for index = 1, #app_ids do
        records[index] = provider_apps[app_ids[index]]
    end
    return records
end

function SkyPhoneCompatibilityClient.RemoveProviderApp(owner_resource, app_id, allowed_providers)
    local record, record_error = SkyPhoneCompatibilityClient.GetProviderApp(
        owner_resource,
        app_id,
        allowed_providers
    )
    if not record then
        return false, record_error
    end

    return compatibility_core.Remove(owner_resource, app_id)
end

function SkyPhoneCompatibilityClient.FormatNumber(phone_number)
    return SkyPhoneSimNumber.Format(
        phone_number,
        Config.Sim.NumberGroups,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    )
end

AddEventHandler("sky_phone:client:customAppRemoved", function(owner_resource, app_id)
    local record = provider_apps[app_id]
    if record and record.owner_resource == owner_resource then
        provider_apps[app_id] = nil
    end
end)
