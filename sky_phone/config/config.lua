Config.Bridge = {
    Framework = "auto", -- auto, esx, qbox, qb
    Inventory = "auto", -- auto, ox, qb, lj, qs, codem, core, mf
    Locale = "en",
    CallbackTimeout = 5000,
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
