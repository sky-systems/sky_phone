local weather_types = {
    [joaat("EXTRASUNNY")] = "sunny",
    [joaat("CLEAR")] = "clear",
    [joaat("CLOUDS")] = "partly_cloudy",
    [joaat("OVERCAST")] = "cloudy",
    [joaat("RAIN")] = "rain",
    [joaat("CLEARING")] = "rain",
    [joaat("THUNDER")] = "thunder",
    [joaat("SMOG")] = "fog",
    [joaat("FOGGY")] = "fog",
    [joaat("NEUTRAL")] = "cloudy",
    [joaat("SNOW")] = "snow",
    [joaat("BLIZZARD")] = "snow",
    [joaat("SNOWLIGHT")] = "snow",
    [joaat("XMAS")] = "snow",
    [joaat("HALLOWEEN")] = "cloudy",
}

local function weather_region(coords)
    if coords.x > 2500.0 and coords.y < -3000.0 then
        return "cayo_perico"
    end
    if coords.y > 900.0 then
        return "blaine_county"
    end
    return "los_santos"
end

RegisterNUICallback("weather:get", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local weather_hash = GetPrevWeatherTypeHashName()
    local next_weather_hash = GetNextWeatherTypeHashName()
    cb({
        success = true,
        data = {
            condition = weather_types[weather_hash] or "clear",
            nextCondition = weather_types[next_weather_hash] or weather_types[weather_hash] or "clear",
            region = weather_region(coords),
            clock = {
                year = GetClockYear(),
                month = GetClockMonth() + 1,
                day = GetClockDayOfMonth(),
                hour = GetClockHours(),
                minute = GetClockMinutes(),
            },
            windSpeed = math.max(0.0, GetWindSpeed()),
            rainLevel = math.max(0.0, math.min(1.0, GetRainLevel())),
        },
    })
end)
