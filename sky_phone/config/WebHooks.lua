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

    -- Bounded in-memory delivery queue; no database migration is required.
    QueueLimit = 1000, -- Discord messages, including continuation parts
    MaxAttempts = 5, -- retry rate limits, network errors and Discord 5xx responses
}
