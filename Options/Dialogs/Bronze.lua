local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.Bronze = BR.Options.Helpers.SingletonDialog(function()
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersBronzeDialog", "Options.BronzeSettings")
    local dialog, layout = shell.dialog, shell.layout

    local hideInCombatHolder = Components.Checkbox(dialog, {
        label = L["Options.BronzeHideInCombat"],
        get = function()
            return BR.profile.bronzeHideInCombat == true
        end,
        tooltip = {
            title = L["Options.BronzeHideInCombat"],
            desc = L["Options.BronzeHideInCombat.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("bronzeHideInCombat", checked)
        end,
    })
    layout:Add(hideInCombatHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
