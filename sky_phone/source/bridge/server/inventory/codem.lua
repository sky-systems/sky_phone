if Bridge.Inventory.Name ~= "codem" then
    return
end

local inventory = exports["codem-inventory"]

local function normalize(item)
    return Bridge.Inventory.NormalizeItem(item, "info")
end

local function get_inventory(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    return identifier and inventory:GetInventory(identifier, source) or {}
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
    local items = inventory:GetItemsByName(source, item_name) or {}
    if items.name then
        items = { items }
    end
    for _, item in pairs(items) do
        local normalized = normalize(item)
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
    return Bridge.Framework.RegisterUsableItem(item_name, function(source, ...)
        callback(source, normalize(Bridge.Inventory.ResolveUsableItem(...)))
    end)
end
