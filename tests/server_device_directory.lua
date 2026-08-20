local devices = {
    ["111111111111111"] = {
        imei = "111111111111111",
        device_name = "Phone A",
        account_id = 11,
        sim_id = "sim-a",
        phone_number = "5550001",
        sim_type = "registered",
        sim_owner_identifier = "char:1",
    },
    ["222222222222222"] = {
        imei = "222222222222222",
        device_name = "Phone B",
        account_id = 11,
        sim_id = "sim-b",
        phone_number = "5550002",
        sim_type = "registered",
        sim_owner_identifier = "char:1",
    },
    ["333333333333333"] = {
        imei = "333333333333333",
        device_name = "Phone C",
    },
    ["444444444444444"] = {
        imei = "444444444444444",
        device_name = "Phone D",
    },
    ["555555555555555"] = {
        imei = "555555555555555",
        device_name = "Phone E",
    },
    ["666666666666666"] = {
        imei = "666666666666666",
        device_name = "Shared Phone",
        sim_id = "sim-f",
        phone_number = "5550005",
        sim_type = "registered",
        sim_owner_identifier = "char:5",
        mapped_identifier = "char:5",
    },
}

local sims = {
    ["5550001"] = {
        id = "sim-a",
        phone_number = "5550001",
        sim_type = "registered",
        owner_identifier = "char:1",
        imei = "111111111111111",
    },
    ["5550002"] = {
        id = "sim-b",
        phone_number = "5550002",
        sim_type = "registered",
        owner_identifier = "char:1",
        imei = "222222222222222",
    },
    ["5550005"] = {
        id = "sim-f",
        phone_number = "5550005",
        sim_type = "registered",
        owner_identifier = "char:5",
        imei = "666666666666666",
    },
    ["5550009"] = {
        id = "sim-z",
        phone_number = "5550009",
        sim_type = "anonymous",
        owner_identifier = "char:9",
    },
}

local identifiers = {
    [1] = "char:1",
    [2] = "char:2",
    [4] = "char:4",
    [5] = "char:5",
}
local equipped_numbers = {
    [1] = "5550002",
    [2] = nil,
    [4] = nil,
    [5] = nil,
}
local source_by_number = {
    ["5550002"] = 1,
}
local inventory_slots = {
    [1] = {
        { amount = 1, metadata = { imei = "111111111111111" }, slot = 1 },
        { amount = 1, metadata = { imei = "222222222222222" }, slot = 2 },
    },
    [2] = {
        { amount = 1, metadata = { imei = "333333333333333" }, slot = 1 },
    },
    [4] = {
        { amount = 1, metadata = { imei = "444444444444444" }, slot = 1 },
        { amount = 1, metadata = { imei = "555555555555555" }, slot = 2 },
    },
    [5] = {
        { amount = 1, metadata = {}, slot = 1 },
    },
}

local function clone(row)
    if not row then
        return nil
    end
    local copied = {}
    for key, value in pairs(row) do
        copied[key] = value
    end
    return copied
end

Config = {
    Phone = {
        Item = "phone",
        Unique = true,
    },
    Sim = {
        NumberLength = 7,
        NumberPrefix = "",
    },
}

Bridge = {
    Database = {
        AfterMigration = function(name, callback)
            assert(name == "sky_phone")
            callback()
        end,
        Query = function(query, parameters)
            local parameter = parameters[1]
            if query:find("WHERE d.`imei` = ?", 1, true) then
                local row = clone(devices[parameter])
                return row and { row } or {}
            end
            if query:find("WHERE s.`phone_number` = ?", 1, true)
                and query:find("FROM `sky_phone_devices` d", 1, true)
            then
                local sim = sims[parameter]
                local row = sim and sim.imei and clone(devices[sim.imei]) or nil
                return row and { row } or {}
            end
            if query:find("WHERE c.`owner_identifier` = ?", 1, true) then
                for _, device in pairs(devices) do
                    if device.mapped_identifier == parameter then
                        return { clone(device) }
                    end
                end
                return {}
            end
            if query:find("FROM `sky_phone_sims` s", 1, true)
                and query:find("WHERE s.`phone_number` = ?", 1, true)
            then
                local row = clone(sims[parameter])
                return row and { row } or {}
            end
            error("unexpected directory query: " .. query)
        end,
    },
    Debug = function() end,
    Framework = {
        GetIdentifier = function(source)
            return identifiers[source]
        end,
        GetPlayers = function()
            return { 1, 2, 4, 5 }
        end,
    },
    Inventory = {
        GetSlotsWithItem = function(source, item_name)
            assert(item_name == "phone")
            return inventory_slots[source] or {}
        end,
    },
}

SkyPhoneImei = {
    IsValid = function(value)
        return type(value) == "string" and #value == 15 and value:match("^%d+$") ~= nil
    end,
}

