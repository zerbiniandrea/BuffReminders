local _, BR = ...

-- ============================================================================
-- MOVER FRAME SYSTEM
-- Draggable positioning frames shown when the addon is "unlocked."
-- Each category (and the main combined frame) gets its own mover.
-- ============================================================================

-- Lua stdlib locals
local floor = math.floor
local format = string.format
local strfind = string.find
local tinsert, tconcat = table.insert, table.concat

local L = BR.L
local CATEGORIES = BR.CATEGORIES
local CATEGORY_LABELS = BR.CATEGORY_LABELS
local DIRECTION_ANCHORS = BR.DIRECTION_ANCHORS

local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit
local IsIconDetached = BR.Helpers.IsIconDetached

-- Shared hairline border (BR.Colors.Border), unpacked once for the popup/menu chrome below.
local BORDER_R, BORDER_G, BORDER_B = unpack(BR.Colors.Border)

local ANCHOR_COORD_FN = {
    LEFT = function(m, px, py)
        return m:GetLeft() - px, select(2, m:GetCenter()) - py
    end,
    RIGHT = function(m, px, py)
        return m:GetRight() - px, select(2, m:GetCenter()) - py
    end,
    TOP = function(m, px, py)
        return select(1, m:GetCenter()) - px, m:GetTop() - py
    end,
    BOTTOM = function(m, px, py)
        return select(1, m:GetCenter()) - px, m:GetBottom() - py
    end,
    TOPLEFT = function(m, px, py)
        return m:GetLeft() - px, m:GetTop() - py
    end,
    TOPRIGHT = function(m, px, py)
        return m:GetRight() - px, m:GetTop() - py
    end,
    BOTTOMLEFT = function(m, px, py)
        return m:GetLeft() - px, m:GetBottom() - py
    end,
    BOTTOMRIGHT = function(m, px, py)
        return m:GetRight() - px, m:GetBottom() - py
    end,
}

local moverFrames = {} -- Per-category mover frames (shown when unlocked for drag positioning)
local detachedMoverFrames = {} -- Per-icon mover frames for detached icons
local lastDirection = {} -- Tracks previous growDirection per catKey for position conversion
local coordPopup -- Shared coordinate popup (shown on the active mover)

-- Offset from anchor edge to frame center, in units of iconSize
local ANCHOR_TO_CENTER = {
    LEFT = { x = 0.5, y = 0 },
    RIGHT = { x = -0.5, y = 0 },
    TOP = { x = 0, y = -0.5 },
    BOTTOM = { x = 0, y = 0.5 },
    CENTER = { x = 0, y = 0 },
    TOPLEFT = { x = 0.5, y = -0.5 },
    TOPRIGHT = { x = -0.5, y = -0.5 },
    BOTTOMLEFT = { x = 0.5, y = 0.5 },
    BOTTOMRIGHT = { x = -0.5, y = 0.5 },
}

local ResolveAnchorParent -- forward declaration, set after BR.Display is available
local EXT_DIRECTION_ANCHORS -- forward declaration

local EDIT_MODE_DIM_ALPHA = 0.3

---Round a number to the nearest integer
local function RoundCoord(x)
    return floor(x + 0.5)
end

-- Convert saved position from one anchor to another so the frame stays in place
local function ConvertPosition(oldAnchor, newAnchor, x, y, width, height)
    local o, n = ANCHOR_TO_CENTER[oldAnchor], ANCHOR_TO_CENTER[newAnchor]
    return RoundCoord(x + (o.x - n.x) * width), RoundCoord(y + (o.y - n.y) * height)
end

---Get the saved position table for a category key or detached icon key
---@param catKey string "main", a category name, or a detached icon buff key
---@return table position {point, x, y}
local function GetSavedPosition(catKey)
    local db = BR.profile
    -- Detached icon position
    if IsIconDetached(catKey) then
        if db.detachedIcons and db.detachedIcons[catKey] and db.detachedIcons[catKey].position then
            return db.detachedIcons[catKey].position
        end
        return { x = 0, y = 0 }
    end
    local defaults = BR.defaults
    if catKey == "main" then
        return (db.categorySettings and db.categorySettings.main and db.categorySettings.main.position)
            or db.position
            or { point = "CENTER", x = 0, y = 0 }
    end
    local catSettings = db.categorySettings and db.categorySettings[catKey]
    return (catSettings and catSettings.position)
        or (defaults.categorySettings[catKey] and defaults.categorySettings[catKey].position)
        or { point = "CENTER", x = 0, y = 0 }
end

-- Forward declarations
local PositionMoverFrame
local SaveDetachedPosition, PositionDetachedMoverFrame

---Save a position for a category key (or detached icon key) and reposition its frame
---@param catKey string "main", a category name, or a detached icon buff key
---@param x number
---@param y number
local function SavePosition(catKey, x, y)
    -- Detached icon: delegate to detached-specific save
    if IsIconDetached(catKey) then
        SaveDetachedPosition(catKey, x, y)
        PositionDetachedMoverFrame(catKey)
        return
    end

    local db = BR.profile
    if not db.categorySettings then
        db.categorySettings = {}
    end
    if not db.categorySettings[catKey] then
        db.categorySettings[catKey] = {}
    end
    db.categorySettings[catKey].position = { x = x, y = y }

    -- Reposition the icon container frame
    local container = catKey == "main" and BR.Display.mainFrame or BR.Display.categoryFrames[catKey]
    if container then
        local settings = GetCategorySettings(catKey)
        local direction = settings.growDirection or "CENTER"
        local anchor = DIRECTION_ANCHORS[direction] or "CENTER"
        container:ClearAllPoints()
        local extFrame, extPoint = ResolveAnchorParent(catKey)
        if extFrame then
            local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][direction] or anchor
            container:SetPoint(extAnchor, extFrame, extPoint, x, y)
        else
            container:SetPoint(anchor, UIParent, "CENTER", x, y)
        end
    end

    -- Keep the mover frame in sync
    PositionMoverFrame(catKey)
end

