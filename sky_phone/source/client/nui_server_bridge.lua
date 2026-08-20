local callback_groups = {
    account = [[login register logout devices remove-device]],
    admin = [[
        bootstrap player save-apps reveal-password activity
        reset-passcode change-number factory-reset
    ]],
    banking = [[overview transfer]],
    billing = [[overview list detail markRead pay dispute]],
    calendar = [[list create update delete]],
    calls = [[recents dial answer set-speaker set-muted decline hangup block]],
    citywarn = [[bootstrap publish update resolve]],
    companies = [[
        list get my-requests get-request work-context work-queue list-members
        create-request cancel-request send-message claim-request assign-request update-request-status
        update-availability update-profile update-hours update-services publish-announcement
        set-call-availability call-customer dial-service-line
    ]],
    contacts = [[list save delete favorite]],
    crewlink = [[
        bootstrap login register logout update-profile create-group update-group delete-group set-active
        join-code rotate-code nearby invite-nearby respond-invite update-member transfer-owner
        remove-member leave create-ping remove-ping
    ]],
    crypto = [[
        bootstrap register login logout quote execute deposit withdraw update-profile recipient transfer
    ]],
    ["custom-app"] = [[storage:get storage:set]],
    darkchat = [[
        bootstrap create-profile delete-profile update-profile start thread send media react
        message-action update-conversation add-contact remove-contact block report clear
    ]],
    device = [[save notification-open factory-reset]],
    easyshare = [[bootstrap own-contact set-visibility request respond cancel]],
    feather = [[
        bootstrap create-profile update-profile feed explore network create-post react follow connections
        remove-connection profile bookmarks thread activities mark-activities delete block report
    ]],
    flare = [[bootstrap delete-profile save-profile set-discovery swipe rewind unmatch thread send]],
    fliptok = [[
        register login logout bootstrap feed video discover music-metadata publish react follow
        comments comment comment-react view share profile connections update-profile activities
        mark-activities report admin-reports admin-resolve-report block delete
    ]],
    gallery = [[list counts favorite]],
    mail = [[
        register login logout counts mailboxes create-mailbox delete-mailbox list get get-draft
        save-draft delete-draft delete-many send set-read move trash restore delete-forever empty-trash
    ]],
    map = [[markers create-marker delete-marker]],
    marketplace = [[
        list profile auth profile-save get list-own create update set-status favorite counts
        list-inquiries get-inquiry send-message make-offer respond-offer report block
    ]],
    media = [[config import:sources import:list import:commit import:url]],
    memos = [[list update delete]],
    messages = [[conversations thread send media delete gifs]],
    music = [[
        bootstrap add-youtube remove-youtube create-playlist rename-playlist delete-playlist
        add-to-playlist remove-from-playlist
    ]],
    notes = [[list create update delete]],
    notifications = [[save]],
    pages = [[
        list get profile profile-save list-own create share-citymarkt react delete
    ]],
    picstagram = [[
        register login logout bootstrap feed post explore search saved profile connections update-profile
        publish-post update-post set-post-status react follow respond-follow comments comment comment-react
        remove-comment publish-story stories view-story story-viewers remove-story activities mark-activities
        block report admin-reports admin-resolve-report
    ]],
    security = [[unlock set-passcode change-passcode disable-passcode]],
    sim = [[insert eject]],
    ["weazel-news"] = [[context list get manage-list create update delete]],
}

for namespace, endpoints in pairs(callback_groups) do
    for endpoint in endpoints:gmatch("%S+") do
        local callback_name = namespace .. ":" .. endpoint
        RegisterNUICallback(callback_name, function(data, cb)
            if type(data) ~= "table" then
                cb({ success = false, error = "invalid_request" })
                return
            end

            local result = Bridge.Callbacks.Trigger("sky_phone:" .. callback_name, data)
            if callback_name:match("^media:import:") and (not result or not result.success) then
                Bridge.Debug(
                    "warn",
                    "[sky_phone] NUI callback '%s' failed: %s.",
                    callback_name,
                    tostring(result and result.error or "no server response"),
                    { always = true }
                )
            end
            if type(result) == "table" then
                cb(result)
                return
            end

            cb({ success = false, error = "request_failed" })
        end)
    end
end
