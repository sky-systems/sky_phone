dofile("sky_phone/config/init.lua")
for _, name in ipairs({ "ar", "cn", "cz", "de", "en", "es", "fi", "fr", "it", "nl", "pl", "pt", "rs", "ru", "se" }) do dofile("sky_phone/config/locales/" .. name .. ".lua") end

local function setup(adapter, resources, framework)
    Config = { Bridge = { Inventory = adapter, Locale = "de" }, Phone = { Item = "phone" },
        Sim = { RegisteredItem = "sim_registered", AnonymousItem = "sim_anonymous" } }
    local state = { registered = {}, exports = {}, events = {}, warnings = {}, notices = {}, response = { success = true } }
    local function record(provider, item, key, label)
        assert(type(key) == "string" and type(label) == "string" and label ~= "")
        if state.fail then error("inventory not ready") end
        state.registered[#state.registered + 1] = { provider = provider, item = item, key = key, label = label }
        if state.during_registration then
            local fn = state.during_registration
            state.during_registration = nil
            fn()
        end
        return true
    end
    exports = setmetatable({
        ox_inventory = { displayMetadata = function(_, key, label) return record("ox", "*", key, label) end },
        ["tgiann-inventory"] = { DisplayItemMetadata = function(_, item, key, label) return record("tgiann", item, key, label) end },
        one_inventory = { ShowItemMetadata = function(_, key, label, item) return record("one", item, key, label) end },
    }, { __call = function(_, name, fn) state.exports[name] = fn end })
    Bridge = {
        Inventory = {},
        Debug = function(_, message) state.warnings[#state.warnings + 1] = message end,
        Framework = {
            GetName = function() return framework or "qb" end,
            Notify = function(title, message, kind)
                assert(type(title) == "string" and type(message) == "string" and message ~= "")
                state.notices[#state.notices + 1] = { title = title, message = message, kind = kind }
            end,
        },
        Callbacks = { Trigger = function(name, data)
            assert(name == "sky_phone:sim:eject-item")
            state.request = data
            return state.response
        end },
    }
    GetResourceState = function(name) return resources[name] and "started" or "missing" end
    AddEventHandler = function(name, fn) state.events[name] = fn end
    CreateThread = function(fn) state.start = fn end
    dofile("sky_phone/source/bridge/inventory.lua")
    dofile("sky_phone/source/bridge/client/inventory.lua")
    state.start()
    return state
end

for _, provider in ipairs({ { "ox_inventory", "ox", 2 }, { "tgiann-inventory", "tgiann", 6 }, { "one_inventory", "one", 6 } }) do
    local state = setup(provider[1], { [provider[1]] = true })
    assert(#state.registered == provider[3])
    for _, row in ipairs(state.registered) do
        assert(row.provider == provider[2])
        assert(row.label == (row.key == "imei" and "IMEI" or Locales.de.Nui.Apps.settings.simNumber))
    end
    state.events["sky_phone:configurator:updated"]()
    assert(#state.registered == provider[3], "config sync must not duplicate tooltip labels")
    state.events.onClientResourceStop(provider[1])
    state.events.onClientResourceStart(provider[1])
    assert(#state.registered == provider[3] * 2, "inventory restart must restore labels")
    Config.Phone.Item = "custom_phone"
    state.events["sky_phone:configurator:updated"]()
    local extra = provider[2] == "ox" and 0 or 2
    assert(#state.registered == provider[3] * 2 + extra, "custom item names need scoped labels")
end

local state = setup("auto", { ["tgiann-inventory"] = true, ox_inventory = true })
assert(#state.registered == 6 and state.registered[1].provider == "tgiann", "use the same auto priority as the server")
state = setup("auto", { ["ps-inventory"] = true, ["tgiann-inventory"] = true, ox_inventory = true }, "esx")
assert(state.registered[1].provider == "tgiann", "incompatible inventories must be skipped")
state = setup("auto", { ["qs-inventory"] = true, ox_inventory = true })
assert(#state.registered == 0, "do not call ox exports for a different selected inventory")
for _, name in ipairs({ "qs", "qb", "ps", "lj", "jaksam", "core", "codem", "jpr", "origen", "ak47", "mf", "smx", "hex", "esx" }) do
    state = setup(name, { ox_inventory = true })
    assert(#state.registered == 0)
end
state = setup("qbox", { ox_inventory = true })
assert(#state.registered == 2)
local resources = {}
state = setup("ox", resources)
assert(#state.registered == 0)
resources.ox_inventory = true
state.fail = true
state.events.onClientResourceStart("ox_inventory")
assert(#state.warnings == 1 and #state.registered == 0, "unavailable exports must warn without crashing")
state.fail = false
state.during_registration = state.events["sky_phone:configurator:updated"]
state.events["sky_phone:configurator:updated"]()
assert(#state.registered == 2, "yielding exports must not register duplicates")

-- All shipped languages and their regional aliases use the phone's existing translations.
for _, locale_name in ipairs({ "ar", "cn", "cz", "de", "en", "es", "fi", "fr", "it", "nl", "pl", "pt", "rs", "ru", "se", "de-DE", "zh-CN", "cs-CZ", "sr-RS", "sv-SE", "unknown" }) do
    Config.Bridge.Locale = locale_name
    local locale = SkyPhoneLocales.Resolve(locale_name)
    local labels = state.exports.GetInventoryLabels()
    assert(labels.imei == locale.Nui.Apps.settings.imei and labels.phone_number == locale.Nui.Apps.settings.simNumber)
    assert(labels.eject_sim == locale.Nui.Apps.settings.ejectSim)
    state.response = { success = true }
    assert(state.exports.EjectSimFromSlot({ slot = 8 }).success)
    assert(state.request.slot == 8 and state.notices[#state.notices].message == locale.Nui.Apps.phone.sim_removed)
    for _, code in ipairs({ "no_sim", "inventory_full", "phone_not_owned", "operation_in_progress", "metadata_unsupported", "request_failed", "device_locked", "unknown_error" }) do
        state.response = { success = false, error = code }
        assert(not state.exports.EjectSimFromSlot("SLOT-8", "own").success)
        assert(state.request.slot == "SLOT-8" and state.request.inventory == "own")
        assert(state.notices[#state.notices].kind == "error")
    end
end
state.response = { success = true }
state.exports.EjectSimFromSlot({ slot = 8, metadata = { imei = "123456789012345" } })
assert(state.request.imei == "123456789012345", "item payloads must retain the expected identity for server comparison")
state.response = nil
assert(state.exports.EjectSimFromSlot(3).error == "request_failed", "callback timeouts need a localized failure")
state.response = { success = true }
state.events["sky_phone:sim:eject-item"](8)
assert(state.request.slot == 8)

print("Client inventory tooltip and locale tests passed")
