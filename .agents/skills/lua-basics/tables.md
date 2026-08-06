# Tables

## Imply Array Indices

Other languages don't allow declaring an array with explicit indices. Unless the keys have important meaning that needs to be made clear to the reader, they should be implied.

**BAD:**
```lua
local myTable = {
    [1] = "first index",
    [2] = "second index",
    [3] = "third index"
}
```

**GOOD:**
```lua
local myTable = {
    "first index",
    "second index",
    "third index"
}
```

## Dereferencing

### Prefer object access for constant keys, and array access for non-constant keys

```lua
local company = {
    boss = "Sam"
}
```

**BAD:**
```lua
local boss = company["boss"]
```

**GOOD:**
```lua
local boss = company.boss
```

### Extract duplicate table dereferences into local variables

This is both a readability and performance boost.

**BAD:**
```lua
local concatenation = myTable["key"] .. myTable["key"]
```

**GOOD:**
```lua
local myTableValue = myTable["key"]
local concatenation = myTableValue .. myTableValue
```

## Avoid table.insert()

It has horrible performance. It should only be used if needing to insert into an array at a specific index that is not the last index.

### Inserting at the end of a table

**BAD:**
```lua
table.insert(myTable, "value")
```

**GOOD:**
```lua
myTable[#myTable + 1] = "value"
```

### Inserting/Overwriting a given key

**BAD:**
```lua
table.insert(myTable, "key", "value")
```

**GOOD:**
```lua
myTable["key"] = "value"
```

## Use numeric for loops when iterating over an array

This is a performance boost.

**BAD:**
```lua
for k, v in pairs(myArray) do
    print(k .. ", " .. v)
end
```

**GOOD:**
```lua
for i=1, #myArray do
    print(i .. ", " .. myArray[i])
end
```

## Maintain your own array size variable

There is a significant performance difference for large arrays as #array is an O(n) operation. Note that sometimes iterating through the entire array to find the size is preferable, but a common pattern of starting with an empty array and populating it in a loop should use an array size variable.

**BAD:**
```lua
for i = 1, 100 do
  myArray[#myArray+1] = i
end
```

**GOOD:**
```lua
local myArraySize = 0
for i = 1, 100 do
  myArraySize += 1
  myArray[myArraySize] = i
end
```
