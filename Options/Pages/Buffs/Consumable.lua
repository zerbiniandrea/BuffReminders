local _, BR = ...

local L = BR.L

BR.Options.Pages.consumable = {
    title = L["Category.Consumables"],
    showMasqueBanner = true,
    Build = function(content, scrollFrame)
        BR.Options.Pages.BuffTemplate.Build(content, scrollFrame, "consumable")
    end,
}
