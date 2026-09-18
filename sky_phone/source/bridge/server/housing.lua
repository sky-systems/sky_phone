Bridge.Housing = {
    Providers = {},
}

local selected_provider_name = nil
local last_provider_state = nil

function Bridge.Housing.RegisterProvider(name, provider)
    assert(type(name) == "string" and name ~= "", "Housing provider name must be a non-empty string")
    assert(type(provider) == "table", "Housing provider must be a table")
    assert(type(provider.is_available) == "function", "Housing provider must implement is_available")
    assert(type(provider.get_overview) == "function", "Housing provider must implement get_overview")
    assert(type(provider.prepare) == "function", "Housing provider must implement prepare")
    assert(not Bridge.Housing.Providers[name], ("Housing provider '%s' is already registered"):format(name))
    Bridge.Housing.Providers[name] = provider
end

local function provider_available(name)
    local provider = Bridge.Housing.Providers[name]
    return provider and provider.is_available()
end

local function report_provider_state(state, message)
    if last_provider_state == state then
        return
    end
    last_provider_state = state
    Bridge.Debug(state == "online" and "debug" or "warn", message, { always = true })
end

function Bridge.Housing.ResolveProvider()
    if selected_provider_name and provider_available(selected_provider_name) then
        return selected_provider_name, Bridge.Housing.Providers[selected_provider_name]
    end

    selected_provider_name = nil
    local configured = tostring(Config.Housing.System or "auto")
    if configured ~= "auto" then
        if provider_available(configured) then
            selected_provider_name = configured
        else
            report_provider_state(
                "offline:" .. configured,
                ("[sky_phone] Configured housing provider '%s' is unavailable."):format(configured)
            )
            return nil, nil
        end
    else
        for _, name in ipairs(Config.Housing.AutoPriority or {}) do
            if provider_available(name) then
                selected_provider_name = name
                break
            end
        end
        if not selected_provider_name then
            report_provider_state("offline:auto", "[sky_phone] No supported housing provider is running.")
            return nil, nil
        end
    end

    report_provider_state(
        "online",
        ("[sky_phone] Housing provider '%s' is active."):format(selected_provider_name)
    )
    return selected_provider_name, Bridge.Housing.Providers[selected_provider_name]
end

function Bridge.Housing.GetOverview(source)
    local name, provider = Bridge.Housing.ResolveProvider()
    if not provider then
        return {
            available = false,
            provider = nil,
            properties = {},
        }
    end

    local properties, error_code = provider.get_overview(source)
    if not properties then
        return nil, error_code or "provider_error"
    end
    return {
        available = true,
        provider = name,
        properties = properties,
    }
end

function Bridge.Housing.Prepare(source, action, data)
    local name, provider = Bridge.Housing.ResolveProvider()
    if not provider then
        return nil, "provider_unavailable"
    end
    local prepared, error_code = provider.prepare(source, action, data)
    if not prepared then
        return nil, error_code or "action_failed"
    end
    prepared.provider = name
    return prepared
end

local function reset_provider(resource_name)
    for _, provider in pairs(Bridge.Housing.Providers) do
        if provider.resource_name == resource_name then
            selected_provider_name = nil
            last_provider_state = nil
            return
        end
    end
end

AddEventHandler("onResourceStart", reset_provider)
AddEventHandler("onResourceStop", reset_provider)

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    selected_provider_name = nil
    last_provider_state = nil
end)
