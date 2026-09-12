local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function new_server(options)
    options = options or {}
    local test = { callbacks = {}, events = {}, queries = {}, logs = {}, charged = 0, refunded = 0 }
    local framework = options.framework or "esx"
    local owner_column = framework == "esx" and "owner" or "citizenid"
    local parked_column = framework == "esx" and "stored" or "state"
    local table_name = framework == "esx" and "owned_vehicles" or "player_vehicles"
    test.rows = options.rows or { {
        owner = "owner-1", citizenid = "owner-1", plate = " MSK123 ",
        stored = 1, state = 1, garage = "A", name = "My Sultan", type = "car", fuel = 45,
        vehicle = framework == "esx" and "{properties}" or "sultan", mods = "{properties}",
    } }
    local resources = options.resources or { msk_garage = "started" }
    local env = setmetatable({
        Config = { Garage = {
            System = options.system or "msk", MaximumVehicles = 250, RequestsPerMinute = 30,
            VehicleImages = { Enabled = false },
            Valet = {
                Enabled = true, Price = 750, Account = "bank", RequestsPerMinute = 3,
                CooldownSeconds = 60, TimeoutSeconds = 180, DriverModel = "s_m_m_autoshop_01",
                VehicleTypes = { car = true, bike = true },
            },
        } },
        GetResourceState = function(name) return resources[name] or "missing" end,
        GetCurrentResourceName = function() return "sky_phone" end,
        TriggerClientEvent = function() end,
        CreateThread = function(callback) test.timeout_thread = coroutine.create(callback) end,
        Wait = coroutine.yield,
        NetworkGetEntityFromNetworkId = function(id) return id == 10 and 100 or 0 end,
        DoesEntityExist = function(entity) return entity == 100 and 1 or nil end,
        NetworkGetEntityOwner = function() return 1 end,
        os = { time = function() return test.now or 1000 end },
        json = { decode = function(value)
            assert(value == "{properties}", "malformed JSON")
            return { model = 970598228, plate = "MSK123", fuelLevel = 99, engineHealth = 850,
                bodyHealth = 730, modEngine = 3 }
        end },
        SkyPhone = {
            AllowOperation = function() return not options.rate_limited end,
            RequireSession = function()
                if options.no_session then return nil, { success = false, error = "no_session" } end
                return {}
            end,
        },
    }, { __index = _G })
    env.AddEventHandler = function(name, callback) test.events[name] = callback end
    env.Bridge = {
        Debug = function(_, message) test.logs[#test.logs + 1] = message end,
        Framework = {
            GetName = function() return framework end,
            GetIdentifier = function(source) return "owner-" .. source end,
            GetMoney = function() return options.balance or 1000 end,
            RemoveMoney = function(_, account, amount)
                assert(account == "bank")
                if options.payment_failure then return false end
                test.charged = test.charged + amount
                return true
            end,
            AddMoney = function(_, account, amount)
                assert(account == "bank")
                test.refunded = test.refunded + amount
                return true
            end,
        },
        Callbacks = { Register = function(name, callback) test.callbacks[name] = callback end },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Query = function(sql, params)
                test.queries[#test.queries + 1] = { sql = sql, params = copy(params) }
                assert(sql:find(table_name, 1, true), "wrong framework table")
                assert(sql:find(owner_column, 1, true), "missing owner scope")
                if sql:find("SELECT", 1, true) == 1 then
                    local result = {}
                    for _, row in ipairs(test.rows) do
                        local plate = row.plate:match("^%s*(.-)%s*$")
                        if row[owner_column] == params[1]
                            and (not sql:find("TRIM(plate)", 1, true) or plate == params[2])
                        then
                            result[#result + 1] = copy(row)
                        end
                    end
                    return result
                end
                local changed = 0
                assert(sql:find("UPDATE", 1, true) == 1)
                assert(sql:find("SET `" .. parked_column .. "` = ?", 1, true),
                    "MSK must write only its framework parked flag")
                for _, row in ipairs(test.rows) do
                    if options.reservation_race then row[parked_column] = 0 end
                    local stored = row[parked_column]
                    if stored == true then stored = 1 elseif stored == false then stored = 0 end
                    local expected = params[4]
                    if expected == true then expected = 1 elseif expected == false then expected = 0 end
                    if row[owner_column] == params[2]
                        and row.plate:match("^%s*(.-)%s*$") == params[3]
                        and tonumber(stored) == tonumber(expected)
                    then
                        row[parked_column] = params[1]
                        changed = changed + 1
                    end
                end
                return { affectedRows = changed }
            end,
        },
    }
    assert(loadfile("sky_phone/source/server/garage.lua", "t", env))()
    function test.call(action, data, source)
        return test.callbacks["sky_phone:garage:" .. action](source or 1, data)
    end
    function test.overview() return test.call("vehicles").data.vehicles end
    function test.request(plate) return test.call("valet-request", { plate = plate or "MSK123", price = 0 }) end
    function test.cancel(order) return test.call("valet-cancel", { orderId = order.data.orderId }) end
    function test.stop() test.events.onResourceStop("sky_phone") end
    function test.disconnect()
        env.source = 1
        test.events.playerDropped()
    end
    function test.timeout()
        assert(coroutine.resume(test.timeout_thread))
        test.now = 1181
        assert(coroutine.resume(test.timeout_thread))
    end
    return test
end

local scenarios = 0
local function scenario(name, callback)
    callback()
    scenarios = scenarios + 1
    print("PASS " .. name)
end

for _, framework in ipairs({ "esx", "qb", "qbox" }) do
    scenario(framework .. " MSK ownership, mapping and valet lifecycle", function()
        local test = new_server({ framework = framework, system = "auto" })
        local row = test.rows[1]
        -- Legacy data from a previous garage must neither override nor be modified by MSK.
        row.in_garage, row.parked, row.impound = 1, 1, 1
        row.garage_id, row.parking, row.nickname = "old_impound", "old_parking", "old name"
        row.engine, row.body = 1000, 1000
        row.model = 123
        if framework == "esx" then row.state = 2 else row.stored = 0 end
        local vehicle = test.overview()[1]
        assert(vehicle.plate == "MSK123" and vehicle.nickname == "My Sultan")
        assert(vehicle.model == 970598228, "MSK properties must decide the vehicle model")
        assert(vehicle.location == "A" and vehicle.status == "garaged")
        assert(vehicle.fuel == 45 and vehicle.engine == 85 and vehicle.body == 73)
        assert(#test.call("vehicles", nil, 2).data.vehicles == 0, "other owners must not see vehicles")
        assert(test.call("valet-request", { plate = "MSK123" }, 2).error == "vehicle_not_owned")
        local before = copy(row)
        local order = test.request(" MSK123 ")
        assert(order.success, tostring(order.error))
        assert(order.data.vehicle.properties.modEngine == 3)
        assert(order.data.vehicle.garageSystem == "msk" and order.data.vehicle.fuel == 45)
        assert(test.charged == 750 and order.data.cost == 750, "server must decide the price")
        assert(test.overview()[1].status == "out")
        assert(test.request().error == "valet_active")
        assert(test.call("valet-cancel", { orderId = "wrong" }).error == "valet_not_found")
        assert(test.refunded == 0)
        local column = framework == "esx" and "stored" or "state"
        for key, value in pairs(before) do
            assert(row[key] == (key == column and 0 or value), "unexpected mutation: " .. key)
        end
        assert(test.cancel(order).success and test.refunded == 750)
        for key, value in pairs(before) do assert(row[key] == value, "restore changed " .. key) end
        assert(test.overview()[1].status == "garaged")
    end)
end

scenario("auto keeps JG priority and explicit MSK overrides it", function()
    local resources = { msk_garage = "started", ["jg-advancedgarages"] = "started" }
    local auto = new_server({ system = "auto", resources = resources })
    auto.rows[1].in_garage = 0
    assert(auto.overview()[1].status == "out")
    local explicit = new_server({ resources = resources })
    explicit.rows[1].in_garage = 0
    assert(explicit.overview()[1].status == "garaged")
end)

scenario("auto falls back to the framework without MSK", function()
    local test = new_server({ system = "auto", resources = {} })
    test.rows[1].nickname = "ESX nickname"
    test.rows[1].state = 2
    assert(test.overview()[1].status == "impounded")
    assert(test.overview()[1].nickname == "ESX nickname")
end)

scenario("out MSK vehicles remain out despite stale parked flags", function()
    local test = new_server()
    test.rows[1].stored, test.rows[1].in_garage = 0, 1
    assert(test.overview()[1].status == "out")
    assert(test.request().error == "vehicle_not_garaged")
    assert(test.charged == 0)
end)

scenario("MSK aircraft cannot use road-only valet", function()
    local test = new_server()
    test.rows[1].type = "aircraft"
    test.rows[1].garage_type = "car"
    assert(test.overview()[1].kind == "plane")
    assert(test.request().error == "valet_vehicle_type")
    assert(test.charged == 0)
end)

scenario("failed payment restores MSK status without a refund", function()
    local test = new_server({ payment_failure = true })
    assert(test.request().error == "insufficient_funds")
    assert(test.rows[1].stored == 1 and test.charged == 0 and test.refunded == 0)
end)

scenario("concurrent park-out cannot create a second MSK valet order", function()
    local test = new_server({ reservation_race = true })
    assert(test.request().error == "vehicle_not_garaged")
    assert(test.charged == 0 and test.rows[1].stored == 0 and #test.logs == 1)
end)

for _, action in ipairs({ "stop", "disconnect", "timeout" }) do
    scenario(action .. " restores an undelivered MSK vehicle", function()
        local test = new_server()
        assert(test.request().success)
        test[action]()
        assert(test.rows[1].stored == 1 and test.refunded == 750)
    end)
end

scenario("completion leaves the delivered vehicle out", function()
    local test = new_server()
    local order = test.request()
    assert(test.call("valet-complete", { orderId = order.data.orderId, networkId = 0 }).error
        == "valet_vehicle_unverified")
    assert(test.call("valet-complete", { orderId = order.data.orderId, networkId = 10 }).success)
    test.stop()
    assert(test.rows[1].stored == 0 and test.refunded == 0)
    assert(test.request().error == "valet_cooldown")
end)

scenario("rollback never overwrites a new owner's row", function()
    local test = new_server()
    local order = test.request()
    test.rows[1].owner = "owner-2"
    assert(test.cancel(order).success)
    assert(test.rows[1].stored == 0 and #test.logs == 1)
end)

scenario("MSK fuel liters remain unrounded for valet", function()
    local test = new_server({ resources = { msk_garage = "started", msk_fuel = "started" } })
    test.rows[1].fuel = 140
    local vehicle = test.overview()[1]
    assert(vehicle.fuel == nil and vehicle.mskFuel == 140, "liters are not a percentage")
    local order = test.request()
    assert(order.success and order.data.vehicle.fuel == 140)
end)

scenario("session and rate limits still protect MSK access", function()
    local blocked = new_server({ rate_limited = true })
    assert(blocked.call("vehicles").error == "rate_limited")
    assert(blocked.request().error == "rate_limited" and #blocked.queries == 0)
    local no_session = new_server({ no_session = true })
    assert(no_session.call("vehicles").error == "no_session")
    assert(no_session.request().error == "no_session" and #no_session.queries == 0)
end)

print(("Server garage tests passed (%d scenarios)"):format(scenarios))
