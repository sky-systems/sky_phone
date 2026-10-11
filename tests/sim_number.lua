dofile("sky_phone/source/shared/sim_number.lua")

local number = SkyPhoneSimNumber.FromEntropy("550e8400-e29b-41d4-a716-446655440000", 10, "")
assert(number == "5508400294", "SIM number must be derived deterministically from entropy")
assert(SkyPhoneSimNumber.Normalize("550 840 0294") == number, "formatted numbers must normalize")
assert(SkyPhoneSimNumber.Normalize("0298822") == "0298822", "leading zeroes must survive normalization")
assert(SkyPhoneSimNumber.Normalize("029 8822") == "0298822", "display groups must not become stored data")
assert(SkyPhoneSimNumber.Normalize("123") == "123", "short numbers must not require a generated SIM format")
assert(SkyPhoneSimNumber.Normalize("0") == "0", "single-digit numbers must normalize")
assert(SkyPhoneSimNumber.Normalize(string.rep("0", 24)) == string.rep("0", 24), "the storage limit must be supported")
assert(SkyPhoneSimNumber.Normalize(string.rep("0", 25)) == nil, "numbers beyond the storage limit must fail")
assert(SkyPhoneSimNumber.Normalize("") == nil and SkyPhoneSimNumber.Normalize("abc") == nil, "numbers must contain digits")
assert(SkyPhoneSimNumber.Normalize(false) == nil and SkyPhoneSimNumber.Normalize({}) == nil, "invalid types must fail")
assert(SkyPhoneSimNumber.Format(number, { 3, 3, 4 }) == "550 840 0294", "groups must format")
assert(SkyPhoneSimNumber.Format("0298822", { 3, 3, 4 }) == "029 882 2", "short numbers must format without trailing spaces")
assert(SkyPhoneSimNumber.Format("02988221234", { 3, 3, 4 }) == "029 882 2123 4", "display formatting must never truncate digits")
assert(SkyPhoneSimNumber.NormalizeService("9-1-1", 10) == "911", "formatted service numbers must normalize")
assert(SkyPhoneSimNumber.NormalizeService("0", 10) == "0", "single-digit service numbers must normalize")
assert(SkyPhoneSimNumber.NormalizeService("", 10) == nil, "empty service numbers must fail")
assert(SkyPhoneSimNumber.NormalizeService("12345678901", 10) == nil, "long service numbers must fail")
assert(SkyPhoneSimNumber.ValidateConfiguration(9, "555"), "numeric SIM prefixes must be valid")
assert(SkyPhoneSimNumber.FromEntropy("550e8400-e29b-41d4-a716-446655440000", 9, "555") == "555550840")
assert(not SkyPhoneSimNumber.ValidateConfiguration(9, "555-"), "formatted SIM prefixes must be rejected")
assert(SkyPhoneSimNumber.FromEntropy("550e8400-e29b-41d4-a716-446655440000", 9, "555-") == nil)

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
