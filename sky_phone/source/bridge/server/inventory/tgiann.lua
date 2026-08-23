if Bridge.Inventory.Name ~= "tgiann" then
    return
end

local inventory = exports["tgiann-inventory"]

local function normalize(item, fallback_slot)
    local normalized = Bridge.Inventory.NormalizeItem(item, "info", fallback_slot)
    if not normalized or not normalized.name or normalized.amount < 1 then
        return nil
    end
    return normalized
end

function Bridge.Inventory.GetResourceName()
    return "tgiann-inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    local numeric_slot = tonumber(slot_id)
    return numeric_slot and normalize(inventory:GetItemBySlot(source, numeric_slot), numeric_slot) or nil
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local matches = {}
    for index, item in pairs(inventory:GetPlayerItems(source) or {}) do
        local normalized = normalize(item, tonumber(index) or index)
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
    inventory:UpdateItemMetadata(source, slot.name, slot.slot, requested_metadata)
    local updated = Bridge.Inventory.GetSlot(source, slot.slot)
    return updated and Bridge.Inventory.MetadataMatches(updated.metadata, requested_metadata) or false
end

function Bridge.Inventory.CanCarryItem(source, item_name, count)
    return inventory:CanCarryItem(source, item_name, count) == true
end

function Bridge.Inventory.AddItem(source, item_name, count, slot, metadata)
    if not Bridge.Inventory.CanCarryItem(source, item_name, count, metadata) then
        return false
    end
    return inventory:AddItem(source, item_name, count, slot, metadata or {}) == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if metadata and not slot then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end
    return inventory:RemoveItem(source, item_name, count, slot, metadata) == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    return Bridge.Framework.RegisterUsableItem(item_name, function(source, ...)
        callback(source, normalize(Bridge.Inventory.ResolveUsableItem(...)))
    end)
end