-- Build a label showing which categories are in mainFrame
local function GetMainFrameLabel()
    local parts = {}
    for _, category in ipairs(CATEGORIES) do
        if not IsCategorySplit(category) then
            tinsert(parts, CATEGORY_LABELS[category])
        end
    end
    if #parts == 0 then
        return L["Mover.MainEmpty"]
    elseif #parts == #CATEGORIES then
        return L["Mover.MainAll"]
    else
        return tconcat(parts, " + ")
    end
end

-- Dim/restore the icon container for a specific mover during drag
local function GetContainerForCatKey(catKey)
    if catKey == "main" then
        return BR.Display.mainFrame
    end
    -- Check detached frames first, then category frames
    local detached = BR.Display.detachedFrames and BR.Display.detachedFrames[catKey]
    if detached then
        return detached
    end
    return BR.Display.categoryFrames[catKey]
end

local function DimContainer(catKey)
    local container = GetContainerForCatKey(catKey)
    if container then
        container:SetAlpha(EDIT_MODE_DIM_ALPHA)
    end
end

local function RestoreContainer(catKey)
    local container = GetContainerForCatKey(catKey)
    if container then
        container:SetAlpha(1)
    end
end

---Absolute screen coordinates (scale-normalized) of a named point on a frame.
---@param frame table
---@param point string Anchor point name (TOPLEFT, CENTER, BOTTOMRIGHT, ...)
---@return number? x, number? y nil when the frame has no laid-out rect yet
local function GetPointCoords(frame, point)
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then
        return nil, nil
    end
    local w, h = frame:GetWidth(), frame:GetHeight()
    local x = strfind(point, "LEFT") and left or (strfind(point, "RIGHT") and (left + w) or (left + w / 2))
    local y = strfind(point, "TOP") and (bottom + h) or (strfind(point, "BOTTOM") and bottom or (bottom + h / 2))
    local scale = frame:GetEffectiveScale()
    return x * scale, y * scale
end

