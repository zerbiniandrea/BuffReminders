local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- BUFF PAGE TEMPLATE (orchestrator)
-- ============================================================================
-- Builds a per-category page by composing display sections in a fixed order.
-- This is the only builder for a category tab, so every tab gets the same top
-- padding and the same section rhythm. The caller declares a category and
-- optional resize hooks; the template decides which sections that category gets.
-- Per-category branches inside a section (raid-only / pet-only / consumable-only
-- widgets) live in that section file, not here.
--
-- The order answers one question per section: what the reminder shows, when it
-- shows, where it sits, how it looks, what is drawn on it, how it glows, and
-- what the mouse does. A category leaves out a section that has nothing for it,
-- but never moves one.
--
-- The template renders only "how this category displays". Per-buff toggling
-- lives on the All Buffs page.
--
-- Each section is a separate file because Lua 5.1 caps a closure at 60 upvalues.
-- One combined builder crosses that ceiling.

local Components = BR.Components

-- A pet is present or missing. A utility chore expires only if it gives a timed aura.
---@param category CategoryName
---@return boolean
local function HasExpiration(category)
    if category == "pet" then
        return false
    end
    if category ~= "utility" then
        return true
    end
    for _, buff in ipairs(BR.BuffData.buffTables.utility) do
        if buff.renewAuraID then
            return true
        end
    end
    return false
end

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local Template = {}

---@param content table Frame the sections render into (the tab frame)
---@param scrollFrame table Owning scroll container (for content width)
---@param category string Category key driving the section set
---@param opts? table { appearancePadding?: number, onAppearanceResize?: fun() }
---        The template sizes the tab frame after the last section and after every
---        relayout, then calls onAppearanceResize so the page can grow.
function Template.Build(content, scrollFrame, category, opts)
    opts = opts or {}
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    local function FitHeight()
        content:SetHeight(math.abs(layout:GetY()) + (opts.appearancePadding or 30))
        if opts.onAppearanceResize then
            opts.onAppearanceResize()
        end
    end

    local ctx = {
        category = category,
        content = content,
        scrollFrame = scrollFrame,
        contentWidth = scrollFrame:GetContentWidth(),
        -- A section that changes the height of a block calls this, so the
        -- sections below it move.
        relayout = function()
            layout:Reflow()
            FitHeight()
        end,
    }

    local Sections = BR.Options.BuffSections
    local userAuthored = category == "custom" or category == "loadout"

    if category == "pet" then
        Sections.PetDisplay(ctx, layout)
    end
    if category == "consumable" then
        Sections.ItemDisplay(ctx, layout)
    end

    -- The user-authored categories carry styling only. Their entry lists and
    -- per-entry config live on their own sidebar pages and dialogs.
    if not userAuthored then
        Sections.Visibility(ctx, layout)
        if HasExpiration(category) then
            Sections.Timing(ctx, layout)
        end
        if category == "consumable" then
            Sections.ConsumableFilters(ctx, layout)
            Sections.FreeConsumables(ctx, layout)
        end
    end

    Sections.Layout(ctx, layout)
    Sections.Appearance(ctx, layout)

    if not userAuthored then
        Sections.Overlays(ctx, layout)
    end

    Sections.Glow(ctx, layout)

    if category ~= "loadout" then
        Sections.ClickToCast(ctx, layout)
    end

    FitHeight()
end

BR.Options.Pages.BuffTemplate = Template
