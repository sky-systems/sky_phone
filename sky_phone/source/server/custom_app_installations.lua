Bridge.Database.AfterMigration("sky_phone", function()
local installation_locks = {}
local payment_locks = {}
local PURCHASE_NAMESPACE = "customAppPurchases"

local function affected_rows(result)
    if type(result) == "number" then return result end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function require_app_policy(source, data)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then return nil, nil, error_response end
    if type(data) ~= "table" or not SkyPhoneApps.ValidateAppId(data.appId)
        or type(data.ownerResource) ~= "string" then
        return nil, nil, { success = false, error = "invalid_request" }
    end
    if data.imei ~= session.imei or data.sessionToken ~= session.token then
        return nil, nil, { success = false, error = "stale_session" }
    end
    local policy = SkyPhoneApps.GetPolicy(data.appId)
    if not policy then
        if data.requirePolicy then
            return nil, nil, { success = false, error = "app_policy_required" }
        end
        return session, nil
    end
    if policy.ownerResource ~= data.ownerResource then
        return nil, nil, { success = false, error = "app_owner_mismatch" }
    end
    local options = policy.store or {}
    local job = Bridge.Framework.GetJob(source)
    local job_name, grade = job and job.name or "", job and job.grade or 0
    if options.disabledJobs and options.disabledJobs[job_name] ~= nil then
        return nil, nil, { success = false, error = "app_job_denied" }
    end
    if options.allowedJobs and next(options.allowedJobs)
        and (options.allowedJobs[job_name] == nil or grade < options.allowedJobs[job_name]) then
        return nil, nil, { success = false, error = "app_job_denied" }
    end
    return session, policy
end

local function load_purchases(imei)
    local rows = Bridge.Database.Query([[
        SELECT `payload`, `revision` FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = ? LIMIT 1
    ]], { imei, PURCHASE_NAMESPACE })
    if not rows[1] then return {}, 0 end
    local purchases = json.decode(rows[1].payload)
    if type(purchases) ~= "table" then
        error("[sky_phone] Invalid custom app purchase ledger.")
    end
    return purchases, tonumber(rows[1].revision) or 0
end

local function save_purchases(imei, purchases, revision)
    if revision == 0 then
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`, `revision`)
            VALUES (?, ?, ?, 1)
        ]], { imei, PURCHASE_NAMESPACE, json.encode(purchases) })
        return affected_rows(result) == 1
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_device_data` SET `payload` = ?, `revision` = `revision` + 1
        WHERE `device_imei` = ? AND `namespace` = ? AND `revision` = ?
    ]], { json.encode(purchases), imei, PURCHASE_NAMESPACE, revision })
    return affected_rows(result) == 1
end

local function same_session(source, session, identifier)
    local current = SkyPhone.RequireSession(source)
    return current == session and Bridge.Framework.GetIdentifier(source) == identifier
end

SkyPhoneApps.HasAppPurchase = function(imei, policy)
    local purchases = load_purchases(imei)
    local purchase = purchases[policy.ownerResource .. "/" .. policy.id]
    return purchase ~= nil and purchase.ownerResource == policy.ownerResource and purchase.status == "paid"
end

Bridge.Callbacks.Register("sky_phone:custom-app:authorize", function(source, data)
    if not SkyPhone.AllowOperation(source, "custom_app_authorize", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, policy, error_response = require_app_policy(source, data)
    if error_response then return error_response end
    if policy and (policy.store.price or 0) > 0 and not SkyPhoneApps.HasAppPurchase(session.imei, policy) then
        return { success = false, error = "app_not_purchased" }
    end
    local _, _, refreshed_error = require_app_policy(source, data)
    if refreshed_error then return refreshed_error end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:custom-app:install", function(source, data)
    if not SkyPhone.AllowOperation(source, "custom_app_install", 30, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, policy, error_response = require_app_policy(source, data)
    if error_response then return error_response end
    local price = policy and policy.store and policy.store.price or 0
    if data.expectedPrice ~= price then return { success = false, error = "app_price_changed" } end
    if price == 0 then return { success = true } end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then return { success = false, error = "player_unavailable" } end
    -- Reserve before any yielding I/O; the durable pending record prevents a
    -- resource restart or uncertain provider outcome from charging a second time.
    if installation_locks[session.imei] or payment_locks[identifier] then
        return { success = false, error = "app_install_pending" }
    end
    installation_locks[session.imei] = true
    payment_locks[identifier] = true
    local success, response = xpcall(function()
        local purchases, revision = load_purchases(session.imei)
        local purchase_key = policy.ownerResource .. "/" .. policy.id
        local purchase = purchases[purchase_key]
        if purchase and purchase.ownerResource == policy.ownerResource then
            if purchase.status == "paid" then return { success = true } end
            return { success = false, error = "app_install_pending" }
        end
        purchases[purchase_key] = {
            ownerResource = policy.ownerResource, identifier = identifier,
            price = price, account = "bank", status = "pending", createdAt = os.time(),
        }
        if not save_purchases(session.imei, purchases, revision) then
            return { success = false, error = "conflict" }
        end
        revision = revision + 1
        if not same_session(source, session, identifier) then
            purchases[purchase_key] = nil
            if not save_purchases(session.imei, purchases, revision) then
                Bridge.Debug("error", "[sky_phone] Could not clear a cancelled custom app purchase reservation.")
            end
            return { success = false, error = "stale_session" }
        end
        local current_policy = SkyPhoneApps.GetPolicy(policy.id)
        if not current_policy or current_policy.ownerResource ~= policy.ownerResource
            or (current_policy.store.price or 0) ~= price then
            purchases[purchase_key] = nil
            if not save_purchases(session.imei, purchases, revision) then
                Bridge.Debug("error", "[sky_phone] Could not clear a changed custom app purchase reservation.")
            end
            return { success = false, error = "app_price_changed" }
        end
        local _, _, permission_error = require_app_policy(source, data)
        local balance = Bridge.Framework.GetMoney(source, "bank")
        if permission_error or type(balance) ~= "number" or balance < price
            or not Bridge.Framework.RemoveMoney(source, "bank", price) then
            purchases[purchase_key] = nil
            if not save_purchases(session.imei, purchases, revision) then
                Bridge.Debug("error", "[sky_phone] Could not clear a rejected custom app purchase reservation.")
            end
            return permission_error or { success = false, error = "insufficient_funds" }
        end
        purchases[purchase_key].status = "paid"
        if not save_purchases(session.imei, purchases, revision) then
            if Bridge.Framework.GetIdentifier(source) == identifier and Bridge.Framework.AddMoney(source, "bank", price) then
                purchases[purchase_key] = nil
                if not save_purchases(session.imei, purchases, revision) then
                    Bridge.Debug("error", "[sky_phone] Custom app payment refunded; purchase reservation requires reconciliation.")
                end
            else
                Bridge.Debug("error", "[sky_phone] Custom app payment outcome requires reconciliation; automatic retry is blocked.")
            end
            return { success = false, error = "app_purchase_failed" }
        end
        return { success = true }
    end, debug.traceback)
    installation_locks[session.imei] = nil
    payment_locks[identifier] = nil
    if not success then
        Bridge.Debug("error", "[sky_phone] Custom app installation failed: %s", tostring(response))
        return { success = false, error = "app_purchase_failed" }
    end
    return response
end)
end)
