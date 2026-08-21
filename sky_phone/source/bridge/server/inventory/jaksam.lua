if Bridge.Inventory.Name ~= "jaksam" then
    return
end

local inventory = exports["jaksam_inventory"]

local function normalize(item)
    local normalized = Bridge.Inventory.NormalizeItem(item)
    if not normalized or not normalized.name or normalized.amount < 1 then
        return nil
    end
    return normalized
end

local function get_inventory(source)
    local player_inventory = inventory:getInventory(source)
    return type(player_inventory) == "table" and type(player_inventory.items) == "table"
        and player_inventory.items or {}
end

function Bridge.Inventory.GetResourceName()
    return "jaksam_inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    for index, item in pairs(get_inventory(source)) do
        local normalized = normalize(item)
        local item_slot = normalized and (normalized.slot or tonumber(index)) or nil
        if tostring(item_slot) == tostring(slot_id) then
            normalized.slot = item_slot
            return normalized
        end
    end
    return nil
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local matches = {}
    for index, item in pairs(get_inventory(source)) do
        local normalized = normalize(item)
        if normalized and normalized.name == item_name
            and Bridge.Inventory.MetadataMatches(normalized.metadata, metadata) then
            normalized.slot = normalized.slot or tonumber(index) or index
            matches[#matches + 1] = normalized
        end
    end
    return matches
end

function Bridge.Inventory.SetSlotMetadata(source, slot_id, metadata)
    local slot = Bridge.Inventory.GetSlot(source, slot_id)
    if not slot then
        return false
    end

    local requested_metadata = type(metadata) == "table" and metadata or {}
    local success = inventory:setItemMetadataInSlot(source, slot.slot, requested_metadata)
    if success ~= true then
        return false
    end
    local updated = Bridge.Inventory.GetSlot(source, slot.slot)
    return updated and Bridge.Inventory.MetadataMatches(updated.metadata, requested_metadata) or false
end

function Bridge.Inventory.CanCarryItem(source, item_name, count)
    return inventory:canCarryItem(source, item_name, count) == true
end

function Bridge.Inventory.AddItem(source, item_name, count, slot, metadata)
    if not Bridge.Inventory.CanCarryItem(source, item_name, count, metadata) then
        return false
    end
    local success = inventory:addItem(source, item_name, count, metadata or {}, slot)
    return success == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if metadata and not slot then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end
    local success = inventory:removeItem(source, item_name, count, nil, slot)
    return success == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    inventory:registerUsableItem(item_name, function(source, ...)
        callback(source, normalize(Bridge.Inventory.ResolveUsableItem(...)))
    end)
    return true
end
