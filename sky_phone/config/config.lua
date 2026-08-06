Config.Bridge = {
    Framework = "auto", -- auto, esx, qbox, qb
    Inventory = "auto", -- auto, ox, qb, lj, qs, codem, core, mf
    Locale = "en",
    CallbackTimeout = 15000,
    Debug = false,
    DebugLevels = {
        info = true,
        warn = true,
        error = true,
    },
}

Config.Command = "phone"

Config.Phone = {
    Item = "sky_phone",
    DevelopmentCommand = false,
    DeviceName = "iFruit Phone",
}

Config.Sim = {
    RegisteredItem = "sky_phone_sim_registered",
    AnonymousItem = "sky_phone_sim_anonymous",
    NumberLength = 10,
    NumberPrefix = "",
    NumberGroups = { 3, 3, 4 },
}

Config.Calls = {
    VoiceProvider = "pma",
    RingSeconds = 30,
    ContactNameMaxLength = 80,
    RecentPageSize = 100,
}

Config.Messages = {
    BodyMaxLength = 2000,
    ConversationScanLimit = 1000,
    ThreadPageSize = 200,
    SendsPerMinute = 30,
    MediaLoadsPerMinute = 120,
    VoiceMaxDurationMs = 30000,
    VoiceMaxBase64Length = 180000,
    VoiceWaveformSamples = 48,
    VideoMaxDurationMs = 30000,
    DeleteBatchSize = 20,
}

Config.Media = {
    GiphyApiKey = "",
    GifPageSize = 24,
    GifRating = "pg-13",
    UrlMaxLength = 2048,
    AllowedGifHosts = { "giphy.com" },
}

Config.Mail = {
    Domain = "ifruit.com",
    LocalPartMinLength = 3,
    LocalPartMaxLength = 32,
    PasswordMinLength = 6,
    PasswordMaxLength = 64,
    SubjectMaxLength = 120,
    BodyMaxLength = 20000,
    MaxRecipients = 10,
    PageSize = 50,
    AuthAttemptsPerMinute = 5,
}
