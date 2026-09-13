-- Human-readable presentation of the already sanitized server audit record.
-- Keep transport, authorization and content capture independent of formatting.
local app_names = { Pages = "Local Pages", Marketplace = "CityMarkt", WeazelNews = "Weazel News", Crypto = "VaultX" }
local subjects = {
    Calls = "call", Contacts = "contact", Messages = "message", Picstagram = "post", Feather = "post",
    FlipTok = "video", SkyPic = "snap", DarkChat = "message", Flare = "profile", Mail = "mail",
    Marketplace = "listing", Pages = "post", Companies = "request", Banking = "payment", Crypto = "trade",
    Billing = "invoice", Uploads = "media", Gallery = "media", Memos = "memo", Notes = "note",
    Calendar = "event", WeazelNews = "article", CityWarn = "alert", CrewLink = "group", SkyRide = "ride",
    Radio = "radio", Garage = "vehicle", Housing = "home", Health = "health", Music = "music",
    Map = "marker", EasyShare = "share", Account = "account", Device = "settings", Security = "security",
    Sim = "sim", Admin = "settings", CustomApps = "settings",
}
local subject_rules = {
    { "profile", "profile" }, { "comment", "comment" }, { "story", "story" }, { "spotlight", "post" },
    { "message", "message" }, { "snap", "snap" }, { "friend", "friend" }, { "follow", "follow" },
    { "report", "report" }, { "playlist", "playlist" }, { "ping", "marker" }, { "invite", "invitation" },
    { "member", "member" }, { "contact", "contact" }, { "mailbox", "mailbox" }, { "draft", "draft" },
    { "offer", "offer" }, { "settings", "settings" }, { "configurator", "settings" }, { "webhooks", "settings" },
    { "passcode", "security" }, { "tone", "tone" }, { "account", "account" }, { "react", "reaction" },
}

function SkyPhoneLog.Labels(section)
    local locale = Config and Config.Bridge and Config.Bridge.Locale or "en"
    local language = Locales and (Locales[locale] or Locales.en)
    return language and language[section] or {}
end

local function readable(key)
    return tostring(key):gsub("(%l)(%u)", "%1 %2"):gsub("[_:%-]", " ")
end

function SkyPhoneLog.FormatAudit(category, action, status, record, timestamp)
    local labels = SkyPhoneLog.Labels("DiscordAudit")
    local function label(group, key, fallback)
        return labels[group] and labels[group][key] or fallback or readable(key)
    end
    local operation = action:match("([^:]+)$") or action
    local subject = subjects[category] or "activity"
    for _, rule in ipairs(subject_rules) do
        if operation:find(rule[1], 1, true) then subject = rule[2]; break end
    end
    if operation == "login" or operation == "logout" or operation == "register" then subject = "account" end
    if operation == "thread" or operation == "send" then subject = "message" end
    if operation == "save" or operation == "save-configurator" or operation == "save-webhooks" then subject = "settings" end
    local title = label("titles", subject .. "_" .. status,
        label("subjects", subject) .. " · " .. label("states", status))
    local lines, actor, details = {}, record.actor or {}, record.details or {}
    local function append(value) lines[#lines + 1] = value end
    append("**" .. label("fields", "by", "By") .. ":** " .. tostring(actor.name or label("fields", "server", "Server")))
    append("**" .. label("fields", "time", "Date / time") .. ":** <t:" .. timestamp .. ":F> · <t:" .. timestamp .. ":R>")
    local seen = {}
    local scope
    local function render(value, key, depth)
        if value == nil or value == "" then return end
        if type(value) ~= "table" then
            local content = type(value) == "boolean" and label("values", value and "yes" or "no") or tostring(value)
            if key == "status" or key == "state" then content = label("states", content) end
            local instant = tonumber(value)
            if instant and (tostring(key):match("_at$") or tostring(key):match("At$")) then
                if instant > 100000000000 then instant = instant / 1000 end
                if instant > 1000000000 and instant < 10000000000 then content = "<t:" .. math.floor(instant) .. ":f>" end
            end
            if key == "author_handle" or key == "handle" then content = "@" .. content:gsub("^@", "") end
            if key == "media_type" then content = label("values", content) end
            -- Keep before/after values, but omit request/result duplicates of
            -- persisted content that staff have already read above.
            local signature = tostring(key) .. "\0" .. content
            if (scope == "request" or scope == "result") and seen[signature] then return end
            seen[signature] = true
            append("**" .. label("fields", key) .. ":** " .. content)
            return
        end
        if next(value) == nil then return end
        if depth > 8 then return end
        if key == "records" and #value == 1 then render(value[1], "entry", depth); return end
        local keys = {}
        for child in pairs(value) do keys[#keys + 1] = child end
        table.sort(keys, function(a, b)
            local priority = { records = 1, media = 99, author_handle = 1, author_name = 2, title = 3, subject = 3, body = 4, caption = 4,
                description = 4, text = 4, status = 5, created_at = 90, updated_at = 91, id = 99 }
            if type(a) == "number" and type(b) == "number" then return a < b end
            local pa, pb = priority[a] or 50, priority[b] or 50
            return pa == pb and tostring(a) < tostring(b) or pa < pb
        end)
        for _, child in ipairs(keys) do
            local start = #lines
            local heading = type(value[child]) == "table" and child ~= "records"
                and not (type(child) == "number" and #value == 1)
            if heading then
                append("\n**" .. label("fields", type(child) == "number" and "entry" or child)
                    .. (type(child) == "number" and (" " .. child) or "") .. "**")
            end
            render(value[child], type(child) == "number" and key or child, depth + 1)
            if heading and #lines == start + 1 then lines[#lines] = nil end
        end
    end
    -- Persisted content leads; before/after snapshots retain deleted/edited text.
    for _, key in ipairs({ "content", "snapshots", "request", "result" }) do
        if type(details[key]) == "table" and next(details[key]) then
            scope = key
            local start = #lines
            append("\n**" .. label("fields", key) .. "**")
            render(details[key], key, 0)
            if #lines == start + 1 then lines[#lines] = nil end
        end
    end
    scope = nil
    local other = {}
    for key, value in pairs(details) do
        if key ~= "content" and key ~= "snapshots" and key ~= "request" and key ~= "result" then other[key] = value end
    end
    render(other, "details", 0)
    append("\n**" .. label("fields", "player", "Player") .. "**")
    for _, key in ipairs({ "source", "accountId", "phoneNumber", "imei" }) do render(actor[key], key, 0) end
    return (app_names[category] or label("apps", category, category)) .. " · " .. title, table.concat(lines, "\n")
end
