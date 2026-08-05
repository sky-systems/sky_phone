if Bridge.Inventory.Name ~= "mf" then
    return
end

if Bridge.Framework.GetName() ~= "esx" then
    error("[sky_phone] mf-inventory is only supported with ESX.")
end

local ESX = exports["es_extended"]:getSharedObject()
local inventory = exports["mf-inventory"]

local function get_identifier(source)
    local player = ESX.GetPlayerFromId(source)
    return player and player.identifier or nil
end

local function get_inventory(source)
    local identifier = get_identifier(source)
    return identifier and inventory:getInventoryItems(identifier) or {}
end

local function normalize(item)
    return Bridge.Inventory.NormalizeItem(item, "metadata")
end

function Bridge.Inventory.GetResourceName()
    return "mf-inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    for _, item in pairs(get_inventory(source)) do
        if tostring(item.slot) == tostring(slot_id) then
            return normalize(item)
        end
    end
    return nil
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local matches = {}
    for _, item in pairs(get_inventory(source)) do
        local normalized = normalize(item)
        if normalized.name == item_name and Bridge.Inventory.MetadataMatches(normalized.metadata, metadata) then
            matches[#matches + 1] = normalized
        end
    end
    return matches
end

function Bridge.Inventory.SetSlotMetadata(source, slot_id, metadata)
    local identifier = get_identifier(source)
    local slot = identifier and Bridge.Inventory.GetSlot(source, slot_id) or nil
    if not slot then
        return false
    end
    inventory:setItemProperty(identifier, slot.slot, "metadata", metadata or {})
    local updated = Bridge.Inventory.GetSlot(source, slot.slot)
    return updated and Bridge.Inventory.MetadataMatches(updated.metadata, metadata or {}) or false
end

function Bridge.Inventory.CanCarryItem(source, item_name, count)
    local identifier = get_identifier(source)
    return identifier and inventory:canCarry(identifier, item_name, count) == true or false
end

function Bridge.Inventory.AddItem(source, item_name, count, _, metadata)
    local identifier = get_identifier(source)
    if not identifier or not Bridge.Inventory.CanCarryItem(source, item_name, count, metadata) then
        return false
    end
    return inventory:addInventoryItem(identifier, item_name, count, source, 100, metadata or {}) == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if metadata and not slot then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end
    local identifier = get_identifier(source)
    if not identifier then
        return 0
    end
    return inventory:removeInventoryItem(identifier, item_name, count, source, slot) == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    ESX.RegisterUsableItem(item_name, function(source, _, _, item)
        callback(source, normalize(item))
    end)
    return true
end
