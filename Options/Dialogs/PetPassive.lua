local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.PetPassive = BR.Options.Helpers.SingletonDialog(function()
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersPetPassiveDialog", "Options.PetPassiveSettings")
    local dialog, layout = shell.dialog, shell.layout

    local passiveCombatHolder = Components.Checkbox(dialog, {
        label = L["Options.PetPassiveCombat"],
        get = function()
            return BR.profile.petPassiveOnlyInCombat == true
        end,
        tooltip = {
            title = L["Options.PetPassiveCombat"],
            desc = L["Options.PetPassiveCombat.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("petPassiveOnlyInCombat", checked)
        end,
    })
    layout:Add(passiveCombatHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
