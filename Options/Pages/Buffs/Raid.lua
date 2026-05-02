local _, BR = ...

local L = BR.L

BR.Options.Pages.raid = {
    title = L["Category.RaidBuffs"],
    showMasqueBanner = true,
    Build = function(content, scrollFrame)
        BR.Options.Pages.BuffTemplate.Build(content, scrollFrame, "raid")
    end,
}
