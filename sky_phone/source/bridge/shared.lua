Bridge = Bridge or {}
Bridge.Callbacks = Bridge.Callbacks or {}
Bridge.Database = Bridge.Database or {}
Bridge.Framework = Bridge.Framework or {}
Bridge.Inventory = Bridge.Inventory or {}
Bridge.Radio = Bridge.Radio or {}

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
    local enabled = options and options.always
        or bridge_config and (bridge_config.Debug or bridge_config.DebugLevels and bridge_config.DebugLevels[level])
    if not enabled then
        return
    end

    local formatted = #arguments > 0 and message:format(table.unpack(arguments)) or message
    print(("%s%s^0"):format(level_colours[level] or "^7", formatted))
end
