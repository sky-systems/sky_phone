SkyPhoneCompatibility = {}

function SkyPhoneCompatibility.RegisterExportAlias(resource_name, export_name, handler)
    assert(type(resource_name) == "string" and resource_name ~= "", "Export alias resource must be a non-empty string")
    assert(type(export_name) == "string" and export_name ~= "", "Export alias name must be a non-empty string")
    assert(type(handler) == "function", "Export alias handler must be a function")

    AddEventHandler(("__cfx_export_%s_%s"):format(resource_name, export_name), function(set_callback)
        set_callback(function(...)
            local debug_custom_app = SkyPhoneApps and SkyPhoneApps.Debug
            local invoking_resource = GetInvokingResource and GetInvokingResource() or nil
            if debug_custom_app then
                debug_custom_app(
                    "export",
                    "call provider=%s export=%s invoking_resource=%s argument_count=%s",
                    resource_name,
                    export_name,
                    tostring(invoking_resource),
                    select("#", ...)
                )
            end

            local results = table.pack(handler(...))
            if debug_custom_app then
                debug_custom_app(
                    "export",
                    "result provider=%s export=%s invoking_resource=%s success=%s error=%s",
                    resource_name,
                    export_name,
                    tostring(invoking_resource),
                    tostring(results[1]),
                    tostring(results[2])
                )
            end
            return table.unpack(results, 1, results.n)
        end)
    end)
end

function SkyPhoneCompatibility.EmitServerProviderStop(resource_name)
    assert(type(resource_name) == "string" and resource_name ~= "", "Provider resource must be a non-empty string")

    TriggerEvent("onServerResourceStop", resource_name)
    TriggerEvent("onResourceStop", resource_name)
end

function SkyPhoneCompatibility.EmitServerProviderStart(resource_name)
    assert(type(resource_name) == "string" and resource_name ~= "", "Provider resource must be a non-empty string")

    TriggerEvent("onServerResourceStart", resource_name)
    TriggerEvent("onResourceStart", resource_name)
end

SkyPhoneCompatibility.Providers = {
    lb = "lb_phone",
    seventeen = "17mov",
    high = "high_phone",
    quasar = "quasar_v3",
    yseries = "yseries",
}

function SkyPhoneCompatibility.NormalizeAtResourceUrl(owner_resource, url, error_prefix)
    if type(url) ~= "string" or url == "" then
        return nil, "invalid_" .. error_prefix
    end
    if url:sub(1, 7) == "http://" then
        return nil, "insecure_" .. error_prefix
    end
    if url:sub(1, 1) ~= "@" then
        return url
    end

    local url_owner, url_path = url:match("^@([^/]+)/(.+)$")
    if url_owner ~= owner_resource or not url_path then
        return nil, error_prefix .. "_owner_mismatch"
    end
    return owner_resource .. "/" .. url_path
end