-- Finish a mover drag: read the direction-anchor edge, re-anchor, save
local function FinishMoverDrag(mover, catKey)
    mover.isDragging = false
    mover:SetScript("OnUpdate", nil)
    mover:StopMovingOrSizing()
    local settings = GetCategorySettings(catKey)
    local direction = settings.growDirection or "CENTER"
    local anchor = DIRECTION_ANCHORS[direction] or "CENTER"
    local x, y

    -- Anchored frame: dragging adjusts the offsets RELATIVE TO the anchor
    -- frame instead of silently deleting the anchor (clearing an anchor is an
    -- explicit action in the coordinate popup, never a drag side effect).
    local extFrame, extPoint = ResolveAnchorParent(catKey)
    if extFrame then
        local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][direction] or anchor
        local mx, my = GetPointCoords(mover, extAnchor)
        local ex, ey = GetPointCoords(extFrame, extPoint)
        if mx and ex then
            local scale = mover:GetEffectiveScale()
            x = RoundCoord((mx - ex) / scale)
            y = RoundCoord((my - ey) / scale)
            mover:ClearAllPoints()
            mover:SetPoint(extAnchor, extFrame, extPoint, x, y)
            SavePosition(catKey, x, y)
            if coordPopup and coordPopup:IsShown() and coordPopup.catKey == catKey then
                coordPopup.xEdit:SetText(tostring(x))
                coordPopup.yEdit:SetText(tostring(y))
            end
            RestoreContainer(catKey)
            if BR.SecureButtons then
                BR.SecureButtons.ScheduleSecureSync()
            end
            return
        end
    end

    -- No anchor frame (or it isn't laid out): UIParent-relative
    local px, py = UIParent:GetCenter()
    local coordFn = ANCHOR_COORD_FN[anchor]
    if coordFn then
        x, y = coordFn(mover, px, py)
        x = RoundCoord(x)
        y = RoundCoord(y)
    else -- CENTER
        local cx, cy = mover:GetCenter()
        x = RoundCoord(cx - px)
        y = RoundCoord(cy - py)
    end
    mover:ClearAllPoints()
    mover:SetPoint(anchor, UIParent, "CENTER", x, y)
    SavePosition(catKey, x, y)
    if coordPopup and coordPopup:IsShown() and coordPopup.catKey == catKey then
        coordPopup.xEdit:SetText(tostring(x))
        coordPopup.yEdit:SetText(tostring(y))
    end
    RestoreContainer(catKey)
    -- Re-sync sub-icon action buttons at new position
    if BR.SecureButtons then
        BR.SecureButtons.ScheduleSecureSync()
    end
end

-- Anchor point options for the dropdown (common subset like UUF)
local ANCHOR_POINT_OPTIONS = {
    "TOPLEFT",
    "TOP",
    "TOPRIGHT",
    "LEFT",
    "CENTER",
    "RIGHT",
    "BOTTOMLEFT",
    "BOTTOM",
    "BOTTOMRIGHT",
}

local rad = math.rad

-- Well-known unit frame names to look for (Blizzard + popular addons)
local KNOWN_ANCHOR_FRAMES = {
    -- Blizzard
    "PlayerFrame",
    "TargetFrame",
    "PartyFrame",
    "Minimap",
    "ObjectiveTrackerFrame",
    -- SUF (ShadowedUnitFrames)
    "SUFUnitplayer",
    "SUFUnittarget",
    "SUFUnitboss1",
    "SUFUnitparty1",
    -- ElvUI
    "ElvUF_Player",
    "ElvUF_Target",
    "ElvUF_Boss1",
    "ElvUF_Party",
    "ElvUF_Raid",
    -- Z-Perl / XPerl
    "XPerl_PlayerFrame",
    "XPerl_TargetFrame",
    -- Pitbull
    "PitBull4_Frames_Player",
    "PitBull4_Frames_Target",
    -- UUF (UnitFramesImproved)
    "UUF_Player",
    "UUF_Target",
    -- Cell (raid frames)
    "CellAnchorFrame",
    -- Grid2
    "Grid2LayoutFrame",
    -- VuhDo
    "Vd1",
}

-- Scan for anchor frames: check known names + user custom names
local function ScanAnchorFrames()
    local results = {}
    local seen = {}

    -- Check known frame names
    for _, name in ipairs(KNOWN_ANCHOR_FRAMES) do
        local obj = _G[name]
        if obj and type(obj) == "table" and not seen[obj] and obj.GetCenter ~= nil then
            seen[obj] = true
            tinsert(results, name)
        end
    end

    -- Check user-defined custom anchor frames
    local db = BR.profile
    if db.customAnchorFrames then
        for _, name in ipairs(db.customAnchorFrames) do
            local obj = _G[name]
            if obj and type(obj) == "table" and not seen[obj] and obj.GetCenter ~= nil then
                seen[obj] = true
                tinsert(results, name)
            end
        end
    end

    return results
end

-- Coordinate popup: shared singleton for typing exact X/Y positions and anchor settings
local function CreateCoordinatePopup()
    local fontPath = BR.Display.GetFontPath()
    local outlineFlag = BR.Display.GetOutline()
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(240, 210)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    popup:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)

    -- Draggable title bar
    local titleBar = CreateFrame("Frame", nil, popup)
    titleBar:SetHeight(22)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        popup:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        popup:StopMovingOrSizing()
    end)

    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont(fontPath, 11, outlineFlag)
    title:SetPoint("TOP", 0, -8)
    title:SetText(L["Mover.SetPosition"])
    title:SetTextColor(unpack(BR.Colors.Accent))

    local LABEL_X = 12
    local EDIT_WIDTH = 155
    local MENU_WIDTH = EDIT_WIDTH + 16

    -- X row
    local xLabel = popup:CreateFontString(nil, "OVERLAY")
    xLabel:SetFont(fontPath, 11, outlineFlag)
    xLabel:SetPoint("TOPLEFT", LABEL_X, -30)
    xLabel:SetText("X")
    xLabel:SetTextColor(1, 1, 1, 1)

    local xEdit = CreateFrame("EditBox", nil, popup)
    xEdit:SetSize(EDIT_WIDTH, 20)
    xEdit:SetFont(fontPath, 11, "")
    xEdit:SetAutoFocus(false)
    local xContainer = BR.StyleEditBox(xEdit)
    xContainer:SetSize(EDIT_WIDTH, 20)
    xContainer:SetPoint("LEFT", xLabel, "RIGHT", 8, 0)

    -- Y row
    local yLabel = popup:CreateFontString(nil, "OVERLAY")
    yLabel:SetFont(fontPath, 11, outlineFlag)
    yLabel:SetPoint("TOPLEFT", LABEL_X, -56)
    yLabel:SetText("Y")
    yLabel:SetTextColor(1, 1, 1, 1)

    local yEdit = CreateFrame("EditBox", nil, popup)
    yEdit:SetSize(EDIT_WIDTH, 20)
    yEdit:SetFont(fontPath, 11, "")
    yEdit:SetAutoFocus(false)
    local yContainer = BR.StyleEditBox(yEdit)
    yContainer:SetSize(EDIT_WIDTH, 20)
    yContainer:SetPoint("LEFT", yLabel, "RIGHT", 8, 0)

    -- Separator
    local sep = popup:CreateTexture(nil, "ARTWORK")
    sep:SetSize(216, 1)
    sep:SetPoint("TOPLEFT", LABEL_X, -82)
    sep:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 1)

    -- Anchor Frame label + dropdown button
    local anchorLabel = popup:CreateFontString(nil, "OVERLAY")
    anchorLabel:SetFont(fontPath, 10, outlineFlag)
    anchorLabel:SetPoint("TOPLEFT", LABEL_X, -90)
    anchorLabel:SetText(L["Mover.AnchorFrame"])
    anchorLabel:SetTextColor(0.7, 0.7, 0.7, 1)

    local anchorBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    anchorBtn:SetSize(MENU_WIDTH, 20)
    anchorBtn:SetPoint("TOPLEFT", LABEL_X, -104)
    anchorBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    anchorBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    anchorBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local anchorText = anchorBtn:CreateFontString(nil, "OVERLAY")
    anchorText:SetFont(fontPath, 11, "")
    anchorText:SetPoint("LEFT", 6, 0)
    anchorText:SetPoint("RIGHT", -20, 0)
    anchorText:SetJustifyH("LEFT")
    anchorText:SetTextColor(1, 1, 1, 1)

    local anchorArrow = anchorBtn:CreateTexture(nil, "OVERLAY")
    anchorArrow:SetSize(12, 12)
    anchorArrow:SetPoint("RIGHT", -4, 0)
    anchorArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    anchorArrow:SetRotation(rad(-90))
    anchorArrow:SetVertexColor(0.6, 0.6, 0.6, 1)

    -- Click-away overlay: closes open dropdown menus when clicking outside
    -- Parented to UIParent at FULLSCREEN_DIALOG strata (above DIALOG popup, below TOOLTIP menus)
    local clickAway = CreateFrame("Button", nil, UIParent)
    clickAway:SetFrameStrata("FULLSCREEN_DIALOG")
    clickAway:SetAllPoints(UIParent)
    clickAway:Hide()

    local function HideAllMenus()
        if popup.anchorMenu then
            popup.anchorMenu:Hide()
        end
        if popup.pointMenu then
            popup.pointMenu:Hide()
        end
        clickAway:Hide()
    end
    clickAway:SetScript("OnClick", HideAllMenus)

    -- Scrollable dropdown menu for anchor frame
    local ITEM_HEIGHT = 18
    local MAX_VISIBLE_ITEMS = 12

    local anchorMenu = CreateFrame("Frame", nil, anchorBtn, "BackdropTemplate")
    anchorMenu:SetFrameStrata("TOOLTIP")
    anchorMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    anchorMenu:SetBackdropColor(0.12, 0.12, 0.12, 0.98)
    anchorMenu:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    anchorMenu:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -2)
    anchorMenu:SetClampedToScreen(true)
    anchorMenu:EnableMouse(true)
    anchorMenu:Hide()
    anchorMenu:SetScript("OnHide", function()
        if not popup.pointMenu or not popup.pointMenu:IsShown() then
            clickAway:Hide()
        end
    end)

    local anchorScroll = CreateFrame("ScrollFrame", nil, anchorMenu)
    anchorScroll:SetPoint("TOPLEFT", 1, -1)
    anchorScroll:SetPoint("BOTTOMRIGHT", -1, 1)

    local anchorScrollChild = CreateFrame("Frame", nil, anchorScroll)
    anchorScroll:SetScrollChild(anchorScrollChild)

    anchorMenu:SetScript("OnMouseWheel", function(_, delta)
        local cur = anchorScroll:GetVerticalScroll()
        local maxScroll = anchorScrollChild:GetHeight() - anchorScroll:GetHeight()
        local newScroll = cur - delta * ITEM_HEIGHT * 3
        anchorScroll:SetVerticalScroll(math.max(0, math.min(newScroll, math.max(0, maxScroll))))
    end)

    -- Pool of reusable menu item buttons
    local anchorMenuItems = {}

    local function SetAnchorFrame(frameName)
        local catKey = popup.catKey
        if not catKey then
            return
        end
        anchorText:SetText(frameName or L["Mover.NoneScreenCenter"])
        anchorMenu:Hide()
        -- Set anchor in DB directly, reset position to (0,0), then fire LayoutRefresh once
        -- This avoids a double-reposition (LayoutRefresh would use old position then SavePosition resets)
        local db = BR.profile
        if not db.categorySettings then
            db.categorySettings = {}
        end
        if not db.categorySettings[catKey] then
            db.categorySettings[catKey] = {}
        end
        db.categorySettings[catKey].anchorFrame = frameName
        SavePosition(catKey, 0, 0)
        if coordPopup and coordPopup:IsShown() and coordPopup.catKey == catKey then
            coordPopup.xEdit:SetText("0")
            coordPopup.yEdit:SetText("0")
        end
        BR.CallbackRegistry:TriggerEvent("LayoutRefresh")
        -- Update mover label
        local mover = moverFrames[catKey]
        if mover then
            local catSettings = GetCategorySettings(catKey)
            local dir = catSettings.growDirection or "CENTER"
            local moverLabel = frameName and format(L["Mover.AnchorGrowthFrame"], dir, frameName)
                or format(L["Mover.AnchorGrowth"], dir)
            mover.anchorText:SetText(moverLabel)
        end
        -- Update enabled state of anchor point controls (resolved at call time via popup.*)
        local hasAnchor = frameName ~= nil
        popup.pointBtn:SetEnabled(hasAnchor)
        if hasAnchor then
            popup.pointText:SetTextColor(1, 1, 1, 1)
            popup.pointArrow:SetVertexColor(0.6, 0.6, 0.6, 1)
        else
            popup.pointText:SetTextColor(0.4, 0.4, 0.4, 1)
            popup.pointArrow:SetVertexColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
    end

    local function GetOrCreateMenuItem(index)
        if anchorMenuItems[index] then
            return anchorMenuItems[index]
        end
        local item = CreateFrame("Button", nil, anchorScrollChild, "BackdropTemplate")
        item:SetSize(MENU_WIDTH - 2, ITEM_HEIGHT)
        item:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        item:SetBackdropColor(0, 0, 0, 0)
        item.text = item:CreateFontString(nil, "OVERLAY")
        item.text:SetFont(fontPath, 11, "")
        item.text:SetPoint("LEFT", 6, 0)
        item.text:SetPoint("RIGHT", -6, 0)
        item.text:SetJustifyH("LEFT")
        item.text:SetTextColor(1, 1, 1, 1)
        item:SetScript("OnEnter", function()
            item:SetBackdropColor(0.2, 0.4, 0.6, 1)
        end)
        item:SetScript("OnLeave", function()
            item:SetBackdropColor(0, 0, 0, 0)
        end)
        anchorMenuItems[index] = item
        return item
    end

    local function PopulateAnchorMenu()
        local frames = ScanAnchorFrames()
        local totalItems = #frames + 1 -- +1 for "None" option

        for i = 1, totalItems do
            local item = GetOrCreateMenuItem(i)
            item:SetPoint("TOPLEFT", 1, -(i - 1) * ITEM_HEIGHT)
            if i == 1 then
                item.text:SetText(L["Mover.NoneScreenCenter"])
                item.text:SetTextColor(0.6, 0.6, 0.6, 1)
                item:SetScript("OnClick", function()
                    SetAnchorFrame(nil)
                end)
            else
                local name = frames[i - 1]
                item.text:SetText(name)
                item.text:SetTextColor(1, 1, 1, 1)
                item:SetScript("OnClick", function()
                    SetAnchorFrame(name)
                end)
            end
            item:Show()
        end
        -- Hide unused items
        for i = totalItems + 1, #anchorMenuItems do
            anchorMenuItems[i]:Hide()
        end

        local visibleItems = math.min(totalItems, MAX_VISIBLE_ITEMS)
        anchorMenu:SetSize(MENU_WIDTH, visibleItems * ITEM_HEIGHT + 2)
        anchorScrollChild:SetSize(MENU_WIDTH - 2, totalItems * ITEM_HEIGHT)
        anchorScroll:SetVerticalScroll(0)
    end

    anchorBtn:SetScript("OnClick", function()
        if anchorMenu:IsShown() then
            anchorMenu:Hide()
        else
            if popup.pointMenu then
                popup.pointMenu:Hide()
            end
            PopulateAnchorMenu()
            anchorMenu:Show()
            clickAway:Show()
        end
    end)

    -- Anchor Point label + dropdown button
    local pointLabel = popup:CreateFontString(nil, "OVERLAY")
    pointLabel:SetFont(fontPath, 10, outlineFlag)
    pointLabel:SetPoint("TOPLEFT", LABEL_X, -130)
    pointLabel:SetText(L["Mover.AnchorPoint"])
    pointLabel:SetTextColor(0.7, 0.7, 0.7, 1)

    local pointBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    pointBtn:SetSize(MENU_WIDTH, 20)
    pointBtn:SetPoint("TOPLEFT", LABEL_X, -144)
    pointBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pointBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    pointBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local pointText = pointBtn:CreateFontString(nil, "OVERLAY")
    pointText:SetFont(fontPath, 11, "")
    pointText:SetPoint("LEFT", 6, 0)
    pointText:SetTextColor(1, 1, 1, 1)

    local pointArrow = pointBtn:CreateTexture(nil, "OVERLAY")
    pointArrow:SetSize(12, 12)
    pointArrow:SetPoint("RIGHT", -4, 0)
    pointArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    pointArrow:SetRotation(rad(-90))
    pointArrow:SetVertexColor(0.6, 0.6, 0.6, 1)

    -- Simple dropdown menu for anchor point
    local pointMenu = CreateFrame("Frame", nil, pointBtn, "BackdropTemplate")
    pointMenu:SetFrameStrata("TOOLTIP")
    pointMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pointMenu:SetBackdropColor(0.12, 0.12, 0.12, 0.98)
    pointMenu:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    pointMenu:SetPoint("TOP", pointBtn, "BOTTOM", 0, -2)
    pointMenu:EnableMouse(true)
    pointMenu:Hide()
    pointMenu:SetScript("OnHide", function()
        if not anchorMenu:IsShown() then
            clickAway:Hide()
        end
    end)

    for i, pt in ipairs(ANCHOR_POINT_OPTIONS) do
        local item = CreateFrame("Button", nil, pointMenu, "BackdropTemplate")
        item:SetSize(MENU_WIDTH - 2, ITEM_HEIGHT)
        item:SetPoint("TOPLEFT", 1, -(i - 1) * ITEM_HEIGHT - 1)
        item:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        item:SetBackdropColor(0, 0, 0, 0)
        local itemText = item:CreateFontString(nil, "OVERLAY")
        itemText:SetFont(fontPath, 11, "")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(pt)
        itemText:SetTextColor(1, 1, 1, 1)
        item:SetScript("OnEnter", function()
            item:SetBackdropColor(0.2, 0.4, 0.6, 1)
        end)
        item:SetScript("OnLeave", function()
            item:SetBackdropColor(0, 0, 0, 0)
        end)
        item:SetScript("OnClick", function()
            pointText:SetText(pt)
            pointMenu:Hide()
            local catKey = popup.catKey
            if catKey then
                BR.Config.Set("categorySettings." .. catKey .. ".anchorPoint", pt)
            end
        end)
    end
    pointMenu:SetSize(MENU_WIDTH, #ANCHOR_POINT_OPTIONS * ITEM_HEIGHT + 2)

    pointBtn:SetScript("OnClick", function()
        if pointMenu:IsShown() then
            pointMenu:Hide()
        else
            anchorMenu:Hide()
            pointMenu:Show()
            clickAway:Show()
        end
    end)

    -- Apply button (for X/Y)
    local applyBtn = BR.CreateButton(popup, L["Mover.Apply"], function()
        local xVal = tonumber(xEdit:GetText())
        local yVal = tonumber(yEdit:GetText())
        if not xVal or not yVal then
            return
        end
        local catKey = popup.catKey
        xVal = RoundCoord(xVal)
        yVal = RoundCoord(yVal)
        SavePosition(catKey, xVal, yVal)
    end)
    applyBtn:SetPoint("BOTTOM", 0, 8)

    -- Tab from X to Y
    xEdit:SetScript("OnTabPressed", function()
        yEdit:SetFocus()
    end)

    -- Enter triggers Apply on either editbox
    xEdit:SetScript("OnEnterPressed", function()
        applyBtn:Click()
    end)
    yEdit:SetScript("OnEnterPressed", function()
        applyBtn:Click()
    end)
    yEdit:SetScript("OnTabPressed", function()
        xEdit:SetFocus()
    end)

    -- Escape to close
    popup:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            HideAllMenus()
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    popup.xEdit = xEdit
    popup.yEdit = yEdit
    popup.anchorText = anchorText
    popup.anchorBtn = anchorBtn
    popup.anchorMenu = anchorMenu
    popup.pointText = pointText
    popup.pointBtn = pointBtn
    popup.pointArrow = pointArrow
    popup.pointMenu = pointMenu
    popup:SetScript("OnHide", HideAllMenus)
    popup:Hide()
    return popup
end

-- Show the shared popup anchored to a specific mover, populated with its coords
local function ShowCoordinatePopup(catKey, mover)
    if not coordPopup then
        coordPopup = CreateCoordinatePopup()
    end
    coordPopup.catKey = catKey
    coordPopup:ClearAllPoints()
    coordPopup:SetPoint("LEFT", mover, "RIGHT", 10, 0)

    local pos = GetSavedPosition(catKey)
    coordPopup.xEdit:SetText(tostring(pos.x or 0))
    coordPopup.yEdit:SetText(tostring(pos.y or 0))

    -- Populate anchor fields (not applicable for detached icons)
    local isDetached = IsIconDetached(catKey)
    local anchorName, anchorPoint
    if not isDetached then
        local db = BR.profile
        local catSettings = db.categorySettings and db.categorySettings[catKey]
        anchorName = catSettings and catSettings.anchorFrame
        anchorPoint = catSettings and catSettings.anchorPoint or "CENTER"
    end
    coordPopup.anchorText:SetText(anchorName or L["Mover.NoneScreenCenter"])
    coordPopup.pointText:SetText(anchorPoint or "CENTER")
    coordPopup.anchorMenu:Hide()
    coordPopup.pointMenu:Hide()

    -- Disable anchor controls for detached icons (they always use screen center)
    coordPopup.anchorBtn:SetEnabled(not isDetached)
    local hasAnchor = not isDetached and anchorName ~= nil and anchorName ~= ""
    coordPopup.pointBtn:SetEnabled(hasAnchor)
    if hasAnchor then
        coordPopup.pointText:SetTextColor(1, 1, 1, 1)
        coordPopup.pointArrow:SetVertexColor(0.6, 0.6, 0.6, 1)
    else
        coordPopup.pointText:SetTextColor(0.4, 0.4, 0.4, 1)
        coordPopup.pointArrow:SetVertexColor(BORDER_R, BORDER_G, BORDER_B, 1)
    end

    coordPopup:Show()
end

-- Update the shared popup's edit boxes from live mover position during drag
local function UpdatePopupLive(mover, catKey)
    if not coordPopup or not coordPopup:IsShown() then
        return
    end
    -- Anchor is always cleared on drag start, so this is always UIParent-relative
    -- Detached icons always use CENTER anchor
    local anchor
    if IsIconDetached(catKey) then
        anchor = "CENTER"
    else
        local settings = GetCategorySettings(catKey)
        anchor = DIRECTION_ANCHORS[settings.growDirection or "CENTER"] or "CENTER"
    end
    local px, py = UIParent:GetCenter()
    local x, y
    local coordFn = ANCHOR_COORD_FN[anchor]
    if coordFn then
        x, y = coordFn(mover, px, py)
    else
        local cx, cy = mover:GetCenter()
        x = cx - px
        y = cy - py
    end
    coordPopup.xEdit:SetText(tostring(RoundCoord(x)))
    coordPopup.yEdit:SetText(tostring(RoundCoord(y)))
end

-- Create a mover frame for positioning a category.
-- The mover matches the category's iconSize for accurate positioning. Shown when unlocked.
local function CreateMoverFrame(catKey, displayName)
    local fontPath = BR.Display.GetFontPath()
    local outlineFlag = BR.Display.GetOutline()
    local catSettings = GetCategorySettings(catKey)
    local iconSize = catSettings.iconSize or 64
    local iconWidth = catSettings.iconWidth or iconSize

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetSize(iconWidth, iconSize)
    mover:SetFrameStrata("HIGH")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    -- Green background
    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.7, 0, 0.6)

    -- Label above the mover
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    mover.label:SetFont(fontPath, 11, outlineFlag)
    mover.label:SetTextColor(0.4, 1, 0.4, 1)
    mover.label:SetText(displayName or catKey)

    -- "Anchor" text below the green box (updated with growth direction in UpdateAnchor)
    mover.anchorText = mover:CreateFontString(nil, "OVERLAY")
    mover.anchorText:SetPoint("TOP", mover, "BOTTOM", 0, -4)
    mover.anchorText:SetFont(fontPath, 11, outlineFlag)
    mover.anchorText:SetTextColor(0.4, 1, 0.4, 1)

    mover.catKey = catKey

    function mover:UpdateSize()
        local settings = GetCategorySettings(catKey)
        local size = settings.iconSize or 64
        self:SetSize(settings.iconWidth or size, size)
    end

    -- Position at saved location using direction-based anchor (or external anchor)
    local pos = GetSavedPosition(catKey)
    local initSettings = GetCategorySettings(catKey)
    local initDirection = initSettings.growDirection or "CENTER"
    local initAnchor = DIRECTION_ANCHORS[initDirection] or "CENTER"
    local extFrame, extPoint = ResolveAnchorParent(catKey)
    if extFrame then
        local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][initDirection]
            or initAnchor
        mover:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
    else
        mover:SetPoint(initAnchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end

    -- Tooltip
    BR.SetupTooltip(mover, L["Mover.BuffAnchor"], L["Mover.DragTooltip"])

    -- Drag scripts
    mover:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        DimContainer(catKey)
        -- Hide sub-icon action buttons so they don't linger at old positions during drag
        if BR.SecureButtons then
            BR.SecureButtons.HideSecureFramesForCatKey(catKey)
        end
        -- External anchors survive dragging: FinishMoverDrag recomputes the
        -- offsets relative to the anchor frame, so a nudge never silently
        -- converts an anchored frame back to screen coordinates.
        self.isDragging = true
        self:StartMoving()
        -- Live coordinate updates if popup is already open
        if coordPopup and coordPopup:IsShown() then
            coordPopup:ClearAllPoints()
            coordPopup:SetPoint("LEFT", self, "RIGHT", 10, 0)
            coordPopup.catKey = catKey
        end
        self:SetScript("OnUpdate", function()
            UpdatePopupLive(self, catKey)
        end)
    end)
    mover:SetScript("OnDragStop", function(self)
        FinishMoverDrag(self, catKey)
    end)
    mover:SetScript("OnHide", function(self)
        if self.isDragging then
            FinishMoverDrag(self, catKey)
        end
    end)

    -- Click to toggle coordinate popup
    mover:SetScript("OnMouseUp", function(self, button)
        if not self.isDragging and button == "LeftButton" then
            if coordPopup and coordPopup:IsShown() and coordPopup.catKey == catKey then
                coordPopup:Hide()
            else
                ShowCoordinatePopup(catKey, self)
            end
        end
    end)

    mover:Hide()
    return mover
