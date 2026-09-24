# Trace the failing side

Identify the reproduction, actual resource/package, active provider and exact error first.
Trace the caller through the authority/provider and back to its consumer. Inspect configuration
and shipped bytes when source and observed behavior disagree.

Server console logs describe server execution; F8 logs describe the game client's execution.
NUI also has its own browser diagnostics. A clean server console does not rule out a client
or UI error. Read available logs first; request the relevant F8/server excerpt only when needed
for an unresolved branch. Preserve the timestamp, resource name, stack and reproduction steps.

When the missing evidence is client-side, the concrete collection procedure is:

1. Reproduce the issue once and note the action and time.
2. Press F8 in the game client to open its console.
3. Copy the relevant error and stack, including the resource/file/line and adjacent context.

Collect the matching server excerpt for a server branch and browser diagnostics for a NUI
branch. Do not ask for all logs merely because one console is clean.

Use narrow English diagnostics that explain the failing value and boundary; do not log secrets
or whole player records. Under the Sky bridge workspace rules, diagnostics stay out of locale files and user-facing
messages remain localized. Remove speculative guards, retries or waits that hide the cause.

Report evidence separately: static parsing, build output, deployment-copy hashes, server restart
and in-game reproduction prove different things. A browser or unit test is not a FiveM session.
For timing claims use a comparable [FiveM profiler capture](https://docs.fivem.net/docs/scripting-manual/debugging/using-profiler/).
