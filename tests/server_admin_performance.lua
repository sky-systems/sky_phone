-- Exercise real callbacks and query results rather than counting source strings.
local current_path = "sky_phone/source/server/admin.lua"
local baseline_path = arg and arg[1]

local function fixture(path, player_count)
    local state = { queries = {}, inventories = 0, authorized = true, allowed = true,
        sources = {}, identifiers = {}, inventory = {}, owners = {}, devices = {} }
    for source = 1, player_count do
        local imei = ("%015d"):format(source)
        state.sources[#state.sources + 1] = tostring(player_count - source + 1)
        state.identifiers[source] = "test-char-" .. source
        state.inventory[source] = { { metadata = { imei = imei } } }
        state.devices[imei] = { imei = imei, phone_number = "555" .. source, updated_at = source }
    end
    local callbacks = {}
    local env = setmetatable({
        Config = { Phone = { Item = "phone" }, AdminPanel = { Enabled = true,
            Command = "phonepanel", MaximumPlayers = 128, AuditLimit = 40,
            ReadRequestsPerMinute = 60 } },
        SkyPhone = { AllowOperation = function() return state.allowed end,
            GetDisabledApps = function() return {} end },
        SkyPhoneImei = { IsValid = function(value)
            return type(value) == "string" and #value == 15 and value:match("^%d+$") ~= nil
        end },
        RegisterCommand = function() end, AddEventHandler = function() end,
        GetPlayerName = function(source) return "Server " .. source end,
        json = { decode = function(value) assert(value == "{}") return {} end },
    }, { __index = _G })
    env.Bridge = {
        Debug = function() end,
        Framework = {
            HasPermission = function(_, permission) assert(permission == "phonepanel") return state.authorized end,
            GetPlayers = function()
                local sources = {}
                for index, source in ipairs(state.sources) do sources[index] = source end
                return sources
            end,
            GetIdentifier = function(source) return state.identifiers[source] end,
            GetFirstname = function(source) return "Character" .. source end,
            GetLastname = function() return "Test" end,
            GetJob = function(source)
                return { name = "test", label = source == 1 and "" or "Test Job", grade = source, onDuty = source % 2 == 0 }
            end,
        },
        Inventory = { GetSlotsWithItem = function(source, item)
            assert(item == "phone")
            state.inventories = state.inventories + 1
            return state.inventory[source] or {}
        end },
        Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Query = function(sql, params)
                state.queries[#state.queries + 1] = { sql = sql, params = params }
                if sql:find("COUNT(*) AS `devices`", 1, true) then
                    return { { devices = "9", linked_devices = "8", sim_devices = "7", active_devices = "6",
                        accounts = "5", messages_today = "4", calls_today = "3", audit_entries = "2", audit_today = "1" } }
                end
                if sql:find("FROM `sky_phone_admin_audit`", 1, true) then return {} end
                if sql:find("sky_phone_character_devices", 1, true) then
                    local selected, rows = {}, {}
                    for _, identifier in ipairs(params) do selected[identifier] = true end
                    for _, owner in ipairs(state.owners) do
                        if selected[owner.owner_identifier] then rows[#rows + 1] = owner end
                    end
                    return rows
                end
                if sql:find("FROM `sky_phone_devices` device", 1, true) then
                    local rows, seen = {}, {}
                    for _, imei in ipairs(params) do
                        local device = state.devices[imei]
                        if device and not seen[imei] then
                            local row = {}
                            for key, value in pairs(device) do row[key] = value end
                            rows[#rows + 1], seen[imei] = row, true
                        end
                    end
                    table.sort(rows, function(left, right)
                        if left.updated_at ~= right.updated_at then return left.updated_at > right.updated_at end
                        return left.imei < right.imei
                    end)
                    return rows
                end
                error("Unexpected admin SQL in performance fixture: " .. sql)
            end,
        },
    }
    assert(loadfile(path, "t", env))()
    return callbacks, state, env
end

local function bootstrap(path, count)
    local callbacks, state = fixture(path, count)
    local result = callbacks["sky_phone:admin:bootstrap"](1)
    assert(result.success and #result.data.players == count)
    return result.data, state
end

for _, count in ipairs({ 1, 128 }) do
    local data, state = bootstrap(current_path, count)
    assert(#state.queries == 4, "Bootstrap must keep its two list queries plus statistics and audit independent of player count")
    assert(state.inventories == count)
    assert(data.players[1].source == 1 and data.players[count].source == count, "Player sources must sort numerically")
    assert(data.players[1].job == "test" and data.players[1].deviceCount == 1)
    assert(data.players[count].phoneNumber == "555" .. count)
    assert(data.stats.online == count and data.stats.devices == 9 and data.stats.auditToday == 1)
    if baseline_path then
        local old_data, old_state = bootstrap(baseline_path, count)
        assert(#old_state.queries == count * 2 + 2, "Expected the verified pre-change per-player query pattern")
        for index, player in ipairs(data.players) do
            local old_player = old_data.players[index]
            for key, value in pairs(player) do assert(old_player[key] == value, "Sidebar output differs for " .. key) end
        end
        print(("Bootstrap %d players: baseline %d SQL queries; current %d"):format(count, #old_state.queries, #state.queries))
    end
end

local callbacks, state, env = fixture(current_path, 3)
local shared, persistent, sim, ghost = "000000000000010", "000000000000011", "000000000000012", "000000000000099"
state.inventory[1] = { { metadata = { imei = shared } }, { metadata = { imei = shared } },
    { metadata = { imei = ghost } }, { metadata = { imei = "invalid" } }, { metadata = {} } }
state.inventory[2] = { { metadata = { imei = shared } } }
state.inventory[3] = {}
state.owners = { { owner_identifier = "test-char-1", imei = shared },
    { owner_identifier = "test-char-1", imei = persistent }, { owner_identifier = "test-char-1", imei = sim },
    { owner_identifier = "test-char-1", imei = sim }, { owner_identifier = "test-char-2", imei = shared },
    { owner_identifier = "test-char-999", imei = "000000000000777" } }
state.devices = {
    [shared] = { imei = shared, phone_number = "555-shared", updated_at = 20 },
    [persistent] = { imei = persistent, phone_number = "555-mapping", updated_at = 30 },
    [sim] = { imei = sim, phone_number = "555-sim", updated_at = 10 },
}
local data = callbacks["sky_phone:admin:bootstrap"](1).data
assert(data.players[1].deviceCount == 3 and data.players[1].phoneNumber == "555-mapping",
    "Inventory, mapped and SIM ownership must merge, deduplicate and choose the latest real device")
assert(data.players[2].deviceCount == 1 and data.players[2].phoneNumber == "555-shared",
    "A shared device must remain associated with both owners")
assert(data.players[3].deviceCount == 0 and data.players[3].phoneNumber == nil)
local device_query = state.queries[2]
assert(#device_query.params == 4, "Shared/duplicate IMEIs must query once; a missing row must not count as a real device")
assert(not device_query.sql:find("security", 1, true) and not device_query.sql:find("payload", 1, true),
    "Sidebar summaries must not load security or application payloads")

-- The maximum applies to the numerically sorted source slice, as before.
env.Config.AdminPanel.MaximumPlayers = 2
state.identifiers[1] = nil
state.queries, state.inventories = {}, 0
data = callbacks["sky_phone:admin:bootstrap"](1).data
assert(#data.players == 1 and data.players[1].source == 2 and state.inventories == 1)
assert(data.stats.online == 1)

state.queries, state.inventories = {}, 0
data = callbacks["sky_phone:admin:statistics"](1).data
assert(#state.queries == 1 and state.inventories == 0, "Statistics must not rebuild sidebar inventories or device details")
assert(data.online == 1 and data.linkedDevices == 8 and data.messagesToday == 4)

for _, denied in ipairs({ "permission", "rate", "disabled" }) do
    state.queries, state.inventories, state.authorized, state.allowed = {}, 0, true, true
    env.Config.AdminPanel.Enabled = true
    if denied == "permission" then state.authorized = false
    elseif denied == "rate" then state.allowed = false
    else env.Config.AdminPanel.Enabled = false end
    assert(not callbacks["sky_phone:admin:bootstrap"](1).success)
    assert(not callbacks["sky_phone:admin:statistics"](1).success)
    assert(#state.queries == 0 and state.inventories == 0, "Denied callers must never cause database/inventory work")
end

print("Admin batched sidebar ownership, constant-query scaling, lightweight statistics and permission tests passed")