end

-- Position a mover frame at its saved coordinates using direction-based anchor
PositionMoverFrame = function(catKey)
    local mover = moverFrames[catKey]
    if not mover or mover.isDragging then
        return
    end
    local pos = GetSavedPosition(catKey)
    local settings = GetCategorySettings(catKey)
    local direction = settings.growDirection or "CENTER"
    local anchor = DIRECTION_ANCHORS[direction] or "CENTER"
    mover:ClearAllPoints()
    local extFrame, extPoint = ResolveAnchorParent(catKey)
    if extFrame then
        local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][direction] or anchor
        mover:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
    else
        mover:SetPoint(anchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end
    if coordPopup and coordPopup:IsShown() and coordPopup.catKey == catKey then
        -- Don't overwrite text while user is actively editing
        if not coordPopup.xEdit:HasFocus() and not coordPopup.yEdit:HasFocus() then
            coordPopup.xEdit:SetText(tostring(pos.x or 0))
            coordPopup.yEdit:SetText(tostring(pos.y or 0))
        end
    end
end

-- ============================================================================
-- DETACHED ICON MOVERS
-- ============================================================================

---Get saved position for a detached icon
---@param key string Buff key
---@return table position {x, y}
local function GetDetachedSavedPosition(key)
    local db = BR.profile
    if db.detachedIcons and db.detachedIcons[key] and db.detachedIcons[key].position then
        return db.detachedIcons[key].position
    end
    return { x = 0, y = 0 }
end

---Save position for a detached icon and reposition its container
---@param key string Buff key
---@param x number
---@param y number
SaveDetachedPosition = function(key, x, y)
    local db = BR.profile
    if not db.detachedIcons then
        db.detachedIcons = {}
    end
    if not db.detachedIcons[key] then
        db.detachedIcons[key] = {}
    end
    db.detachedIcons[key].position = { x = x, y = y }

    -- Reposition the detached container frame
    local container = BR.Display.detachedFrames and BR.Display.detachedFrames[key]
    if container then
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

---Finish drag for a detached icon mover
---@param mover table The mover frame
---@param key string Buff key
local function FinishDetachedMoverDrag(mover, key)
    mover.isDragging = false
    mover:SetScript("OnUpdate", nil)
    mover:StopMovingOrSizing()
    local px, py = UIParent:GetCenter()
    local cx, cy = mover:GetCenter()
    local x = RoundCoord(cx - px)
    local y = RoundCoord(cy - py)
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", x, y)
    SaveDetachedPosition(key, x, y)
    if coordPopup and coordPopup:IsShown() and coordPopup.catKey == key then
        coordPopup.xEdit:SetText(tostring(x))
        coordPopup.yEdit:SetText(tostring(y))
    end
    RestoreContainer(key)
    if BR.SecureButtons then
        BR.SecureButtons.ScheduleSecureSync()
    end
end

---Position a detached mover at its saved coordinates
---@param key string Buff key
PositionDetachedMoverFrame = function(key)
    local mover = detachedMoverFrames[key]
    if not mover or mover.isDragging then
        return
    end
    local pos = GetDetachedSavedPosition(key)
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
    if coordPopup and coordPopup:IsShown() and coordPopup.catKey == key then
        if not coordPopup.xEdit:HasFocus() and not coordPopup.yEdit:HasFocus() then
            coordPopup.xEdit:SetText(tostring(pos.x or 0))
            coordPopup.yEdit:SetText(tostring(pos.y or 0))
        end
    end
end

---Create a mover frame for a detached icon
---@param key string Buff key
---@param displayName string Display name for the label
---@return table? mover The mover frame, or nil if in combat
local function CreateDetachedMover(key, displayName)
    if InCombatLockdown() then
        return nil
    end

    local fontPath = BR.Display.GetFontPath()
    local outlineFlag = BR.Display.GetOutline()
    local buffFrame = BR.Display.frames[key]
    local effectiveCat = "main"
    if buffFrame and buffFrame.buffCategory then
        local cat = buffFrame.buffCategory
        if IsCategorySplit(cat) or BR.Config.HasCustomAppearance(cat) then
            effectiveCat = cat
        end
    end
    local catSettings = GetCategorySettings(effectiveCat)
    local iconSize = catSettings.iconSize or 64
    local iconWidth = catSettings.iconWidth or iconSize

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetSize(iconWidth, iconSize)
    mover:SetFrameStrata("HIGH")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    -- Yellow background to distinguish from category movers
    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.9, 0.7, 0, 0.6)

    -- Label above the mover
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    mover.label:SetFont(fontPath, 11, outlineFlag)
    mover.label:SetTextColor(1, 0.85, 0.3, 1)
    mover.label:SetText(displayName or key)

    -- Anchor text below
    mover.anchorText = mover:CreateFontString(nil, "OVERLAY")
    mover.anchorText:SetPoint("TOP", mover, "BOTTOM", 0, -4)
    mover.anchorText:SetFont(fontPath, 11, outlineFlag)
    mover.anchorText:SetTextColor(1, 0.85, 0.3, 1)
    mover.anchorText:SetText(L["Mover.Detached"])

    mover.catKey = key

    function mover:UpdateSize()
        local bf = BR.Display.frames[key]
        local eCat = "main"
        if bf and bf.buffCategory then
            local c = bf.buffCategory
            if IsCategorySplit(c) or BR.Config.HasCustomAppearance(c) then
                eCat = c
            end
        end
        local s = GetCategorySettings(eCat)
        local sz = s.iconSize or 64
        self:SetSize(s.iconWidth or sz, sz)
    end

    -- Position at saved location
    local pos = GetDetachedSavedPosition(key)
    mover:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)

    -- Tooltip
    BR.SetupTooltip(mover, L["Mover.BuffAnchor"], L["Mover.DragTooltip"])

    -- Drag scripts
    mover:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        DimContainer(key)
        if BR.SecureButtons then
            BR.SecureButtons.HideSecureFramesForCatKey(key)
        end
        self.isDragging = true
        self:StartMoving()
        if coordPopup and coordPopup:IsShown() then
            coordPopup:ClearAllPoints()
            coordPopup:SetPoint("LEFT", self, "RIGHT", 10, 0)
            coordPopup.catKey = key
        end
        self:SetScript("OnUpdate", function()
            UpdatePopupLive(self, key)
        end)
    end)
    mover:SetScript("OnDragStop", function(self)
        FinishDetachedMoverDrag(self, key)
    end)
    mover:SetScript("OnHide", function(self)
        if self.isDragging then
            FinishDetachedMoverDrag(self, key)
        end
    end)

    -- Click to toggle coordinate popup
    mover:SetScript("OnMouseUp", function(self, button)
        if not self.isDragging and button == "LeftButton" then
            if coordPopup and coordPopup:IsShown() and coordPopup.catKey == key then
                coordPopup:Hide()
            else
                ShowCoordinatePopup(key, self)
            end
        end
    end)

    mover:Hide()
    return mover
