if Bridge.Inventory.Name ~= "ps" then
    return
end

if Bridge.Framework.GetName() ~= "qb" then
    error("[sky_phone] ps-inventory is only supported with QBCore.")
end

local inventory = exports["ps-inventory"]
local QBCore = exports["qb-core"]:GetCoreObject()

local function normalize(item, fallback_slot)
    local normalized = Bridge.Inventory.NormalizeItem(item, "info", fallback_slot)
    if not normalized or not normalized.name or normalized.amount < 1 then
        return nil
    end
    return normalized
end

local function get_inventory(source)
    local player = QBCore.Functions.GetPlayer(tonumber(source))
    return player and player.PlayerData.items or {}
end

local function restore_slot(source, slot, metadata)
    local restored = inventory:AddItem(source, slot.name, slot.amount, slot.slot, metadata)
    if not restored then
        Bridge.Debug(
            "error",
            "[sky_phone] ps-inventory could not restore item '%s' in slot %s after a metadata update failed.",
            tostring(slot.name),
            tostring(slot.slot)
        )
    end
    return restored == true
end

function Bridge.Inventory.GetResourceName()
    return "ps-inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    local numeric_slot = tonumber(slot_id)
    return numeric_slot and normalize(inventory:GetItemBySlot(source, numeric_slot), numeric_slot) or nil
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local matches = {}
    for index, item in pairs(get_inventory(source)) do
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
    if not slot or slot.amount < 1 then
        return false
    end

    local previous_metadata = slot.metadata
    local requested_metadata = type(metadata) == "table" and metadata or {}
    if inventory:RemoveItem(source, slot.name, slot.amount, slot.slot) ~= true then
        return false
    end
    if inventory:AddItem(source, slot.name, slot.amount, slot.slot, requested_metadata) ~= true then
        restore_slot(source, slot, previous_metadata)
        return false
    end

    local updated = Bridge.Inventory.GetSlot(source, slot.slot)
    if updated and Bridge.Inventory.MetadataMatches(updated.metadata, requested_metadata) then
        return true
    end

    inventory:RemoveItem(source, slot.name, slot.amount, slot.slot)
    restore_slot(source, slot, previous_metadata)
    return false
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
