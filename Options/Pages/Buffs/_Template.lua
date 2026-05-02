local _, BR = ...

-- ============================================================================
-- BUFF PAGE TEMPLATE (orchestrator)
-- ============================================================================
-- Builds a per-category page by composing display sections in a fixed order.
-- Per-buff toggling lives on the All Buffs page (Pages/Buffs/AllBuffs.lua) -
-- this template renders only "how this category displays" (visibility, icons,
-- click-to-cast, layout, etc.). Per-category branches inside sections
-- (raid-only / pet-only / consumable-only widgets) live within each section
-- file, not here.
--
-- Sound alerts are a cross-cutting notification feature and live on their own
-- dedicated sidebar page (Pages/Sounds.lua), not as a per-category section.
--
-- Custom Buffs uses Pages/Buffs/Custom.lua, which has its own list+editor
-- (dialog-driven) and reuses only Layout + CustomAppearance.

local Components = BR.Components

local COL_PADDING = BR.Options.Constants.COL_PADDING

local Template = {}

function Template.Build(content, scrollFrame, category)
    local ctx = {
        category = category,
        content = content,
        scrollFrame = scrollFrame,
        contentWidth = scrollFrame:GetContentWidth(),
    }
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })

    local Sections = BR.Options.BuffSections

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
    Sections.Layout(ctx, layout)
    -- CustomAppearance MUST be last: it owns content:SetHeight so the page
    -- can collapse when its toggle is off (reserved appearance grid space
    -- would otherwise leave the page scrollable over empty whitespace).
    Sections.CustomAppearance(ctx, layout)
end

BR.Options.Pages.BuffTemplate = Template
