local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.Soulstone = BR.Options.Helpers.SingletonDialog(function()
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersSoulstoneDialog", "Options.SoulstoneSettings")
    local dialog, layout = shell.dialog, shell.layout

    local visHolder = Components.Dropdown(dialog, {
        label = L["Options.Visibility"],
        width = 200,
        get = function()
            return BR.Config.Get("defaults.soulstoneVisibility", "readyCheck")
        end,
        options = {
            {
                value = "readyCheck",
                label = L["Options.Soulstone.ReadyCheckOnly"],
                desc = L["Options.Soulstone.ReadyCheckDesc"],
            },
            {
                value = "casterOnly",
                label = L["Options.Soulstone.ReadyCheckWarlock"],
                desc = L["Options.Soulstone.WarlockAlwaysDesc"],
            },
            { value = "always", label = L["Options.Soulstone.AlwaysShow"], desc = L["Options.Soulstone.AlwaysDesc"] },
        },
        tooltip = { title = L["Options.Soulstone.Visibility"], desc = L["Options.Soulstone.Visibility.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.soulstoneVisibility", val)
        end,
    })
    layout:Add(visHolder, nil, COMPONENT_GAP)

    local cdHolder = Components.Checkbox(dialog, {
        label = L["Options.Soulstone.HideCooldown"],
        get = function()
            return BR.Config.Get("defaults.soulstoneHideCooldown", false)
        end,
        tooltip = {
            title = L["Options.Soulstone.HideCooldown"],
            desc = L["Options.Soulstone.HideCooldown.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.soulstoneHideCooldown", checked)
        end,
    })
    layout:Add(cdHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
