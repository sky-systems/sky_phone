# Client vs server

## Client scripts

- Run on **each player’s game**.
- Can use game natives: peds, vehicles, world, UI, drawing, etc.
- Have access to the local player and game state on that machine.

## Server script

- Runs **once** on the server.
- No direct access to game world or visuals.
- Use for: persistence, auth, shared data, validation, database, economy.
- Can target specific clients with `TriggerClientEvent(event, playerId, ...)`.

## Shared scripts

- **shared_scripts** run on both client and server.
- Put config, constants, or helper functions here.
- Be careful: no game natives in shared code unless you guard by environment.

## Communication

- **Events** — `TriggerServerEvent` / `TriggerClientEvent` (see rules/events.md).
- **Exports** — Call functions from other resources (see rules/exports.md).
- **State bags** — Shared key/value state (see docs).

## Summary

| Side   | Runs on     | Game natives | Use for                          |
|--------|-------------|---------------|-----------------------------------|
| Client | Each player | Yes           | UI, gameplay, locals, rendering   |
| Server | Once        | No (server natives only) | Data, auth, validation, broadcast |
