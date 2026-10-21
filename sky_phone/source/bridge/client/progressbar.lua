-- Cancellable provider contracts copied from Sky Base
-- 43cec3f6080a3e23f4e31f3341afc2bb22355dca. Animations remain native.
Bridge.Progressbar = {}
local active
local unsupported_msk_version
local blocked_controls = { 21, 22, 23, 24, 25, 30, 31, 75, 140, 141, 142 }
local providers = {
    {
        resource = "codem-supreme-hud",
        start = function(data, finish)
            if exports["codem-supreme-hud"]:isDoingSomething() then finish(true) return end
            exports["codem-supreme-hud"]:Progress(data,
                function() finish(false) end, function() finish(true) end)
        end,
        cancel = function() exports["codem-supreme-hud"]:CancelProgress() end,
    },
    {
        resource = "17mov_Hud",
        start = function(data, finish)
            exports["17mov_Hud"]:StartProgress(data, nil, nil, finish)
        end,
        cancel = function() exports["17mov_Hud"]:StopProgress() end,
    },
    {
        resource = "risk-notify",
        start = function(data, finish)
            exports["risk-notify"]:startProgress(data.duration, data.label, {
                freeze = false, onFinish = function() finish(false) end,
                onCancel = function() finish(true) end,
            })
        end,
        cancel = function() exports["risk-notify"]:cancelProgress() end,
    },
    {
        resource = "lation_ui",
        start = function(data, finish) finish(not exports.lation_ui:progressBar(data)) end,
        cancel = function()
            if exports.lation_ui:progressActive() then exports.lation_ui:cancelProgress() end
        end,
    },
    {
        resource = "prism_uipack",
        start = function(data, finish) finish(not exports.prism_uipack:ProgressBar(data)) end,
        cancel = function()
            if exports.prism_uipack:ProgressActive() then exports.prism_uipack:CancelProgress() end
        end,
    },
    {
        resource = "msk_core", minimum_version = { 4, 1 },
        start = function(data, finish) finish(not exports.msk_core:Progressbar(data)) end,
        cancel = function() exports.msk_core:ProgressStop() end,
    },
    {
        resource = "esx_progressbar",
        start = function(data, finish)
            local started = exports.esx_progressbar:Progressbar(data.label, data.duration, {
                FreezePlayer = false, onFinish = function() finish(false) end,
                onCancel = function() finish(true) end,
            })
            if started == false then finish(true) end
        end,
        cancel = function() exports.esx_progressbar:CancelProgressbar() end,
    },
    {
        resource = "ox_lib",
        start = function(data, finish)
            if exports.ox_lib:progressActive() then finish(true) return end
            finish(not exports.ox_lib:progressBar(data))
        end,
        cancel = function()
            if exports.ox_lib:progressActive() then exports.ox_lib:cancelProgress() end
        end,
    },
    {
        resource = "progressbar",
        start = function(data, finish)
            if exports.progressbar:isDoingSomething() then finish(true) return end
            exports.progressbar:Progress(data, finish)
        end,
        cancel = function() TriggerEvent("progressbar:client:cancel") end,
    },
    {
        resource = "mythic_progbar",
        start = function(data, finish) exports.mythic_progbar:Progress(data, finish) end,
        cancel = function() TriggerEvent("mythic_progbar:client:cancel") end,
    },
}

-- HEX has no completion callback; its documented duration controls completion.
for _, resource in ipairs({ "hex_4_hud", "hex_2_hud", "hex_final_hud", "hex_finalhud_v2",
    "hex_future_hud", "hex_genesis_hud", "hex_hud_prem" }) do
    providers[#providers + 1] = {
        resource = resource, timed = true,
        start = function(data) exports[resource]:StartProgressbar(data.duration, data.label) end,
        cancel = function() exports[resource]:StopProgressbar() end,
    }
end

local function stop_animation(request)
    if request.playing then
        StopAnimTask(request.ped, request.animation.dict, request.animation.clip, 2.0)
        request.playing = false
    end
    RemoveAnimDict(request.animation.dict)
end

function Bridge.Progressbar.Cancel()
    local request = active
    if not request or request.done then return end
    -- Set cancellation before calling providers such as 17mov, whose stop
    -- callback reports completion. A late callback must never undo this.
    request.done, request.cancelled = true, true
    stop_animation(request)
    if request.started and request.provider then request.provider.cancel() end