dofile("sky_phone/source/shared/sim_number.lua")

SkyPhone = {
    FindDeviceSlots = function(source, imei)
        if source == 5 and imei == "666666666666666" then
            return inventory_slots[source]
        end
        local matches = {}
        for _, slot in ipairs(inventory_slots[source] or {}) do
            if slot.metadata and slot.metadata.imei == imei then
                matches[#matches + 1] = slot
            end
        end
        return matches
    end,
    GetEquippedPhoneNumber = function(source)
        return equipped_numbers[source]
    end,
    GetSourceFromNumber = function(phone_number)
        return source_by_number[phone_number]
    end,
}

dofile("sky_phone/source/server/device_directory.lua")

local source_identity = assert(SkyPhoneDeviceDirectory.GetOnlineBySource(1))
assert(source_identity.source == 1 and source_identity.identifier == "char:1")
assert(source_identity.imei == "222222222222222", "equipped number must select the preferred device, not the first slot")
assert(source_identity.phoneNumber == "5550002" and source_identity.equipped and source_identity.online)

local phone_identity = assert(SkyPhoneDeviceDirectory.GetOnlineByPhoneNumber("555-0002"))
assert(phone_identity.source == 1 and phone_identity.imei == "222222222222222")

local identifier_identity = assert(SkyPhoneDeviceDirectory.GetOnlineByIdentifier(" char:1 "))
assert(identifier_identity.source == 1 and identifier_identity.phoneNumber == "5550002")

local imei_identity = assert(SkyPhoneDeviceDirectory.GetOnlineByImei("222222222222222"))
assert(imei_identity.source == 1 and imei_identity.phoneNumber == "5550002")

local no_sim_identity = assert(SkyPhoneDeviceDirectory.GetOnlineBySource(2))
assert(no_sim_identity.imei == "333333333333333" and no_sim_identity.phoneNumber == nil)
assert(assert(SkyPhoneDeviceDirectory.GetOnlineByImei("333333333333333")).source == 2)

local ambiguous_identity, ambiguous_error = SkyPhoneDeviceDirectory.GetOnlineBySource(4)
assert(ambiguous_identity == nil and ambiguous_error == "equipped_device_ambiguous")

local stored_device = assert(SkyPhoneDeviceDirectory.GetStoredDeviceByPhoneNumber("5550001"))
assert(stored_device.imei == "111111111111111" and not stored_device.online and not stored_device.equipped)

local stored_sim = assert(SkyPhoneDeviceDirectory.GetStoredSimByPhoneNumber("5550009"))
assert(stored_sim.simId == "sim-z" and stored_sim.deviceImei == nil)
assert(stored_sim.registeredIdentifier == "char:9", "SIM registration identity must remain distinct")

local ejected_device, ejected_error = SkyPhoneDeviceDirectory.GetStoredDeviceByPhoneNumber("5550009")
assert(ejected_device == nil and ejected_error == "device_not_found")

local unique_identifier, unique_identifier_error = SkyPhoneDeviceDirectory.GetStoredDeviceByIdentifier("char:5")
assert(unique_identifier == nil and unique_identifier_error == "identity_scope_unsupported")

local invalid_source, invalid_source_error = SkyPhoneDeviceDirectory.GetOnlineBySource("1")
assert(invalid_source == nil and invalid_source_error == "invalid_source")
local infinite_source, infinite_source_error = SkyPhoneDeviceDirectory.GetOnlineBySource(math.huge)
assert(infinite_source == nil and infinite_source_error == "invalid_source")
local invalid_imei, invalid_imei_error = SkyPhoneDeviceDirectory.GetStoredDeviceByImei("123")
assert(invalid_imei == nil and invalid_imei_error == "invalid_imei")

equipped_numbers[1] = "5550001"
source_by_number["5550002"] = nil
source_by_number["5550001"] = 1
local refreshed_identity = assert(SkyPhoneDeviceDirectory.GetOnlineBySource(1))
assert(refreshed_identity.imei == "111111111111111", "online directory lookups must not cache equipped identity")
equipped_numbers[1] = "5550002"
source_by_number["5550001"] = nil
source_by_number["5550002"] = 1

Config.Phone.Unique = false
dofile("sky_phone/source/server/device_directory.lua")

local offline_shared = assert(SkyPhoneDeviceDirectory.GetStoredDeviceByIdentifier("char:5"))
assert(offline_shared.imei == "666666666666666" and offline_shared.identifier == "char:5")

local online_shared = assert(SkyPhoneDeviceDirectory.GetOnlineBySource(5))
assert(online_shared.imei == "666666666666666" and online_shared.identifier == "char:5")
assert(online_shared.phoneNumber == "5550005")

print("Server device directory tests passed")
