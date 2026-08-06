# Error Handling

An unexpected state or condition within the code may cause a lua error to be thrown. However, these bad states can have other consequences when not so explicitly detected and handled. They may propagate bad state to other components of the system, or introduce unintended behavior. Checking for and handling unexpected state can make your code more robust to possible failures and vulnerabilities.

## Use assert instead of 'if expression then error()'

assert is a more succinct, readable way to throw an error on a condition not being met.

**BAD:**
```lua
if not someVar then error("someVar is nil") end
```

**GOOD:**
```lua
assert(someVar ~= nil, "someVar is nil")
```

## Pre-condition check liberally

When performing an operation, make a list of assumptions and then write pre-condition checks.

## Fail loudly for unexpected state

When writing pre-condition checks, failure should often result in a lua error with a message. Failing silently by just early returning from a function can be difficult to debug and may go undetected.

**BAD:**
```lua
if not isPlayerDead() then return end
```

**GOOD:**
```lua
assert(isPlayerDead(), "player is not dead")
```

## Throwing an Error vs Logging

Some states may be unexpected, but recoverable. In these cases, it may be preferable to log the state, but still allow the operation to proceed. An example of this would be a player selling items to an NPC. If some of the items were failing to sell, it would be better to log/print the error, while allowing the rest of the items to go through.

Keep in mind what execution will be cancelled by throwing an error and use best judgment to decide whether throwing or logging is the better choice.

## Assertions vs Errors as Values

Assertions cause lua errors to propagate up the stack, forcing callers to handle them via protected calls. While assertions should always be used for unexpected or "impossible" cases, errors as values can be helpful for expected failure cases that we want the caller of the API to handle. This involves returning a success boolean, followed by an optional error code & message. Doing this makes the default behavior of our function fail silently, as it becomes the callers responsibility to decide to handle the error. This can provide a better experience for players as a silent failure may be preferable to loud error messages in cases where the player pressed the wrong button for example.

Note that API functions should be idempotent when possible. A no-op result is still considered successful, if the state of the system is the one the caller expects after the function is ran.

### Example Error as Value

```lua
function add(a, b)
    if not a or not b then
        return nil, {
            code = 'missing_required_params',
            message = 'either a or b is nil',
        }
    end
    return a + b
end
```
