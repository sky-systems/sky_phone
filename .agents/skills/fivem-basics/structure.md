# Structure/Scope

Best practices for organizing FiveM resources and Lua code.

## Prefer Limited Scope

Variables and functions should be scoped to the smallest visibility needed. Prefer in order:
1. **local function** (most restricted)
2. **function** (module/file level)
3. **export function** (cross-resource)
4. **AddEventHandler** (event-based)
5. **RegisterNetEvent/Callback** (networked, least restricted)

## Separate Client & Server Files

Client and server specific files should be organized into their own folders.

**Example structure:**
```
my-resource/
├── fxmanifest.lua
├── client/
│   ├── main.lua
│   └── ui.lua
└── server/
    ├── main.lua
    └── database.lua
```

## Use Logical Grouping

It may make sense to place constructs of the same type together in a file. For example:
- All file scoped variables at the top of the file
- Followed by all local functions
- Followed by all global functions
- Followed by events

This grouping structure makes it easier to understand the API at the server, resource, and file levels.

Alternatively, local single use functions could be located directly above or as close as possible to the functions they are called from, and grouping can be based on call structure rather than construct type.

## Use Files/Modules To Hide Local Functions

If you have one resource scoped function which calls a few local single use functions, put them all in their own file or module. This keeps your code organized and maintains proper encapsulation.

## Resource Naming

Resources should be named with underscores "_" instead of spaces. Other special characters should be avoided so that exports work well.

**Examples:**
- ✅ `my_awesome_resource`
- ✅ `vehicle_shop`
- ❌ `my awesome resource` (spaces)
- ❌ `vehicle-shop!` (special characters)

## File Naming

Files should be named all lower case without any spaces. Dashes "-" or underscores "_" can be used instead of spaces.

**Examples:**
- ✅ `main.lua`
- ✅ `player_manager.lua`
- ✅ `vehicle-shop.lua`
- ❌ `PlayerManager.lua` (camelCase)
- ❌ `vehicle shop.lua` (spaces)
