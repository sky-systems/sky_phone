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
    -- The outer glass/camera reaches Y=-0.00471; keep the overlay 0.79 mm in front.
    Screen = { width = 0.0736, height = 0.1589, y = -0.0055, radius = 0.0081 },
}
for frame in pairs(SkyPhoneProp.Frames) do
    SkyPhoneProp.Models[joaat(frame == "black" and "sky_phone_prop" or "sky_phone_prop_" .. frame)] = true
end
SkyPhoneProp.Models[joaat("sky_phone_prop_burgundy")] = true

function SkyPhoneProp.DisplayEnabled()
    return type(Config) == "table" and type(Config.Animations) == "table"
        and Config.Animations.WorldDisplayEnabled == true
end

function SkyPhoneProp.Model(frame, configured)
    if not SkyPhoneProp.Models[joaat(configured)] then return configured end
    if configured == "sky_phone_prop_burgundy" then return configured end
    local selected = SkyPhoneProp.Frames[frame] and frame or "black"
    return selected == "black" and SkyPhoneProp.DefaultModel or "sky_phone_prop_" .. selected
end

-- Read the SOF header before forwarding client-provided compressed images.
local base64_values = {}
local base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, #base64_alphabet do
    base64_values[base64_alphabet:sub(i, i)] = i - 1
end

function SkyPhoneProp.ValidFrame(jpeg)
    if type(jpeg) ~= "string" or #jpeg < 100 or #jpeg > SkyPhoneProp.MaxFrameBytes
        or not jpeg:match("^data:image/jpeg;base64,/9j/[A-Za-z0-9+/=]+$") then return false end
    local bytes, buffer, bits, offset = {}, 0, 0, 3
    for i = 24, math.min(#jpeg, 24 + 4095) do
        local value = base64_values[jpeg:sub(i, i)]
        if not value then break end
        buffer, bits = buffer * 64 + value, bits + 6
        if bits >= 8 then
            bits = bits - 8
            bytes[#bytes + 1] = math.floor(buffer / 2 ^ bits) % 256
            buffer = buffer % 2 ^ bits
            if #bytes >= offset + 3 then
                if bytes[offset] ~= 255 then return false end
                local marker = bytes[offset + 1]
                local length = bytes[offset + 2] * 256 + bytes[offset + 3]
                if length < 2 then return false end
                if marker == 192 or marker == 194 then
                    if #bytes >= offset + 8 then
                        return bytes[offset + 5] * 256 + bytes[offset + 6] == SkyPhoneProp.Height
                            and bytes[offset + 7] * 256 + bytes[offset + 8] == SkyPhoneProp.Width
                    end
                else
                    offset = offset + 2 + length
                end
            end
        end
    end
    return false
end
