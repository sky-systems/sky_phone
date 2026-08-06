# Functions

## Size & Scope

- Functions should only do one thing, and should be small. If a function is not small, break it up into smaller functions.
- Avoid mixing high level code with low level code in the same function.

## Naming

- Local functions should be named in camelCase format to differentiate from natives and standard lua library functions
- Global functions should be named in PascalCase format
- Functions should also be named with a leading verb.

**BAD:**
```lua
function player()
function playerDrop()
```

**GOOD:**
```lua
function getPlayerObject()
function dropPlayer()
```

## Parameters

### Limit Number of Parameters

If needing more than 3 or so parameters for a single function, that may be a sign that the parameters can be grouped within a table and passed as a object, rather than as individual arguments.

**BAD:**
```lua
function createChar(name, age, height, birthday, nationality)

end
```

**GOOD:**
```lua
function createChar(char)

end
```

### Avoid boolean parameters in APIs

Boolean parameters are a signal that a function is doing two things. Instead, call two different functions that each do one thing. While what is considered an API is ambiguous, a good rule of thumb is not to include boolean parameters in global or exported functions.

**BAD:**
```lua
function PrintEmotionalState(isHappy)
    if isHappy then
        print("happy")
    else
        print("sad")
    end
end
```

**GOOD:**
```lua
function PrintHappy()
    print("happy")
end

function PrintSad()
    print("sad")
end
```

### Avoid passing implied functions as arguments

Instead declare the function in a local variable and pass the variable as the argument. This has major performance improvements if the calling function is invoked more than once. Some functions such as CreateThread are often only invoked once, so there wouldn't be any performance improvement to localizing the argument function. However, it's still recommended anyway as a defensive measure to avoid the issue entirely if the code were to change in the future.

**BAD:**
```lua
someFunction(function()

end)
```

**GOOD:**
```lua
local function myFunction()

end
someFunction(myFunction)
```

### Parameter Overloads

Be careful overloading a function. Overloading can be a smell that a function is doing more than one thing. Overloads are useful as wrapper functions, providing different ways to call the same underlying function.

### Optional Parameters

Required parameters should come before optional ones.

## Export Documentation

Exports should have a lua-language-server annotation to declare the API:

```lua
--- Puts a space between a first and last name
---@param first string first name
---@param last string last name
---@return string full name
local function formatName(first, last)
    return first .. ' ' .. last
end

exports('formatName', formatName)
```

### Keep returned values small in size

Since returned values are passed-by-value, there can be a significant performance cost to returning large payloads. Benchmarks show it is more performant to have many export calls that return a small amount of data each, than few export calls that return large payloads, even if the total number of bytes transferred is the same. Providing accessor exports instead of direct access to tables also makes your API more flexible to future changes.

**BAD:**
```lua
exports('GetTable', function()
    return myTable
end)
```

**GOOD:**
```lua
exports('GetValue', function(key)
    return myTable[key]
end)
```

## Use guard clauses

Often before doing the "real" work of a function, certain pre-conditions must be met. Guard clauses are conditional statements that provide early returns to check certain conditions. This allows the reader to also exit early, rather than reading the entire function.

Additionally, using guard clauses avoids nesting, which can make code difficult to read. Sometimes though, a simple if statement reads just fine. Use your best judgment.

**BAD:**
```lua
local function getFullName(first, last)
    if not nameHidden and first and last then
        return first .. last
    else
        return nil
    end
end
```

**GOOD:**
```lua
local function getFullName(first, last)
    if nameHidden then return end
    if not first or not last then return end
    return first .. last
end
```
