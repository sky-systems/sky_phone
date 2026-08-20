local source_path = "sky_phone/source/server/update_check.lua"
local original_print = print

local function run_check(installed_version, status_code, release_version)
    local output = {}
    local request

    print = function(message)
        output[#output + 1] = tostring(message)
    end
    GetCurrentResourceName = function()
        return "sky_phone"
    end
    GetResourceMetadata = function(resource_name, key, index)
        assert(resource_name == "sky_phone", "update check must read its own resource metadata")
        assert(key == "version" and index == 0, "update check must read the fxmanifest version")
        return installed_version
    end
    PerformHttpRequest = function(url, callback, method, body, headers)
        request = {
            url = url,
            callback = callback,
            method = method,
            body = body,
            headers = headers,
        }
    end
    CreateThread = function(callback)
        callback()
    end
    json = {
        decode = function()
            return { tag_name = release_version }
        end,
    }

    dofile(source_path)

    if request then
        assert(request.url == "https://api.github.com/repos/sky-systems/sky_phone/releases/latest")
        assert(request.method == "GET" and request.body == "", "update check must use a read-only GET request")
        assert(request.headers["Accept"] == "application/vnd.github+json")
        assert(request.headers["User-Agent"] == "sky_phone-update-check")
        request.callback(status_code, "{}")
    end

    return table.concat(output, "\n"), request
end

local current_output = run_check("0.1.0", 200, "0.1.0")
assert(current_output:find("Version 0.1.0 is up to date", 1, true), "matching versions must report up to date")

local outdated_output = run_check("0.1.0", 200, "0.2.0")
assert(outdated_output:find("SKY PHONE UPDATE AVAILABLE", 1, true), "newer releases must show an update notice")
assert(outdated_output:find("Installed version: ^10.1.0", 1, true), "notice must show the manifest version")
assert(outdated_output:find("Latest release:    ^20.2.0", 1, true), "notice must show the release tag")

local ahead_output = run_check("1.0.0", 200, "0.9.9")
assert(ahead_output:find("newer than the latest GitHub release", 1, true), "ahead versions must be distinguished")

local invalid_output, invalid_request = run_check("development", 200, "0.1.0")
assert(not invalid_request, "invalid manifest versions must not make an HTTP request")
assert(invalid_output:find("fxmanifest.lua has an invalid version", 1, true), "invalid manifests must be visible")

local failed_output = run_check("0.1.0", 429, "0.1.0")
assert(failed_output:find("GitHub update check failed with HTTP 429", 1, true), "HTTP failures must be visible")

print = original_print
io.write("Sky Phone update check tests passed\n")
