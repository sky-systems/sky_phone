-- Provider contracts copied from Sky Base 43cec3f6080a3e23f4e31f3341afc2bb22355dca.
-- Standalone Phone bridge: no Sky runtime dependency.

Bridge.HelpNotify = {}
local providers = {}
local selected, selected_resource
local last_message, last_key, last_owner, serial

providers["codem-supreme-hud"] = {
    show = function(message, key, shown)
        exports["codem-supreme-hud"]:ShowTextUI(message, { key = key })
    end,
    hide = function()
        exports["codem-supreme-hud"]:HideTextUI()
    end,
}

providers["codem-textui"] = {
    show = function(message, key, shown)
        exports["codem-textui"]:OpenTextUI(message, key, "thema-1")
    end,
    hide = function()
        exports["codem-textui"]:CloseTextUI()
    end,
}

providers["17mov_Hud"] = {
    show = function(message, key, shown)
        exports["17mov_Hud"]:ShowHelpNotification("[" .. key .. "] " .. message)
    end,
    hide = function()
        exports["17mov_Hud"]:HideHelpNotification()
    end,
}

providers["prims_hud"] = {
    show = function(message, key, shown)
        exports.prims_hud:prims_keybind_show({ key = key, title = message, description = "" })
    end,
    hide = function()
        exports.prims_hud:prims_keybind_hide()
    end,
}

providers["aty_ui"] = {
    show = function(message, key, shown)
        exports["aty_ui"]:GetAtyUI().openTextUi(key, "", message, "blue")
    end,
    hide = function()
        exports["aty_ui"]:GetAtyUI().closeTextUi()
    end,
}

providers["brutal_textui"] = {
    show = function(message, key, shown)
        exports["brutal_textui"]:Open("[" .. key .. "] " .. message, "blue", 1, "left")
    end,
    hide = function()
        exports["brutal_textui"]:Close()
    end,
}

providers["lation_ui"] = {
    show = function(message, key, shown)
        exports.lation_ui:showText({
            description = message,
            keybind = key,
        })
    end,
    hide = function()
        exports.lation_ui:hideText()
    end,
}

providers["qs-textui"] = {
    show = function(message, key, shown)
        local text = "[" .. key .. "] " .. message
        if not shown then
            exports["qs-textui"]:displayTextUI(text, "left")
        else
            exports["qs-textui"]:changeText(text, "left")
        end
    end,
    hide = function()
        exports["qs-textui"]:hideTextUI()
    end,
}

providers["jg-textui"] = {
    show = function(message, key, shown)
        exports["jg-textui"]:DrawText("[" .. key .. "] " .. message)
    end,
    hide = function()
        exports["jg-textui"]:HideText()
    end,
}

providers["okokTextUI"] = {
    show = function(message, key, shown)
        exports["okokTextUI"]:Open("[" .. key .. "] " .. message, "darkblue", "left", false)
    end,
    hide = function()
        exports["okokTextUI"]:Close()
    end,
}

providers["wasabi_uikit"] = {
    show = function(message, key, shown)
        if not shown then
            exports.wasabi_uikit:OpenTextUI(message, key)
        else
            exports.wasabi_uikit:ChangeTextUI(message, key)
        end
    end,
    hide = function()
        exports.wasabi_uikit:CloseTextUI()
    end,
}

providers["esx_textui"] = {
    show = function(message, key, shown)
        exports["esx_textui"]:TextUI("[" .. key .. "] " .. message, "info")
    end,
    hide = function()
        exports["esx_textui"]:HideUI()
    end,
}

providers["msk_core"] = {
    show = function(message, key, shown)
        exports.msk_core:ShowTextUI({ key = key, text = message })
    end,
    hide = function()
        exports.msk_core:HideTextUI()
    end,
}

providers["qb"] = {
    show = function(message, key, shown)
        local text = "[" .. key .. "] " .. message
        if not shown then
            exports["qb-core"]:DrawText(text, "left")
        else
            exports["qb-core"]:ChangeText(text, "left")
        end
    end,
    hide = function()
        exports["qb-core"]:HideText()
    end,
}

