dofile("sky_phone/source/shared/imei.lua")

local imei = SkyPhoneImei.FromEntropy("550e8400-e29b-41d4-a716-446655440000")
assert(type(imei) == "string" and #imei == 15, "IMEI must contain 15 digits")
assert(imei:match("^%d+$"), "IMEI must be numeric")
assert(SkyPhoneImei.IsValid(imei), "generated IMEI must pass its check digit")
assert(not SkyPhoneImei.IsValid(imei:sub(1, 14) .. tostring((tonumber(imei:sub(15, 15)) + 1) % 10)), "invalid check digit must fail")
assert(not SkyPhoneImei.IsValid("123"), "short IMEI must fail")

local entropy = {
    "550e8400-e29b-41d4-a716-446655440000",
    "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
}
local entropy_index = 0
local reserve_attempts = 0
local reserved = SkyPhoneImei.Reserve(function()
    entropy_index = entropy_index + 1
    return entropy[entropy_index]
end, function()
    reserve_attempts = reserve_attempts + 1
    return reserve_attempts == 2
end)
assert(reserve_attempts == 2, "IMEI reservation must retry database collisions")
assert(reserved == SkyPhoneImei.FromEntropy(entropy[2]), "IMEI reservation must return the accepted candidate")

print("IMEI tests passed")
