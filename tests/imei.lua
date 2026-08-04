dofile("sky_phone/source/shared/imei.lua")

local imei = SkyPhoneImei.FromEntropy("550e8400-e29b-41d4-a716-446655440000")
assert(type(imei) == "string" and #imei == 15, "IMEI must contain 15 digits")
assert(imei:match("^%d+$"), "IMEI must be numeric")
assert(SkyPhoneImei.IsValid(imei), "generated IMEI must pass its check digit")
assert(not SkyPhoneImei.IsValid(imei:sub(1, 14) .. tostring((tonumber(imei:sub(15, 15)) + 1) % 10)), "invalid check digit must fail")
assert(not SkyPhoneImei.IsValid("123"), "short IMEI must fail")

print("IMEI tests passed")
