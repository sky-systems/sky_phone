if Bridge.Inventory.Name ~= "codem" then
    return
end

local inventory = exports["codem-inventory"]

local function normalize(item)
    return Bridge.Inventory.NormalizeItem(item, "info")
end

local function get_inventory(source)
    return inventory:GetInventory(false, source) or {}
end

function Bridge.Inventory.GetResourceName()
    return "codem-inventory"
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
    local slot = Bridge.Inventory.GetSlot(source, slot_id)
    if not slot then
        return false
    end
    inventory:SetItemMetadata(source, slot.slot, metadata or {})
    local updated = Bridge.Inventory.GetSlot(source, slot.slot)
    return updated and Bridge.Inventory.MetadataMatches(updated.metadata, metadata or {}) or false
end

function Bridge.Inventory.CanCarryItem()
    return true
end

function Bridge.Inventory.AddItem(source, item_name, count, slot, metadata)
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
    return inventory:RemoveItem(source, item_name, count, slot) == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    return Bridge.Framework.RegisterUsableItem(item_name, function(source, item)
        callback(source, normalize(item))
    end)
end
