if Bridge.Inventory.Name ~= "qb" and Bridge.Inventory.Name ~= "lj" then
    return
end

local resource_name = Bridge.Inventory.Name == "lj" and "lj-inventory" or "qb-inventory"
local inventory = exports[resource_name]
local QBCore = Bridge.Inventory.Name == "lj" and exports["qb-core"]:GetCoreObject() or nil

local function get_lj_player(source)
    return QBCore and QBCore.Functions.GetPlayer(tonumber(source)) or nil
end

local function normalize(item)
    if not item then
        return nil
    end

    local metadata = {}
    for key, value in pairs(type(item.info) == "table" and item.info or {}) do
        metadata[key] = value
    end
    return {
        name = item.name,
        slot = tonumber(item.slot),
        count = tonumber(item.amount) or 0,
        amount = tonumber(item.amount) or 0,
        metadata = metadata,
    }
end

local function metadata_matches(actual, expected)
    if type(expected) ~= "table" then
        return true
    end
    actual = type(actual) == "table" and actual or {}
    for key, value in pairs(expected) do
        if actual[key] ~= value then
            return false
        end
    end
    return true
end

function Bridge.Inventory.GetResourceName()
    return resource_name
end

function Bridge.Inventory.GetSlot(source, slot_id)
    if Bridge.Inventory.Name == "lj" then
        local player = get_lj_player(source)
        return normalize(player and player.PlayerData.items[tonumber(slot_id)] or nil)
    end
    return normalize(inventory:GetItemBySlot(source, tonumber(slot_id)))
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local matches = {}
    local items
    if Bridge.Inventory.Name == "lj" then
        local player = get_lj_player(source)
        items = player and player.PlayerData.items or {}
    else
        items = inventory:GetItemsByName(source, item_name) or {}
    end
    for _, item in pairs(items) do
        local normalized = normalize(item)
        if normalized.name == item_name and metadata_matches(normalized.metadata, metadata) then
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
    if Bridge.Inventory.Name == "lj" then
        local player = get_lj_player(source)
        if not player then
            return false
        end
        local requested_metadata = type(metadata) == "table" and metadata or {}
        player.PlayerData.items[slot.slot].info = requested_metadata
        player.Functions.SetInventory(player.PlayerData.items, true)
        local updated = player.PlayerData.items[slot.slot]
        return updated ~= nil and Bridge.Inventory.MetadataMatches(updated.info, requested_metadata)
    end

    local amount = tonumber(slot.amount or slot.count) or 0
    if amount <= 0 then
        return false
    end

    local requested_metadata = type(metadata) == "table" and metadata or {}
    if inventory:RemoveItem(source, slot.name, amount, slot.slot, "sky_phone:metadata-update") ~= true then
        return false
    end

    if inventory:AddItem(source, slot.name, amount, slot.slot, requested_metadata, "sky_phone:metadata-update") ~= true then
        return false
    end

    local updated = Bridge.Inventory.GetSlot(source, slot.slot)
    return updated
        and updated.name == slot.name
        and updated.amount == amount
        and Bridge.Inventory.MetadataMatches(updated.metadata, requested_metadata)
        or false
end

function Bridge.Inventory.CanCarryItem(source, item_name, count)
    if Bridge.Inventory.Name == "lj" then
        return get_lj_player(source) ~= nil
    end
    return inventory:CanAddItem(source, item_name, count) == true
end

function Bridge.Inventory.AddItem(source, item_name, count, slot, metadata)
    if not Bridge.Inventory.CanCarryItem(source, item_name, count, metadata) then
        return false
    end
    if Bridge.Inventory.Name == "lj" then
        local player = get_lj_player(source)
        return player and player.Functions.AddItem(item_name, count, slot, metadata or {}) == true or false
    end
    return inventory:AddItem(source, item_name, count, slot, metadata or {}, "sky_phone") == true
end

function Bridge.Inventory.RemoveItem(source, item_name, count, slot, metadata)
    if metadata and not slot then
        local slots = Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
        slot = slots[1] and slots[1].slot or nil
        if not slot then
            return 0
        end
    end
    if Bridge.Inventory.Name == "lj" then
        local player = get_lj_player(source)
        return player and player.Functions.RemoveItem(item_name, count, slot) == true and count or 0
    end
    return inventory:RemoveItem(source, item_name, count, slot, "sky_phone") == true and count or 0
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    return Bridge.Framework.RegisterUsableItem(item_name, function(source, item)
        callback(source, normalize(item))
    end)
end
