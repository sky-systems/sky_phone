-- SERVER ONLY. Never add this file to shared_scripts, client_scripts or files.
-- These are administrative audit channels: messages and private app content are logged.
-- Paste a different Discord webhook URL into each category you want to enable.
-- "" uses Default; false disables the category even when Default is configured.
-- Phonepanel > Webhooks can store server-only SQL overrides (including AvatarUrl).
-- Select "File setting" in Phonepanel to use this file again for an endpoint.
WebHooks = {
    Enabled = true,
    Username = "Sky Phone",
    AvatarUrl = "", -- Optional HTTPS image URL for all webhook messages
    -- Public posts use their app icon; AvatarUrl remains the admin webhook avatar.
    FooterIconUrl = "https://avatars.githubusercontent.com/u/94749467?v=4",
    FeatherIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/2fc93a3c7c799277039d40c8dec34e83b5c92533/frontend/src/assets/img/app-icons/feather.webp",
    PagesIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/2fc93a3c7c799277039d40c8dec34e83b5c92533/frontend/src/assets/img/app-icons/local-pages.webp",
    MarketplaceIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/2fc93a3c7c799277039d40c8dec34e83b5c92533/frontend/src/assets/img/app-icons/citymarkt.webp",
    PicstagramIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/2fc93a3c7c799277039d40c8dec34e83b5c92533/frontend/src/assets/img/app-icons/picstagram.webp",
    FlipTokIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/2fc93a3c7c799277039d40c8dec34e83b5c92533/frontend/src/assets/img/app-icons/fliptok.webp",
    SkyPicIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/89982508ca4e1ee14cf32bba52b3664b70127aea/frontend/src/assets/img/app-icons/skypic.jpg",
    WeazelNewsIconUrl = "https://raw.githubusercontent.com/sky-systems/sky_phone/2fc93a3c7c799277039d40c8dec34e83b5c92533/frontend/src/assets/img/app-icons/weazel-news.webp",
    VideoMaxBytes = 20971520,
    Default = "",

    Calls = "",
    Contacts = "",
    Messages = "",
    Picstagram = "",
    Feather = "",
    FlipTok = "",
    SkyPic = "",
    DarkChat = "",
    Flare = "",
    Mail = "",
    Marketplace = "",
    Pages = "",
    Companies = "",
    Banking = "",
    Crypto = "",
    Billing = "",
    Uploads = "",
    Gallery = "",
    Memos = "",
    Notes = "",
    Calendar = "",
    WeazelNews = "",
    CityWarn = "",
    CrewLink = "",
    SkyRide = "",
    Radio = "",
    Garage = "",
    Housing = "",
    Health = "",
    Music = "",
    Map = "",
    EasyShare = "",
    Account = "",
    Device = "",
    Security = "",
    Sim = "",
    Admin = "",
    CustomApps = "",

    -- Optional separate channels for individual actions (without sky_phone:).
    -- Example: ["skypic:send-snap"] = "", ["calls:ended"] = false.
    Actions = {},

    -- Player-facing announcements. These NEVER inherit administrative URLs above.
    -- Only public posts/stories/listings are announced; private activity is admin-only.
    Public = {
        Default = "",
        Feather = "",
        Pages = "", -- Local Pages
        Marketplace = "", -- CityMarkt
        Picstagram = "",
        FlipTok = "",
        SkyPic = "",
        WeazelNews = "",
        Actions = {}, -- Optional per-action overrides, e.g. ["feather:create-post"] = ""
    },

    -- Bounded in-memory delivery queue (shared by admin/public destinations).
    QueueLimit = 1000, -- Discord messages, including continuation parts
    MaxAttempts = 5, -- retry rate limits, network errors and Discord 5xx responses
}
