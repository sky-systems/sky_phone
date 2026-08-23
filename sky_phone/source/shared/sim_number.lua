SkyPhoneSimNumber = {}

function SkyPhoneSimNumber.ValidateConfiguration(length, prefix)
    if type(length) ~= "number" or length ~= math.floor(length) or length < 1 or length > 24 then
        return false, "NumberLength must be a whole number between 1 and 24"
    end
    if type(prefix) ~= "string" or prefix:find("%D") then
        return false, "NumberPrefix must contain digits only"
    end
    if #prefix > length then
        return false, "NumberPrefix cannot be longer than NumberLength"
    end
    return true
end

function SkyPhoneSimNumber.Normalize(value, length, prefix)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    if not SkyPhoneSimNumber.ValidateConfiguration(length, prefix) then
        return nil
    end
    local number = tostring(value):gsub("%D", "")
    if #number ~= length or number:sub(1, #prefix) ~= prefix then
        return nil
    end
    return number
end

function SkyPhoneSimNumber.NormalizeService(value, maximum_length)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    local number = tostring(value):gsub("%D", "")
    if number == "" or #number > maximum_length then
        return nil
    end
    return number
end

function SkyPhoneSimNumber.FromEntropy(entropy, length, prefix)
    if type(entropy) ~= "string" or entropy == "" then
        return nil
    end
    if not SkyPhoneSimNumber.ValidateConfiguration(length, prefix) then
        return nil
    end
    local source = entropy:gsub("%D", "")
    if source == "" then
        return nil
    end
    local number = prefix
    local index = 1
    while #number < length do
        number = number .. source:sub(index, index)
        index = index + 1
        if index > #source and #number < length then
            index = 1
        end
    end
    return number
end

function SkyPhoneSimNumber.Format(value, groups, length, prefix)
    local number = SkyPhoneSimNumber.Normalize(value, length, prefix)
    if not number then
        return tostring(value or "")
    end
    local formatted = {}
    local offset = 1
    for _, group_length in ipairs(groups) do
        formatted[#formatted + 1] = number:sub(offset, offset + group_length - 1)
        offset = offset + group_length
    end
    if offset <= #number then
        formatted[#formatted + 1] = number:sub(offset)
    end
    return table.concat(formatted, " ")
end

function SkyPhoneSimNumber.Reserve(entropy, accept, length, prefix)
    for _ = 1, 20 do
        local candidate = SkyPhoneSimNumber.FromEntropy(entropy(), length, prefix)
        if candidate and accept(candidate) then
            return candidate
        end
    end
    return nil
end