end

-- Initialize mover frames for all categories (called from InitializeFrames)
local function InitializeMovers()
    -- Resolve forward declarations now that BR.Display is available
    ResolveAnchorParent = BR.Display.ResolveAnchorParent
    EXT_DIRECTION_ANCHORS = BR.EXT_DIRECTION_ANCHORS

    moverFrames["main"] = CreateMoverFrame("main", GetMainFrameLabel())
    lastDirection["main"] = (GetCategorySettings("main").growDirection or "CENTER")
    for _, category in ipairs(CATEGORIES) do
        moverFrames[category] = CreateMoverFrame(category, CATEGORY_LABELS[category])
        lastDirection[category] = (GetCategorySettings(category).growDirection or "CENTER")
    end
end

-- Check if all categories are split into separate frames
local function AreAllCategoriesSplit()
    for _, category in ipairs(CATEGORIES) do
        if not IsCategorySplit(category) then
            return false
        end
    end
    return true
end

-- Update mover frame visibility and labels based on lock/split state.
-- IMPORTANT: Never reposition a mover that is already shown - doing so would cancel
-- an active StartMoving() drag via ClearAllPoints(). Only position on first show.
local function UpdateAnchor()
    if not BR.Display.mainFrame then
        return
    end

    local db = BR.profile
    local unlocked = not db.locked

    -- Main mover: show when unlocked AND not all categories split
    local allSplit = AreAllCategoriesSplit()
    local mainMover = moverFrames["main"]
    if mainMover then
        if unlocked and not allSplit then
            local mainSettings = GetCategorySettings("main")
            mainMover.label:SetText(GetMainFrameLabel())
            local mainDir = mainSettings.growDirection or "CENTER"
            local mainCatSettings = db.categorySettings and db.categorySettings["main"]
            local mainAnchorName = mainCatSettings and mainCatSettings.anchorFrame
            local mainAnchorLabel = (mainAnchorName and mainAnchorName ~= "")
                    and format(L["Mover.AnchorGrowthFrame"], mainDir, mainAnchorName)
                or format(L["Mover.AnchorGrowth"], mainDir)
            mainMover.anchorText:SetText(mainAnchorLabel)
            PositionMoverFrame("main")
            mainMover:Show()
        else
            mainMover:Hide()
        end
    end

    -- Category movers: show when unlocked AND that category is split
    for _, category in ipairs(CATEGORIES) do
        local mover = moverFrames[category]
        if mover then
            if unlocked and IsCategorySplit(category) then
                local catSettings = GetCategorySettings(category)
                mover.label:SetText(CATEGORY_LABELS[category])
                local catDir = catSettings.growDirection or "CENTER"
                local catDbSettings = db.categorySettings and db.categorySettings[category]
                local catAnchorName = catDbSettings and catDbSettings.anchorFrame
                local catAnchorLabel = (catAnchorName and catAnchorName ~= "")
                        and format(L["Mover.AnchorGrowthFrame"], catDir, catAnchorName)
                    or format(L["Mover.AnchorGrowth"], catDir)
                mover.anchorText:SetText(catAnchorLabel)
                PositionMoverFrame(category)
                mover:Show()
            else
                mover:Hide()
            end
        end
    end

    -- Detached icon movers: show when unlocked
    if db.detachedIcons then
        for key in pairs(db.detachedIcons) do
            if unlocked then
                if not detachedMoverFrames[key] then
                    detachedMoverFrames[key] = CreateDetachedMover(key, BR.Helpers.GetBuffDisplayName(key))
                end
                if detachedMoverFrames[key] then
                    detachedMoverFrames[key]:UpdateSize()
                    PositionDetachedMoverFrame(key)
                    detachedMoverFrames[key]:Show()
                end
            elseif detachedMoverFrames[key] then
                detachedMoverFrames[key]:Hide()
            end
        end
    end
    -- Hide movers for icons that are no longer detached
    for key, mover in pairs(detachedMoverFrames) do
        if not (db.detachedIcons and db.detachedIcons[key]) then
            mover:Hide()
        end
    end
