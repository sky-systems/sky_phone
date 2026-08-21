local source_path = "sky_phone/source/server/nui_build_check.lua"
local original_print = print

local function run_check(files)
    local output = {}

    print = function(message)
        output[#output + 1] = tostring(message)
    end
    GetCurrentResourceName = function()
        return "sky_phone"
    end
    LoadResourceFile = function(resource_name, path)
        assert(resource_name == "sky_phone", "NUI build check must inspect its own resource")
        return files[path]
    end

    dofile(source_path)
    return table.concat(output, "\n")
end

local valid_files = {
    ["source/html/index.html"] = [[
        <link rel="stylesheet" href="./assets/sky-index.css">
        <script type="module" src="./assets/sky-index.js"></script>
    ]],
    ["source/html/assets/sky-index.css"] = "body{}",
    ["source/html/assets/sky-index.js"] = "console.log('ready')",
    ["source/html/img/custom-app.svg"] = "<svg></svg>",
    ["source/html/sounds/button.mp3"] = "audio",
}

assert(run_check(valid_files) == "", "a complete NUI build must not print a warning")

local missing_build_output = run_check({})
assert(missing_build_output:find("SKY PHONE UI BUILD IS MISSING OR INCOMPLETE", 1, true))
assert(missing_build_output:find("source/html/index.html", 1, true))
assert(missing_build_output:find("source/html/assets/*", 1, true))
assert(missing_build_output:find("source/html/img/custom-app.svg", 1, true))
assert(missing_build_output:find("source/html/sounds/button.mp3", 1, true))
assert(missing_build_output:find("not GitHub's automatic source archive", 1, true))
assert(missing_build_output:find("build_frontend.bat", 1, true))

local missing_asset_files = {}
for path, content in pairs(valid_files) do
    missing_asset_files[path] = content
end
missing_asset_files["source/html/assets/sky-index.js"] = nil

local missing_asset_output = run_check(missing_asset_files)
assert(missing_asset_output:find("source/html/assets/sky-index.js", 1, true))
assert(not missing_asset_output:find("source/html/assets/sky-index.css", 1, true))

local query_asset_files = {}
for path, content in pairs(valid_files) do
    query_asset_files[path] = content
end
query_asset_files["source/html/index.html"] = [[
    <script type="module" src="./assets/sky-index.js?v=1#entry"></script>
]]
assert(run_check(query_asset_files) == "", "asset query strings and fragments must be ignored")

print = original_print
io.write("Sky Phone NUI build check tests passed\n")
