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

function Bridge.Inventory.ResolveAdapter(configured_inventory, framework_name)
    configured_inventory = inventory_aliases[configured_inventory] or configured_inventory

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

    return configured_inventory, supported_inventories[configured_inventory]
end
