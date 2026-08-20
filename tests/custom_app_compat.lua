dofile("sky_phone/source/bridge/phones/shared.lua")

assert(type(SkyPhoneCompatibility.RegisterExportAlias) == "function", "Shared core must expose export aliases")
assert(type(SkyPhoneCompatibility.EmitServerProviderStop) == "function", "Shared core must expose stop lifecycle")
assert(type(SkyPhoneCompatibility.EmitServerProviderStart) == "function", "Shared core must expose start lifecycle")
assert(type(SkyPhoneCompatibility.NormalizeAtResourceUrl) == "function", "Shared core must expose URL validation")
assert(SkyPhoneCompatibility.Providers.lb == "lb_phone", "Shared core must expose provider constants")
assert(SkyPhoneCompatibility.BuildLbDefinition == nil, "Shared core must not contain the LB mapper")
assert(SkyPhoneCompatibility.Build17MovDefinition == nil, "Shared core must not contain the 17mov mapper")
assert(SkyPhoneCompatibility.BuildHighDefinition == nil, "Shared core must not contain the High mapper")
assert(SkyPhoneCompatibility.BuildQuasarDefinition == nil, "Shared core must not contain the Quasar mapper")
assert(SkyPhoneCompatibility.BuildYSeriesDefinition == nil, "Shared core must not contain the YSeries mapper")

dofile("sky_phone/source/bridge/phones/shared/lb.lua")
assert(type(SkyPhoneCompatibility.BuildLbDefinition) == "function", "LB provider must expose its mapper")
assert(SkyPhoneCompatibility.Build17MovDefinition == nil, "LB provider must not expose the 17mov mapper")

dofile("sky_phone/source/bridge/phones/shared/seventeen.lua")
assert(type(SkyPhoneCompatibility.Build17MovDefinition) == "function", "17mov provider must expose its mapper")
assert(SkyPhoneCompatibility.BuildHighDefinition == nil, "17mov provider must not expose the High mapper")

dofile("sky_phone/source/bridge/phones/shared/high.lua")
assert(type(SkyPhoneCompatibility.BuildHighDefinition) == "function", "High provider must expose its mapper")
assert(SkyPhoneCompatibility.BuildQuasarDefinition == nil, "High provider must not expose the Quasar mapper")

dofile("sky_phone/source/bridge/phones/shared/quasar.lua")
assert(type(SkyPhoneCompatibility.CopyQuasarData) == "function", "Quasar provider must expose its copier")
assert(type(SkyPhoneCompatibility.BuildQuasarDefinition) == "function", "Quasar provider must expose its mapper")
assert(SkyPhoneCompatibility.BuildYSeriesDefinition == nil, "Quasar provider must not expose the YSeries mapper")

dofile("sky_phone/source/bridge/phones/shared/yseries.lua")
assert(type(SkyPhoneCompatibility.BuildYSeriesDefinition) == "function", "YSeries provider must expose its mapper")

local lb_on_open_calls = 0
local lb_on_use_calls = 0
local lb_definition = assert(SkyPhoneCompatibility.BuildLbDefinition("lb_app", {
    identifier = "dispatch",
    name = "Dispatch",
    description = "Dispatch terminal",
    ui = "ui/index.html",
    defaultApp = true,
    fixBlur = true,
    landscape = true,
    onOpen = function()
        lb_on_open_calls = lb_on_open_calls + 1
    end,
    onUse = function()
        lb_on_use_calls = lb_on_use_calls + 1
    end,
    onDelete = function() end,
}))
assert(lb_definition.id == "dispatch", "LB identifier must map to the Sky app ID")
assert(lb_definition.ui == "ui/index.html", "LB relative UI must remain owner-relative")
assert(lb_definition.orientation == "landscape", "LB landscape flag must be preserved")
assert(type(lb_definition.onOpen) == "function", "LB onUse must map to the open lifecycle")
lb_definition.onOpen()
assert(lb_on_open_calls == 1, "LB onOpen must run when the app opens")
assert(lb_on_use_calls == 1, "LB onUse must also run when the app opens")
assert(type(lb_definition.onDelete) == "function", "LB onDelete must map to the uninstall lifecycle")
assert(lb_definition.compatibility.resourceName == "lb_app", "LB callbacks must target the registering resource")
assert(lb_definition.compatibility.fixBlur, "LB fixBlur must be preserved")

local bridged_lb_definition = assert(SkyPhoneCompatibility.BuildLbDefinition("phone_adapter", {
    identifier = "bridged",
    name = "Bridged",
    ui = "manufacturer_app/ui/index.html",
    resource = "manufacturer_app",
}))
assert(
    bridged_lb_definition.compatibility.resourceName == "manufacturer_app",
    "LB adapter callbacks must target the declared app resource"
)

local invalid_lb, invalid_lb_error = SkyPhoneCompatibility.BuildLbDefinition("lb_app", {
    identifier = "dispatch",
    name = "Dispatch",
    ui = "@another_resource/ui/index.html",
})
assert(invalid_lb == nil, "LB must reject an @ URL owned by another resource")
assert(invalid_lb_error == "ui_owner_mismatch", "LB owner mismatch must be explicit")

local mov_definition = assert(SkyPhoneCompatibility.Build17MovDefinition({
    name = "market",
    label = "Market",
    ui = "https://cfx-nui-market_app/ui/index.html",
    iconBackground = "#112233",
    preInstalled = true,
}))
assert(mov_definition.id == "market", "17mov name must map to the Sky app ID")
assert(mov_definition.iconBackground == "#112233", "17mov icon background must be preserved")
assert(mov_definition.defaultInstalled, "17mov preInstalled must be preserved")

local high_definition = assert(SkyPhoneCompatibility.BuildHighDefinition("high_app", "bankingv2", {
    externalUrl = "@high_app/ui/index.html",
    icon = {
        imageUrl = "ui/icon.png",
        background = "#1b1b1b",
    },
    preAdded = true,
}, {
    en = {
        label = "Banking",
        description = "Banking app",
    },
}))
assert(high_definition.ui == "high_app/ui/index.html", "High @ URL must normalize to its owner")
assert(high_definition.name.en == "Banking", "High locale labels must be preserved")
assert(high_definition.iconBackground == "#1b1b1b", "High icon background must be preserved")

local quasar_data = {
    id = "services",
    label = "Services",
    iframe = {
        url = "https://cfx-nui-services/ui/index.html",
    },
}
local quasar_definition = assert(SkyPhoneCompatibility.BuildQuasarDefinition(quasar_data))
local quasar_copy = SkyPhoneCompatibility.CopyQuasarData(quasar_data)
quasar_copy.iframe.url = "changed"
assert(quasar_definition.id == "services", "Quasar ID must be preserved")
assert(quasar_data.iframe.url ~= quasar_copy.iframe.url, "Quasar iframe data must be copied")

local yseries_definition = assert(SkyPhoneCompatibility.BuildYSeriesDefinition({
    key = "slots",
    name = "Slots",
    ui = "https://cfx-nui-slots/ui/index.html",
    icon = {
        yos = "ui/yos.png",
        humanoid = "ui/humanoid.png",
    },
    game = true,
}))
assert(yseries_definition.id == "slots", "YSeries key must map to the Sky app ID")
assert(yseries_definition.icon == "ui/yos.png", "YSeries must prefer the YOS icon")
assert(yseries_definition.category == "games", "YSeries game flag must be preserved")

print("Custom app compatibility mapping tests passed")
