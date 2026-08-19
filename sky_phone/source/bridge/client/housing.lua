Bridge.Housing = {
    ClientProviders = {},
}

function Bridge.Housing.RegisterClientProvider(name, provider)
    assert(type(name) == "string" and name ~= "", "Housing provider name must be a non-empty string")
    assert(type(provider) == "table" and type(provider.execute) == "function", "Housing client provider must implement execute")
    assert(
        provider.enrich_overview == nil or type(provider.enrich_overview) == "function",
        "Housing client provider enrich_overview must be a function"
    )
    assert(not Bridge.Housing.ClientProviders[name], ("Housing client provider '%s' is already registered"):format(name))
    Bridge.Housing.ClientProviders[name] = provider
end

function Bridge.Housing.EnrichOverview(provider_name, properties)
    if type(properties) ~= "table" then
        return nil, "invalid_overview"
    end
    local provider = Bridge.Housing.ClientProviders[provider_name]
    if not provider or type(provider.enrich_overview) ~= "function" then
        return properties
    end

    local success, enriched, error_code = pcall(provider.enrich_overview, properties)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] Housing provider '%s' overview enrichment failed: %s",
            tostring(provider_name),
            tostring(enriched)
        )
        return properties
    end
    if type(enriched) ~= "table" then
        Bridge.Debug(
            "error",
            "[sky_phone] Housing provider '%s' returned invalid overview enrichment: %s",
            tostring(provider_name),
            tostring(error_code or enriched)
        )
        return properties
    end

    local entrances = {}
    for _, property in ipairs(enriched) do
        if type(property) == "table" and property.id ~= nil and entrances[property.id] == nil then
            entrances[property.id] = Bridge.Normalize.Coordinates(property.entrance)
        end
    end

    local result = {}
    for _, property in ipairs(properties) do
        local entrance = type(property) == "table" and entrances[property.id] or nil
        if entrance then
            local normalized = {}
            for key, value in pairs(property) do
                normalized[key] = value
            end
            normalized.entrance = entrance
            result[#result + 1] = normalized
        else
            result[#result + 1] = property
        end
    end
    return result
end

function Bridge.Housing.Execute(provider_name, action, data)
    local provider = Bridge.Housing.ClientProviders[provider_name]
    if not provider then
        return false, "provider_unavailable"
    end
    return provider.execute(action, data)
end
