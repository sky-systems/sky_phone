local required_methods = {
    "GetResourceName",
    "GetSlot",
    "GetSlotsWithItem",
    "SetSlotMetadata",
    "CanCarryItem",
    "AddItem",
    "RemoveItem",
    "RegisterUsableItem",
}

local configuration_error = Bridge.Inventory.ConfigurationError

for _, method_name in ipairs(required_methods) do
    if configuration_error then
        Bridge.Inventory[method_name] = function()
            error(configuration_error, 2)
        end
    elseif type(Bridge.Inventory[method_name]) ~= "function" then
        local contract_error = ("[sky_phone] Inventory adapter '%s' is missing required method '%s'.")
            :format(tostring(Bridge.Inventory.Name), method_name)
        Bridge.Inventory[method_name] = function()
            error(contract_error, 2)
        end
    end
end
