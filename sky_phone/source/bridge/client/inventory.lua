local registrations = {}

local function inventory_labels()
    local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)
    local settings = locale.Nui.Apps.settings
    return {
        imei = settings.imei,
        phone_number = settings.simNumber,
        eject_sim = settings.ejectSim,
    }
end

local function eject_sim_from_slot(slot, inventory_id)
    local expected_imei
    if type(slot) == "table" then
        expected_imei = type(slot.metadata) == "table" and slot.metadata.imei or nil
        slot = slot.slot
    end
    local response = Bridge.Callbacks.Trigger("sky_phone:sim:eject-item", {
        slot = slot,
        inventory = inventory_id,
        imei = expected_imei,
    })
    if type(response) ~= "table" then
        response = { success = false, error = "request_failed" }
    end

    local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)
    local phone = locale.Nui.Apps.phone
    local message = response.success and phone.sim_removed
        or phone.errors[response.error] or locale.DeviceErrors[response.error] or phone.errors.default
    Bridge.Framework.Notify(locale.Nui.Apps.settings.ejectSim, message, response.success and "success" or "error", 5000)
    return response
end

local function run_ox_item_use(data, item_label)
    if type(data) ~= "table" then
        Bridge.Debug("warn", "[sky_phone] %s item export received invalid item data.", item_label)
        return false
    end

    local verified_item
    local completed, result = pcall(function()
        return exports.ox_inventory:useItem(data, function(used_item)
            verified_item = used_item
            return used_item ~= nil
        end)
    end)
    if not completed then
        Bridge.Debug(
            "error",
            "[sky_phone] %s item export could not complete ox_inventory useItem: %s.",
            item_label,
            tostring(result)
        )
        return false
    end

    return verified_item ~= nil or result == true
end

local function use_phone_item(data)
    return run_ox_item_use(data, "Phone")
end

local function use_sim_item(data)
    return run_ox_item_use(data, "SIM")
end

exports("GetInventoryLabels", inventory_labels)
exports("EjectSimFromSlot", eject_sim_from_slot)
exports("UsePhoneItem", use_phone_item)
exports("UseSimItem", use_sim_item)
AddEventHandler("sky_phone:sim:eject-item", eject_sim_from_slot)

local function register_metadata()
    local name, adapter = Bridge.Inventory.ResolveAdapter(Config.Bridge.Inventory, Bridge.Framework.GetName())
    if not adapter or GetResourceState(adapter.resource) ~= "started" then
        return
    end
    if name ~= "ox" and name ~= "tgiann" and name ~= "one" then
        return
    end

    local registered = registrations[adapter.resource] or {}
    registrations[adapter.resource] = registered
    local labels = inventory_labels()
    local items = name == "ox" and { "*" }
        or { Config.Phone.Item, Config.Sim.RegisteredItem, Config.Sim.AnonymousItem }

    for _, item_name in ipairs(items) do
        for _, key in ipairs({ "imei", "phone_number" }) do
            local registration_key = item_name .. ":" .. key
            if not registered[registration_key] then
                -- Exports may wait for the inventory UI; reserve the key before yielding.
                registered[registration_key] = true
                local success, result = pcall(function()
                    if name == "ox" then
                        return exports.ox_inventory:displayMetadata(key, labels[key])
                    elseif name == "tgiann" then
                        return exports["tgiann-inventory"]:DisplayItemMetadata(item_name, key, labels[key])
                    else
                        return exports.one_inventory:ShowItemMetadata(key, labels[key], item_name)
                    end
                end)
                if not success or result == false then
                    registered[registration_key] = nil
                    Bridge.Debug("warn", "[sky_phone] Inventory '%s' could not register tooltip field '%s': %s. Check the inventory version and README integration instructions.",
                        adapter.resource, key, tostring(result))
                    return
                end
            end
        end
    end
end

AddEventHandler("onClientResourceStart", function(resource_name)
    local _, adapter = Bridge.Inventory.ResolveAdapter(Config.Bridge.Inventory, Bridge.Framework.GetName())
    if adapter and resource_name == adapter.resource then
        register_metadata()
    end
end)

AddEventHandler("onClientResourceStop", function(resource_name)
    registrations[resource_name] = nil
end)

-- Some providers append labels instead of updating them. Keep registrations
-- stable across config syncs; new item names still get their own tooltip rows.
AddEventHandler("sky_phone:configurator:updated", register_metadata)
CreateThread(register_metadata)
