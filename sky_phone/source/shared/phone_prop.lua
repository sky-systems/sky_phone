-- Geometry and palette contract generated alongside storage/phone_prop.
SkyPhoneProp = {
    DefaultModel = "sky_phone_prop",
    Frames = {
        black = true, blue = true, green = true, lavender = true, red = true,
        white = true, orange = true, yellow = true, lime = true, teal = true,
        cyan = true, purple = true, pink = true, gold = true, rgb = true,
    },
    Models = {},
    Range = 3.0,
    IntervalMs = 500,
    MaxFrameBytes = 64000,
    MaxDisplays = 12,
    Width = 360,
    Height = 780,
    Screen = { width = 0.0736, height = 0.1589, y = -0.00456, radius = 0.0081 },
}
for frame in pairs(SkyPhoneProp.Frames) do
    SkyPhoneProp.Models[joaat(frame == "black" and "sky_phone_prop" or "sky_phone_prop_" .. frame)] = true
end
SkyPhoneProp.Models[joaat("sky_phone_prop_burgundy")] = true

function SkyPhoneProp.Model(frame, configured)
    if not SkyPhoneProp.Models[joaat(configured)] then return configured end
    if configured == "sky_phone_prop_burgundy" then return configured end
    local selected = SkyPhoneProp.Frames[frame] and frame or "black"
    return selected == "black" and SkyPhoneProp.DefaultModel or "sky_phone_prop_" .. selected
end

-- Read the SOF header before forwarding client-provided compressed images.
function SkyPhoneProp.ValidFrame(jpeg)
    if type(jpeg) ~= "string" or #jpeg < 100 or #jpeg > SkyPhoneProp.MaxFrameBytes
        or not jpeg:match("^data:image/jpeg;base64,/9j/[A-Za-z0-9+/=]+$") then return false end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values = {}
    for i = 1, #alphabet do values[alphabet:sub(i, i)] = i - 1 end
    local bytes, buffer, bits = {}, 0, 0
    for i = 24, math.min(#jpeg, 24 + 4095) do
        local value = values[jpeg:sub(i, i)]
        if not value then break end
        buffer, bits = buffer * 64 + value, bits + 6
        if bits >= 8 then
            bits = bits - 8
            bytes[#bytes + 1] = math.floor(buffer / 2 ^ bits) % 256
            buffer = buffer % 2 ^ bits
        end
    end
    local offset = 3
    while offset + 8 <= #bytes and bytes[offset] == 255 do
        local marker = bytes[offset + 1]
        local length = bytes[offset + 2] * 256 + bytes[offset + 3]
        if marker == 192 or marker == 194 then
            return bytes[offset + 5] * 256 + bytes[offset + 6] == SkyPhoneProp.Height
                and bytes[offset + 7] * 256 + bytes[offset + 8] == SkyPhoneProp.Width
        end
        if length < 2 then return false end
        offset = offset + 2 + length
    end
    return false
end
