local _, BR = ...

local L = BR.L

BR.Options.Pages.self = {
    title = L["Category.SelfBuffs"],
    showMasqueBanner = true,
    Build = function(content, scrollFrame)
        BR.Options.Pages.BuffTemplate.Build(content, scrollFrame, "self")
    end,
}
