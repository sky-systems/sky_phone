Bridge = Bridge or {}
Bridge.Callbacks = Bridge.Callbacks or {}
Bridge.Calls = Bridge.Calls or {}
Bridge.Database = Bridge.Database or {}
Bridge.Framework = Bridge.Framework or {}
Bridge.Inventory = Bridge.Inventory or {}
Bridge.Radio = Bridge.Radio or {}
Bridge.Normalize = Bridge.Normalize or {}
Bridge.Speaker = Bridge.Speaker or {}

function Bridge.Normalize.FiniteNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return nil
    end
    return number
end

function Bridge.Normalize.Coordinates(value)
    if value == nil then
        return nil
    end

    local success, x, y, z = pcall(function()
        return value.x or value[1], value.y or value[2], value.z or value[3]
    end)
    if not success then
        return nil
    end

    x = Bridge.Normalize.FiniteNumber(x)
    y = Bridge.Normalize.FiniteNumber(y)
    z = Bridge.Normalize.FiniteNumber(z)
    if not x or not y or not z then
        return nil
    end
    return { x = x, y = y, z = z }
end

function Bridge.Speaker.IsEnabled()
    return not Config.Speaker or Config.Speaker.Enabled ~= false
end

function Bridge.Calls.SupportsMute()
    return false
end

function Bridge.Calls.SetMuted()
    return false
end

function Bridge.Radio.SupportsSpeaker()
    return false
end

function Bridge.Radio.SetPlayerSpeaker()
    return false
end

local level_colours = {
    debug = "^5",
    info = "^2",
    warn = "^3",
    error = "^1",
}

function Bridge.Debug(level, message, ...)
    local arguments = { ... }
    local options = type(arguments[#arguments]) == "table" and arguments[#arguments] or nil
    if options then
        arguments[#arguments] = nil
    end

    local bridge_config = Config and Config.Bridge or nil
    local important = level == "warn" or level == "error"
    local notice = options and options.notice == true
    local enabled = important or notice or bridge_config and bridge_config.Debug == true
    if not enabled then
        return
    end

    local formatted = #arguments > 0 and message:format(table.unpack(arguments)) or message
    print(("%s%s^0"):format(level_colours[level] or "^7", formatted))
end
