# 🛡️ Secure Event Handling

The single biggest vulnerability in FiveM development is trusting data sent from the client via `TriggerServerEvent`. **Hackers don't need complex menus; they just execute events with spoofed parameters.**

## ❌ Bad Practice: Trusting the Client

Never let the client dictate the outcome.

```lua
-- CLIENT
TriggerServerEvent("job:payMe", 5000) -- The hacker just changes this to 5000000

-- SERVER
RegisterNetEvent("job:payMe", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.AddMoney("cash", amount) -- Boom, economy ruined.
end)
```

## ✅ Good Practice: Server Authority

The client **requests** an action; the server **calculates** the result.

```lua
-- CLIENT
-- Client just says "I finished the job"
TriggerServerEvent("job:requestPayment") 

-- SERVER
RegisterNetEvent("job:requestPayment", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- The SERVER decides how much to pay based on server-side logic/config
    local paymentAmount = Config.JobPayAmount 
    
    -- Additional security: Are they actually clocked in? Did they wait the required time?
    if not ServerSideJobState[src].isWorking then return end
    
    Player.Functions.AddMoney("cash", paymentAmount)
end)
```

## 📍 Distance Checks (Crucial)

If a player triggers an event to "buy an item" or "harvest a plant," the server **MUST** check if they are actually physically near the location. Hackers can trigger events from across the map.

```lua
-- SERVER
local sellPosition = vector3(100.0, 0.0, 0.0)

RegisterNetEvent("packages:givePackage", function()
    local src = source
    local ped = GetPlayerPed(src)
    local position = GetEntityCoords(ped) 
    
    -- Server checks distance. 10 units is usually a safe margin for latency.
    if #(position - sellPosition) >= 10.0 then 
        print(("Exploit attempt: %s tried to sell from too far away."):format(GetPlayerName(src)))
        return 
    end

    -- Proceed with giving the item
end)
```

## 🛡️ Best Practices Summary

1. **Client requests, Server decides.** Never send prices, amounts, or sensitive item names from the client if it can be avoided.
2. **Always perform Distance Checks** on the server using `GetEntityCoords(GetPlayerPed(source))`.
3. **Verify State.** If the event requires a specific job or item, verify it on the server *again*.
4. **Log suspicious activity.** If a distance check fails drastically, log it for admins.