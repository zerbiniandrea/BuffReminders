local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE SECTION: Interaction
-- ============================================================================
-- What the mouse does. One override covers click to cast, the hover highlight and
-- the tooltips. While it is off, the controls show the values of the Defaults page.

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local LayoutSectionHeader = Helpers.LayoutSectionHeader

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DEPENDENT_INDENT = BR.Options.Constants.DEPENDENT_INDENT

local INTERACTION_KEYS = { "clickable", "clickableHighlight", "showDescriptionTooltips" }

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local prefix = "categorySettings." .. category .. "."

    local function isOverriding()
        return Helpers.GetCategorySetting(category, "useCustomInteraction", false) == true
    end

    local function getEffective(key)
        return BR.Config.GetCategorySetting(category, key)
    end

    local function isClickable()
        return getEffective("clickable") == true
    end

    LayoutSectionHeader(layout, parent, L["Options.Interaction"])

    Helpers.AddOverrideRow(parent, layout, {
        get = isOverriding,
        desc = L["Options.Override.Interaction.Desc"],
        defaultsLink = true,
        onChange = function(checked)
            local changes = { [prefix .. "useCustomInteraction"] = checked }
            if checked then
                -- Snapshot the effective values, so the override does not change the display.
                local profileDefaults = BR.profile.defaults
                for _, key in ipairs(INTERACTION_KEYS) do
                    if Helpers.GetCategorySetting(category, key) == nil then
                        changes[prefix .. key] = profileDefaults[key]
                    end
                end
            end
            BR.Config.SetMulti(changes)
            BR.SecureButtons.UpdateActionButtons(category)
            Components.RefreshAll()
        end,
    })

    local clickableHolder = Components.Checkbox(parent, {
        label = L["Options.ClickToCast"],
        get = isClickable,
        enabled = isOverriding,
        disabledReason = L["DisabledReason.OverrideSection"],
        tooltip = {
            title = L["Options.ClickToCast"],
            desc = category == "custom" and L["Options.ClickToCast.Custom.Desc"] or L["Options.ClickToCast.DescFull"],
        },
        onChange = function(checked)
            BR.Config.Set(prefix .. "clickable", checked)
            BR.SecureButtons.UpdateActionButtons(category)
            Components.RefreshAll()
        end,
    })
    layout:Add(clickableHolder, nil, COMPONENT_GAP)

    local baseX = layout:GetX()
    layout:SetX(baseX + DEPENDENT_INDENT)
    local highlightHolder = Components.Checkbox(parent, {
        label = L["Options.HoverHighlight"],
        get = function()
            return getEffective("clickableHighlight") ~= false
        end,
        enabled = function()
            return isOverriding() and isClickable()
        end,
        disabledReason = function()
            return isOverriding() and L["DisabledReason.ClickToCast"] or L["DisabledReason.OverrideSection"]
        end,
        tooltip = {
            title = L["Options.HoverHighlight"],
            desc = L["Options.HoverHighlight.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set(prefix .. "clickableHighlight", checked)
            BR.SecureButtons.UpdateActionButtons(category)
        end,
    })
    layout:Add(highlightHolder, nil, COMPONENT_GAP)

    -- A global key outside the override: it applies wherever pet clicks are on.
    if category == "pet" then
        local specIconHolder = Components.Checkbox(parent, {
            label = L["Options.PetSpecIcon"],
            get = function()
                return BR.Config.Get("defaults.petSpecIconOnHover")
            end,
            enabled = isClickable,
            disabledReason = L["DisabledReason.ClickToCast"],
            tooltip = {
                title = L["Options.PetSpecIcon.Title"],
                desc = L["Options.PetSpecIcon.Desc"],
            },
            onChange = function(checked)
                BR.Config.Set("defaults.petSpecIconOnHover", checked)
            end,
        })
        layout:Add(specIconHolder, nil, COMPONENT_GAP)
    end
    layout:SetX(baseX)

    -- The hover tooltip works on the icon frame itself, not on the click overlay.
    -- Thus click to cast does not gate it.
    local tooltipsHolder = Components.Checkbox(parent, {
        label = L["Options.ShowDescriptionTooltips"],
        get = function()
            return getEffective("showDescriptionTooltips") == true
        end,
        enabled = isOverriding,
        disabledReason = L["DisabledReason.OverrideSection"],
        tooltip = {
            title = L["Options.ShowDescriptionTooltips"],
            desc = L["Options.ShowDescriptionTooltips.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set(prefix .. "showDescriptionTooltips", checked)
        end,
    })
    layout:Add(tooltipsHolder, nil, COMPONENT_GAP)
end

BR.Options.BuffSections.ClickToCast = Build
