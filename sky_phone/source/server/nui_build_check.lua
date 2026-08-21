local resource_name = GetCurrentResourceName()
local index_path = "source/html/index.html"
local required_static_files = {
    "source/html/img/custom-app.svg",
    "source/html/sounds/button.mp3",
}

local function load_non_empty_file(path)
    local content = LoadResourceFile(resource_name, path)
    if type(content) ~= "string" or content == "" then
        return nil
    end
    return content
end

local function add_missing_path(missing_paths, seen_paths, path)
    if seen_paths[path] then
        return
    end

    seen_paths[path] = true
    missing_paths[#missing_paths + 1] = path
end

local function normalize_entry_asset_path(url)
    if type(url) ~= "string" then
        return nil
    end

    local path = url:gsub("[?#].*$", "")
    while path:sub(1, 2) == "./" do
        path = path:sub(3)
    end

    if path:sub(1, 7) ~= "assets/" then
        return nil
    end

    return "source/html/" .. path
end

local function collect_entry_asset_paths(index_html)
    local paths = {}
    local seen_paths = {}

    for url in index_html:gmatch("src%s*=%s*[\"']([^\"']+)[\"']") do
        local path = normalize_entry_asset_path(url)
        if path and not seen_paths[path] then
            seen_paths[path] = true
            paths[#paths + 1] = path
        end
    end

    for url in index_html:gmatch("href%s*=%s*[\"']([^\"']+)[\"']") do
        local path = normalize_entry_asset_path(url)
        if path and not seen_paths[path] then
            seen_paths[path] = true
            paths[#paths + 1] = path
        end
    end

    return paths
end

local function find_missing_nui_files()
    local missing_paths = {}
    local seen_paths = {}
    local index_html = load_non_empty_file(index_path)

    if not index_html then
        add_missing_path(missing_paths, seen_paths, index_path)
        add_missing_path(missing_paths, seen_paths, "source/html/assets/* (generated entry assets)")
    else
        local entry_asset_paths = collect_entry_asset_paths(index_html)
        if #entry_asset_paths == 0 then
            add_missing_path(missing_paths, seen_paths, "source/html/assets/* (no entry asset referenced by index.html)")
        else
            for index = 1, #entry_asset_paths do
                local path = entry_asset_paths[index]
                if not load_non_empty_file(path) then
                    add_missing_path(missing_paths, seen_paths, path)
                end
            end
        end
    end

    for index = 1, #required_static_files do
        local path = required_static_files[index]
        if not load_non_empty_file(path) then
            add_missing_path(missing_paths, seen_paths, path)
        end
    end

    return missing_paths
end

local function print_missing_nui_notice(missing_paths)
    local border = "======================================================================"
    local lines = {
        ("^1%s^0"):format(border),
        "^1              SKY PHONE UI BUILD IS MISSING OR INCOMPLETE          ^0",
        ("^1%s^0"):format(border),
        "^3 The resource started, but the packaged phone UI cannot load.^0",
        "",
        "^3 Missing or invalid files:^0",
    }

    for index = 1, #missing_paths do
        lines[#lines + 1] = ("^1 - %s^0"):format(missing_paths[index])
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "^3 Install the latest published release package, not GitHub's automatic source archive.^0"
    lines[#lines + 1] = "^5 Release: https://github.com/sky-systems/sky_phone/releases/latest^0"
    lines[#lines + 1] = "^3 Developers working from source must run build_frontend.bat before starting sky_phone.^0"
    lines[#lines + 1] = ("^1%s^0"):format(border)

    print(table.concat(lines, "\n"))
end

local missing_paths = find_missing_nui_files()
if #missing_paths > 0 then
    print_missing_nui_notice(missing_paths)
end
