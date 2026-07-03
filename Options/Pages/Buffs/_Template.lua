local _, BR = ...

-- ============================================================================
-- BUFF PAGE TEMPLATE (orchestrator)
-- ============================================================================
-- Builds a per-category page by composing display sections in a fixed order.
-- This is the SINGLE builder for every category tab (Pages/Buffs/Categories.lua
-- calls it for all of them), so the layout is identical everywhere: same top
-- padding, same section rhythm, same CustomAppearance-owns-the-height contract.
-- The caller declares a category and optional resize hooks; the template
-- decides which sections that category gets. Per-category branches inside
-- sections (raid-only / pet-only / consumable-only widgets) live within each
-- section file, not here.
--
-- Per-buff toggling lives on the All Buffs page (Pages/Buffs/AllBuffs.lua) -
-- this template renders only "how this category displays" (visibility, icons,
-- click-to-cast, layout, etc.). Sound alerts are a cross-cutting notification
-- feature and live on their own sidebar page (Pages/Sounds.lua).
--
-- The user-authored categories (custom / loadout) keep their entry list +
-- per-entry config on their own sidebar pages and dialogs, so their tab carries
-- styling only (Layout + CustomAppearance) - declared as one branch below
-- rather than hand-rolled by the caller.

local Components = BR.Components

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local Template = {}

---@param content table Frame the sections render into (the tab frame)
---@param scrollFrame table Owning scroll container (for content width)
---@param category string Category key driving the section set
---@param opts? table { appearancePadding?: number, onAppearanceResize?: fun() }
---        Threaded into ctx so CustomAppearance (the last section) can size the
---        tab frame and notify the page to resize.
function Template.Build(content, scrollFrame, category, opts)
    opts = opts or {}
    local ctx = {
        category = category,
        content = content,
        scrollFrame = scrollFrame,
        contentWidth = scrollFrame:GetContentWidth(),
        appearancePadding = opts.appearancePadding,
        onAppearanceResize = opts.onAppearanceResize,
    }
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    local Sections = BR.Options.BuffSections

    -- Styling-only categories: only Layout + CustomAppearance.
    if category == "custom" or category == "loadout" then
        Sections.Layout(ctx, layout)
        Sections.CustomAppearance(ctx, layout)
        return
    end

    Sections.Visibility(ctx, layout)
    if category == "consumable" then
        Sections.FreeConsumables(ctx, layout)
    end
    Sections.Icons(ctx, layout)
    if category == "raid" then
        Sections.RaidIcons(ctx, layout)
    end
    Sections.ClickToCast(ctx, layout)
    if category == "pet" then
        Sections.PetDisplay(ctx, layout)
    end
    if category == "consumable" then
        Sections.ItemDisplay(ctx, layout)
    end
    -- Pet reminders have no expiration concept (a pet is present or missing),
    -- so the Timing section is skipped there.
    if category ~= "pet" then
        Sections.Timing(ctx, layout)
    end
    Sections.Layout(ctx, layout)
    -- CustomAppearance (Appearance + Glow override sections) MUST be last:
    -- it owns the final content:SetHeight for the page.
    Sections.CustomAppearance(ctx, layout)
end

BR.Options.Pages.BuffTemplate = Template
