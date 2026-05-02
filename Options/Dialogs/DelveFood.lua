local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.DelveFood = BR.Options.Helpers.SingletonDialog(function()
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersDelveFoodDialog", "Options.DelveFoodSettings")
    local dialog, layout = shell.dialog, shell.layout

    local timerHolder = Components.Checkbox(dialog, {
        label = L["Options.DelveFoodTimer"],
        get = function()
            return BR.Config.Get("defaults.delveFoodTimer", false) == true
        end,
        tooltip = {
            title = L["Options.DelveFoodTimer"],
            desc = L["Options.DelveFoodTimer.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.delveFoodTimer", checked)
        end,
    })
    layout:Add(timerHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
