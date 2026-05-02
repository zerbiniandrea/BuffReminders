local _, BR = ...

local L = BR.L

BR.Options.Pages.targeted = {
    title = L["Category.TargetedBuffs"],
    showMasqueBanner = true,
    Build = function(content, scrollFrame)
        BR.Options.Pages.BuffTemplate.Build(content, scrollFrame, "targeted")
    end,
}
