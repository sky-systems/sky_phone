AddEventHandler = function()
end

local function reset_bridge(inventory_name, resource_name, inventory_export, framework_name, extra_exports)
    Config = {
        Bridge = { Inventory = inventory_name },
        Phone = { Unique = true },
        Sim = { Enabled = true },
    }

    local usable_items = {}
    Bridge = {
        Debug = function()
        end,
        Framework = {
            GetName = function()
                return framework_name or "qb"
            end,
            GetIdentifier = function(source)
                return ("player:%s"):format(source)
            end,
            RegisterUsableItem = function(item_name, callback)
                usable_items[item_name] = callback
                return true
            end,
        },
        Inventory = {},
    }

    exports = extra_exports or {}
    exports[resource_name] = inventory_export
    GetResourceState = function(candidate)
        return candidate == resource_name and "started" or "missing"
    end

    return usable_items
end

local function load_adapter(adapter_path)
    dofile("sky_phone/source/bridge/server/inventory.lua")
    dofile(adapter_path)
    dofile("sky_phone/source/bridge/server/inventory_contract.lua")
end

local function assert_metadata(metadata, imei)
    assert(type(metadata) == "table" and metadata.imei == imei)
end

Config = {
    Bridge = { Inventory = "auto" },
    Phone = { Unique = true },
    Sim = { Enabled = true },
}
Bridge = {
    Framework = {
        GetName = function()
            return "esx"
        end,
    },
    Inventory = {},
}
GetResourceState = function(resource_name)
    if resource_name == "ps-inventory" or resource_name == "tgiann-inventory" or resource_name == "ox_inventory" then
        return "started"
    end
    return "missing"
end
dofile("sky_phone/source/bridge/server/inventory.lua")
assert(Bridge.Inventory.Name == "tgiann", "auto detection must follow the shared Sky inventory priority")

local ak47_items = {
    [3] = { name = "phone", slot = 3, amount = 1, info = { owner = "kept" } },
}
local ak47 = {}

function ak47:GetSlot(identifier, slot)
    assert(identifier == "player:21")
    return ak47_items[slot]
end

function ak47:GetSlotsWithItem(identifier, item_name)
    assert(identifier == "player:21" and item_name == "phone")
    return ak47_items
end

function ak47:SetItemInfo(identifier, slot, metadata)
    assert(identifier == "player:21")
    ak47_items[slot].info = metadata
end

function ak47:CanAddItem()
    return true
end

function ak47:AddItem()
    return true
end

function ak47:RemoveItem()
    return true
end

local ak47_usable = reset_bridge("ak47_inventory", "ak47_inventory", ak47)
load_adapter("sky_phone/source/bridge/server/inventory/ak47.lua")
assert(Bridge.Inventory.Name == "ak47", "resource-name aliases must resolve to adapter names")
assert(Bridge.Inventory.SetSlotMetadata(21, 3, { owner = "kept", imei = "111111111111111" }))
assert_metadata(Bridge.Inventory.GetSlot(21, 3).metadata, "111111111111111")
assert(Bridge.Inventory.RegisterUsableItem("phone", function(source, item)
    assert(source == 21 and item.slot == 3)
end))
ak47_usable.phone(21, "phone", ak47_items[3])

local jaksam_items = {
    [5] = { name = "phone", slot = 5, amount = 1, metadata = {} },
}
local jaksam_usable = {}
local jaksam = {}

function jaksam:getInventory()
    return { items = jaksam_items }
end

function jaksam:setItemMetadataInSlot(_, slot, metadata)
    jaksam_items[slot].metadata = metadata
    return true
end

function jaksam:canCarryItem()
    return true
end

function jaksam:addItem()
    return true
end

function jaksam:removeItem()
    return true
end

function jaksam:registerUsableItem(item_name, callback)
    jaksam_usable[item_name] = callback
end

reset_bridge("jaksam", "jaksam_inventory", jaksam)
load_adapter("sky_phone/source/bridge/server/inventory/jaksam.lua")
assert(Bridge.Inventory.SetSlotMetadata(22, 5, { imei = "222222222222222" }))
assert_metadata(Bridge.Inventory.GetSlot(22, 5).metadata, "222222222222222")
assert(Bridge.Inventory.RegisterUsableItem("phone", function(source, item)
    assert(source == 22 and item.slot == 5)
end))
jaksam_usable.phone(22, jaksam_items[5])

local one_items = {
    [7] = { name = "phone", slot = 7, count = 1, metadata = {} },
}
local one = {}

function one:GetSlot(_, slot)
    return one_items[slot]
end

function one:SearchInventory()
    return one_items
end