end

-- Hide all mover frames and the coordinate popup
local function HideAllMovers()
    if coordPopup then
        coordPopup:Hide()
    end
    for _, mover in pairs(moverFrames) do
        if mover then
            mover:Hide()
        end
    end
    for _, mover in pairs(detachedMoverFrames) do
        if mover then
            mover:Hide()
        end
    end
end

-- Convert saved positions when growth direction changes (called from LayoutRefresh callback)
local function ConvertDirectionPositions()
    local allCatKeys = { "main" }
    for _, cat in ipairs(CATEGORIES) do
        allCatKeys[#allCatKeys + 1] = cat
    end
    for _, catKey in ipairs(allCatKeys) do
        local settings = GetCategorySettings(catKey)
        local dir = settings.growDirection or "CENTER"
        local oldDir = lastDirection[catKey]
        -- Skip conversion when externally anchored (offset is relative to the anchor, not UIParent)
        if oldDir and oldDir ~= dir and not ResolveAnchorParent(catKey) then
            local oldAnchor = DIRECTION_ANCHORS[oldDir] or "CENTER"
            local newAnchor = DIRECTION_ANCHORS[dir] or "CENTER"
            local pos = GetSavedPosition(catKey)
            local size = settings.iconSize or 64
            local w = settings.iconWidth or size
            local nx, ny = ConvertPosition(oldAnchor, newAnchor, pos.x or 0, pos.y or 0, w, size)
            SavePosition(catKey, nx, ny)
        end
        lastDirection[catKey] = dir
    end
end

-- Sync lastDirection cache from the current profile's settings.
-- Must run before LayoutRefresh on profile switch to prevent ConvertDirectionPositions
-- from seeing a stale oldDir and doing a spurious position conversion.
local function SyncDirectionCache()
    lastDirection["main"] = (GetCategorySettings("main").growDirection or "CENTER")
    for _, category in ipairs(CATEGORIES) do
        lastDirection[category] = (GetCategorySettings(category).growDirection or "CENTER")
    end
end

-- Reposition all mover frames from the active profile's saved positions.
-- Called after profile switch to move frames to the new profile's positions.
local function RepositionAllFrames()
    PositionMoverFrame("main")
    for _, category in ipairs(CATEGORIES) do
        PositionMoverFrame(category)
    end
    -- Reposition detached icon containers and movers
    local db = BR.profile
    if db.detachedIcons then
        for key in pairs(db.detachedIcons) do
            -- Reposition the container frame
            local container = BR.Display.detachedFrames and BR.Display.detachedFrames[key]
            if container then
                local pos = GetDetachedSavedPosition(key)
                container:ClearAllPoints()
                container:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
            end
            -- Reposition the mover
            PositionDetachedMoverFrame(key)
        end
    end
end

-- Export module
BR.Movers = {
    Initialize = InitializeMovers,
    UpdateAnchor = UpdateAnchor,
    HideAll = HideAllMovers,
    SavePosition = SavePosition,
    ScanAnchorFrames = ScanAnchorFrames,
    GetMoverFrames = function()
        return moverFrames
    end,
    GetDetachedMoverFrames = function()
        return detachedMoverFrames
    end,
    ConvertDirectionPositions = ConvertDirectionPositions,
    SyncDirectionCache = SyncDirectionCache,
    RepositionAllFrames = RepositionAllFrames,
}
