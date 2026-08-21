local inventory_adapters = {
    { name = "jaksam", resource = "jaksam_inventory" },
    { name = "qs", resource = "qs-inventory" },
    { name = "ps", resource = "ps-inventory", framework = "qb" },
    { name = "codem", resource = "codem-inventory" },
    { name = "tgiann", resource = "tgiann-inventory" },
    { name = "core", resource = "core_inventory" },
    { name = "jpr", resource = "jpr-inventory", framework = "qb" },
    { name = "origen", resource = "origen_inventory" },
    { name = "ak47", resource = "ak47_inventory" },
    { name = "one", resource = "one_inventory" },
    { name = "ox", resource = "ox_inventory" },
    { name = "mf", resource = "mf-inventory", framework = "esx" },
    { name = "smx", resource = "smx-inventory", framework = "esx" },
    { name = "lj", resource = "lj-inventory" },
    { name = "qb", resource = "qb-inventory" },
    { name = "hex", resource = "hex_4_inventory", framework = "esx", metadata = false },
    { name = "esx", resource = "es_extended", framework = "esx", metadata = false },
}

local inventory_aliases = {
    ["qb-inv"] = "qb",
    qbox = "ox",
}
local supported_inventories = {}
for _, adapter in ipairs(inventory_adapters) do
    inventory_aliases[adapter.resource] = adapter.name
    supported_inventories[adapter.name] = adapter
end

local configured_inventory = Config.Bridge.Inventory
configured_inventory = inventory_aliases[configured_inventory] or configured_inventory
local framework_name = Bridge.Framework.GetName()

if configured_inventory == "auto" then
    for _, adapter in ipairs(inventory_adapters) do
        local compatible_framework = not adapter.framework or adapter.framework == framework_name
        if adapter.name ~= "esx" and compatible_framework and GetResourceState(adapter.resource) == "started" then
            configured_inventory = adapter.name
            break
        end
    end

    if configured_inventory == "auto" and framework_name == "esx" then
        configured_inventory = "esx"
    end
end

local selected_adapter = supported_inventories[configured_inventory]
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

if selected_adapter.metadata == false then
    if Config.Phone.Unique ~= false or Config.Sim.Enabled ~= false then
        Bridge.Inventory.ConfigurationError = ("[sky_phone] Inventory '%s' cannot store unique phone or physical SIM metadata. Set Config.Phone.Unique = false and Config.Sim.Enabled = false, or configure a metadata-capable inventory.")
            :format(configured_inventory)
    end
end

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
        if actual[key] ~= value then
            return false
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
