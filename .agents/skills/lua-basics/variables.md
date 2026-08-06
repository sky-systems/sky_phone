# Variables

## Naming

### Name constants using ALL_CAPS

```lua
local MY_CONSTANT = "constant value"
MY_GLOBAL_CONSTANT = "another constant value"
```

### camelCase non-constant local variable names

```lua
local myVariable = "variable value"
```

### PascalCase non-constant global variable names

```lua
MyGlobalVariable = "global variable value"
```

### Use underscore "_" as the name of a variable that cannot be deleted but is unused

```lua
local function printValues(map)
    for _, v in pairs(map) do
        print(v)
    end
end
```

### Enums Vs Booleans

Enums should be used to reflect the state of something when more than two options exist. A common anti-pattern is using multiple booleans to reflect the state. This is confusing and problematic, because the code then needs to defend against impossible states, as the combination of booleans is able to represent more states than is desired. It also makes the code more opaque and harder to reason about. What does it mean if isWalking and isRunning are both false? That we don't know? Is the state idle? Or maybe swimming?

**BAD:**
```lua
local isWalking = false
local isRunning = false
```

**GOOD:**
```lua
local MOVEMENT = {
    UNKNOWN = 1,
    WALKING = 2,
    RUNNING = 3
}
local movementState = MOVEMENT.UNKNOWN
```

Representing the state in an enum this way also makes it easier to modify in the future to add more states. Such as idle, swimming, flying, falling, etc. Adding an UNKNOWN field is useful when the enum isn't exhaustive, as a catch all to represent any other state.

## Location

Local variables within a function should be declared as close as possible to the place where they are used. This limits what the developer must keep in their head while reading the code. Local variables declared outside of a function should be declared at the top of the file, grouped together. Global variables should be declared at the top of the file grouped together. client/server global variables should only be declared within a single client/server file. This helps keep things organized instead of spreading random globals around the resource.
