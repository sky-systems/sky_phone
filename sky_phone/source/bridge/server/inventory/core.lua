if Bridge.Inventory.Name ~= "core" then
    return
end

local inventory = exports.core_inventory

local function normalize(item)
    return Bridge.Inventory.NormalizeItem(item, "metadata")
end

local function get_inventory(source)
    return inventory:getInventory(source) or {}
end

function Bridge.Inventory.GetResourceName()
    return "core_inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    for _, item in pairs(get_inventory(source)) do
        local item_slot = item.slot or item.id
        if tostring(item_slot) == tostring(slot_id) then
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
    local numeric_slot = tonumber(slot_id)
    if not numeric_slot then
        return false
    end
    inventory:setMetadata(source, numeric_slot, metadata or {})
    return true
end

function Bridge.Inventory.CanCarryItem()
    return true
end

function Bridge.Inventory.AddItem(source, item_name, count, _, metadata)
    return inventory:addItem(source, item_name, count, metadata or {}) == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if metadata and not slot then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end
    local success
    if slot then
        success = inventory:removeItemExact(source, slot, count)
    else
        success = inventory:removeItem(source, item_name, count)
    end
    return success == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    return Bridge.Framework.RegisterUsableItem(item_name, function(source, item_name_or_item, item)
        local used_item = Bridge.Framework.GetName() == "esx" and item or item_name_or_item
        callback(source, normalize(used_item))
    end)
end
