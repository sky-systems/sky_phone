-- Run from the repository root with Lua 5.4.
local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local config = read_file("sky_phone/config/config.lua")
local defaults = read_file("sky_phone/source/shared/config_default.lua")
local panel = read_file("frontend/src/components/AdminPanel.vue")
assert(config:find("skypic = true,", 1, true), "Config.Apps must include SkyPic")
assert(defaults:find("skypic = true,", 1, true), "Config defaults must include SkyPic")
assert(panel:find("['Apps.skypic', phone.t('Apps.skypic.name')]", 1, true),
    "Phone Configurator must label SkyPic from the existing app name")

local migrations = {}
local handlers = {}
local cancelled = {}
local queued = {}

Config = { Apps = { picstagram = false, skypic = false, mail = true } }
Bridge = {
    Database = {
        Migrate = function(name, schema)
            migrations[#migrations + 1] = {
                name = name,
                count = #schema,
                first = schema[1] and schema[1].name or nil,
            }
        end,
        AfterMigration = function(_, callback)
            queued[#queued + 1] = callback
        end,
    },
    Callbacks = {
        CancelDeferred = function(name)
            cancelled[#cancelled + 1] = name
        end,
    },
    Debug = function() end,
}

function AddEventHandler(name, callback)
    local list = handlers[name]
    if not list then
        list = {}
        handlers[name] = list
    end
    list[#list + 1] = callback
end

dofile("sky_phone/source/server/app_database.lua")

local schema = {
    { name = "sky_phone_picstagram_posts" },
    { name = "sky_phone_skypic_profiles" },
    { name = "sky_phone_media" },
    { name = "sky_phone_mail_messages" },
    { name = "sky_phone_mailboxes" },
    { name = "sky_phone_crypto_markets" },
}

local function names_of(tables)
    local names = {}
    for index = 1, #tables do
        names[tables[index].name] = true
    end
    return names
end

local filtered = names_of(SkyPhoneAppDatabase.Filter(schema))
assert(not filtered["sky_phone_picstagram_posts"], "disabled Picstagram tables must stay out of startup")
assert(not filtered["sky_phone_skypic_profiles"], "disabled SkyPic tables must stay out of startup")
assert(filtered["sky_phone_media"], "shared media must stay in startup")
assert(filtered["sky_phone_mail_messages"] and filtered["sky_phone_mailboxes"],
    "mail and its mailboxes share one app")
assert(filtered["sky_phone_crypto_markets"], "crypto storage is not part of the app-table filter")

Config.Apps.skypic = nil
assert(names_of(SkyPhoneAppDatabase.Filter(schema))["sky_phone_skypic_profiles"],
    "a missing app key stays enabled")
Config.Apps.skypic = false
Config.Apps = nil
assert(#SkyPhoneAppDatabase.Filter(schema) == #schema, "missing app settings keep every table")
Config.Apps = { picstagram = false, skypic = false, mail = true }

assert(SkyPhoneAppDatabase.CallbackApp("sky_phone:marketplace:list") == "citymarkt")
assert(SkyPhoneAppDatabase.CallbackApp("sky_phone:housing:overview") == "house")
assert(SkyPhoneAppDatabase.CallbackApp("sky_phone:weazel-news:list") == "weazel-news")
assert(SkyPhoneAppDatabase.CallbackApp("sky_phone:device:open") == nil)
assert(SkyPhoneAppDatabase.Owner("sky_phone_mailboxes") == "mail")
assert(SkyPhoneAppDatabase.Owner("sky_phone_voice_memos") == "memos")
assert(SkyPhoneAppDatabase.Owner("SKY_PHONE_MEDIA") == nil)

local ran = false
SkyPhoneAppDatabase.Run("picstagram", function()
    ran = true
end)
assert(ran == false, "post-schema SQL must wait while the app is off")

local mail_ran = false
SkyPhoneAppDatabase.Run("mail", function()
    mail_ran = true
end)
assert(mail_ran, "post-schema SQL for an enabled app still runs at startup")

SkyPhoneAppDatabase.Remember(schema)
assert(SkyPhoneAppDatabase.Ensure("picstagram") == false)
assert(#migrations == 0, "ensuring a disabled app must not create its tables")
assert(SkyPhoneAppDatabase.Ensure("picstagram", true))
assert(ran, "a forced import must run the remembered SQL")
assert(#migrations == 1)
assert(migrations[1].name == "sky_phone_app_picstagram")
assert(migrations[1].count == 1 and migrations[1].first == "sky_phone_picstagram_posts")
assert(SkyPhoneAppDatabase.Ensure("mail"))
assert(#migrations == 1, "an app migrated at startup must not be migrated again")

local starts = 0
Config.Apps.citywarn = false
SkyPhoneAppDatabase.WhenEnabled("citywarn", function()
    starts = starts + 1
end, { "sky_phone:citywarn:blips" })
assert(#queued == 1)
queued[1]()
assert(starts == 0, "a disabled app must not start after migration")
assert(cancelled[1] == "sky_phone:citywarn:blips",
    "a disabled public read must not keep warning after startup")
Config.Apps.citywarn = true
handlers["sky_phone:configurator:serverUpdated"][1]()
assert(starts == 1, "turning an app on must start it once")
handlers["sky_phone:configurator:serverUpdated"][1]()
assert(starts == 1, "later configuration saves must not start the app again")

local responses = {}
function RegisterNetEvent(name, callback)
    handlers[name] = { callback }
end
function SetTimeout() end
SkyPhoneCellular = {
    RequiresSignal = function() return false end,
    HasSignal = function() return true end,
}
SkyPhoneLog = nil
Bridge.Network = {
    SendClient = function(_, _, request_id, result)
        responses[request_id] = result
        return true
    end,
}
source = 7
dofile("sky_phone/source/bridge/server/callbacks.lua")
handlers["sky_phone:bridge:callback:request"][1]("sky_phone:picstagram:feed", 4, {})
assert(responses[4].error == "app_disabled")
Config.Apps.picstagram = true
handlers["sky_phone:bridge:callback:request"][1]("sky_phone:missing", 5, {})
assert(responses[5] == nil)

print("app database: ok; disabled apps stay out of startup until they are enabled")
