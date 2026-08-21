if Bridge.Inventory.Name ~= "ox" then
    return
end

local inventory = exports.ox_inventory
local usable_items = {}

AddEventHandler("ox_inventory:usedItem", function(source, item_name, slot_id)
    local callback = usable_items[item_name]
    if not callback then
        return
    end

    local slot = Bridge.Inventory.GetSlot(source, slot_id)
    if not slot or slot.name ~= item_name then
        Bridge.Debug(
            "warn",
            "[sky_phone] ox_inventory reported an invalid used slot %s for item '%s' and source %s.",
            tostring(slot_id),
            tostring(item_name),
            tostring(source)
        )
        return
    end

    callback(source, slot)
end)

function Bridge.Inventory.GetResourceName()
    return "ox_inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    return inventory:GetSlot(source, tonumber(slot_id))
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    return inventory:GetSlotsWithItem(source, item_name, metadata, false) or {}
end

function Bridge.Inventory.SetSlotMetadata(source, slot_id, metadata)
    local slot = Bridge.Inventory.GetSlot(source, slot_id)
    if not slot then
        return false
    end

    local requested_metadata = type(metadata) == "table" and metadata or {}
    inventory:SetMetadata(source, tonumber(slot_id), requested_metadata)
    local updated = Bridge.Inventory.GetSlot(source, slot_id)
    return updated and Bridge.Inventory.MetadataMatches(updated.metadata, requested_metadata) or false
end

function Bridge.Inventory.CanCarryItem(source, item_name, count, metadata)
    return inventory:CanCarryItem(source, item_name, count, metadata)
end

function Bridge.Inventory.AddItem(source, item_name, count, slot, metadata)
    if not Bridge.Inventory.CanCarryItem(source, item_name, count, metadata) then
        return false
    end

    local success = inventory:AddItem(source, item_name, count, metadata, slot)
    return success == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if slot then
        local success = inventory:RemoveItem(source, item_name, count, nil, slot)
        return success and count or 0
    end

    if metadata then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end

    local success = inventory:RemoveItem(source, item_name, count, metadata, slot, false, false)
    return success and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    usable_items[item_name] = callback
    return true
end
