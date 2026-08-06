local configured_inventory = Config.Bridge.Inventory

if configured_inventory == "auto" then
    if GetResourceState("ox_inventory") == "started" then
        configured_inventory = "ox"
    elseif GetResourceState("qb-inventory") == "started" then
        configured_inventory = "qb"
    elseif GetResourceState("lj-inventory") == "started" then
        configured_inventory = "lj"
    elseif GetResourceState("qs-inventory") == "started" then
        configured_inventory = "qs"
    elseif GetResourceState("codem-inventory") == "started" then
        configured_inventory = "codem"
    elseif GetResourceState("core_inventory") == "started" then
        configured_inventory = "core"
    elseif GetResourceState("mf-inventory") == "started" then
        configured_inventory = "mf"
    elseif GetResourceState("smx-inventory") == "started" then
        configured_inventory = "smx"
    end
end

local supported_inventories = {
    ox = true,
    qb = true,
    lj = true,
    qs = true,
    codem = true,
    core = true,
    mf = true,
    smx = true,
}

if not supported_inventories[configured_inventory] then
    error(("[sky_phone] Unsupported or unavailable inventory '%s'. A metadata-capable inventory adapter is required."):format(tostring(configured_inventory)))
end

Bridge.Inventory.Name = configured_inventory

function Bridge.Inventory.NormalizeItem(item, metadata_field)
    if not item then
        return nil
    end

    local metadata = item[metadata_field or "metadata"]
    if type(metadata) ~= "table" then
        metadata = item.metadata or item.info
    end

    return {
        name = item.name,
        slot = item.slot or item.id,
        count = tonumber(item.count or item.amount) or 0,
        amount = tonumber(item.amount or item.count) or 0,
        metadata = type(metadata) == "table" and metadata or {},
    }
end

function Bridge.Inventory.MetadataMatches(actual, expected)
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
