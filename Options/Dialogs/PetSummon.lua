local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.PetSummon = BR.Options.Helpers.SingletonDialog(function()
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersPetSummonDialog", "Options.PetSummonSettings")
    local dialog, layout = shell.dialog, shell.layout

    local felDomHolder = Components.Checkbox(dialog, {
        label = L["Options.FelDomination"],
        get = function()
            return BR.Config.Get("defaults.useFelDomination", false)
        end,
        tooltip = {
            title = L["Options.FelDomination.Title"],
            desc = L["Options.FelDomination.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.useFelDomination", checked)
        end,
    })
    layout:Add(felDomHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
