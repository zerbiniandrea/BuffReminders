local _, BR = ...

local L = BR.L

BR.Options.Pages.pet = {
    title = L["Category.PetReminders"],
    showMasqueBanner = true,
    Build = function(content, scrollFrame)
        BR.Options.Pages.BuffTemplate.Build(content, scrollFrame, "pet")
    end,
}
