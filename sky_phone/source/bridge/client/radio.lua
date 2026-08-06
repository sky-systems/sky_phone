local provider
local provider_resources = {
    yaca = "yaca-voice",
    pma = "pma-voice",
    saltychat = "saltychat",
}
local provider_aliases = {
    ["yaca-voice"] = "yaca",
    ["pma-voice"] = "pma",
    salty = "saltychat",
}

local function resolve_provider()
    if provider and GetResourceState(provider_resources[provider]) == "started" then
        return provider
    end
    provider = nil

    local configured = Config.Radio.VoiceProvider
    if configured ~= "auto" then
        local selected = provider_aliases[configured] or configured
        if provider_resources[selected] and GetResourceState(provider_resources[selected]) == "started" then
            provider = selected
            return provider
        end
        return nil
    end

    local providers = {
        { name = "yaca", resource = "yaca-voice" },
        { name = "pma", resource = "pma-voice" },
        { name = "saltychat", resource = "saltychat" },
    }
    for _, candidate in ipairs(providers) do
        if GetResourceState(candidate.resource) == "started" then
            provider = candidate.name
            return provider
        end
    end

    return nil
end

function Bridge.Radio.GetProvider()
    return resolve_provider()
end

function Bridge.Radio.SupportsSecondary()
    local selected = resolve_provider()
    return Config.Radio.AllowSecondary and (selected == "yaca" or selected == "saltychat")
end

function Bridge.Radio.Join(primary, secondary)
    local selected = resolve_provider()
    if selected == "yaca" then
        local voice = exports["yaca-voice"]
        if not voice:isRadioEnabled() then
            voice:enableRadio(true)
            Wait(100)
        end
        voice:setActiveRadioChannel(1)
        voice:changeRadioFrequency(tostring(primary))
        if secondary > 0 and Bridge.Radio.SupportsSecondary() then
            voice:setSecondaryRadioChannel(2)
            voice:changeRadioFrequencyRaw(2, tostring(secondary))
            voice:muteRadioChannelRaw(2, false)
        else
            voice:changeRadioFrequencyRaw(2, "0")
            voice:muteRadioChannelRaw(2, true)
        end
        voice:setActiveRadioChannel(1)
        return true
    end

    if selected == "pma" then
        exports["pma-voice"]:setRadioChannel(primary)
        return true
    end

    if selected == "saltychat" then
        exports.saltychat:SetRadioChannel(tostring(primary), true)
        exports.saltychat:SetRadioChannel(secondary > 0 and tostring(secondary) or "", false)
        return true
    end

    Bridge.Debug("error", "[sky_phone] No supported radio voice provider is running.")
    return false
end

function Bridge.Radio.Leave()
    local selected = resolve_provider()
    if selected == "yaca" then
        exports["yaca-voice"]:enableRadio(false)
    elseif selected == "pma" then
        exports["pma-voice"]:setRadioChannel(0)
    elseif selected == "saltychat" then
        exports.saltychat:SetRadioChannel("", true)
        exports.saltychat:SetRadioChannel("", false)
    end
end

function Bridge.Radio.SetVolume(volume)
    local selected = resolve_provider()
    if selected == "yaca" then
        exports["yaca-voice"]:changeRadioChannelVolumeRaw(1, volume / 100)
        if Bridge.Radio.SupportsSecondary() then
            exports["yaca-voice"]:changeRadioChannelVolumeRaw(2, volume / 100)
        end
    elseif selected == "pma" then
        exports["pma-voice"]:setRadioVolume(volume)
    elseif selected == "saltychat" then
        exports.saltychat:SetRadioVolume(volume / 100)
    end
end

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        Bridge.Radio.Leave()
    end
end)
