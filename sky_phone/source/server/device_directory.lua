Bridge.Database.AfterMigration("sky_phone", function()
    if type(SkyPhone) ~= "table"
        or type(SkyPhone.GetEquippedPhoneNumber) ~= "function"
        or type(SkyPhone.GetSourceFromNumber) ~= "function"
        or type(SkyPhone.FindDeviceSlots) ~= "function"
    then
        error("[sky_phone] Device directory initialized before the phone core.")
    end

    SkyPhoneDeviceDirectory = {}

    local unique_phones = Config.Phone.Unique ~= false

    local function normalize_source(source)
        if type(source) ~= "number"
            or source ~= source
            or source <= 0
            or source >= math.huge
            or source ~= math.floor(source)
        then
            return nil
        end
        return source
    end

    local function normalize_identifier(identifier)
        if type(identifier) ~= "string" then
            return nil
        end
        identifier = identifier:match("^%s*(.-)%s*$")
        if identifier == "" or #identifier > 80 then
            return nil
        end
        return identifier
    end

    local function normalize_imei(imei)
        return SkyPhoneImei.IsValid(imei) and imei or nil
    end

    local function normalize_phone_number(phone_number)
        return SkyPhoneSimNumber.Normalize(
            phone_number,
            Config.Sim.NumberLength,
            Config.Sim.NumberPrefix
        )
    end

    local function build_device_identity(row)
        if not row then
            return nil
        end
        return {
            accountId = tonumber(row.account_id),
            deviceName = row.device_name,
            equipped = false,
            imei = row.imei,
            mappedIdentifier = row.mapped_identifier,
            online = false,
            phoneNumber = row.phone_number,
            registeredIdentifier = row.sim_owner_identifier,
            simId = row.sim_id,
            simType = row.sim_type,
            source = nil,
        }
    end

    local function load_stored_device(where_clause, parameter)
        local rows = Bridge.Database.Query(([[
            SELECT d.`imei`, d.`device_name`, d.`account_id`, d.`sim_id`,
                s.`phone_number`, s.`sim_type`, s.`owner_identifier` AS `sim_owner_identifier`,
                c.`owner_identifier` AS `mapped_identifier`
            FROM `sky_phone_devices` d
            LEFT JOIN `sky_phone_sims` s ON s.`id` = d.`sim_id`
            LEFT JOIN `sky_phone_character_devices` c ON c.`device_imei` = d.`imei`
            WHERE %s
            LIMIT 1
        ]]):format(where_clause), { parameter })
        return build_device_identity(rows[1])
    end

    local function mark_equipped(identity, source, identifier)
        identity.equipped = true
        identity.identifier = identifier
        identity.online = true
        identity.source = source
        return identity
    end

    local function get_inventory_device_imeis(source)
        local seen = {}
        local imeis = {}
        local slots = Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)
        for index = 1, #slots do
            local slot = slots[index]
            local amount = tonumber(slot.amount or slot.count) or 0
            local imei = amount == 1 and slot.metadata and normalize_imei(slot.metadata.imei) or nil
            if imei and not seen[imei] then
                seen[imei] = true
                imeis[#imeis + 1] = imei
            end
        end
        table.sort(imeis)
        return imeis
    end

    function SkyPhoneDeviceDirectory.GetStoredDeviceByImei(imei)
        imei = normalize_imei(imei)
        if not imei then
            return nil, "invalid_imei"
        end

        local identity = load_stored_device("d.`imei` = ?", imei)
        if not identity then
            return nil, "device_not_found"
        end
        return identity
    end

    function SkyPhoneDeviceDirectory.GetStoredDeviceByPhoneNumber(phone_number)
        phone_number = normalize_phone_number(phone_number)
        if not phone_number then
            return nil, "invalid_phone_number"
        end

        local identity = load_stored_device("s.`phone_number` = ?", phone_number)
        if not identity then
            return nil, "device_not_found"
        end
        return identity
    end

    function SkyPhoneDeviceDirectory.GetStoredDeviceByIdentifier(identifier)
        identifier = normalize_identifier(identifier)
        if not identifier then
            return nil, "invalid_identifier"
        end
        if unique_phones then
            return nil, "identity_scope_unsupported"
        end

        local identity = load_stored_device("c.`owner_identifier` = ?", identifier)
        if not identity then
            return nil, "device_not_found"
        end
        identity.identifier = identifier
        return identity
    end

    function SkyPhoneDeviceDirectory.GetStoredSimByPhoneNumber(phone_number)
        phone_number = normalize_phone_number(phone_number)
        if not phone_number then
            return nil, "invalid_phone_number"
        end

        local rows = Bridge.Database.Query([[
            SELECT s.`id`, s.`phone_number`, s.`sim_type`, s.`owner_identifier`, d.`imei`
            FROM `sky_phone_sims` s
            LEFT JOIN `sky_phone_devices` d ON d.`sim_id` = s.`id`
            WHERE s.`phone_number` = ?
            LIMIT 1
        ]], { phone_number })
        local row = rows[1]
        if not row then
            return nil, "sim_not_found"
        end
        return {
            deviceImei = row.imei,
            phoneNumber = row.phone_number,
            registeredIdentifier = row.owner_identifier,
            simId = row.id,
            simType = row.sim_type,
        }
    end

    function SkyPhoneDeviceDirectory.GetOnlineBySource(source)
        source = normalize_source(source)
        if not source then
            return nil, "invalid_source"
        end

        local identifier = normalize_identifier(Bridge.Framework.GetIdentifier(source))
        if not identifier then
            return nil, "player_unavailable"
        end

        local phone_number = SkyPhone.GetEquippedPhoneNumber(source)
        if phone_number then
            local identity = SkyPhoneDeviceDirectory.GetStoredDeviceByPhoneNumber(phone_number)
            if not identity then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Equipped phone number %s for source %s has no attached device.",
                    tostring(phone_number),
                    tostring(source)
                )
                return nil, "identity_inconsistent"
            end
            if not SkyPhone.FindDeviceSlots(source, identity.imei)[1] then
                return nil, "device_not_equipped"
            end
            return mark_equipped(identity, source, identifier)
        end

        local identity
        if unique_phones then
            local imeis = get_inventory_device_imeis(source)
            if #imeis == 0 then
                return nil, "device_not_equipped"
            end
            if #imeis > 1 then
                return nil, "equipped_device_ambiguous"
            end
            identity = SkyPhoneDeviceDirectory.GetStoredDeviceByImei(imeis[1])
        else
            identity = SkyPhoneDeviceDirectory.GetStoredDeviceByIdentifier(identifier)
        end
        if not identity then
            return nil, "device_not_found"
        end
        if not SkyPhone.FindDeviceSlots(source, identity.imei)[1] then
            return nil, "device_not_equipped"
        end
        return mark_equipped(identity, source, identifier)
    end

    function SkyPhoneDeviceDirectory.GetOnlineByPhoneNumber(phone_number)
        phone_number = normalize_phone_number(phone_number)
        if not phone_number then
            return nil, "invalid_phone_number"
        end

        local source = SkyPhone.GetSourceFromNumber(phone_number)
        if not source then
            return nil, "player_unavailable"
        end
        local identity, identity_error = SkyPhoneDeviceDirectory.GetOnlineBySource(source)
        if not identity then
            return nil, identity_error
        end
        if identity.phoneNumber ~= phone_number then
            return nil, "identity_inconsistent"
        end
        return identity
    end

    function SkyPhoneDeviceDirectory.GetOnlineByIdentifier(identifier)
        identifier = normalize_identifier(identifier)
        if not identifier then
            return nil, "invalid_identifier"
        end

        local matched_source
        for _, player in ipairs(Bridge.Framework.GetPlayers()) do
            local source = tonumber(player)
            local current_identifier = source and normalize_identifier(Bridge.Framework.GetIdentifier(source)) or nil
            if current_identifier == identifier then
                if matched_source then
                    Bridge.Debug(
                        "error",
                        "[sky_phone] Multiple online sources expose identifier %s.",
                        identifier
                    )
                    return nil, "identifier_ambiguous"
                end
                matched_source = source
            end
        end
        if not matched_source then
            return nil, "player_unavailable"
        end
        return SkyPhoneDeviceDirectory.GetOnlineBySource(matched_source)
    end

    function SkyPhoneDeviceDirectory.GetOnlineByImei(imei)
        imei = normalize_imei(imei)
        if not imei then
            return nil, "invalid_imei"
        end

        local stored, stored_error = SkyPhoneDeviceDirectory.GetStoredDeviceByImei(imei)
        if not stored then
            return nil, stored_error
        end
        if stored.phoneNumber then
            local source = SkyPhone.GetSourceFromNumber(stored.phoneNumber)
            if source then
                local identity, identity_error = SkyPhoneDeviceDirectory.GetOnlineBySource(source)
                if not identity then
                    return nil, identity_error
                end
                if identity.imei ~= imei then
                    return nil, "identity_inconsistent"
                end
                return identity
            end
        end

        local matched_identity
        for _, player in ipairs(Bridge.Framework.GetPlayers()) do
            local source = tonumber(player)
            if source then
                local identity = SkyPhoneDeviceDirectory.GetOnlineBySource(source)
                if identity and identity.imei == imei then
                    if matched_identity then
                        Bridge.Debug(
                            "error",
                            "[sky_phone] Device IMEI %s is equipped by multiple online sources.",
                            imei
                        )
                        return nil, "device_holder_ambiguous"
                    end
                    matched_identity = identity
                end
            end
        end
        if not matched_identity then
            return nil, "player_unavailable"
        end
        return matched_identity
    end
end)
