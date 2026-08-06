# Debugging FiveM scripts

## Server vs client logs

- **Server console** (TxAdmin, terminal, or server window): errors and prints from `server_script` and server-side code.
- **F8 client console**: in-game console opened with **F8**. Shows errors and prints from `client_script` and client-side code.

## When to ask for F8 logs

If there is **no error on the server side** (server console is clean or the issue doesn’t show there), ask the user to **share the F8 logs** (client console). Many issues (client Lua errors, missing natives, UI or gameplay bugs) only appear in the client console.

Tell the user to:
1. Reproduce the issue in-game.
2. Press **F8** to open the client console.
3. Copy the relevant output (errors in red, or the last lines) and share it.

This helps distinguish server-side vs client-side problems.
