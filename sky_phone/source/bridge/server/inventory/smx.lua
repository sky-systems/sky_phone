if Bridge.Inventory.Name ~= "smx" then
    return
end

if Bridge.Framework.GetName() ~= "esx" then
    error("[sky_phone] smx-inventory is only supported with ESX.")
end

local ESX = exports["es_extended"]:getSharedObject()
local metadata_key = "sky_phone_inventory"

ESX.AddItems({
    { name = Config.Phone.Item, label = Config.Phone.DeviceName, weight = 100, rare = false, canRemove = true },
    { name = Config.Sim.RegisteredItem, label = "Registered SIM", weight = 5, rare = false, canRemove = true },
    { name = Config.Sim.AnonymousItem, label = "Anonymous SIM", weight = 5, rare = false, canRemove = true },
})

local function get_player(source)
    return ESX.GetPlayerFromId(source)
end

local function get_item(source, item_name)
    local player = get_player(source)
    local item = player and player.getInventoryItem(item_name) or nil
    if not item or (tonumber(item.count) or 0) < 1 then
        return nil
    end

    local player_metadata = player.getMeta()
    local all_metadata = type(player_metadata) == "table" and player_metadata[metadata_key] or nil
    local metadata = type(all_metadata) == "table" and all_metadata[item_name] or nil
    return {
        name = item_name,
        slot = item_name,
        count = 1,
        amount = 1,
        metadata = type(metadata) == "table" and metadata or {},
    }
end

local function set_item_metadata(source, item_name, metadata)
    local player = get_player(source)
    if not player or not get_item(source, item_name) then
        return false
    end

    local player_metadata = player.getMeta()
    local all_metadata = type(player_metadata) == "table" and player_metadata[metadata_key] or nil
    all_metadata = type(all_metadata) == "table" and all_metadata or {}
    all_metadata[item_name] = metadata or {}
    player.setMeta(metadata_key, all_metadata)
    return true
end

local function clear_item_metadata(player, item_name)
    local player_metadata = player.getMeta()
    local all_metadata = type(player_metadata) == "table" and player_metadata[metadata_key] or nil
    if type(all_metadata) ~= "table" or all_metadata[item_name] == nil then
        return
    end

    all_metadata[item_name] = nil
    player.setMeta(metadata_key, all_metadata)
end

function Bridge.Inventory.GetResourceName()
    return "smx-inventory"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    return get_item(source, tostring(slot_id))
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local item = get_item(source, item_name)
    if not item or not Bridge.Inventory.MetadataMatches(item.metadata, metadata) then
        return {}
    end
    return { item }
end

function Bridge.Inventory.SetSlotMetadata(source, slot_id, metadata)
    return set_item_metadata(source, tostring(slot_id), metadata)
end

function Bridge.Inventory.CanCarryItem(source, item_name, count)
    local player = get_player(source)
    return player and player.canCarryItem(item_name, count) or false
end

function Bridge.Inventory.AddItem(source, item_name, count, _, metadata)
    local player = get_player(source)
    if not player or not player.canCarryItem(item_name, count) then
        return false
    end

    local before = player.getInventoryItem(item_name)
    local before_count = before and tonumber(before.count) or 0
    player.addInventoryItem(item_name, count)
    local after = player.getInventoryItem(item_name)
    local added = (after and tonumber(after.count) or 0) - before_count
    if added ~= count then
        return false
    end

    if metadata and not set_item_metadata(source, item_name, metadata) then
        player.removeInventoryItem(item_name, count)
        return false
    end
    return true
end

function Bridge.Inventory.RemoveItem(source, item_name, count)
    local player = get_player(source)
    local before = player and player.getInventoryItem(item_name) or nil
    local before_count = before and tonumber(before.count) or 0
    if not player or before_count < count then
        return 0
    end

    player.removeInventoryItem(item_name, count)
    local after = player.getInventoryItem(item_name)
    local removed = before_count - (after and tonumber(after.count) or 0)
    if removed == count then
        clear_item_metadata(player, item_name)
    end
    return removed
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    ESX.RegisterUsableItem(item_name, function(source)
        local item = get_item(source, item_name)
        if not item then
            Bridge.Debug(
                "warn",
                "[sky_phone] smx-inventory usable callback could not resolve item '%s' for source %s.",
                item_name,
                tostring(source)
            )
            return
        end
        callback(source, item)
    end)
    return true
end
