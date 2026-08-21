if Bridge.Inventory.Name ~= "one" then
    return
end

local inventory = exports.one_inventory

local function normalize(item, fallback_slot)
    local normalized = Bridge.Inventory.NormalizeItem(item, nil, fallback_slot)
    if not normalized or not normalized.name or normalized.amount < 1 then
        return nil
    end
    return normalized
end

function Bridge.Inventory.GetResourceName()
    return "one_inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    local numeric_slot = tonumber(slot_id)
    return numeric_slot and normalize(inventory:GetSlot(source, numeric_slot), numeric_slot) or nil
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local matches = {}
    for index, item in pairs(inventory:SearchInventory(source, item_name, metadata) or {}) do
        local normalized = normalize(item, tonumber(index) or index)
        if normalized and normalized.name == item_name
            and Bridge.Inventory.MetadataMatches(normalized.metadata, metadata) then
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
    if inventory:SetItemMetadata(source, slot.slot, requested_metadata) ~= true then
        return false
    end
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
    return inventory:AddItem(source, item_name, count, metadata or {}, slot) == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if metadata and not slot then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end
    return inventory:RemoveItem(source, item_name, count, metadata, slot) == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    return Bridge.Framework.RegisterUsableItem(item_name, function(source, ...)
        callback(source, normalize(Bridge.Inventory.ResolveUsableItem(...)))
    end)
end