function one:SetItemMetadata(_, slot, metadata)
    one_items[slot].metadata = metadata
    return true
end

function one:CanCarryItem()
    return true
end

function one:AddItem()
    return true
end

function one:RemoveItem()
    return true
end

reset_bridge("one", "one_inventory", one)
load_adapter("sky_phone/source/bridge/server/inventory/one.lua")
assert(Bridge.Inventory.SetSlotMetadata(23, 7, { imei = "333333333333333" }))
assert_metadata(Bridge.Inventory.GetSlotsWithItem(23, "phone")[1].metadata, "333333333333333")

local origen_items = {
    [9] = { name = "phone", slot = 9, amount = 1, metadata = {} },
}
local origen = {}

function origen:GetInventory()
    return { inventory = origen_items }
end

function origen:setMetadata(_, slot, metadata)
    origen_items[slot].metadata = metadata
end

function origen:canCarryItem()
    return true
end

function origen:addItem()
    return true
end

function origen:removeItem()
    return true
end

reset_bridge("origen", "origen_inventory", origen)
load_adapter("sky_phone/source/bridge/server/inventory/origen.lua")
assert(Bridge.Inventory.SetSlotMetadata(24, 9, { imei = "444444444444444" }))
assert_metadata(Bridge.Inventory.GetSlot(24, 9).metadata, "444444444444444")

local tgiann_items = {
    [11] = { name = "phone", slot = 11, amount = 1, info = {} },
}
local tgiann = {}

function tgiann:GetPlayerItems()
    return tgiann_items
end

function tgiann:GetItemBySlot(_, slot)
    return tgiann_items[slot]
end

function tgiann:UpdateItemMetadata(_, _, slot, metadata)
    tgiann_items[slot].info = metadata
end

function tgiann:CanCarryItem()
    return true
end

function tgiann:AddItem()
    return true
end

function tgiann:RemoveItem()
    return true
end

reset_bridge("tgiann", "tgiann-inventory", tgiann)
load_adapter("sky_phone/source/bridge/server/inventory/tgiann.lua")
assert(Bridge.Inventory.SetSlotMetadata(25, 11, { imei = "555555555555555" }))
assert_metadata(Bridge.Inventory.GetSlot(25, 11).metadata, "555555555555555")

local qb_items = {
    [13] = { name = "phone", slot = 13, amount = 1, info = { owner = "kept" } },
}
local qb_player = { PlayerData = { items = qb_items } }
local qb_core = {
    Functions = {
        GetPlayer = function()
            return qb_player
        end,
    },
}
local qb_export = {
    GetCoreObject = function()
        return qb_core
    end,
}

local jpr_drop_next_metadata = true
local jpr = {}

function jpr:GetItemBySlot(_, slot)
    return qb_items[slot]
end

function jpr:RemoveItem(_, _, _, slot)
    qb_items[slot] = nil
    return true
end

function jpr:AddItem(_, item_name, amount, slot, metadata)
    qb_items[slot] = {
        name = item_name,
        slot = slot,
        amount = amount,
        info = jpr_drop_next_metadata and {} or metadata,
    }
    jpr_drop_next_metadata = false
    return true
end

reset_bridge("jpr", "jpr-inventory", jpr, "qb", { ["qb-core"] = qb_export })
load_adapter("sky_phone/source/bridge/server/inventory/jpr.lua")
assert(not Bridge.Inventory.SetSlotMetadata(26, 13, { owner = "kept", imei = "666666666666666" }))
assert(qb_items[13] and qb_items[13].info.owner == "kept", "jpr metadata failure must restore the original item")
assert(Bridge.Inventory.SetSlotMetadata(26, 13, { owner = "kept", imei = "666666666666666" }))
assert_metadata(Bridge.Inventory.GetSlot(26, 13).metadata, "666666666666666")

qb_items[15] = { name = "phone", slot = 15, amount = 1, info = {} }
local ps = {}

function ps:GetItemBySlot(_, slot)
    return qb_items[slot]
end

function ps:RemoveItem(_, _, _, slot)
    qb_items[slot] = nil
    return true
end

function ps:AddItem(_, item_name, amount, slot, metadata)
    qb_items[slot] = { name = item_name, slot = slot, amount = amount, info = metadata }
    return true
end

reset_bridge("ps", "ps-inventory", ps, "qb", { ["qb-core"] = qb_export })
load_adapter("sky_phone/source/bridge/server/inventory/ps.lua")
assert(Bridge.Inventory.SetSlotMetadata(27, 15, { imei = "777777777777777" }))
assert_metadata(Bridge.Inventory.GetSlot(27, 15).metadata, "777777777777777")

print("extended inventory bridge regression checks passed")