end

-- Yields until completion; true means completed, false means cancelled.
-- valid() belongs to the caller and checks the target/state/proximity.
function Bridge.Progressbar.Run(data)
    if active then
        print("[sky_phone] Progress rejected: another Phone progress action is active.")
        return false
    end
    local request = { ped = PlayerPedId(), animation = data.animation }
    active = request
    for _, provider in ipairs(providers) do
        if GetResourceState(provider.resource) == "started" then
            local supported = true
            if provider.minimum_version then
                local version = GetResourceMetadata(provider.resource, "version", 0) or ""
                local major, minor = version:match("(%d+)%.(%d+)")
                major, minor = tonumber(major), tonumber(minor)
                supported = major and (major > 4 or major == 4 and minor >= 1)
                if not supported and unsupported_msk_version ~= version then
                    unsupported_msk_version = version
                    print(("[sky_phone] Skipping msk_core progress: version '%s' requires an upgrade to 4.1+."):format(version))
                end
            end
            if supported then request.provider = provider break end
        end
    end
    local function finish(cancelled)
        if request.done then return end
        request.done, request.cancelled = true, cancelled == true
    end
    local ok, failure = xpcall(function()
        RequestAnimDict(data.animation.dict)
        local deadline = GetGameTimer() + 10000
        while not HasAnimDictLoaded(data.animation.dict) do
            if request.done or not data.valid() then Bridge.Progressbar.Cancel() return end
            if GetGameTimer() >= deadline then
                error("[sky_phone] Progress animation dictionary failed to load: " .. data.animation.dict)
            end
            Wait(0)
        end
        if request.done or not data.valid() then Bridge.Progressbar.Cancel() return end
        TaskPlayAnim(request.ped, data.animation.dict, data.animation.clip, 3.0, 2.0, -1, 1, 0.0, false, false, false)
        request.playing = true
        local started_at = GetGameTimer()
        if request.provider then
            CreateThread(function()
                if request.done then return end
                request.started = true
                local started, start_error = xpcall(function()
                    request.provider.start({ name = "sky_phone_tower", label = data.label,
                        duration = data.duration, canCancel = true, useWhileDead = false,
                        disable = {}, controlDisables = {} }, finish)
                end, debug.traceback)
                if not started then
                    request.failure = start_error
                    finish(true)
                end
            end)
        end
        while not request.done do
            if not data.valid() or PlayerPedId() ~= request.ped or IsEntityDead(request.ped)
                or IsPedInAnyVehicle(request.ped, false) or IsControlJustReleased(0, 73) then
                Bridge.Progressbar.Cancel()
                break
            end
            -- Keep movement/combat from interrupting the native work animation.
            -- X remains available; controls restore automatically next frame.
            for _, control in ipairs(blocked_controls) do
                DisableControlAction(0, control, true)
            end
            local elapsed = GetGameTimer() - started_at
            if not request.provider then
                local fraction = math.min(elapsed / data.duration, 1.0)
                DrawRect(0.5, 0.88, 0.24, 0.012, 20, 20, 20, 210)
                DrawRect(0.38 + 0.12 * fraction, 0.88, 0.24 * fraction, 0.012, 70, 140, 220, 240)
                SetTextFont(0)
                SetTextScale(0.0, 0.32)
                SetTextColour(255, 255, 255, 255)
                SetTextCentre(true)
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(data.label)
                EndTextCommandDisplayText(0.5, 0.84)
            end
            Bridge.HelpNotify.Show(data.cancelLabel, "X", "progressbar")
            if (not request.provider or request.provider.timed) and elapsed >= data.duration then finish(false) end
            Wait(0)
        end
        if request.failure then error(request.failure) end
    end, debug.traceback)
    if not ok then Bridge.Progressbar.Cancel() end
    stop_animation(request)
    Bridge.HelpNotify.Hide("progressbar")
    active = nil
    if not ok then
        print(failure)
        return false, "request_failed"
    end
    return not request.cancelled
end

AddEventHandler("onResourceStop", function(resource)
    if not active then return end
    if resource == GetCurrentResourceName() then
        Bridge.Progressbar.Cancel()
    elseif active.provider and resource == active.provider.resource then
        -- Provider exports have already expired.
        active.started = false
        Bridge.Progressbar.Cancel()
    end
end)
