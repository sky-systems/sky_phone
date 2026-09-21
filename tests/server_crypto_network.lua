local callbacks, events, threads, sent, rows = {}, {}, {}, {}, {}
local viewers, balances_read, query_hook = {}, 0, nil
local env = setmetatable({ Config = {} }, { __index = _G })
env.IsDuplicityVersion = function() return true end
env.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
env.GetCurrentResourceName = function() return "sky_phone" end
env.AddEventHandler = function(name, callback) events[name] = callback end
env.CreateThread = function(callback) threads[#threads + 1] = coroutine.create(callback) end
env.Wait = function(ms) return coroutine.yield(ms) end
env.exports = { sky_phone = { CryptoRandomInt = function(_, minimum) return minimum end } }
env.SkyPhone = {
    AllowOperation = function() return true end,
    RequireSession = function(player)
        return viewers[player], { success = false, error = "device_not_open" }
    end,
}
env.Bridge = {
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Framework = { GetIdentifier = function(player) return "test-player-" .. player end },
    Network = { SendClient = function(name, target, payload)
        assert(name == "sky_phone:crypto:changed" and target ~= -1, "never broadcast prices to all players")
        sent[#sent + 1] = { target = target, payload = payload }
        return true
    end },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Transaction = function() return true end,
        Query = function(sql, params)
            if query_hook then local callback = query_hook; query_hook = nil; callback() end
            if sql:find("INSERT INTO `sky_phone_crypto_markets`", 1, true) then
                rows[params[1]] = { id = params[1], asset_scale = params[2], price_scale = params[3],
                    issued_supply = params[4], price = params[5], version = 1, status = "active", updated_at = os.time() }
                return {}
            end
            if sql:find("SELECT `asset_scale`", 1, true) then return { rows[params[1]] } end
            if sql:find("SELECT `id`,`price`,`version`", 1, true) then
                local result = {}
                for _, row in pairs(rows) do result[#result + 1] = row end
                return result
            end
            if sql:find("SELECT `price`", 1, true) then
                local history = {}
                for index = 1, 48 do history[index] = { price = rows[params[1]].price + index } end
                return history
            end
            if sql:find("SELECT `available`,`locked`,`version`", 1, true) then
                balances_read = balances_read + 1
                return { { available = 100000000, locked = 0, version = 1 } }
            end
            return {}
        end,
    },
}
assert(loadfile("sky_phone/config/config.lua", "t", env))()
assert(loadfile("sky_phone/source/server/crypto.lua", "t", env))()
assert(#threads == 3)
local ticker = threads[3]
local function tick()
    local success, delay = coroutine.resume(ticker)
    assert(success, delay)
    assert(delay >= 7000 and delay <= 12000, "price scheduler must keep its existing interval")
end
tick() -- first scheduled wait
tick()
assert(#sent == 0 and balances_read == 0, "closed apps must cause no market DTO queries or traffic")
local watch = callbacks["sky_phone:crypto:watch"]
assert(not watch(7, { active = true }).success, "watch requires an owned unlocked phone")
assert(not watch(7, { active = "true" }).success)
for player = 1, 60 do viewers[player] = { token = "session-" .. player, imei = "phone-" .. player } end
assert(watch(7, { active = true }).success)
assert(watch(42, { active = true }).success)
local bootstrap = callbacks["sky_phone:crypto:bootstrap"](7)
assert(bootstrap.success and bootstrap.data.markets[1].symbol)
tick()
assert(#sent == 2, "60 connected players with two viewers must receive exactly two updates")
local payload = sent[1].payload
assert(payload == sent[2].payload, "build the market DTO once per tick, not once per recipient")
assert(#payload.markets == env.Config.Crypto.MarketsPerTickMinimum)
for _, market in ipairs(payload.markets) do
    assert(market.version > 1 and market.price and #market.priceHistory == 48)
    assert(market.symbol == nil and market.logo == nil and market.sparkline == nil,
        "ticks must omit static metadata and duplicate normalized chart data")
end
watch(7, { active = false })
viewers[42] = nil
local count, reads = #sent, balances_read
tick()
assert(#sent == count and balances_read == reads, "unsubscribe and lost phones must stop all updates")
assert(watch(9, { active = true }).success)
env.source = 9
events.playerDropped()
tick()
assert(#sent == count, "dropped source IDs must not retain a subscription")
-- Unsubscribing while a snapshot query yields must not register the viewer again.
query_hook = function() watch(11, { active = false }) end
assert(watch(11, { active = true }).success)
tick()
assert(#sent == count, "a late watch response must not undo unsubscribe")
print("Crypto subscription, payload and 60-player fan-out tests passed")
