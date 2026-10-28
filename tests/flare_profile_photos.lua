local callbacks, transactions, resolved = {}, {}, {}
local photo_failure, failing_id
local environment = setmetatable({
    Bridge = {
        Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Query = function() return {} end,
            Transaction = function(statements)
                transactions[#transactions + 1] = statements
                return true
            end,
        },
    },
    SkyPhone = {
        AllowOperation = function() return true end,
        RequireAccount = function() return { id = 7 } end,
    },
    SkyPhoneMedia = { ResolveOwnedMedia = function(source, media_id, media_type)
        assert(source == 42 and media_type == "photo")
        resolved[#resolved + 1] = media_id
        if media_id == failing_id then return nil, photo_failure end
        return "https://media.example.test/" .. media_id .. ".jpg"
    end },
    json = { encode = function() return "[]" end },
}, { __index = _G })
assert(loadfile("sky_phone/source/server/flare.lua", "t", environment))()
local save_profile = assert(callbacks["sky_phone:flare:save-profile"])
local function save(ids)
    transactions, resolved = {}, {}
    return save_profile(42, {
        name = "Alex", age = 27, bio = "", avatar = 0, gender = "woman",
        interestedIn = "everyone", minAge = 21, maxAge = 45, lookingFor = "longTerm",
        interests = {}, photoMediaIds = ids,
    })
end

for count = 1, 6 do
    local ids = {}
    for id = 1, count do ids[id] = id end
    assert(save(ids).success, "One to six valid owned photos must permit profile creation")
    assert(#resolved == count and #transactions == 1 and #transactions[1] == count + 2)
    for index, id in ipairs(ids) do
        local statement = transactions[1][index + 2]
        assert(statement.params[1] == id and statement.params[2] == index and statement.params[3] == 7,
            "Profile photos must retain their selected order and authenticated account")
    end
end

for _, ids in ipairs({ {}, { 1, 2, 3, 4, 5, 6, 7 }, { 1, 1 }, { -1 }, { 1.5 }, { "invalid" }, { [2] = 1 } }) do
    assert(save(ids).error == "invalid_profile_photos" and #transactions == 0,
        "Invalid counts, duplicates and malformed photo IDs must never mutate a profile")
end

failing_id = 6
for _, failure in ipairs({ "import_url_unavailable", "import_media_unavailable" }) do
    photo_failure = failure
    assert(save({ 1, 2, 3, 4, 5, 6 }).error == "profile_photo_unavailable" and #transactions == 0,
        "A removed sixth photo must identify unavailability instead of reporting the photo count")
end
for _, failure in ipairs({ "import_source_unavailable", "import_provider_unauthorized", "invalid_attachment" }) do
    photo_failure = failure
    assert(save({ 1, 2, 3, 4, 5, 6 }).error == "profile_photo_verification_failed" and #transactions == 0,
        "Verification and ownership failures must remain rejected without mutating the profile")
end
print("Flare profile photo counts, ownership, verification errors and transaction boundaries passed")
