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

local ok, configuration_error = pcall(Bridge.Inventory.RegisterUsableItem, "phone", function()
end)
assert(not ok)
assert(configuration_error:find("Config.Phone.Unique = false", 1, true))
assert(configuration_error:find("Config.Sim.Enabled = false", 1, true))

local manifest_file = assert(io.open("sky_phone/fxmanifest.lua", "rb"))
local manifest = manifest_file:read("*a")
manifest_file:close()
local adapters = assert(manifest:find("source/bridge/server/inventory/*.lua", 1, true))
local contract = assert(manifest:find("source/bridge/server/inventory_contract.lua", 1, true))
assert(adapters < contract, "inventory contract must load after provider adapters")

print("inventory bridge regression checks passed")
