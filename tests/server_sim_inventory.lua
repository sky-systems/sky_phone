local callbacks, handlers, items, devices, sims, added, calls, writes, flags, session, usable
local imei_a, imei_b = "123456789012345", "223456789012345"

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, nested in pairs(value) do result[key] = copy(nested) end
    return result
end

local function reset()
    callbacks, handlers, added, calls, writes, flags = {}, {}, {}, {}, {}, {}
    session, usable = nil, {}
    Config = {
        Phone = { Item = "phone", Unique = true },
        Sim = { Enabled = true, RegisteredItem = "sim_registered", AnonymousItem = "sim_anonymous",
            NumberLength = 7, NumberPrefix = "", NumberGroups = { 3, 4 } },
    }
    sims = {
        first = { id = "first", phone_number = "5550101", sim_type = "anonymous", is_virtual = 0 },
        second = { id = "second", phone_number = "5550102", sim_type = "registered", is_virtual = 0,
            owner_identifier = "test:owner", owner_firstname = "Test", owner_lastname = "Owner",
            owner_birthdate = "2000-01-01", registered_at = "2026-01-01" },
    }
    items = {
        [3] = { name = "phone", slot = 3, count = 1,
            metadata = { imei = imei_a, sim_id = "first", phone_number = "5550101", formatted_number = "555-0101", custom = "keep" } },
        [8] = { name = "phone", slot = 8, count = 1,
            metadata = { imei = imei_b, sim_id = "second", phone_number = "5550102", formatted_number = "555-0102", custom = "keep" } },
    }
    devices = { [imei_a] = { sim_id = "first" }, [imei_b] = { sim_id = "second" } }
    Bridge = {
        Debug = function() end,
        Callbacks = { Register = function(name, fn) callbacks[name] = fn end },
        Inventory = {
            RegisterUsableItem = function(name, callback) usable[name] = callback; return true end,
            GetSlotsWithItem = function(_, name)
                local matches = {}
                for _, item in pairs(items) do
                    if item.name == name then matches[#matches + 1] = copy(item) end
                end
                return matches
            end,
            RemoveItem = function(_, name, count, slot)
                if not items[slot] or items[slot].name ~= name then return 0 end
                items[slot] = nil
                return count
            end,
            IsPlayerInventory = function(source, id) return id == nil or id == source or id == "own" end,
            GetSlot = function(_, slot) return copy(items[tonumber(slot) or slot]) end,
            CanCarryItem = function() return not flags.full end,
            SetSlotMetadata = function(_, slot, metadata)
                writes[#writes + 1] = slot
                if flags.metadata_exception then error("metadata export unavailable") end
                if flags.metadata_failure then return false end
                if flags.merge_metadata then
                    for key, value in pairs(metadata) do items[slot].metadata[key] = value end
                else
                    items[slot].metadata = copy(metadata)
                end
                return true
            end,
            AddItem = function(_, name, amount, slot, metadata)
                if flags.add_exception then error("add export unavailable") end
                if flags.add_failure then return false end
                added[#added + 1] = { name = name, amount = amount, metadata = copy(metadata) }
                return true
            end,
        },
        Database = {
            AfterMigration = function(_, fn) fn() end,
            Transaction = function(queries)
                local parameters = queries[1].params
                devices[parameters[2]].sim_id = parameters[1]
                return true
            end,
            Query = function(query, parameters)
                if query:find("INNER JOIN", 1, true) then return 0 end -- startup virtual-SIM cleanup
                if query:find("SELECT *", 1, true) then return { copy(sims[parameters[1]]) } end
                if query:find("SET `sim_id` = NULL", 1, true) then
                    if flags.during_claim then flags.during_claim() end
                    local device = devices[parameters[1]]
                    if flags.claim_failure or device.sim_id ~= parameters[2] then return 0 end
                    device.sim_id = nil
                    if flags.after_claim then flags.after_claim() end
                    return { affectedRows = 1 }
                end
                if query:find("AND `sim_id` IS NULL", 1, true) then
                    local device = devices[parameters[2]]
                    if device.sim_id then return 0 end
                    device.sim_id = parameters[1]
                    if flags.after_restore then flags.after_restore() end
                    return 1
                end
                error("Unexpected SIM query: " .. query)
            end,
        },
    }
    SkyPhone = {
        LoadDevice = function(imei) return copy(devices[imei]) end,
        FindDeviceSlots = function(_, imei)
            local matches = {}
            for _, slot in pairs(items) do
                if slot.name == "phone" and slot.metadata.imei == imei then matches[#matches + 1] = copy(slot) end
            end
            return matches
        end,
        EnsureDevice = function(_, slot) return slot.metadata.imei or imei_a end,
        RequireDeviceSession = function() return session end,
        RequireSession = function()
            if not session then return nil, { success = false, error = "device_not_open" } end
            if not session.unlocked then return nil, { success = false, error = "device_locked" } end
            return session
        end,
        RefreshDevice = function(imei) calls.refreshed = imei end,
    }
    SkyPhoneCompanies = {
        IsServiceNumber = function() return false end,
        ClearCallAvailability = function() calls.cleared = true end,
    }
    SkyPhoneCalls = { EndForSim = function(id, reason) calls.ended, calls.reason = id, reason end }
    SkyPhoneImei = { IsValid = function(imei) return type(imei) == "string" and #imei == 15 and imei:match("^%d+$") ~= nil end }
    SkyPhoneSimNumber = {
        ValidateConfiguration = function() return true end,
        Format = function(number) return number:sub(1, 3) .. "-" .. number:sub(4) end,
    }
    AddEventHandler = function(name, fn) handlers[name] = fn end
    GetGameTimer = function() return 1 end
    TriggerClientEvent = function() end
    TriggerEvent = function() end
    dofile("sky_phone/source/server/sim.lua")
end

local function eject(slot, inventory)
    return callbacks["sky_phone:sim:eject-item"](21, { slot = slot, inventory = inventory })
end
local function expect_error(response, code)
    assert(response.success == false and response.error == code, "expected " .. code .. ", got " .. tostring(response.error))
end
local function unchanged()
    assert(devices[imei_a].sim_id == "first" and devices[imei_b].sim_id == "second")
    assert(items[3].metadata.sim_id == "first" and items[8].metadata.sim_id == "second")
    assert(#added == 0 and calls.ended == nil)
end

-- The clicked second phone is independent of the first phone's active, locked session.
reset()
session = { imei = imei_a, slot = 3, unlocked = false }
assert(eject(8).success)
assert(devices[imei_a].sim_id == "first" and devices[imei_b].sim_id == nil)
assert(items[3].metadata.sim_id == "first" and items[8].metadata.sim_id == nil)
assert(items[8].metadata.imei == imei_b and items[8].metadata.custom == "keep")
assert(items[8].metadata.phone_number == nil and items[8].metadata.formatted_number == nil)
assert(#added == 1 and added[1].name == "sim_registered" and added[1].amount == 1)
assert(added[1].metadata.sim_id == "second" and added[1].metadata.phone_number == "5550102")
assert(added[1].metadata.firstname == "Test" and added[1].metadata.lastname == "Owner")
assert(added[1].metadata.birthdate == "2000-01-01" and added[1].metadata.registered_at == "2026-01-01")
assert(calls.ended == "second" and calls.refreshed == imei_b and not calls.cleared)
assert(session.imei == imei_a and not session.unlocked, "inventory removal must not open or unlock a phone")
expect_error(eject(8), "no_sim")
assert(#added == 1, "repeated clicks must not duplicate a SIM")

reset()
assert(eject("3", "own").success, "closed phones must support physical ejection")
assert(added[1].name == "sim_anonymous" and calls.reason == "sim_removed")

reset()
session = { imei = imei_a, slot = 3, unlocked = false }
expect_error(callbacks["sky_phone:sim:eject"](21), "device_locked")
unchanged()
session.unlocked = true
assert(callbacks["sky_phone:sim:eject"](21).success, "existing Settings action must still work")
assert(calls.cleared and calls.refreshed == imei_a)

for _, invalid in ipairs({ false, {}, "", string.rep("x", 129), 0, -1, 1.5, math.huge, 0/0 }) do
    reset()
    expect_error(eject(invalid), "invalid_request")
    unchanged()
end
reset()
expect_error(callbacks["sky_phone:sim:eject-item"](21, nil), "invalid_request")
expect_error(eject(3, {}), "invalid_request")
expect_error(eject(3, "stash:other"), "phone_not_owned")
expect_error(eject(55), "phone_not_owned")
expect_error(callbacks["sky_phone:sim:eject-item"](21, { slot = 3, imei = imei_b }), "phone_not_owned")
items[3].name = "bread"
expect_error(eject(3), "phone_not_owned")
unchanged()

reset()
items[3].count = 2
expect_error(eject(3), "phone_not_owned")
unchanged()
reset()
items[7] = copy(items[3])
items[7].slot = 7
expect_error(eject(3), "invalid_imei")
unchanged()
reset()
items[3].metadata.imei = nil
expect_error(eject(3), "no_sim")
unchanged()
reset()
items[3].metadata.imei = "bad"
expect_error(eject(3), "invalid_imei")
unchanged()

reset()
sims.first.is_virtual = 1
expect_error(eject(3), "no_sim")
unchanged()
reset()
Config.Sim.Enabled = false
expect_error(eject(3), "disabled")
expect_error(callbacks["sky_phone:sim:eject"](21), "disabled")
unchanged()
reset()
Config.Phone.Unique = false
items[3].count, items[3].metadata = 4, {}
assert(eject(3).success)
assert(#writes == 0 and devices[imei_a].sim_id == nil, "character phones must not receive item identity metadata")

for _, failure in ipairs({ { "full", "inventory_full" }, { "metadata_failure", "metadata_unsupported" },
    { "add_failure", "inventory_full" }, { "claim_failure", "request_failed" },
    { "metadata_exception", "request_failed" }, { "add_exception", "request_failed" },
    { "merge_metadata", "metadata_unsupported" } }) do
    reset()
    flags[failure[1]] = true
    expect_error(eject(3), failure[2])
    unchanged()
    flags[failure[1]] = nil
    assert(eject(3).success, "failed operations must release their lock")
end

reset()
flags.after_claim = function() items[3] = copy(items[8]); items[3].slot = 3 end
expect_error(eject(3), "phone_not_owned")
assert(devices[imei_a].sim_id == "first" and #added == 0 and #writes == 0)
assert(items[3].metadata.imei == imei_b and items[3].metadata.sim_id == "second")

for _, failure in ipairs({ "metadata_failure", "add_failure" }) do
    reset()
    flags[failure] = true
    flags.after_restore = function() items[3] = copy(items[8]); items[3].slot = 3 end
    assert(not eject(3).success)
    assert(items[3].metadata.imei == imei_b and items[3].metadata.sim_id == "second", "rollback must not overwrite a replacement item")
    assert(devices[imei_a].sim_id == "first" and #added == 0)
end

reset()
flags.during_claim = function()
    expect_error(eject(3), "operation_in_progress")
    expect_error(eject(8), "operation_in_progress")
    expect_error(callbacks["sky_phone:sim:insert"](21, { imei = imei_a }), "operation_in_progress")
end
assert(eject(3).success and #added == 1, "overlapping requests must award exactly one SIM")

-- Even a second holder of a duplicated/transferred IMEI must not obtain a second copy.
reset()
flags.during_claim = function()
    flags.during_claim = nil
    assert(callbacks["sky_phone:sim:eject-item"](22, { slot = 3 }).success)
end
expect_error(eject(3), "request_failed")
assert(#added == 1 and devices[imei_a].sim_id == nil, "the SQL claim must protect requests from different sources")

reset()
local original_load = SkyPhone.LoadDevice
SkyPhone.LoadDevice = function() error("temporary database failure") end
expect_error(eject(3), "request_failed")
SkyPhone.LoadDevice = original_load
assert(eject(3).success, "exceptions must release the operation lock")

-- Inserting/replacing a SIM still roundtrips through the usable item and picker.
reset()
sims.third = { id = "third", phone_number = "5550103", sim_type = "anonymous", is_virtual = 0 }
sims.fourth = { id = "fourth", phone_number = "5550104", sim_type = "anonymous", is_virtual = 0 }
items[12] = { name = "sim_anonymous", slot = 12, count = 1,
    metadata = { sim_id = "third", phone_number = "5550103" } }
items[13] = { name = "sim_anonymous", slot = 13, count = 1,
    metadata = { sim_id = "fourth", phone_number = "5550104" } }
usable.sim_anonymous(21, items[12])
expect_error(callbacks["sky_phone:sim:insert"](21, { imei = imei_b }), "confirmation_required")
local load_device = SkyPhone.LoadDevice
SkyPhone.LoadDevice = function(imei)
    expect_error(eject(3), "operation_in_progress")
    return load_device(imei)
end
assert(callbacks["sky_phone:sim:insert"](21, { imei = imei_b, confirmed = true }).success)
SkyPhone.LoadDevice = load_device
assert(devices[imei_b].sim_id == "third" and items[8].metadata.phone_number == "5550103")
assert(items[8].metadata.imei == imei_b and items[8].metadata.custom == "keep")
assert(items[13].metadata.sim_id == "fourth", "using one of multiple SIMs must keep the other slot untouched")
assert(#added == 1 and added[1].metadata.sim_id == "second" and added[1].metadata.firstname == "Test")
assert(eject(8).success and #added == 2 and added[2].metadata.sim_id == "third")
assert(items[8].metadata.phone_number == nil and devices[imei_b].sim_id == nil)

print("Server inventory SIM ejection tests passed")
