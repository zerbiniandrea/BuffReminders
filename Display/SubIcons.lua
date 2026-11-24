local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- SUB-ICON ROWS
-- The small secure buttons around a reminder icon: consumable items and choice
-- rows. Each button anchors to UIParent, never to the buff frame, because an anchor
-- protects the buff frame hierarchy. Call CreateButton, Activate and Park only out of combat.
-- ============================================================================

local floor, max, min = math.floor, math.max, math.min

local SubIcons = {}

local ICON_SCALE = 0.45
local ICON_MIN = 18
local EDGE_OFFSET = -6
local FADE_IN_DURATION = 0.12
SubIcons.FADE_OUT_DURATION = 0.2

-- A choice row can lie over a neighbor icon. One strata up, no overlay takes its mouse.
SubIcons.STRATA_ABOVE = {
    BACKGROUND = "LOW",
    LOW = "MEDIUM",
    MEDIUM = "HIGH",
    HIGH = "DIALOG",
    DIALOG = "FULLSCREEN",
    FULLSCREEN = "FULLSCREEN_DIALOG",
    FULLSCREEN_DIALOG = "TOOLTIP",
    TOOLTIP = "TOOLTIP",
}

---@param iconSize number Main icon size of the host category
---@return number size Side of one sub-icon
---@return number spacing Gap between two sub-icons
function SubIcons.Metrics(iconSize)
    local size = max(ICON_MIN, floor(iconSize * ICON_SCALE))
    return size, max(2, floor(size * 0.2))
end

---Screen position of one sub-icon. Rows wrap at the host width (TOP, BOTTOM) or
---the host height (LEFT, RIGHT), and each line is centered on the host.
---@param idx number Zero-based index among the shown sub-icons
---@param count number Number of shown sub-icons
---@param side string "TOP", "BOTTOM", "LEFT" or "RIGHT"
---@param left number Host rect, screen coordinates
---@param bottom number
---@param width number
---@param height number
---@param size number From Metrics
---@param spacing number From Metrics
---@return number x Bottom-left corner of the sub-icon
---@return number y
function SubIcons.Position(idx, count, side, left, bottom, width, height, size, spacing)
    local step = size + spacing
    if side == "LEFT" or side == "RIGHT" then
        local perLine = max(1, floor((height + spacing) / step))
        local line = floor(idx / perLine)
        local lineCount = min(perLine, count - line * perLine)
        local lineStart = bottom + (height - (lineCount * size + (lineCount - 1) * spacing)) / 2
        local y = lineStart + (idx % perLine) * step
        if side == "LEFT" then
            return left + EDGE_OFFSET - size - line * step, y
        end
        return left + width - EDGE_OFFSET + line * step, y
    end
    local perLine = max(1, floor((width + spacing) / step))
    local line = floor(idx / perLine)
    local lineCount = min(perLine, count - line * perLine)
    local lineStart = left + (width - (lineCount * size + (lineCount - 1) * spacing)) / 2
    local x = lineStart + (idx % perLine) * step
    if side == "TOP" then
        return x, bottom + height - EDGE_OFFSET + line * step
    end
    return x, bottom + EDGE_OFFSET - size - line * step
end

---A hidden sub-icon button with its icon, count and highlight. The caller adds the
---click and hover scripts. The sync positions it, then calls Activate.
---@return table btn
function SubIcons.CreateButton()
    local btn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:Hide()
    RegisterStateDriver(btn, "visibility", "hide")
    -- IsVisible(), not IsShown(): the host can be shown inside a hidden container.
    btn:SetScript("OnShow", function(self)
        local host = self._br_buff_frame
        if not host or not host:IsVisible() then
            self:Hide()
        end
    end)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", -1, 1)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)
    btn.highlight:SetColorTexture(1, 1, 1, 0.2)

    -- Alpha animations only: a moving secure button can miss the click.
    local fadeIn = btn:CreateAnimationGroup()
    local alphaIn = fadeIn:CreateAnimation("Alpha")
    alphaIn:SetFromAlpha(0)
    alphaIn:SetToAlpha(1)
    alphaIn:SetDuration(FADE_IN_DURATION)
    btn._br_fadeIn = fadeIn
    btn._br_alphaIn = alphaIn
    -- The final alpha holds until the sync hides the button.
    local fadeOut = btn:CreateAnimationGroup()
    fadeOut:SetToFinalAlpha(true)
    local alphaOut = fadeOut:CreateAnimation("Alpha")
    alphaOut:SetFromAlpha(1)
    alphaOut:SetToAlpha(0)
    alphaOut:SetDuration(SubIcons.FADE_OUT_DURATION)
    btn._br_fadeOut = fadeOut
    btn._br_alphaOut = alphaOut
    btn._br_alpha = 1
    return btn
end

---Match the alpha of a button to its host icon. A button is a child of UIParent, so
---it does not inherit the icon alpha or a container dim. The fades end at this alpha.
---@param btn table
---@param alpha number
function SubIcons.SetAlpha(btn, alpha)
    if btn._br_alpha ~= alpha then
        btn._br_alpha = alpha
        btn._br_alphaIn:SetToAlpha(alpha)
        btn._br_alphaOut:SetFromAlpha(alpha)
    end
    -- A finished fade-out holds alpha 0 on a button that stays active.
    if not btn._br_fadeOut:IsPlaying() and btn:GetAlpha() ~= alpha then
        btn:SetAlpha(alpha)
    end
end

---Hand the visibility of a placed button to the combat driver.
---@param btn table
---@return boolean activated True when the button was parked before this call
function SubIcons.Activate(btn)
    if btn._br_driver_active then
        return false
    end
    RegisterStateDriver(btn, "visibility", "[combat] hide; show")
    btn._br_driver_active = true
    btn:SetAlpha(btn._br_alpha)
    return true
end

---Hide a button until the next Activate. An active button forgets its position.
---@param btn table
function SubIcons.Park(btn)
    if btn._br_driver_active then
        RegisterStateDriver(btn, "visibility", "hide")
        btn._br_driver_active = false
        btn._br_x = nil
    else
        btn:Hide()
    end
end

BR.SubIcons = SubIcons
