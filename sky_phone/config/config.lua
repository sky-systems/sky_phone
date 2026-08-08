Config.Bridge = {
    Framework = "auto", -- auto, esx, qbox, qb
    Inventory = "auto", -- auto, ox, qb, lj, qs, codem, core, mf, smx
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
    Item = "phone",
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

Config.DarkChat = {
    AliasMaxLength = 32,
    BodyMaxLength = 2000,
    ThreadPageSize = 200,
    SendsPerMinute = 30,
    ActionsPerMinute = 60,
    ReportsPerDay = 10,
    VoiceMaxDurationMs = 60000,
    VoiceMaxBase64Length = 360000,
    VoiceWaveformSamples = 48,
    CleanupIntervalSeconds = 30,
    AllowedDisappearTimers = {
        [0] = true,
        [-1] = true, -- after reading
        [60] = true,
        [300] = true,
        [3600] = true,
        [86400] = true,
        [604800] = true,
    },
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

Config.Banking = {
    Currency = "$",
    MinimumAmount = 1,
    MaximumAmount = 1000000,
    ActionsPerMinute = 12,
    HistoryLimit = 50,
}

Config.Marketplace = {
    PageSize = 20,
    MessagePageSize = 50,
    OfferHistorySize = 50,
    MaxActiveListings = 15,
    MaxImages = 6,
    TitleMinLength = 5,
    TitleMaxLength = 70,
    DescriptionMinLength = 20,
    DescriptionMaxLength = 2000,
    MessageMaxLength = 1000,
    MaximumPrice = 100000000,
    ListingLifetimeDays = 7,
    Categories = {
        "vehicles",
        "property",
        "electronics",
        "clothing",
        "tools",
        "leisure",
        "services",
        "jobs",
        "wanted",
        "other",
    },
    Districts = {
        "los_santos",
        "vinewood",
        "vespucci",
        "south_los_santos",
        "sandy_shores",
        "paleto_bay",
        "blaine_county",
    },
    PhotoGradients = {
        "linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)",
        "linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)",
        "linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)",
        "linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)",
        "linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)",
        "linear-gradient(150deg, #00c9a7, #4d8076 46%, #1f3a5f)",
        "linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)",
    },
}

Config.LocalPages = {
    PageSize = 20,
    MaxImages = 6,
    TitleMinLength = 5,
    TitleMaxLength = 80,
    BodyMinLength = 10,
    BodyMaxLength = 1500,
    Categories = { "recommendation", "wanted", "service", "event", "place", "community" },
    CityMarktSharesPerDay = 1,
}

Config.Calendar = {
    TitleMaxLength = 120,
    NoteMaxLength = 2000,
    MaximumDurationSeconds = 7 * 24 * 60 * 60,
    MaximumQuerySeconds = 370 * 24 * 60 * 60,
    PastEditSeconds = 365 * 24 * 60 * 60,
    FutureSeconds = 5 * 365 * 24 * 60 * 60,
    ReminderPollSeconds = 15,
}
