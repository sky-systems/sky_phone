local framework_name = Bridge.Framework.GetName()
local configured_inventory, selected_adapter = Bridge.Inventory.ResolveAdapter(Config.Bridge.Inventory, framework_name)

if not selected_adapter then
    error(("[sky_phone] Unsupported or unavailable inventory '%s'. Configure a supported inventory adapter."):format(tostring(configured_inventory)))
end
if GetResourceState(selected_adapter.resource) ~= "started" then
    error(("[sky_phone] Inventory '%s' is configured, but resource '%s' is not started.")
        :format(tostring(configured_inventory), selected_adapter.resource))
end
if selected_adapter.framework and selected_adapter.framework ~= framework_name then
    error(("[sky_phone] Inventory '%s' is only supported with framework '%s'.")
        :format(tostring(configured_inventory), selected_adapter.framework))
end

Bridge.Inventory.Name = configured_inventory

local metadata_free_inventory = selected_adapter.metadata == false

local function enforce_metadata_compatibility()
    if not metadata_free_inventory then
        return
    end

    local modes_changed = Config.Phone.Unique ~= false or Config.Sim.Enabled ~= false
    Config.Phone.Unique = false
    Config.Sim.Enabled = false

    if modes_changed then
        Bridge.Debug(
            "warn",
            "[sky_phone] Inventory '%s' does not support item metadata; unique phones and physical SIM cards were disabled automatically.",
            configured_inventory
        )
    end
end

enforce_metadata_compatibility()

AddEventHandler("sky_phone:configurator:serverUpdated", enforce_metadata_compatibility)

function Bridge.Inventory.NormalizeItem(item, metadata_field, fallback_slot)
    if type(item) ~= "table" then
        return nil
    end

    local metadata = item[metadata_field or "metadata"]
    if type(metadata) ~= "table" then
        metadata = item.metadata or item.info
    end

    local slot = item.slot or item.id or fallback_slot
    local numeric_slot = tonumber(slot)
    local count = tonumber(item.count or item.amount or item.quantity) or 0

    return {
        name = item.name or item.item,
        slot = numeric_slot or slot,
        count = count,
        amount = count,
        metadata = type(metadata) == "table" and metadata or {},
    }
end

function Bridge.Inventory.MetadataMatches(actual, expected)
    if type(expected) ~= "table" then
        return true
    end
    actual = type(actual) == "table" and actual or {}
    for key, value in pairs(expected) do
        if type(value) == "table" and type(actual[key]) == "table" then
            local matches, mismatch_key = Bridge.Inventory.MetadataMatches(actual[key], value)
            if not matches then
                return false, tostring(key) .. "." .. mismatch_key
            end
        elseif actual[key] ~= value then
            return false, tostring(key)
        end
    end
    return true
end

function Bridge.Inventory.ResolveUsableItem(...)
    for index = select("#", ...), 1, -1 do
        local candidate = select(index, ...)
        if type(candidate) == "table" and (candidate.name or candidate.item) then
            return candidate
        end
    end
    return nil
end

function Bridge.Inventory.IsPlayerInventory(source, inventory_id)
    return inventory_id == nil or tostring(inventory_id) == tostring(source)
end
