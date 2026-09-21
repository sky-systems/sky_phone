local function new_server(responder, configure)
    local requests, warnings = {}, {}
    local noop = function() end
    local environment = setmetatable({
        Config = { PhoneConfigurator = { Enabled = true } },
        AddEventHandler = noop,
        SetTimeout = noop,
        GetConvar = function() return "" end,
        Bridge = {
            Callbacks = { Register = noop },
            Debug = function(level, message)
                if level == "warn" then warnings[#warnings + 1] = message end
            end,
        },
        promise = { new = function()
            return { resolve = function(self, value) self.value = value end }
        end },
        Citizen = { Await = function(request) return assert(request.value) end },
        joaat = function(value)
            local hash = 0
            for index = 1, #value do hash = (hash * 31 + value:byte(index)) & 0xffffffff end
            return hash
        end,
        json = { decode = function(value) return value end },
    }, { __index = _G })
    environment.PerformHttpRequest = function(url, callback, method, body, headers, options)
        assert(method == "GET", "Media probing must not issue HEAD requests in FXServer")
        assert(options.followLocation == false, "Do not follow redirects outside the allowed host")
        requests[#requests + 1] = { url = url, headers = headers }
        local status, response, response_headers, transport_error = responder(url, headers)
        callback(status, response, response_headers, transport_error)
    end
    local function load_script(path)
        assert(loadfile("sky_phone/" .. path, "t", environment))()
    end
    load_script("config/media.lua")
    local media = environment.Config.Media
    media.FiveManage.ApiKey = "test-token"
    media.Import.Websites[1].AllowedMediaHosts = { "media.example.com", "fivemanage.com" }
    media.Import.Websites[2] = {
        Id = "manifest", Label = "Manifest", Adapter = "manifest", Enabled = true,
        ManifestUrl = "https://media.example.com/media.json",
        MediaTypes = { "photo", "video" }, AllowedMediaHosts = { "media.example.com" },
    }
    if configure then configure(media) end
    load_script("source/server/media_provider_config.lua")
    load_script("source/server/media_import.lua")
    load_script("source/server/media_import/fivemanage.lua")
    load_script("source/server/media_import/manifest.lua")
    environment.SkyPhoneMediaImport.Initialize()
    return environment.SkyPhoneMediaImport, requests, warnings
end

local url = "https://media.example.com/wallpaper.jpg"
local function public_response(status, headers, transport_error)
    return function(request_url, request_headers)
        if request_url:find("https://api.fivemanage.com/", 1, true) == 1 then
            assert(request_headers.Authorization == "test-token")
            return 404, "", {}
        end
        assert(request_headers.Authorization == nil, "Never send provider credentials to public media hosts")
        assert(request_headers.Range == "bytes=0-0", "Request only one byte of the media")
        assert(request_headers["Accept-Encoding"] == "identity")
        return status, "x", headers, transport_error
    end
end

-- Both adapters must resolve the complete size, not Content-Length: 1.
for _, source in ipairs({ "fivemanage", "manifest" }) do
    local importer, requests, warnings = new_server(public_response(206, {
        ["Content-Type"] = { "image/jpeg; charset=binary" },
        ["Content-Length"] = "1", ["Content-Range"] = "bytes 0-0/173000",
    }))
    local media, error_code = importer.ResolveUrl(source, "  " .. url .. "  ")
    assert(media and not error_code and media.size == 173000)
    assert(media.url == url and media.filename == "wallpaper.jpg")
    assert(media.mediaType == "photo" and media.mimeType == "image/jpeg")
    assert(media.sourceId == source and media.externalId:match("^url:"))
    assert(#requests == (source == "fivemanage" and 2 or 1))
    assert(#warnings == 0, "A valid public URL must not produce a transport warning")

    local full = new_server(public_response(200, {
        ["content-type"] = "image/jpeg", ["content-length"] = "173000",
    }))
    assert(full.ResolveUrl(source, url).size == 173000, "Support hosts that ignore Range")

    for _, content_range in ipairs({ "", "bytes 0-0/*", "bytes 0-0/0", "bytes 1-1/173000" }) do
        local invalid = new_server(public_response(206, {
            ["content-type"] = "image/jpeg", ["content-length"] = "1", ["content-range"] = content_range,
        }))
        local item, failure = invalid.ResolveUrl(source, url)
        assert(not item and failure == "import_size_unavailable",
            "Reject missing or invalid total sizes instead of accepting one byte")
    end

    local oversized = new_server(public_response(206, {
        ["content-type"] = "image/jpeg", ["content-length"] = "1", ["content-range"] = "bytes 0-0/20000000",
    }))
    local item, failure = oversized.ResolveUrl(source, url)
    assert(not item and failure == "import_media_too_large", "Enforce the size limit on the full file")

    for _, case in ipairs({
        { status = 200, headers = { ["content-type"] = "image/jpeg" }, error = "import_size_unavailable" },
        { status = 206, headers = { ["content-type"] = "text/html" }, error = "import_media_not_allowed" },
        { status = 302, headers = { Location = "https://other.example.com/image.jpg" }, error = "import_url_unavailable" },
        { status = 404, headers = {}, error = "import_url_unavailable" },
        { status = 0, headers = {}, error = "import_source_unavailable", transport = "test transport error" },
    }) do
        local failed = new_server(public_response(case.status, case.headers, case.transport))
        local result, result_error = failed.ResolveUrl(source, url)
        assert(not result and result_error == case.error)
    end

    local guarded, guarded_requests = new_server(function() error("Must not request disallowed URLs") end)
    for _, rejected_url in ipairs({
        "http://media.example.com/image.jpg", "https://other.example.com/image.jpg",
        "https://media.example.com.evil.example/image.jpg", "https://user@media.example.com/image.jpg",
    }) do
        local result, result_error = guarded.ResolveUrl(source, rejected_url)
        assert(not result and result_error == "import_url_not_allowed")
    end
    assert(#guarded_requests == 0)
end

-- Authenticated FiveManage metadata still takes precedence over public probes.
local authenticated, authenticated_requests = new_server(function(request_url, headers)
    assert(request_url == "https://api.fivemanage.com/api/v3/file/wallpaper")
    assert(headers.Authorization == "test-token" and not headers.Range)
    return 200, { data = {
        id = "wallpaper", filename = "wallpaper.jpg", type = "image/jpeg",
        size = 173000, url = "https://r2.fivemanage.com/wallpaper.jpg",
    } }, {}
end)
assert(authenticated.ResolveUrl("fivemanage", url).externalId == "wallpaper")
assert(#authenticated_requests == 1)

local unauthorized, unauthorized_requests = new_server(function() return 401, "", {} end)
local item, failure = unauthorized.ResolveUrl("fivemanage", url)
assert(not item and failure == "import_provider_unauthorized" and #unauthorized_requests == 1)

local unconfigured, unconfigured_requests = new_server(function() error("Source requires a token") end,
    function(media) media.FiveManage.ApiKey = "" end)
item, failure = unconfigured.ResolveUrl("fivemanage", url)
assert(not item and failure == "import_url_not_allowed" and #unconfigured_requests == 0)

print("Media import public URL, provider metadata and validation checks passed")
