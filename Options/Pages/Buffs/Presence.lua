local _, BR = ...

local L = BR.L

BR.Options.Pages.presence = {
    title = L["Category.PresenceBuffs"],
    showMasqueBanner = true,
    Build = function(content, scrollFrame)
        BR.Options.Pages.BuffTemplate.Build(content, scrollFrame, "presence")
    end,
}
