local RELEASE_API_URL = "https://api.github.com/repos/sky-systems/sky_phone/releases/latest"
local RELEASE_PAGE_URL = "https://github.com/sky-systems/sky_phone/releases/latest"

local function parse_version(version)
    if type(version) ~= "string" then
        return nil
    end

    local major, minor, patch = version:match("^v?(%d+)%.(%d+)%.(%d+)$")
    if not major then
        return nil
    end

    return tonumber(major), tonumber(minor), tonumber(patch)
end

local function compare_versions(installed_version, release_version)
    local installed_major, installed_minor, installed_patch = parse_version(installed_version)
    local release_major, release_minor, release_patch = parse_version(release_version)
    if not installed_major or not release_major then
        return nil
    end

    if installed_major ~= release_major then
        return installed_major < release_major and -1 or 1
    end

    if installed_minor ~= release_minor then
        return installed_minor < release_minor and -1 or 1
    end

    if installed_patch ~= release_patch then
        return installed_patch < release_patch and -1 or 1
    end

    return 0
end

local function print_update_notice(installed_version, release_version)
    local border = "======================================================================"
    print(([[
^1%s^0
^1                 SKY PHONE UPDATE AVAILABLE                         ^0
^1%s^0
^3 Installed version: ^1%s^0
^3 Latest release:    ^2%s^0

^5 Download: %s^0
^1%s^0]]):format(border, border, installed_version, release_version, RELEASE_PAGE_URL, border))
end

local function check_for_update()
    local resource_name = GetCurrentResourceName()
    local installed_version = GetResourceMetadata(resource_name, "version", 0)
    if not parse_version(installed_version) then
        print(("^3[sky_phone] Update check skipped because fxmanifest.lua has an invalid version: %s.^0")
            :format(tostring(installed_version)))
        return
    end

    PerformHttpRequest(RELEASE_API_URL, function(status_code, response_body)
        if status_code ~= 200 then
            print(("^3[sky_phone] GitHub update check failed with HTTP %s.^0"):format(tostring(status_code)))
            return
        end

        local decoded, release = pcall(json.decode, response_body)
        local release_version = decoded and type(release) == "table" and release.tag_name or nil
        local comparison = compare_versions(installed_version, release_version)
        if not comparison then
            print(("^3[sky_phone] GitHub update check returned an invalid release tag: %s.^0")
                :format(tostring(release_version)))
            return
        end

        if comparison < 0 then
            print_update_notice(installed_version, release_version)
        elseif comparison > 0 then
            print(("^3[sky_phone] Installed version %s is newer than the latest GitHub release %s.^0")
                :format(installed_version, release_version))
        else
            print(("^2[sky_phone] Version %s is up to date.^0"):format(installed_version))
        end
    end, "GET", "", {
        ["Accept"] = "application/vnd.github+json",
        ["User-Agent"] = "sky_phone-update-check",
        ["X-GitHub-Api-Version"] = "2022-11-28",
    })
end

CreateThread(check_for_update)
