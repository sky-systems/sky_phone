dofile("sky_phone/source/shared/sim_number.lua")

local number = SkyPhoneSimNumber.FromEntropy("550e8400-e29b-41d4-a716-446655440000", 10, "")
assert(number == "5508400294", "SIM number must be derived deterministically from entropy")
assert(SkyPhoneSimNumber.Normalize("550 840 0294", 10, "") == number, "formatted numbers must normalize")
assert(SkyPhoneSimNumber.Normalize("123", 10, "") == nil, "short numbers must fail")
assert(SkyPhoneSimNumber.Format(number, { 3, 3, 4 }, 10, "") == "550 840 0294", "groups must format")

local attempts = 0
local reserved = SkyPhoneSimNumber.Reserve(function()
    attempts = attempts + 1
    return attempts == 1 and "550e8400-e29b-41d4-a716-446655440000" or "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
end, function()
    return attempts == 2
end, 10, "")
assert(attempts == 2, "SIM reservation must retry collisions")
assert(reserved == SkyPhoneSimNumber.FromEntropy("6ba7b810-9dad-11d1-80b4-00c04fd430c8", 10, ""), "reservation must return accepted number")

print("SIM number tests passed")
