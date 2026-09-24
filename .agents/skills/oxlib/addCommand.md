# Commands

Server API: lib.addCommand(commandName, properties, callback).
Names can be one string or aliases. Properties include help, params and restricted.
Parameter types include number, playerId, string and longString; optional permits omission.
The callback receives source, parsed arguments and the raw command.

The restricted property controls command permissions; verify the installed ACE behavior and
the intended callers, including console use. Type parsing is not full business validation:
a numeric quantity still needs finite/integer/range checks where appropriate, and a target or
item must be authorized by the server operation. Do not expose an unrestricted grant command.

Keep help/labels localized through the resource's established mechanism. Preserve existing
command ownership instead of registering competing handlers.

[Official command contract](https://overextended.dev/docs/ox_lib/AddCommand/Server)
and [parser/registration source](sources.md).

## Aliases, typed arguments and permissions

This server example only logs a parsed inspection request. The `locale(...)` keys must
exist in the resource's localization; integrate its real inspection service separately.

```lua
lib.addCommand({ "inspectplayer", "inspectp" }, {
    help = locale("command.inspect.help"),
    params = {
        { name = "target", type = "playerId", help = locale("command.target") },
        { name = "limit", type = "number", optional = true, help = locale("command.limit") }
    },
    restricted = { "group.admin", "group.moderator" }
}, function(source, args)
    local limit = args.limit or 10
    if limit ~= limit or limit % 1 ~= 0 or limit < 1 or limit > 50 then
        print("[inspectplayer] Rejected limit: expected an integer from 1 to 50")
        return
    end
    print(("[inspectplayer] actor=%s target=%s limit=%d"):format(source, args.target, limit))
end)
```

At the pinned source, `restricted = true` enables the command ACE without granting a
principal; a string or string array also grants the named principals the command ACE.
`false`/omission leaves the command unrestricted. `properties = false` omits suggestions
and typed parameters. Plan console use (`source == 0`) explicitly.

`playerId` accepts an existing player's ID or `me`; console must provide an actual player.
`longString` consumes the remaining command only as the final parameter. An optional
parameter may be absent, but a supplied invalid value still fails parsing. The inspected
`string` parser rejects numeric strings; do not assume it accepts every textual token.
