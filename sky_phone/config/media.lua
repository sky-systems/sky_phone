--[[
    Sky Phone media configuration

    This file is loaded on the server only. Keep API keys private. When the
    phone configurator is enabled in config.lua, the active media configuration
    is loaded from SQL and frontend builds copy the shipped values from this
    file into source/shared/config_default.lua.
]]

Config.Media = {
    -- Create or sign in to an account at https://developers.giphy.com/, open
    -- the Developer Dashboard, choose "Create an API Key", and paste it here.
    GiphyApiKey = "",
    GifPageSize = 24,
    GifRating = "pg-13",
    UrlMaxLength = 2048,
    AllowedGifHosts = { "giphy.com" },

    -- Create or sign in at https://fivemanage.com/, create or select your team,
    -- then open Dashboard > Tokens and create a token with Media access. Keep
    -- this server-only token private and paste it here.
    FiveManage = {
        ApiKey = "",
        BaseUrl = "https://api.fivemanage.com/api/v3/file",
        RequestTimeoutMs = 10000,
        UploadTimeoutMs = 25000,
    },

    Import = {
        Enabled = true,
        PageSize = 30,
        MaxSelection = 10,
        MaxPhotoBytes = 15 * 1024 * 1024,
        MaxVideoBytes = 150 * 1024 * 1024,
        RevalidateAfterSeconds = 3600,
        ListActionsPerMinute = 60,
        ImportActionsPerMinute = 20,
        CandidateTtlSeconds = 300,
        ManifestCacheSeconds = 30,
        ManifestMaxBytes = 2 * 1024 * 1024,
        ManifestMaxItems = 5000,

        Websites = {
            {
                Id = "fivemanage",
                Label = "FiveManage",
                Enabled = true,
                Adapter = "fivemanage",
                Path = "sky_phone/imports",
                MediaTypes = { "photo", "video" },
                -- Direct Gallery links must use one of these hosts or a subdomain.
                AllowedMediaHosts = { "fivemanage.com" },
            },

            --[[
            {
                Id = "city_media",
                Label = "City Media",
                Enabled = true,
                Adapter = "manifest",
                ManifestUrl = "https://media.example.com/sky-phone/media.json",
                MediaTypes = { "photo", "video" },
                AllowedMediaHosts = { "media.example.com", "cdn.example.com" },
                Auth = {
                    Type = "bearer",
                    TokenConvar = "sky_phone_city_media_token",
                },
                RequiredAce = "sky_phone.import.city_media",
            },
            ]]
        },
    },

    Wallpaper = {
        -- Shows the verified HTTPS media import directly in the wallpaper picker.
        -- Camera and Photos wallpaper sources are not affected by this setting.
        CustomUploadEnabled = true,
    },

    Photo = {
        Encoding = "jpg",
        Quality = 0.95,
    },

    Video = {
        BitrateKbps = 1500,
    },

    UploadSessionTimeoutMs = 60000,
    PageSize = 30,
}
