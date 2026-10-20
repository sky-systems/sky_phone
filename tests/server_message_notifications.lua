local callbacks = {}
local events = {}
local sender_device = { imei = "sender", sim_id = 1, phone_number = "5550001" }
local recipients = {
    { imei = "local-phone", device_name = "Local", sender_name = "Local Contact" },
    { imei = "cloud-phone", device_name = "Cloud", sender_name = "Cloud Contact" },
    { imei = "unknown-phone", device_name = "Unknown" },
}

Config = {
    Sim = { NumberLength = 7, NumberPrefix = "" },
    Messages = { SendsPerMinute = 20, BodyMaxLength = 1000 },
}
SkyPhone = {
    AllowOperation = function() return true end,
    RequireSession = function() return { imei = sender_device.imei } end,
    LoadDevice = function() return sender_device end,
    FindDeviceSlots = function(source)
        return source == 2 and { 1 } or {}
    end,
}
SkyPhoneCellular = { HasSignal = function() return true end }
SkyPhoneCompanies = { GetServiceLine = function() return nil end }
Bridge = {
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Framework = { GetPlayers = function() return { "2", "3" } end },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Query = function(query, params)
            if query:find("FROM `sky_phone_sims`", 1, true) then
                return { { id = 2, phone_number = "5550002" } }
            elseif query:find("FROM `sky_phone_call_blocks`", 1, true) then
                return {}
            elseif query:find("SELECT UUID()", 1, true) then
                return { { id = "message-id" } }
            elseif query:find("INSERT INTO `sky_phone_sms_messages`", 1, true) then
                return {}
            elseif query:find("FROM `sky_phone_sms_messages`", 1, true) then
                return { { id = "message-id", message_type = "text", sender_number = "5550001" } }
            elseif query:find("FROM `sky_phone_devices` d", 1, true) then
                assert(params[1] == "5550001" and params[2] == 2,
                    "notification lookup must bind the sender number and recipient SIM")
                assert(query:find("contact.`account_id` = d.`account_id`", 1, true),
                    "cloud contacts must belong to the receiving account")
                assert(query:find("d.`account_id` IS NULL AND contact.`account_id` IS NULL", 1, true),
                    "local contacts must only be used without a cloud account")
                assert(query:find("contact.`device_imei` = d.`imei`", 1, true),
                    "local contacts must belong to the receiving device")
                return recipients
            end
            error("Unexpected SMS query: " .. query)
        end,
    },
}
function TriggerClientEvent(name, target, payload)
    events[#events + 1] = { name = name, target = target, payload = payload }
end

assert(loadfile("sky_phone/source/shared/sim_number.lua"))()
assert(loadfile("sky_phone/source/server/messages.lua"))()
local send = assert(callbacks["sky_phone:messages:send"])

local function check_delivery(expected_names)
    events = {}
    local result = send(1, { phoneNumber = "5550002", messageType = "text", body = "Hello" })
    assert(result.success, result.error)
    assert(#events == 4, "each owned receiving phone must receive exactly one notification")
    for index, expected in ipairs(expected_names) do
        local event = events[index + 1]
        assert(event.name == "sky_phone:messages:new" and event.target == 2)
        assert(event.payload.sender == expected, "notification used the wrong contact name")
        assert(event.payload.phoneNumber == sender_device.phone_number, "sender number must stay unchanged")
        assert(event.payload.device.imei == recipients[index].imei, "notification used the wrong device")
        assert(event.payload.message.sender_number == sender_device.phone_number)
    end
end

check_delivery({ "Local Contact", "Cloud Contact", "5550001" })
recipients[1].sender_name = "Renamed 100% Contact"
recipients[2].sender_name = nil
check_delivery({ "Renamed 100% Contact", "5550001", "5550001" })

print("SMS contact notification tests passed")
