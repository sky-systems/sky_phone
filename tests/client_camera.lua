local callbacks = {}
local camera_coord = nil
local camera_target = nil
local camera_created = false
local camera_destroyed = false
local scripted_camera_rendering = false
local lb_camera_exports = {}

SkyPhoneCompatibility = {
    RegisterExportAlias = function(resource_name, export_name, handler)
        assert(resource_name == "lb-phone", "camera compatibility exports must target LB Phone")
        lb_camera_exports[export_name] = handler
    end,
}

local vector_meta = {}
vector_meta.__index = vector_meta

function vector_meta.__add(left, right)
    return vector3(left.x + right.x, left.y + right.y, left.z + right.z)
end

function vector_meta.__sub(left, right)
    return vector3(left.x - right.x, left.y - right.y, left.z - right.z)
end

function vector_meta.__mul(left, right)
    if type(left) == "number" then
        left, right = right, left
    end
    return vector3(left.x * right, left.y * right, left.z * right)
end

function vector3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, vector_meta)
end

function RegisterNUICallback(name, callback)
    callbacks[name] = callback
end

function RegisterNetEvent() end
function AddEventHandler() end
function TriggerEvent() end
function TriggerServerEvent() end
function SendNUIMessage() end
function CreateThread() end
function Wait() end
function PlayerPedId() return 7 end
function PlayerId() return 8 end
function GetFollowPedCamViewMode() return 1 end
function GetFollowVehicleCamViewMode() return 2 end
function IsRadarHidden() return false end
function DisplayRadar() end
function SetFollowPedCamViewMode() end
function SetFollowVehicleCamViewMode() end
function IsPedInAnyVehicle() return false end
function DisableControlAction() end
function DisablePlayerFiring() end
function HideHudAndRadarThisFrame() end
function GetCurrentResourceName() return "sky_phone" end

function GetEntityCoords()
    return vector3(10.0, 20.0, 1.0)
end

function GetPedBoneCoords()
    return vector3(10.0, 20.0, 2.7)
end

function GetEntityForwardVector()
    return vector3(0.0, 1.0, 0.0)
end

function CreateCam(name, active)
    assert(name == "DEFAULT_SCRIPTED_CAMERA" and active, "selfie camera must be created active")
    camera_created = true
    camera_destroyed = false
    return 73
end

function DoesCamExist(handle)
    return camera_created and not camera_destroyed and handle == 73
end

function SetCamFov() end
function SetCamActive() end

function RenderScriptCams(active)
    scripted_camera_rendering = active
end

function SetCamCoord(_, x, y, z)
    camera_coord = vector3(x, y, z)
end

function PointCamAtCoord(_, x, y, z)
    camera_target = vector3(x, y, z)
end

function DestroyCam(handle)
    assert(handle == 73, "the selfie camera handle must be destroyed")
    camera_destroyed = true
end

local function response_from(name, data)
    local response = nil
    callbacks[name](data, function(value)
        response = value
    end)
    return response
end

local function close_enough(actual, expected)
    return math.abs(actual - expected) < 0.0001
end

dofile("sky_phone/source/client/camera.lua")

assert(response_from("camera:setActive", { active = true }).success)
assert(response_from("camera:setFacing", { front = true }).success)
assert(camera_created and scripted_camera_rendering, "selfie mode must render a scripted camera")
assert(camera_coord and camera_target, "selfie mode must position and aim the camera")
assert(close_enough(camera_coord.x, 10.0))
assert(close_enough(camera_coord.y, 21.05))
assert(close_enough(camera_coord.z, 2.75))
assert(close_enough(camera_target.x, 10.0))
assert(close_enough(camera_target.y, 20.0))
assert(close_enough(camera_target.z, 2.73))

assert(response_from("camera:setFacing", { front = false }).success)
assert(camera_destroyed and not scripted_camera_rendering, "rear mode must release the selfie camera")

assert(type(lb_camera_exports.EnableWalkableCam) == "function", "LB walkable camera enable export must exist")
assert(type(lb_camera_exports.DisableWalkableCam) == "function", "LB walkable camera disable export must exist")
assert(type(lb_camera_exports.ToggleSelfieCam) == "function", "LB selfie camera export must exist")
assert(type(lb_camera_exports.ToggleCameraFrozen) == "function", "LB frozen camera export must exist")
assert(type(lb_camera_exports.IsWalkingCamEnabled) == "function", "LB walkable camera state export must exist")
assert(type(lb_camera_exports.IsSelfieCam) == "function", "LB selfie camera state export must exist")
assert(type(lb_camera_exports.IsCameraOpen) == "function", "LB camera open state export must exist")

lb_camera_exports.EnableWalkableCam(true)
assert(lb_camera_exports.IsWalkingCamEnabled(), "LB walkable camera must report enabled")
assert(lb_camera_exports.IsSelfieCam(), "LB walkable camera must preserve selfie mode")
assert(lb_camera_exports.IsCameraOpen(), "LB walkable camera must open the camera")
lb_camera_exports.ToggleSelfieCam(false)
assert(not lb_camera_exports.IsSelfieCam(), "LB selfie camera must switch back to rear mode")
lb_camera_exports.ToggleCameraFrozen()
lb_camera_exports.DisableWalkableCam()
assert(not lb_camera_exports.IsWalkingCamEnabled(), "LB walkable camera must report disabled")
assert(not lb_camera_exports.IsCameraOpen(), "LB walkable camera disable must close the camera")

print("Client camera tests passed")
