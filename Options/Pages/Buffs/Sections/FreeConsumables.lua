local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Free Consumables (consumable category only)
-- ============================================================================
-- Sub-section appended to the consumable Visibility block: a toggle that
-- overrides the normal visibility for buffs that do not require an item, plus
-- its own W/S/D/R picker. _Template.lua composes it immediately after
-- Sections.Visibility when category=="consumable".

local L = BR.L
local Components = BR.Components
local Helpers = BR.Options.Helpers

local UpdateDisplay = BR.Display.Update

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

BR.Options.BuffSections = BR.Options.BuffSections or {}

local FREE_VISIBILITY_DEFAULT = {
    openWorld = false,
    scenario = true,
    dungeon = true,
    raid = true,
    housing = false,
    pvp = true,
}

local function Build(ctx, layout)
    local parent = ctx.content
    local db = BR.profile

    local function EnsureFreeVisibility()
        if not db.defaults then
            db.defaults = {}
        end
        if not db.defaults.freeConsumableVisibility then
            local copy = {}
            for k, v in pairs(FREE_VISIBILITY_DEFAULT) do
                copy[k] = v
            end
            db.defaults.freeConsumableVisibility = copy
        end
        return db.defaults.freeConsumableVisibility
    end

    layout:Space(SECTION_GAP)
    Helpers.LayoutSubsectionHeader(layout, parent, L["Options.FreeConsumables"])
    Helpers.LayoutSubsectionNote(layout, parent, L["Options.FreeConsumables.Note"])

    local function IsFreeOverride()
        return BR.Config.Get("defaults.freeConsumableMode") == "override"
    end

    local freeOverrideHolder = Components.Checkbox(parent, {
        label = L["Options.FreeConsumables.Override"],
        get = IsFreeOverride,
        tooltip = {
            title = L["Options.FreeConsumables.Override"],
            desc = L["Options.FreeConsumables.Override.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.freeConsumableMode", checked and "override" or "follow")
            Components.RefreshAll()
        end,
    })
    layout:Add(freeOverrideHolder, nil, COMPONENT_GAP)

    local INDENT = 12
    layout:SetX(layout:GetX() + INDENT)

    local freeVisToggles = Components.VisibilityToggles(parent, {
        store = {
            getContent = function(key)
                local vis = db.defaults and db.defaults.freeConsumableVisibility
                return not vis or vis[key] ~= false
            end,
            setContent = function(key)
                local vis = EnsureFreeVisibility()
                vis[key] = not vis[key]
            end,
            getDiffTable = function(dbKey)
                local vis = db.defaults and db.defaults.freeConsumableVisibility
                return vis and vis[dbKey]
            end,
            ensureDiffTable = function(dbKey)
                local vis = EnsureFreeVisibility()
                if not vis[dbKey] then
                    vis[dbKey] = {} ---@diagnostic disable-line: assign-type-mismatch
                end
                return vis[dbKey]
            end,
        },
        noAutoRefresh = true,
        onChange = function()
            UpdateDisplay()
        end,
    })
    local origVisRefresh = freeVisToggles.Refresh
    function freeVisToggles:Refresh()
        origVisRefresh(self)
        local enabled = IsFreeOverride()
        self:SetAlpha(enabled and 1 or 0.4)
        for _, btn in ipairs(self.allToggleButtons) do
            btn:EnableMouse(enabled)
        end
    end
    table.insert(BR.RefreshableComponents, freeVisToggles)
    layout:Add(freeVisToggles, nil, COMPONENT_GAP)

    layout:SetX(layout:GetX() - INDENT)
end

BR.Options.BuffSections.FreeConsumables = Build
