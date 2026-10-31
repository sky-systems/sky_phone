-- The explicit test-data command must prepare optional schemas before it can
-- mutate player/account/SIM state, including when those apps are switched off.
local commands, prepared, device_calls = {}, {}, 0
local env = setmetatable({
    Config = { TestData = { Enabled = true, Command = "test-phone-data", AdminOnly = true }, Phone = { Item = "phone" } },
    AddEventHandler = function() end,
    RegisterCommand = function(name, callback) commands[name] = callback end,
    TriggerClientEvent = function() end,
    SkyPhoneAppDatabase = { Ensure = function(app, force)
        assert(force, "Explicit test data must also prepare currently disabled app storage")
        prepared[#prepared + 1] = app
        if app == "skyride" then error("synthetic schema failure before seed writes") end
    end },
    SkyPhone = { EnsureDevice = function() device_calls = device_calls + 1; error("test boundary") end },
    Bridge = {
        Debug = function() end,
        Framework = { HasPermission = function() return true end },
        Inventory = { GetSlotsWithItem = function() return { { slot = 1 } } end },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Query = function() error("Test data must not write before optional schemas are ready") end,
        },
    },
}, { __index = _G })
assert(loadfile("sky_phone/source/server/testdata.lua", "t", env))()
commands["test-phone-data"](1)
assert(#prepared == 13 and prepared[1] == "banking" and prepared[13] == "skyride" and device_calls == 0,
    "A schema failure must be reported before any device/account/SIM seeding starts")
print("app database: explicit test-data storage preflight passed")
