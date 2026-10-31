-- Enabling Crypto must validate retained financial invariants against the
-- candidate app switch, before the Configurator persists that switch.
local queries, existing = {}, true
local retained = { { id = "BTC", asset_scale = 100, price_scale = 100, issued_supply = 10000 } }
local env = setmetatable({
    Config = { Apps = { crypto = false }, Crypto = {} },
    AddEventHandler = function() end,
    SkyPhoneAppDatabase = { Enabled = function() return false end },
    Bridge = {
        Callbacks = { Register = function() end },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Query = function(sql)
                queries[#queries + 1] = sql
                if sql:find("information_schema.tables", 1, true) then return existing and { { found = 1 } } or {} end
                assert(sql:find("SELECT `id`,`asset_scale`", 1, true)
                    or sql:find("SELECT `id`, `asset_scale`", 1, true), "Validation must remain read-only")
                return retained
            end,
        },
    },
}, { __index = _G })
assert(loadfile("sky_phone/source/server/crypto.lua", "t", env))()
assert(#queries == 0, "A disabled app must perform no Crypto startup SQL")
local candidate = { Apps = { crypto = true }, Crypto = {
    Markets = { { Id = "BTC", IssuedSupply = 100 } }, AssetScale = 1000, PriceScale = 100,
} }
local valid, reason = env.SkyPhoneCrypto.ValidateConfiguration(candidate)
assert(not valid and reason:find("requires a database migration", 1, true) and #queries == 2,
    "Turning Crypto on must not bypass persisted scale/supply validation")
queries = {}
candidate.Apps.crypto = false
assert(env.SkyPhoneCrypto.ValidateConfiguration(candidate) and #queries == 0,
    "A candidate that remains disabled must not read absent market tables")
candidate.Apps.crypto = true
candidate.Crypto.AssetScale = 100
assert(env.SkyPhoneCrypto.ValidateConfiguration(candidate))
queries, existing = {}, false
assert(env.SkyPhoneCrypto.ValidateConfiguration(candidate) and #queries == 1,
    "First enable on a fresh database may inspect metadata but cannot SELECT an absent market table")
print("app database: Crypto first-enable and retained scale/supply validation passed")
