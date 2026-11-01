local server_bridge = SkyPhoneCompatibilityServer

AddEventHandler("sky_phone:server:phoneNumberChanged", function(player_source, phone_number)
    TriggerEvent("lb-phone:numberChanged", player_source, phone_number)
end)

AddEventHandler("sky_phone:server:phoneNumberGenerated", function(player_source, phone_number)
    TriggerEvent("lb-phone:phoneNumberGenerated", player_source, phone_number)
end)

AddEventHandler("sky_phone:server:factoryReset", function(player_source, phone_number)
    TriggerEvent("lb-phone:factoryReset", player_source, phone_number)
end)

AddEventHandler("sky_phone:server:galleryMediaDeleted", function(player_source, phone_number, link)
    TriggerEvent("lb-phone:deletedFromGallery", player_source, phone_number, link)
end)

local function notify_compatibility_ready()
    Bridge.Debug(
        "debug",
        "[sky_phone] Phone compatibility server exports are ready.",
        { always = true }
    )
    TriggerEvent("sky_phone:server:compatReady")
end

server_bridge.AfterPhoneReady(notify_compatibility_ready)
