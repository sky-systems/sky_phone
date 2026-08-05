if not Sky.DB.AwaitMigrations("sky_phone") then
    error("[sky_phone] SIM database migrations did not complete.")
end

SkyPhoneSim = {}

local pending_insertions = {}
local operation_locks = {}
local sim_types = {
    [Config.Sim.RegisteredItem] = "registered",
    [Config.Sim.AnonymousItem] = "anonymous",
}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function uuid()
    local rows = Sky.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a SIM UUID.")
    end
    return rows[1].id
end

local function reserve_sim(sim_type)
    local sim_id
    local number = SkyPhoneSimNumber.Reserve(uuid, function(candidate)
        sim_id = uuid()
        local result = Sky.Query([[
            INSERT IGNORE INTO `sky_phone_sims` (`id`, `phone_number`, `sim_type`)
            VALUES (?, ?, ?)
        ]], { sim_id, candidate, sim_type })
        return affected_rows(result) == 1
    end, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        error("[sky_phone] Could not reserve a unique SIM number after 20 attempts.")
    end
    return { id = sim_id, phone_number = number, sim_type = sim_type }
end

local function load_sim(sim_id)
    local rows = Sky.Query("SELECT * FROM `sky_phone_sims` WHERE `id` = ? LIMIT 1", { sim_id })
    return rows[1]
end

local function sim_metadata(sim)
    local metadata = {
        sim_id = sim.id,
        phone_number = sim.phone_number,
        formatted_number = SkyPhoneSimNumber.Format(sim.phone_number, Config.Sim.NumberGroups, Config.Sim.NumberLength, Config.Sim.NumberPrefix),
        sim_type = sim.sim_type,
    }
    if sim.sim_type == "registered" and sim.owner_identifier then
        metadata.firstname = sim.owner_firstname
        metadata.lastname = sim.owner_lastname
        metadata.birthdate = sim.owner_birthdate
    end
    return metadata
end

local function resolve_used_sim(source, used_item, item_name)
    local slot_id = tonumber(used_item and (used_item.slot or used_item.id))
    local slot = slot_id and Sky.FW.GetInventorySlot(source, slot_id) or nil
    if slot and slot.name == item_name then
        return slot
    end
    local slots = Sky.FW.GetInventorySlotsWithItem(source, item_name)
    if #slots == 1 then
        return slots[1]
    end
    Sky.Debug("warn", "[sky_phone] Could not resolve exact SIM slot for source %s.", tostring(source))
    return nil
end

local function ensure_sim(source, slot, sim_type)
    if (tonumber(slot.amount or slot.count) or 0) ~= 1 then
        return nil, "sim_stacked"
    end
    local metadata = slot.metadata or {}
    local sim = metadata.sim_id and load_sim(metadata.sim_id) or nil
    if metadata.sim_id and (not sim or sim.sim_type ~= sim_type or sim.phone_number ~= metadata.phone_number) then
        return nil, "invalid_sim"
    end
    if not sim then
        sim = reserve_sim(sim_type)
        if not Sky.FW.SetInventorySlotMetadata(source, slot.slot, sim_metadata(sim)) then
            Sky.Query("DELETE FROM `sky_phone_sims` WHERE `id` = ?", { sim.id })
            return nil, "metadata_unsupported"
        end
    end
    return sim
end

local function list_phone_choices(source)
    local choices = {}
    for _, slot in ipairs(Sky.FW.GetInventorySlotsWithItem(source, Config.Phone.Item)) do
        local imei = SkyPhone.EnsureDevice(source, slot)
        if imei then
            local device = SkyPhone.LoadDevice(imei)
            choices[#choices + 1] = {
                imei = imei,
                name = device.device_name,
                occupied = device.sim_id ~= nil,
                number = device.phone_number,
            }
        end
    end
    return choices
end

local function rollback_phone_metadata(source, phone_slot, old_sim)
    local metadata = phone_slot.metadata or {}
    metadata.sim_id = old_sim and old_sim.id or nil
    metadata.phone_number = old_sim and old_sim.phone_number or nil
    metadata.formatted_number = old_sim and SkyPhoneSimNumber.Format(old_sim.phone_number, Config.Sim.NumberGroups, Config.Sim.NumberLength, Config.Sim.NumberPrefix) or nil
    Sky.FW.SetInventorySlotMetadata(source, phone_slot.slot, metadata)
end

local function insert_sim(source, phone_imei, confirmed)
    if operation_locks[source] then
        return { success = false, error = "operation_in_progress" }
    end
    local pending = pending_insertions[source]
    if not pending or GetGameTimer() - pending.created_at > 60000 then
        pending_insertions[source] = nil
        return { success = false, error = "sim_request_expired" }
    end
    local sim_slot = Sky.FW.GetInventorySlot(source, pending.slot)
    if not sim_slot or sim_slot.name ~= pending.item_name or not sim_slot.metadata
        or sim_slot.metadata.sim_id ~= pending.sim.id then
        return { success = false, error = "sim_not_owned" }
    end
    local phone_matches = SkyPhone.FindDeviceSlots(source, phone_imei)
    if not phone_matches[1] then
        return { success = false, error = "phone_not_owned" }
    end
    local phone_slot = phone_matches[1]
    local device = SkyPhone.LoadDevice(phone_imei)
    local old_sim = device.sim_id and load_sim(device.sim_id) or nil
    if old_sim and not confirmed then
        return { success = false, error = "confirmation_required", data = { requiresConfirmation = true } }
    end

    operation_locks[source] = true
    local phone_metadata = phone_slot.metadata or {}
    phone_metadata.sim_id = pending.sim.id
    phone_metadata.phone_number = pending.sim.phone_number
    phone_metadata.formatted_number = SkyPhoneSimNumber.Format(pending.sim.phone_number, Config.Sim.NumberGroups, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not Sky.FW.SetInventorySlotMetadata(source, phone_slot.slot, phone_metadata) then
        operation_locks[source] = nil
        return { success = false, error = "metadata_unsupported" }
    end
    if Sky.FW.RemoveItem(source, pending.item_name, 1, pending.slot) ~= 1 then
        rollback_phone_metadata(source, phone_slot, old_sim)
        operation_locks[source] = nil
        return { success = false, error = "sim_not_owned" }
    end
    local old_item_name = old_sim and (old_sim.sim_type == "registered" and Config.Sim.RegisteredItem or Config.Sim.AnonymousItem) or nil
    if old_sim and not Sky.FW.AddItem(source, old_item_name, 1, pending.slot, sim_metadata(old_sim)) then
        Sky.FW.AddItem(source, pending.item_name, 1, pending.slot, sim_metadata(pending.sim))
        rollback_phone_metadata(source, phone_slot, old_sim)
        operation_locks[source] = nil
        return { success = false, error = "inventory_full" }
    end

    local transaction = {
        {
            query = "UPDATE `sky_phone_devices` SET `sim_id` = ? WHERE `imei` = ?",
            params = { pending.sim.id, phone_imei },
        },
    }
    if pending.sim.sim_type == "registered" and not pending.sim.owner_identifier then
        transaction[#transaction + 1] = {
            query = [[
                UPDATE `sky_phone_sims`
                SET `owner_identifier` = ?, `owner_firstname` = ?, `owner_lastname` = ?,
                    `owner_birthdate` = ?, `registered_at` = CURRENT_TIMESTAMP
                WHERE `id` = ? AND `owner_identifier` IS NULL
            ]],
            params = {
                Sky_Jobs.PlayerCache.GetIdentifier(source),
                Sky.FW.GetFirstname(source),
                Sky.FW.GetLastname(source),
                Sky.FW.GetBirthdate(source),
                pending.sim.id,
            },
        }
    end
    if not Sky.DB.Transaction(transaction) then
        if old_sim then
            Sky.FW.RemoveItem(source, old_sim.sim_type == "registered" and Config.Sim.RegisteredItem or Config.Sim.AnonymousItem, 1, pending.slot)
        end
        Sky.FW.AddItem(source, pending.item_name, 1, pending.slot, sim_metadata(pending.sim))
        rollback_phone_metadata(source, phone_slot, old_sim)
        operation_locks[source] = nil
        return { success = false, error = "request_failed" }
    end

    pending_insertions[source] = nil
    operation_locks[source] = nil
    if old_sim then
        SkyPhoneCalls.EndForSim(old_sim.id, "sim_removed")
    end
    SkyPhone.RefreshDevice(phone_imei)
    TriggerClientEvent("sky_phone:sim:picker-close", source)
    return { success = true }
end

local function use_sim(source, used_item)
    local item_name = used_item and used_item.name
    local sim_type = item_name and sim_types[item_name]
    if not sim_type then
        Sky.Debug("warn", "[sky_phone] Usable SIM callback received an invalid item for source %s.", tostring(source))
        return false
    end
    if operation_locks[source] then
        TriggerClientEvent("sky_phone:device:error", source, "operation_in_progress")
        return false
    end
    operation_locks[source] = true
    local slot = resolve_used_sim(source, used_item, item_name)
    if not slot then
        operation_locks[source] = nil
        TriggerClientEvent("sky_phone:device:error", source, "sim_slot_missing")
        return false
    end
    local sim, error_code = ensure_sim(source, slot, sim_type)
    if not sim then
        operation_locks[source] = nil
        TriggerClientEvent("sky_phone:device:error", source, error_code)
        return false
    end
    local choices = list_phone_choices(source)
    if #choices == 0 then
        operation_locks[source] = nil
        TriggerClientEvent("sky_phone:device:error", source, "phone_required")
        return false
    end
    pending_insertions[source] = {
        created_at = GetGameTimer(),
        item_name = item_name,
        sim = sim,
        slot = slot.slot,
    }
    operation_locks[source] = nil
    if #choices == 1 and not choices[1].occupied then
        return insert_sim(source, choices[1].imei, false).success
    end
    TriggerClientEvent("sky_phone:sim:picker", source, {
        choices = choices,
        number = sim.phone_number,
    })
    return true
end

Sky.FW.RegisterUsableItem(Config.Sim.RegisteredItem, use_sim, true)
Sky.FW.RegisterUsableItem(Config.Sim.AnonymousItem, use_sim, true)

Sky.Cb.Register("sky_phone:sim:insert", function(source, data)
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end
    return insert_sim(source, data.imei, data.confirmed == true)
end)

Sky.Cb.Register("sky_phone:sim:eject", function(source)
    if operation_locks[source] then
        return { success = false, error = "operation_in_progress" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    local sim = device and device.sim_id and load_sim(device.sim_id) or nil
    if not sim then
        return { success = false, error = "no_sim" }
    end
    local phone_slot = Sky.FW.GetInventorySlot(source, session.slot)
    local item_name = sim.sim_type == "registered" and Config.Sim.RegisteredItem or Config.Sim.AnonymousItem
    local metadata = sim_metadata(sim)
    if not Sky.FW.CanCarryItem(source, item_name, 1, metadata) then
        return { success = false, error = "inventory_full" }
    end

    operation_locks[source] = true
    rollback_phone_metadata(source, phone_slot, nil)
    if not Sky.FW.AddItem(source, item_name, 1, nil, metadata) then
        rollback_phone_metadata(source, phone_slot, sim)
        operation_locks[source] = nil
        return { success = false, error = "inventory_full" }
    end
    if affected_rows(Sky.Query("UPDATE `sky_phone_devices` SET `sim_id` = NULL WHERE `imei` = ? AND `sim_id` = ?", {
        session.imei,
        sim.id,
    })) ~= 1 then
        Sky.FW.RemoveItem(source, item_name, 1, nil, metadata)
        rollback_phone_metadata(source, phone_slot, sim)
        operation_locks[source] = nil
        return { success = false, error = "request_failed" }
    end
    operation_locks[source] = nil
    SkyPhoneCalls.EndForSim(sim.id, "sim_removed")
    SkyPhone.RefreshDevice(session.imei)
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    pending_insertions[source] = nil
    operation_locks[source] = nil
end)
