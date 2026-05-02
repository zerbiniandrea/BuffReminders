local _, BR = ...

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

BR.Options.Dialogs.Healthstone = BR.Options.Helpers.SingletonDialog(function()
    local shell = BR.Options.Helpers.CreateDialogShell("BuffRemindersHealthstoneDialog", "Options.HealthstoneSettings")
    local dialog, layout = shell.dialog, shell.layout

    -- Shared label width so the dropdown and slider line up vertically.
    local labelW = Components.MeasureSharedLabelWidth({
        L["Options.Visibility"],
        L["Options.Healthstone.Threshold"],
    })

    local visHolder = Components.Dropdown(dialog, {
        label = L["Options.Visibility"],
        labelWidth = labelW,
        width = 200,
        get = function()
            return BR.Config.Get("defaults.healthstoneVisibility", "readyCheck")
        end,
        options = {
            {
                value = "readyCheck",
                label = L["Options.Healthstone.ReadyCheckOnly"],
                desc = L["Options.Healthstone.ReadyCheckDesc"],
            },
            {
                value = "casterOnly",
                label = L["Options.Healthstone.ReadyCheckWarlock"],
                desc = L["Options.Healthstone.WarlockAlwaysDesc"],
            },
            {
                value = "always",
                label = L["Options.Healthstone.AlwaysShow"],
                desc = L["Options.Healthstone.AlwaysDesc"],
            },
        },
        tooltip = { title = L["Options.Healthstone.Visibility"], desc = L["Options.Healthstone.Visibility.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.healthstoneVisibility", val)
        end,
    })
    layout:Add(visHolder, nil, COMPONENT_GAP)

    local lowStockHolder = Components.Checkbox(dialog, {
        label = L["Options.Healthstone.LowStock"],
        get = function()
            return BR.Config.Get("defaults.healthstoneLowStock", false)
        end,
        tooltip = {
            title = L["Options.Healthstone.LowStock"],
            desc = L["Options.Healthstone.LowStock.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.healthstoneLowStock", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(lowStockHolder, nil, COMPONENT_GAP)

    local thresholdHolder = Components.Slider(dialog, {
        label = L["Options.Healthstone.Threshold"],
        labelWidth = labelW,
        min = 1,
        max = 2,
        step = 1,
        get = function()
            return BR.Config.Get("defaults.healthstoneThreshold", 1)
        end,
        enabled = function()
            return BR.Config.Get("defaults.healthstoneLowStock", false)
        end,
        tooltip = { title = L["Options.Healthstone.Threshold"], desc = L["Options.Healthstone.Threshold.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.healthstoneThreshold", val)
        end,
    })
    layout:Add(thresholdHolder, nil, COMPONENT_GAP)

    shell:Finalize()
    return dialog
end)