providers["ox_lib"] = {
    show = function(message, key, shown)
        exports.ox_lib:showTextUI("[" .. key .. "] " .. message)
    end,
    hide = function()
        exports.ox_lib:hideTextUI()
    end,
}

providers.hex = {
    every_frame = true,
    show = function(message, key, shown, resource)
        exports[resource]:HelpNotify(message, key)
    end,
}
providers.zenit_hud = {
    every_frame = true,
    show = function(message, key)
        exports["zenit_hud"]:showInteractionThisFrame(key, message)
    end,
}
providers["risk-notify"] = {
    every_frame = true,
    show = function(message, key)
        exports["risk-notify"]:HelpNotify(key, message)
    end,
}
providers.ZSX_UIV2 = {
    show = function(message, key)
        if serial then exports["ZSX_UIV2"]:TextUI_Remove(serial, false) end
        serial = exports["ZSX_UIV2"]:TextUI(key, message)
    end,
    hide = function()
        exports["ZSX_UIV2"]:TextUI_Remove(serial, false)
        serial = nil
    end,
}
providers.native = {
    every_frame = true,
    show = function(message, key)
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName("[" .. key .. "] " .. message)
        EndTextCommandDisplayHelp(0, false, false, 1)
    end,
}

local priority = {
    { "zenit_hud", "zenit_hud" },
    { "hex_4_hud", "hex" },
    { "hex_2_hud", "hex" },
    { "hex_1_hud", "hex" },
    { "hex_final_hud", "hex" },
    { "hex_finalhud_v2", "hex" },
    { "hex_future_hud", "hex" },
    { "hex_genesis_hud", "hex" },
    { "hex_hud_prem", "hex" },
    { "codem-supreme-hud", "codem-supreme-hud" },
    { "codem-textui", "codem-textui" },
    { "17mov_Hud", "17mov_Hud" },
    { "ZSX_UIV2", "ZSX_UIV2" },
    { "prims_hud", "prims_hud" },
    { "aty_ui", "aty_ui" },
    { "risk-notify", "risk-notify" },
    { "brutal_textui", "brutal_textui" },
    { "lation_ui", "lation_ui" },
    { "qs-textui", "qs-textui" },
    { "jg-textui", "jg-textui" },
    { "okokTextUI", "okokTextUI" },
    { "wasabi_uikit", "wasabi_uikit" },
    { "esx_textui", "esx_textui" },
    { "msk_core", "msk_core" },
    { "qb-core", "qb" },
    { "ox_lib", "ox_lib" },

}

function Bridge.HelpNotify.Hide(owner)
    if owner and owner ~= last_owner then return end
    if last_message and selected.hide then selected.hide() end
    last_message, last_key, last_owner = nil, nil, nil
end

function Bridge.HelpNotify.Show(message, key, owner)
    if not selected then
        selected = providers.native
        for _, candidate in ipairs(priority) do
            if GetResourceState(candidate[1]) == "started" then
                selected, selected_resource = providers[candidate[2]], candidate[1]
                break
            end
        end
    end
    key = key or "E"
    if selected.every_frame or message ~= last_message or key ~= last_key then
        selected.show(message, key, last_message ~= nil, selected_resource)
        last_message, last_key = message, key
    end
    last_owner = owner
end

AddEventHandler("onClientResourceStart", function(resource)
    for _, candidate in ipairs(priority) do
        if candidate[1] == resource then
            Bridge.HelpNotify.Hide()
            selected, selected_resource = nil, nil
            break
        end
    end
end)
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        Bridge.HelpNotify.Hide()
    elseif resource == selected_resource then
        -- The provider has already stopped; do not call its expired exports.
        selected, selected_resource, last_message, last_key, last_owner, serial = nil, nil, nil, nil, nil, nil
    end
end)
