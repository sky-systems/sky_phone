# Conditionals

## Default Values

Consider ternary operator 'or' instead of nil checks to improve readability.

**BAD:**
```lua
if name then
    return name
else
    return "John Doe"
end
```

**GOOD:**
```lua
return name or "John Doe"
```

## Don't Write "if true then return true"

When returning or setting a variable to the value of the conditional statement itself, don't use an if else block.

**BAD:**
```lua
if name == "mark" or name == "stacy" then
   return true
else
   return false
end
```

**GOOD:**
```lua
return name == "mark" or name == "stacy"
```

## Prefer positive boolean expressions

This makes the code easier to read.

**BAD:**
```lua
if not isHappy then
  return "sad"
else
  return "happy"
end
```

**GOOD:**
```lua
if isHappy then
  return "happy"
else
  return "sad"
end
```
