-- Quasar Banking Creator's public account and transaction-writing exports.
-- It publishes no history reader: the Phone statement remains the Phone's own ledger.
function Bridge.Finance.Quasar(source, action, data)
    local resource = GetResourceState("qs-banking") == "started" and "qs-banking" or "qs_banking"
    if GetResourceState(resource) ~= "started" then
        return { success = false, error = "banking_unavailable" }
    end
    if action == "overview" then
        local overview = data.overview
        local job = Bridge.Framework.GetJob(source)
        overview.accounts = {}
        overview.historyLimited = true
        if job.isBoss and job.name ~= "" then
            local balance = exports[resource]:GetAccountBalance(job.name)
            local current = Bridge.Framework.GetJob(source)
            if current.name == job.name and current.grade == job.grade and current.isBoss
                and type(balance) == "number" and balance >= 0 then
                overview.accounts[1] = { id = job.name, label = job.label, balance = balance }
            end
        end
        return { success = true, data = overview }
    end
    if action == "prepareTransfer" then
        local held = exports[resource]:GetHeldAmount(data.senderIdentifier)
        local balance = Bridge.Framework.GetMoney(source, "bank")
        if type(held) ~= "number" or held < 0 or type(balance) ~= "number" then
            return { success = false, error = "banking_unavailable" }
        end
        return balance - held >= data.amount and { success = true }
            or { success = false, error = "insufficient_funds" }
    end
    if action == "recordPayment" then
        exports[resource]:AddTransaction(data.senderIdentifier, "Phone invoice", "fa-solid fa-wallet",
            ("Payment %s: %s"):format(data.amount, data.label))
        return { success = true }
    end
    if action == "recordTransfer" then
        -- These exports log only; the Phone's framework bridge already moved the money once.
        exports[resource]:AddTransaction(data.senderIdentifier, "Phone transfer", "fa-solid fa-exchange",
            ("Sent %s to %s"):format(data.amount, data.targetName))
        exports[resource]:AddTransaction(data.targetIdentifier, "Phone transfer", "fa-solid fa-exchange",
            ("Received %s from %s"):format(data.amount, data.senderName))
        return { success = true }
    end
    return { success = false, error = "invalid_request" }
end
