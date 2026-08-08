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

Config.Security = {
    PasscodePepperConvar = "sky_phone_passcode_pepper",
    MaximumAttempts = 5,
    LockSeconds = 30,
    AttemptsPerMinute = 12,
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

Config.Radio = {
    VoiceProvider = "auto", -- auto, yaca, pma, saltychat
    DefaultVolume = 50,
    HistoryLimit = 8,
    FrequencyMin = 0.1,
    FrequencyMax = 999.9,
    FrequencyDecimals = 1,
    AllowSecondary = true,
    Notifications = false,
    AutoRejoin = false,
    DisplayName = {
        Enabled = true,
        MaxLength = 32,
        AllowedJobs = { -- Job name = minimum grade. Unlisted jobs cannot set a radio display name.
            police = 0,
            sheriff = 0,
            fib = 0,
            army = 0,
            ambulance = 0,
        },
    },
    Hud = {
        Enabled = true,
        SpeakerPersistMilliseconds = 3000,
        Position = {
            Horizontal = "right", -- left or right
            Vertical = "top", -- top or bottom
            HorizontalOffset = 2.0, -- vh
            VerticalOffset = 30.0, -- vh
        },
    },
    Badge = {
        Enabled = true,
        MaxLength = 8,
        ForbiddenPatterns = { "88", "1488", "18", "14", "28", "198" },
    },
    LockedChannels = {
        {
            range = { 0.1, 100.0 },
            jobs = {
                police = true,
                sheriff = true,
                fib = true,
                army = true,
                ambulance = true,
            },
        },
    },
}

Config.Animations = {
    Enabled = true,
    PropModel = "prop_npc_phone_02",
    PropBone = 28422,
    LoadTimeoutMs = 5000,
    ContextPollMs = 250,
    Dictionaries = {
        OnFoot = "cellphone@",
        Driver = "anim@cellphone@in_car@ds",
        Passenger = "anim@cellphone@in_car@ps",
        Selfie = "anim@mp_player_intuppertake_selfie",
    },
    Clips = {
        TextIn = "cellphone_text_in",
        TextRead = "cellphone_text_read_base",
        TextOut = "cellphone_text_out",
        TextToCall = "cellphone_text_to_call",
        CallListen = "cellphone_call_listen_base",
        CallToText = "cellphone_call_to_text",
        CallOut = "cellphone_call_out",
        Selfie = "idle_a",
    },
    Transforms = {
        Portrait = {
            position = { x = 0.0, y = 0.0, z = 0.0 },
            rotation = { x = 0.0, y = 0.0, z = 0.0 },
        },
        Landscape = {
            position = { x = 0.0, y = 0.0, z = 0.0 },
            rotation = { x = 0.0, y = 0.0, z = 90.0 },
        },
    },
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

Config.Garage = {
    System = "auto", -- auto, custom, esx, qb, qbox, ak47, bp, cd, codem, ds-servercreator, hex, jg, my, okok, op, quasar, rx, vms, ws, zyke_garages
    MaximumVehicles = 250,
    RequestsPerMinute = 30,
    Custom = {
        Table = "",
        OwnerColumn = "",
    },
    Valet = {
        Enabled = true,
        Price = 750,
        Account = "bank", -- bank or cash
        RequestsPerMinute = 3,
        CooldownSeconds = 60,
        TimeoutSeconds = 180,
        SpawnDistance = 110.0,
        ArrivalDistance = 14.0,
        DriveSpeed = 20.0,
        DrivingStyle = 786603,
        DriverModel = "s_m_m_autoshop_01",
        -- The current valet driver route supports road vehicles. Keep non-road types disabled.
        VehicleTypes = {
            car = true,
            bike = true,
            boat = false,
            plane = false,
            helicopter = false,
        },
    },
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
