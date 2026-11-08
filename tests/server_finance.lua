local function server()
    local state = { identifiers = { "fixture-a", "fixture-b" }, money = { 1000, 100 },
        resources = { sky_phone = "started", ledger = "started", ["qs-banking"] = "started" },
        callbacks = {}, events = {}, api = {}, endpoint = {}, writes = {}, sessions = true,
        debits = 0, credits = 0, calls = 0, held = 0, logs = 0, boss = false }
    local env = setmetatable({ Config = {
        Banking = { Provider = "framework", MinimumAmount = 1, MaximumAmount = 10000,
            Currency = "$", HistoryLimit = 50, ActionsPerMinute = 12 },
        Billing = { Provider = "phone", Enabled = true, ActionsPerMinute = 8, AllowDisputes = true },
    } }, { __index = _G })
    env.GetCurrentResourceName = function() return "sky_phone" end
    env.GetInvokingResource = function() return state.invoker end
    env.GetResourceState = function(name) return state.resources[name] or "missing" end
    env.AddEventHandler = function(name, handler) state.events[name] = handler end
    env.TriggerEvent = function(name) state.triggered = name end
    env.TriggerClientEvent = function(name, player) state.notified = { name, player } end
    env.GetPlayerName = function(source) return "Fixture " .. source end
    env.exports = setmetatable({}, {
        __call = function(_, name, handler) state.api[name] = handler end,
        __index = function(_, resource)
            if resource == "qs-banking" or resource == "qs_banking" then return {
                GetHeldAmount = function() return state.held end,
                GetAccountBalance = function() return 300 end,
                AddTransaction = function() state.logs = state.logs + 1; if state.log_error then error("fixture history unavailable") end end,
            } end
            return setmetatable({}, { __index = function(_, name)
                return function(_, source, action, data)
                    state.calls = state.calls + 1
                    return assert(state.endpoint[name])(source, action, data)
                end
            end })
        end,
    })
    env.Bridge = {
        Debug = function() end,
        Callbacks = { Register = function(name, fn) state.callbacks[name] = fn end },
        Database = {
            AfterMigration = function(_, start) start() end,
            Query = function(sql, params)
                if sql:find("SELECT d.", 1, true) then return { { imei = "fixture-phone" } } end
                if sql:find("INSERT INTO", 1, true) then
                    if state.statement_error then error("fixture statement unavailable") end
                    state.writes[#state.writes + 1] = params
                    if state.change_actor_after_transfer then state.identifiers[1] = "fixture-new-character" end
                    return 1
                end
                if state.read_error then error("fixture read unavailable") end
                return {}
            end,
        },
        Framework = {
            GetIdentifier = function(source) return state.identifiers[source] end,
            GetMoney = function(source, kind) return kind == "bank" and state.money[source] or 10 end,
            GetFirstname = function() return "Fixture" end,
            GetLastname = function(source) return tostring(source) end,
            GetPlayers = function() return { 1, 2 } end,
            GetJob = function() return { name = "fixture_job", label = "Fixture job", grade = 4, isBoss = state.boss } end,
            RemoveMoney = function(source, _, amount)
                if state.money[source] < amount then return false end
                state.debits = state.debits + 1; state.money[source] = state.money[source] - amount; return true
            end,
            AddMoney = function(source, _, amount)
                state.credits = state.credits + 1; state.money[source] = state.money[source] + amount; return true
            end,
        },
    }
    env.SkyPhone = {
        RequireSession = function() if state.sessions then return {} end; return nil, { success = false, error = "session_required" } end,
        AllowOperation = function() return true end,
        FindDeviceSlots = function(source) return source == 2 and { 1 } or {} end,
    }
    env.SkyPhoneSimNumber = { Normalize = function(number) return type(number) == "string" and number:match("^%d+$") end }
    for _, file in ipairs({ "source/server/finance_providers.lua", "source/bridge/server/finance_quasar.lua",
        "source/server/banking.lua", "source/server/billing.lua" }) do
        assert(loadfile("sky_phone/" .. file, "t", env))()
    end
    function state.register(kind, endpoint)
        state.invoker = "ledger"
        local result = state.api.RegisterFinanceProvider(kind, endpoint)
        state.invoker = nil
        return result
    end
    function state.transfer()
        return state.callbacks["sky_phone:banking:transfer"](1,
            { amount = 200, phoneNumber = "1234567", senderIdentifier = "forged", target = 99 })
    end
    return state, env
end

do
    local state, env = server()
    env.Config.Billing.Provider = "ledger"
    assert(not state.api.RegisterFinanceProvider("billing", "Endpoint"), "registration requires a resource owner")
    assert(not state.register("other", "Endpoint"))
    assert(state.register("billing", "Endpoint"))
    state.invoker = "ledger"
    assert(state.api.NotifyFinanceChanged("billing", 1))
    assert(state.notified[1] == "sky_phone:billing:changed" and state.notified[2] == 1)
    state.invoker = "other"
    assert(not state.api.NotifyFinanceChanged("billing", 1))
    state.invoker = nil
    state.endpoint.Endpoint = function(source, action, data)
        assert(source == 1 and action == "pay" and data.id == "17")
        return { success = true, data = { id = "17" } }
    end
    local pay = state.callbacks["sky_phone:billing:pay"]
    state.sessions = false
    assert(pay(1, { id = "ledger:17" }).error == "session_required" and state.calls == 0)
    state.sessions = true
    assert(pay(1, { id = "other:17" }).error == "invoice_not_found" and state.calls == 0)
    assert(pay(1, { id = "ledger:17" }).success and #state.writes == 0, "external invoices never enter the Phone ledger")
    state.endpoint.Endpoint = function() error("fixture lost payment reply") end
    local before = state.calls
    assert(pay(1, { id = "ledger:17" }).error == "payment_unknown" and state.calls == before + 1)
    state.events.onResourceStop("ledger")
    assert(pay(1, { id = "ledger:17" }).error == "billing_unavailable", "stopped providers must not fall back")
    assert(state.register("billing", "Endpoint"))
    state.endpoint.Endpoint = function()
        state.identifiers[1] = "fixture-new-character"
        return { success = true, data = { private = true } }
    end
    assert(pay(1, { id = "ledger:17" }).error == "not_authorized", "discard replies for a changed character")
    state.events.onResourceStart("sky_phone")
    assert(state.triggered == "sky_phone:server:financeReady")
end

do
    local state, env = server()
    env.Config.Banking.Provider = "qs"
    state.held = 900
    assert(state.transfer().error == "insufficient_funds" and state.debits == 0, "held QS funds cannot be spent")
    state.held, state.log_error = 0, true
    local result = state.transfer()
    assert(result.success and result.data.historyWarning, "logging failure must not report a failed payment")
    assert(state.money[1] == 800 and state.money[2] == 300 and state.debits == 1 and state.credits == 1)
    assert(#state.writes == 2 and state.logs == 1, "never retry an uncertain history write")
    assert(result.data.historyLimited and #result.data.accounts == 0)
    state.boss = true
    result = state.callbacks["sky_phone:banking:overview"](1)
    assert(result.data.accounts[1].balance == 300, "only framework-authorized bosses see QS company funds")
end

do
    local state, env = server()
    env.Config.Banking.Provider = "ledger"
    assert(state.register("banking", "Bank"))
    state.endpoint.Bank = function(_, action, data)
        if action == "prepareTransfer" then
            assert(data.senderIdentifier == "fixture-a" and data.target == 2)
            state.identifiers[2] = "fixture-reconnected-player"
        end
        return { success = true }
    end
    assert(state.transfer().error == "target_not_found" and state.debits == 0)
end

do
    local state = server()
    state.read_error = true
    local result = state.transfer()
    assert(result.success and result.data.historyWarning and result.data.bank == 800,
        "a failed statement reload after settlement cannot turn success into a failed transfer")
    assert(state.debits == 1 and state.credits == 1)
end

do
    local state, env = server()
    env.Config.Banking.Provider = "qs"
    assert(env.Bridge.Finance.RecordInvoicePayment(1, 400, "Fixture invoice", "ledger:17", true))
    assert(#state.writes == 1 and state.logs == 1 and state.debits == 0 and state.credits == 0,
        "confirmed invoice logging must not debit or credit framework money")
end

do
    local state = server()
    state.change_actor_after_transfer = true
    local result = state.transfer()
    assert(result.success and not result.data,
        "a completed transfer stays successful without leaking a replaced character's balance")
    assert(state.debits == 1 and state.credits == 1)
end

print("Phone finance: session, ownership, provider lifecycle, held funds and single transfer checks passed")
