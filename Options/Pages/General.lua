local _, BR = ...

-- ============================================================================
-- GENERAL PAGE
-- ============================================================================
-- Addon-meta toggles that aren't tied to any buff or category: login messages
-- and the minimap launcher icon. Kept small intentionally - Chat Requests
-- and Anchor Frames live on their own dedicated pages.

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

local abs = math.abs

local function Build(content)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })

    local loginMsgHolder = Components.Checkbox(content, {
        label = L["Options.ShowLoginMessages"],
        get = function()
            return BR.profile.showLoginMessages ~= false
        end,
        onChange = function(checked)
            BR.profile.showLoginMessages = checked
        end,
    })
    layout:Add(loginMsgHolder, nil, COMPONENT_GAP)

    local minimapHolder = Components.Checkbox(content, {
        label = L["Options.ShowMinimapButton"],
        get = function()
            return not BR.aceDB.global.minimap.hide
        end,
        onChange = function(checked)
            BR.aceDB.global.minimap.hide = not checked
            if BR.MinimapButton then
                if checked then
                    BR.MinimapButton.Icon:Show("BuffReminders")
                else
                    BR.MinimapButton.Icon:Hide("BuffReminders")
                end
            end
        end,
    })
    layout:Add(minimapHolder, nil, COMPONENT_GAP)

    content:SetHeight(abs(layout:GetY()) + 20)
end

BR.Options.Pages.general = {
    title = L["Page.General"],
    Build = Build,
}
