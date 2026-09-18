local event_handlers = {}

AddEventHandler = function(event_name, callback)
    event_handlers[event_name] = callback
end

local function reset_bridge(inventory_name, unique_phones, sim_cards_enabled)
    Config = {
        Bridge = {
            Inventory = inventory_name,
        },
        Phone = {
            Unique = unique_phones,
        },
        Sim = {
            Enabled = sim_cards_enabled,
        },
    }
    Bridge = {
        Debug = function()
        end,
        Framework = {
            GetName = function()
                return inventory_name == "esx" and "esx" or "qb"
            end,
        },
        Inventory = {},
    }
end

local function load_inventory_contract(adapter_path)
    dofile("sky_phone/source/bridge/server/inventory.lua")
    dofile(adapter_path)
    dofile("sky_phone/source/bridge/server/inventory_contract.lua")
end

do
    local function copy_export_value(value)
        if type(value) ~= "table" then
            return value
        end
        local copy = {}
        for key, nested_value in pairs(value) do
            copy[key] = copy_export_value(nested_value)
        end
        return copy
    end

    local ox_item = { name = "phone", slot = 1, count = 1, metadata = {} }
    local ox_write_mode = "persist"
    local ox_inventory = {}

    function ox_inventory:GetSlot(source, slot)
        assert(source == 5 and slot == 1)
        -- FiveM exports serialize tables instead of sharing Lua table references.
        return copy_export_value(ox_item)
    end

    function ox_inventory:SetMetadata(source, slot, metadata)
        assert(source == 5 and slot == 1)
        if ox_write_mode == "ignore" then
            return
        end
        ox_item.metadata = copy_export_value(metadata)
        if ox_write_mode == "drop_nested" then
            ox_item.metadata.custom.labels = nil
        elseif ox_write_mode == "change_nested" then
            ox_item.metadata.custom.labels[1] = "changed"
        elseif ox_write_mode == "remove_slot" then
            ox_item = nil
        end
        -- SetMetadata has no success return value, including when it succeeds.
    end

    reset_bridge("ox", true, true)
    exports = { ox_inventory = ox_inventory }
    GetResourceState = function(resource_name)
        return resource_name == "ox_inventory" and "started" or "missing"
    end
    load_inventory_contract("sky_phone/source/bridge/server/inventory/ox.lua")
    local metadata_errors = {}
    Bridge.Debug = function(level, message, ...)
        assert(level == "error")
        metadata_errors[#metadata_errors + 1] = message:format(...)
    end

    assert(Bridge.Inventory.SetSlotMetadata(5, "1", { imei = "123456789012345" }))

    local phone_metadata = {
        imei = "123456789012345",
        sim_id = "test-sim",
        phone_number = "5550100",
        custom = { labels = { "kept", "also kept" }, enabled = false, empty = {} },
    }
    assert(Bridge.Inventory.SetSlotMetadata(5, "1", phone_metadata),
        "Ox must accept successfully persisted metadata containing copied nested tables")
    assert(ox_item.metadata.custom ~= phone_metadata.custom)
    assert(ox_item.metadata.custom.labels ~= phone_metadata.custom.labels)

    local without_sim = copy_export_value(phone_metadata)
    without_sim.sim_id = nil
    without_sim.phone_number = nil
    assert(Bridge.Inventory.SetSlotMetadata(5, 1, without_sim))
    assert(ox_item.metadata.sim_id == nil and ox_item.metadata.phone_number == nil)
    assert(ox_item.metadata.custom.labels[1] == "kept")
    assert(#metadata_errors == 0, "Successful metadata writes must not emit error diagnostics")

    ox_write_mode = "ignore"
    assert(not Bridge.Inventory.SetSlotMetadata(5, 1, phone_metadata),
        "Ox must reject a metadata write that did not persist the requested SIM")
    ox_write_mode = "drop_nested"
    assert(not Bridge.Inventory.SetSlotMetadata(5, 1, phone_metadata),
        "Ox must reject missing nested metadata")
    assert(metadata_errors[#metadata_errors]:find("field 'custom.labels'", 1, true))
    ox_write_mode = "change_nested"
    assert(not Bridge.Inventory.SetSlotMetadata(5, 1, phone_metadata),
        "Ox must reject changed nested metadata")
    assert(metadata_errors[#metadata_errors]:find("field 'custom.labels.1'", 1, true))
    ox_write_mode = "remove_slot"
    assert(not Bridge.Inventory.SetSlotMetadata(5, 1, phone_metadata))
    assert(metadata_errors[#metadata_errors]:find("after writing", 1, true))
    assert(not Bridge.Inventory.SetSlotMetadata(5, 1, phone_metadata))
    assert(metadata_errors[#metadata_errors]:find("before writing", 1, true))
    assert(#metadata_errors == 5)

    assert(Bridge.Inventory.MetadataMatches({ imei = "test", extra = "kept" }, { imei = "test" }))
    assert(Bridge.Inventory.MetadataMatches({ custom = { enabled = false } }, { custom = { enabled = false } }))
    assert(not Bridge.Inventory.MetadataMatches({ custom = { enabled = true } }, { custom = { enabled = false } }))
    assert(not Bridge.Inventory.MetadataMatches({}, { custom = {} }))
    assert(not Bridge.Inventory.MetadataMatches({ custom = "wrong type" }, { custom = {} }))
    assert(not Bridge.Inventory.MetadataMatches({ custom = {} }, { custom = "wrong type" }))
end

local core_items = {
    {
        name = "phone",
        slot = 15,
        count = 1,
        metadata = {},
    },
}
local metadata_write
local core_inventory = {}

function core_inventory:getInventory(source)
    assert(source == 7)
    return core_items
end

function core_inventory:setMetadata(source, slot, metadata)
    metadata_write = { source = source, slot = slot, metadata = metadata }
    core_items[1].metadata = metadata
end

function core_inventory:updateMetadata()
    error("core bridge must use the stable setMetadata contract")
end

reset_bridge("core", true, true)
exports = {
    core_inventory = core_inventory,
}
GetResourceState = function(resource_name)
    return resource_name == "core_inventory" and "started" or "missing"
end
load_inventory_contract("sky_phone/source/bridge/server/inventory/core.lua")

assert(Bridge.Inventory.SetSlotMetadata(7, "15", { imei = "123456789012345" }))
assert(metadata_write.source == 7)
assert(metadata_write.slot == 15, "core metadata slot must be numeric")
assert(metadata_write.metadata.imei == "123456789012345")
assert(Bridge.Inventory.GetSlot(7, 15).metadata.imei == "123456789012345")

local qb_item = {
    name = "phone",
    slot = 2,
    amount = 1,
    info = { owner = "kept" },
}
local qb_write_mode = "persist"
local qb_inventory = {}

function qb_inventory:GetItemBySlot(source, slot)
    assert(source == 9 and slot == 2)
    return qb_item
end

function qb_inventory:GetItemsByName(source, item_name)
    assert(source == 9 and item_name == "phone")
    return qb_item and { qb_item } or {}
end

function qb_inventory:SetItemData()
    error("qb bridge must not rely on an unverified direct metadata setter")
end

function qb_inventory:RemoveItem(source, item_name, amount, slot, reason)
    assert(source == 9 and item_name == "phone" and amount == 1 and slot == 2)
    assert(reason == "sky_phone:metadata-update")
    if not qb_item then
        return false
    end
    qb_item = nil
    return true
end

function qb_inventory:AddItem(source, item_name, amount, slot, info, reason)
    assert(source == 9 and item_name == "phone" and amount == 1 and slot == 2)
    assert(reason == "sky_phone:metadata-update")
    qb_item = {
        name = item_name,
        slot = slot,
        amount = amount,
        info = qb_write_mode == "drop_metadata" and {} or info,
    }
    return true
end

function qb_inventory:CanAddItem()
    return true
end

reset_bridge("qb", true, true)
exports = {
    ["qb-inventory"] = qb_inventory,
}
GetResourceState = function(resource_name)
    return resource_name == "qb-inventory" and "started" or "missing"
end
load_inventory_contract("sky_phone/source/bridge/server/inventory/qb.lua")

assert(Bridge.Inventory.SetSlotMetadata(9, 2, { owner = "kept", imei = "123456789012345" }))
assert(qb_item.info.owner == "kept" and qb_item.info.imei == "123456789012345")

qb_write_mode = "drop_metadata"
assert(not Bridge.Inventory.SetSlotMetadata(9, 2, { owner = "kept", imei = "999999999999999" }))
assert(qb_item and qb_item.slot == 2, "QB metadata verification must leave the item in its exact slot")

local function create_esx()
    local usable_items = {}
    local player = {}

    function player.getInventoryItem(item_name)
        return {
            name = item_name,
            count = 1,
        }
    end

    local esx = {}

    function esx.GetPlayerFromId(source)
        assert(source == 11)
        return player
    end

    function esx.RegisterUsableItem(item_name, callback)
        usable_items[item_name] = callback
    end

    return esx, usable_items
end

local esx, usable_items = create_esx()
reset_bridge("esx", false, false)
exports = {
    es_extended = {
        getSharedObject = function()
            return esx
        end,
    },
}
GetResourceState = function(resource_name)
    return resource_name == "es_extended" and "started" or "missing"
end
load_inventory_contract("sky_phone/source/bridge/server/inventory/esx.lua")

local used_item
assert(Bridge.Inventory.RegisterUsableItem("phone", function(source, item)
    assert(source == 11)
    used_item = item
end))
usable_items.phone(11)
assert(used_item.name == "phone")
assert(used_item.slot == "phone")
assert(used_item.count == 1)

esx = create_esx()
reset_bridge("esx", true, true)
exports = {
    es_extended = {
        getSharedObject = function()
            return esx
        end,
    },
}
load_inventory_contract("sky_phone/source/bridge/server/inventory/esx.lua")

assert(Config.Phone.Unique == false)
assert(Config.Sim.Enabled == false)
assert(Bridge.Inventory.ConfigurationError == nil)

Config.Phone.Unique = true
Config.Sim.Enabled = true
event_handlers["sky_phone:configurator:serverUpdated"]()
assert(Config.Phone.Unique == false)
assert(Config.Sim.Enabled == false)

assert(Bridge.Inventory.RegisterUsableItem("phone", function()
end))

local manifest_file = assert(io.open("sky_phone/fxmanifest.lua", "rb"))
local manifest = manifest_file:read("*a")
manifest_file:close()
local adapters = assert(manifest:find("source/bridge/server/inventory/*.lua", 1, true))
local contract = assert(manifest:find("source/bridge/server/inventory_contract.lua", 1, true))
assert(adapters < contract, "inventory contract must load after provider adapters")

print("inventory bridge regression checks passed")
