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
local wipe = wipe

local L = BR.L
local CATEGORIES = BR.CATEGORIES
local CATEGORY_LABELS = BR.CATEGORY_LABELS
local DIRECTION_ANCHORS = BR.DIRECTION_ANCHORS

local Plain = BR.Secret.Plain
local ResolveAnchorFrame = BR.ResolveAnchorFrame

local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit
local IsIconDetached = BR.Helpers.IsIconDetached

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

local moverFrames = {}
local detachedMoverFrames = {}
local lastDirection = {} -- Tracks previous growDirection per catKey for position conversion
local coordPopup -- Shared coordinate popup (shown on the active mover)

-- Displays that are not buff categories but share the coordinate popup, keyed the
-- same way a catKey is. Each adapter owns its own settings table and its own
-- repositioning, so the popup stays the single place anchors are assigned.
local moverTargets = {}

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
---@param catKey string "main", a category name, a detached icon buff key, or a registered target
---@return table position {point, x, y}; a target supplies x and y only
local function GetSavedPosition(catKey)
    local target = moverTargets[catKey]
    if target then
        return target.GetPosition()
    end
    local db = BR.profile
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
    local target = moverTargets[catKey]
    if target then
        target.SetPosition(x, y)
        return
    end

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

    PositionMoverFrame(catKey)
end

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

local function GetContainerForCatKey(catKey)
    if catKey == "main" then
        return BR.Display.mainFrame
    end
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
    -- Plain on every read: the anchor can be any frame the user picked, and an
    -- aura-owned one hands back secret geometry that throws on arithmetic.
    local left, bottom = Plain(frame:GetLeft()), Plain(frame:GetBottom())
    local w, h = Plain(frame:GetWidth()), Plain(frame:GetHeight())
    local scale = Plain(frame:GetEffectiveScale())
    if not (left and bottom and w and h and scale) then
        return nil, nil
    end
    local x = strfind(point, "LEFT") and left or (strfind(point, "RIGHT") and (left + w) or (left + w / 2))
    local y = strfind(point, "TOP") and (bottom + h) or (strfind(point, "BOTTOM") and bottom or (bottom + h / 2))
    return x * scale, y * scale
end

---Offsets of a frame's `selfPoint` from `parent`'s `parentPoint`, in UI units.
---@return number? x, number? y nil when either frame has no laid-out rect yet
local function AnchoredOffsets(frame, selfPoint, parent, parentPoint)
    local fx, fy = GetPointCoords(frame, selfPoint)
    local px, py = GetPointCoords(parent, parentPoint)
    if not fx or not px then
        return nil, nil
    end
    local scale = frame:GetEffectiveScale()
    return RoundCoord((fx - px) / scale), RoundCoord((fy - py) / scale)
end

---@return boolean true when the coordinate popup is open for this key
local function IsPopupShownFor(key)
    return coordPopup ~= nil and coordPopup:IsShown() and coordPopup.catKey == key
end

---Write coordinates into the popup while its own display moves.
local function SyncPopupCoords(key, x, y)
    if IsPopupShownFor(key) then
        coordPopup.xEdit:SetText(tostring(x))
        coordPopup.yEdit:SetText(tostring(y))
    end
end

local function HidePopupFor(key)
    if IsPopupShownFor(key) then
        coordPopup:Hide()
    end
end

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
        x, y = AnchoredOffsets(mover, extAnchor, extFrame, extPoint)
        if x and y then
            mover:ClearAllPoints()
            mover:SetPoint(extAnchor, extFrame, extPoint, x, y)
            SavePosition(catKey, x, y)
            SyncPopupCoords(catKey, x, y)
            RestoreContainer(catKey)
            if BR.SecureButtons then
                BR.SecureButtons.ScheduleSecureSync()
            end
            return
        end
    end

    -- No anchor frame (or it is not laid out): UIParent-relative
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
    SyncPopupCoords(catKey, x, y)
    RestoreContainer(catKey)
    if BR.SecureButtons then
        BR.SecureButtons.ScheduleSecureSync()
    end
end

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

-- The anchor targets offered without being asked for. Everything else reaches the
-- dropdown by being picked from the screen, which remembers it in the user's own
-- list - so this stays short and never has to keep up with the next interface.
local STATIC_ANCHOR_FRAMES = {
    { name = "PlayerFrame", source = "Blizzard", role = "player" },
    { name = "TargetFrame", source = "Blizzard", role = "target" },
    { name = "PartyFrame", source = "Blizzard", role = "party" },
    { name = "CompactRaidFrameContainer", source = "Blizzard", role = "raid" },
    { name = "Minimap", labelKey = "Mover.Frame.Minimap" },
    { name = "ObjectiveTrackerFrame", labelKey = "Mover.Frame.ObjectiveTracker" },
    { name = "EssentialCooldownViewer", labelKey = "Mover.Frame.EssentialCooldowns" },
    { name = "UtilityCooldownViewer", labelKey = "Mover.Frame.UtilityCooldowns" },
    { name = "BuffIconCooldownViewer", labelKey = "Mover.Frame.TrackedBuffIcons" },
    { name = "BuffBarCooldownViewer", labelKey = "Mover.Frame.TrackedBuffBars" },
    { name = "CellAnchorFrame", source = "Cell", role = "raid" },
    { name = "Grid2LayoutFrame", source = "Grid2", role = "raid" },
    { name = "Vd1", source = "VuhDo", role = "raid" },
}

local ROLE_LABELS = {
    player = L["Mover.Role.Player"],
    target = L["Mover.Role.Target"],
    focus = L["Mover.Role.Focus"],
    pet = L["Mover.Role.Pet"],
    party = L["Mover.Role.Party"],
    raid = L["Mover.Role.Raid"],
    boss = L["Mover.Role.Boss"],
}

-- The unit a frame reports, mapped to the words a player uses for it. Only these
-- earn a role in a label; every other unit reads as a plain frame name.
local UNIT_ROLE_LABEL = {
    player = ROLE_LABELS.player,
    target = ROLE_LABELS.target,
    focus = ROLE_LABELS.focus,
    pet = ROLE_LABELS.pet,
    party1 = ROLE_LABELS.party,
    boss1 = ROLE_LABELS.boss,
}

local FMT_ANCHOR_ENTRY = L["Mover.AnchorFrameEntry"]
local FMT_UNIT_ENTRY = L["Mover.UnitFrameEntry"]
local TAG_ANCHOR_HIDDEN = L["Mover.AnchorHidden"]
local TAG_ANCHOR_MISSING = L["Mover.AnchorNotFound"]

local STATIC_BY_NAME = {}
for _, desc in ipairs(STATIC_ANCHOR_FRAMES) do
    STATIC_BY_NAME[desc.name] = desc
end

---@param desc table Entry of STATIC_ANCHOR_FRAMES
---@return string
local function DescriptorLabel(desc)
    if desc.labelKey then
        return L[desc.labelKey]
    end
    return format(FMT_ANCHOR_ENTRY, desc.source, ROLE_LABELS[desc.role] or desc.role)
end

---Whether a frame is on screen: true, false, or nil when the client answers with
---a secret. Aura-owned frames report their state as secret values, and a boolean
---test on one throws, so every read on a frame the addon does not own goes through
---Plain.
---@return boolean? shown
local function FrameVisibility(frame)
    if frame.IsVisible == nil then
        return nil
    end
    return Plain(frame:IsVisible())
end

---A forbidden frame raises on every method an addon calls, so this comes before
---any other question about a frame. A secret answer counts as forbidden: a frame
---the addon cannot ask about is one it must not touch.
local function IsForbidden(frame)
    if frame.IsForbidden == nil then
        return false
    end
    return Plain(frame:IsForbidden()) ~= false
end

---The unit a frame stands for, or nil when it is not a unit frame. Two sources,
---because neither alone covers the field: Blizzard's frames and the oUF-based
---addons keep a `unit` field, and secure unit buttons carry the `unit` attribute.
---The field comes first, through rawget, because it costs no client call. Both
---reads pass through Plain, so a secret never reaches a table lookup.
---@return string?
local function UnitOfFrame(frame)
    local unit = Plain(rawget(frame, "unit"))
    if type(unit) ~= "string" and frame.RegisterForClicks and frame.GetAttribute then
        unit = Plain(frame:GetAttribute("unit"))
    end
    return type(unit) == "string" and unit or nil
end

---Anchorable name of a frame: it must resolve back through _G, because the anchor
---is stored as a name. The addon's own frames are excluded - anchoring the display
---to itself is not a position.
---@return string?
local function AnchorableName(frame)
    local name = Plain(frame.GetName and frame:GetName())
    if type(name) ~= "string" or _G[name] ~= frame or strfind(name, "^BuffReminders") then
        return nil
    end
    return name
end

---Label for one anchor target: its role when the frame reports a unit, and its
---own name otherwise. Costs one client call per entry, and only the entries the
---dropdown is about to draw.
---@return string
local function EntryLabel(name, frame)
    local desc = STATIC_BY_NAME[name]
    if desc then
        return DescriptorLabel(desc)
    end
    local unit = frame and UnitOfFrame(frame)
    local role = unit and UNIT_ROLE_LABEL[unit]
    return role and format(FMT_UNIT_ENTRY, role, name) or name
end

---Anchor targets for the dropdown: the offered list, then every frame the user
---picked or typed. A frame that exists but is hidden stays on the list, tagged
---and last: hidden means idle as often as it means replaced (a party frame while
---solo), and only the player can tell which.
---@return table[] entries { name, label, hidden }
local function ScanAnchorFrames()
    local visible, hidden = {}, {}
    local seen = {}

    local function Add(name)
        local frame = ResolveAnchorFrame(name)
        if not frame or seen[frame] then
            return
        end
        seen[frame] = true
        local isHidden = FrameVisibility(frame) == false
        local entry = { name = name, label = EntryLabel(name, frame), hidden = isHidden }
        local bucket = isHidden and hidden or visible
        bucket[#bucket + 1] = entry
    end

    for _, desc in ipairs(STATIC_ANCHOR_FRAMES) do
        Add(desc.name)
    end
    local db = BR.profile
    if db.customAnchorFrames then
        for _, name in ipairs(db.customAnchorFrames) do
            Add(name)
        end
    end

    for i = 1, #hidden do
        visible[#visible + 1] = hidden[i]
    end
    return visible
end

---Keep a picked frame one click away, on this profile, for good. The custom
---anchor list is the surface that already lists, flags and removes these names,
---so a pick writes there rather than into a store of its own.
local function RememberAnchorFrame(name)
    if not name or STATIC_BY_NAME[name] then
        return
    end
    local db = BR.profile
    local names = db.customAnchorFrames
    if not names then
        names = {}
        db.customAnchorFrames = names
    end
    for i = 1, #names do
        if names[i] == name then
            return
        end
    end
    tinsert(names, name)
    BR.CallbackRegistry:TriggerEvent("CustomAnchorsChanged")
end

-- ============================================================================
-- FRAME PICKER
-- ============================================================================
-- Point at the frame you want and click it. This is how a target that no list can
-- name - a container, a bar, a frame from any interface - reaches the dropdown: a
-- pick is remembered in the user's own anchor list.
--
-- The client already knows which frame the pointer is over, so this asks it once a
-- tick and walks no frames of its own. Nothing here captures the mouse: the button
-- state is polled, and the click also reaches whatever sits under it. A frame that
-- covers the screen to catch the click becomes the frame under the pointer, and
-- keeping the frames below it visible needs a call that combat forbids.

local pickHighlight, pickHint, pickKeys
local pickChain, pickIndex = {}, 1
local pickCallback, pickTicker
local shownPickFrame
-- The click that starts the mode is still down when the first tick runs. Picking
-- arms itself once the button comes up.
local pickArmed

-- The pointer cannot cross a frame boundary in a tenth of a second of play, and
-- each tick costs one client call.
local PICK_INTERVAL = 0.1

---The frames receiving mouse focus, topmost first.
---@return table? list
local function MouseFrames()
    return GetMouseFoci()
end

---The frame under the pointer plus its anchorable ancestors, innermost first, and
---which one of them a pick takes.
local function BuildPickChain()
    wipe(pickChain)
    local unitIndex
    local foci = MouseFrames()
    local frame = foci and foci[1]
    while frame do
        if IsForbidden(frame) then
            break
        end
        if AnchorableName(frame) then
            pickChain[#pickChain + 1] = frame
            -- A unit button is what a player means by "the player frame", so the
            -- chain opens there rather than on the texture holder under the pointer.
            if not unitIndex and UnitOfFrame(frame) then
                unitIndex = #pickChain
            end
        end
        frame = Plain(frame.GetParent and frame:GetParent())
        if frame == UIParent or frame == nil then
            break
        end
    end
    -- A unit button when the pointer is on one, otherwise the outermost frame it is
    -- inside: the whole frame rather than the icon or bar within it, which is what a
    -- player means by pointing at something.
    pickIndex = unitIndex or #pickChain
end

local function UpdatePickVisuals()
    local frame = pickChain[pickIndex]
    if frame == shownPickFrame then
        return
    end
    shownPickFrame = frame
    if not frame then
        pickHighlight:Hide()
        pickHint.name:SetText(L["Mover.PickNone"])
        return
    end
    pickHighlight:ClearAllPoints()
    pickHighlight:SetAllPoints(frame)
    pickHighlight:Show()
    local name = AnchorableName(frame)
    local unit = UnitOfFrame(frame)
    local role = unit and UNIT_ROLE_LABEL[unit]
    pickHint.name:SetText(role and format(FMT_UNIT_ENTRY, role, name) or name)
end

local StopPicking

local function PickTick()
    -- A picking session must never survive into a fight.
    if InCombatLockdown() then
        StopPicking(nil)
        return
    end
    -- A throw here leaves the mode running, and it then errors on every tick. The
    -- chain reads frames of unknown origin, which is where that risk lives.
    if not pcall(BuildPickChain) then
        StopPicking(nil)
        return
    end
    UpdatePickVisuals()
    local left, right = IsMouseButtonDown("LeftButton"), IsMouseButtonDown("RightButton")
    if not left and not right then
        pickArmed = true
    elseif pickArmed then
        if right then
            StopPicking(nil)
        else
            local frame = pickChain[pickIndex]
            StopPicking(frame and AnchorableName(frame) or nil)
        end
    end
end

local function CreatePickFrames()
    pickKeys = CreateFrame("Frame", nil, UIParent)
    pickKeys:SetSize(1, 1)
    pickKeys:SetPoint("CENTER")
    pickKeys:EnableKeyboard(true)
    pickKeys:Hide()

    pickHighlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    pickHighlight:SetFrameStrata("TOOLTIP")
    pickHighlight:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    pickHighlight:SetBackdropBorderColor(unpack(BR.Colors.Accent))
    pickHighlight:EnableMouse(false)
    pickHighlight:Hide()

    pickHint = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    pickHint:SetSize(460, 60)
    pickHint:SetPoint("TOP", UIParent, "TOP", 0, -120)
    pickHint:SetFrameStrata("TOOLTIP")
    pickHint:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pickHint:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    pickHint:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
    pickHint:EnableMouse(false)
    pickHint:Hide()

    pickHint.name = pickHint:CreateFontString(nil, "OVERLAY")
    pickHint.name:SetPoint("TOP", 0, -8)
    pickHint.text = pickHint:CreateFontString(nil, "OVERLAY")
    pickHint.text:SetPoint("TOP", pickHint.name, "BOTTOM", 0, -6)
    pickHint.text:SetWidth(430)
    pickHint.text:SetJustifyH("CENTER")

    -- Escape is the only key taken, and it is never a movement binding. Everything
    -- else still reaches the game: picking must not trap the player.
    pickKeys:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            StopPicking(nil)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
end

---End picking. `name` is the chosen frame, or nil when the user cancelled.
StopPicking = function(name)
    if pickTicker then
        pickTicker:Cancel()
        pickTicker = nil
    end
    if pickKeys then
        pickKeys:SetPropagateKeyboardInput(true)
        pickKeys:Hide()
        pickHighlight:Hide()
        pickHint:Hide()
    end

    wipe(pickChain)
    shownPickFrame = nil
    local callback = pickCallback
    pickCallback = nil
    if callback then
        callback(name)
    end
end

---Start picking a frame from the screen. The callback receives the chosen global
---name, or nil when the user cancels.
---@param callback fun(name: string?)
local function StartPicking(callback)
    -- Nothing the picker calls is combat-restricted. The guard exists so the mode
    -- cannot outlive a pull. The callback still runs, so a caller that stepped aside
    -- for the pick comes back.
    if InCombatLockdown() then
        callback(nil)
        return
    end
    if not pickKeys then
        CreatePickFrames()
    end
    pickCallback = callback
    pickArmed = false
    BR.DisplayFonts.Apply(pickHint.name, 13)
    BR.DisplayFonts.Apply(pickHint.text, 11)
    pickHint.name:SetTextColor(unpack(BR.Colors.Accent))
    pickHint.name:SetText(L["Mover.PickNone"])
    pickHint.text:SetTextColor(0.8, 0.8, 0.8, 1)
    pickHint.text:SetText(L["Mover.PickHint"])
    pickHint:Show()
    pickKeys:Show()
    PickTick()
    pickTicker = C_Timer.NewTicker(PICK_INTERVAL, PickTick)
end

---Display name of a saved anchor, tagged when the frame is missing or hidden. A
---hidden frame still holds the anchor, so the tag reads as state, not as an error.
---@param name string? Saved global frame name
---@return string? label nil when no anchor is set
local function AnchorFrameLabel(name)
    if not name or name == "" then
        return nil
    end
    local desc = STATIC_BY_NAME[name]
    local label = desc and DescriptorLabel(desc) or name
    local obj = ResolveAnchorFrame(name)
    if not obj then
        return label .. " " .. TAG_ANCHOR_MISSING
    elseif FrameVisibility(obj) == false then
        -- Only a definite "no" earns the tag. An unknown answer is not a fault to report.
        return label .. " " .. TAG_ANCHOR_HIDDEN
    end
    return label
end

-- Movers and the coordinate popup are built once and never rebuilt, so a font
-- setting change must be pushed to their fontstrings explicitly. TrackFont
-- remembers each styled object plus its outline override (nil = follow the
-- shared outline setting) for RefreshFonts to re-apply.
---@param list table Accumulator of styled objects
---@param obj table FontString or EditBox
---@param size number
---@param outline? string explicit outline override
local function TrackFont(list, obj, size, outline)
    BR.DisplayFonts.Apply(obj, size, outline)
    obj._br_font_size = size
    obj._br_font_explicit_outline = outline
    list[#list + 1] = obj
end

---@param list table Accumulator filled by TrackFont
local function RefreshFonts(list)
    local ApplyFont = BR.DisplayFonts.Apply
    for i = 1, #list do
        local obj = list[i]
        ApplyFont(obj, obj._br_font_size, obj._br_font_explicit_outline)
    end
end

---Rewrite the caption under a mover after its anchor changed.
local function UpdateMoverCaption(catKey)
    local target = moverTargets[catKey]
    if target then
        if target.UpdateLabel then
            target.UpdateLabel()
        end
        return
    end
    local mover = moverFrames[catKey]
    if not mover then
        return
    end
    local db = BR.profile
    local catSettings = db.categorySettings and db.categorySettings[catKey]
    local label = AnchorFrameLabel(catSettings and catSettings.anchorFrame)
    local dir = GetCategorySettings(catKey).growDirection or "CENTER"
    mover.anchorText:SetText(
        label and format(L["Mover.AnchorGrowthFrame"], dir, label) or format(L["Mover.AnchorGrowth"], dir)
    )
end

-- Coordinate popup: shared singleton for typing exact X/Y positions and anchor settings
local function CreateCoordinatePopup()
    local popupFonts = {}
    local function ApplyFont(obj, size, outline)
        TrackFont(popupFonts, obj, size, outline)
    end
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

    local title = popup:CreateFontString(nil, "OVERLAY")
    ApplyFont(title, 11)
    title:SetPoint("TOP", 0, -8)
    title:SetText(L["Mover.SetPosition"])
    title:SetTextColor(unpack(BR.Colors.Accent))

    local LABEL_X = 12
    local EDIT_WIDTH = 155
    local MENU_WIDTH = EDIT_WIDTH + 16

    local xLabel = popup:CreateFontString(nil, "OVERLAY")
    ApplyFont(xLabel, 11)
    xLabel:SetPoint("TOPLEFT", LABEL_X, -30)
    xLabel:SetText("X")
    xLabel:SetTextColor(1, 1, 1, 1)

    local xEdit = CreateFrame("EditBox", nil, popup)
    xEdit:SetSize(EDIT_WIDTH, 20)
    ApplyFont(xEdit, 11, "")
    xEdit:SetAutoFocus(false)
    local xContainer = BR.StyleEditBox(xEdit)
    xContainer:SetSize(EDIT_WIDTH, 20)
    xContainer:SetPoint("LEFT", xLabel, "RIGHT", 8, 0)

    local yLabel = popup:CreateFontString(nil, "OVERLAY")
    ApplyFont(yLabel, 11)
    yLabel:SetPoint("TOPLEFT", LABEL_X, -56)
    yLabel:SetText("Y")
    yLabel:SetTextColor(1, 1, 1, 1)

    local yEdit = CreateFrame("EditBox", nil, popup)
    yEdit:SetSize(EDIT_WIDTH, 20)
    ApplyFont(yEdit, 11, "")
    yEdit:SetAutoFocus(false)
    local yContainer = BR.StyleEditBox(yEdit)
    yContainer:SetSize(EDIT_WIDTH, 20)
    yContainer:SetPoint("LEFT", yLabel, "RIGHT", 8, 0)

    local sep = popup:CreateTexture(nil, "ARTWORK")
    sep:SetSize(216, 1)
    sep:SetPoint("TOPLEFT", LABEL_X, -82)
    sep:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 1)

    local anchorLabel = popup:CreateFontString(nil, "OVERLAY")
    ApplyFont(anchorLabel, 10)
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
    ApplyFont(anchorText, 11, "")
    anchorText:SetPoint("LEFT", 6, 0)
    anchorText:SetPoint("RIGHT", -20, 0)
    anchorText:SetJustifyH("LEFT")
    anchorText:SetWordWrap(false)
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
        local maxScroll = anchorScrollChild:GetHeight() - anchorScroll:GetHeight()
        local newScroll = anchorScroll:GetVerticalScroll() - delta * ITEM_HEIGHT * 3
        anchorScroll:SetVerticalScroll(math.max(0, math.min(newScroll, math.max(0, maxScroll))))
    end)

    local anchorMenuItems = {}

    local function SetAnchorFrame(frameName)
        local catKey = popup.catKey
        if not catKey then
            return
        end
        anchorText:SetText(AnchorFrameLabel(frameName) or L["Mover.NoneScreenCenter"])
        anchorMenu:Hide()
        -- Set the anchor in the DB directly, reset the position to (0,0), then
        -- refresh once. A refresh before the reset places the frame at the old
        -- offsets, so the frame moves twice.
        local target = moverTargets[catKey]
        if target then
            target.SetAnchorFrame(frameName)
            SavePosition(catKey, 0, 0)
        else
            local db = BR.profile
            if not db.categorySettings then
                db.categorySettings = {}
            end
            if not db.categorySettings[catKey] then
                db.categorySettings[catKey] = {}
            end
            db.categorySettings[catKey].anchorFrame = frameName
            SavePosition(catKey, 0, 0)
            BR.CallbackRegistry:TriggerEvent("LayoutRefresh")
        end
        SyncPopupCoords(catKey, 0, 0)
        UpdateMoverCaption(catKey)
        -- pointBtn is created after this function, so the reads go through popup.*
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

    -- Sits beside the dropdown, because pointing at the frame is the answer when
    -- the player cannot tell which name in the list is the frame on their screen.
    local pickBtn = BR.CreateButton(popup, L["Mover.PickFrame"], function()
        HideAllMenus()
        popup:Hide()
        StartPicking(function(name)
            popup:Show()
            if name then
                RememberAnchorFrame(name)
                SetAnchorFrame(name)
            end
        end)
    end)
    pickBtn:SetSize(44, 20)
    pickBtn:SetPoint("TOPLEFT", anchorBtn, "TOPRIGHT", 6, 0)

    local function GetOrCreateMenuItem(index)
        if anchorMenuItems[index] then
            return anchorMenuItems[index]
        end
        local item = CreateFrame("Button", nil, anchorScrollChild, "BackdropTemplate")
        item:SetSize(MENU_WIDTH - 2, ITEM_HEIGHT)
        item:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        item:SetBackdropColor(0, 0, 0, 0)
        item.text = item:CreateFontString(nil, "OVERLAY")
        ApplyFont(item.text, 11, "")
        item.text:SetPoint("LEFT", 6, 0)
        item.text:SetPoint("RIGHT", -6, 0)
        item.text:SetJustifyH("LEFT")
        item.text:SetWordWrap(false)
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
                local entry = frames[i - 1]
                item.text:SetText(entry.hidden and (entry.label .. " " .. TAG_ANCHOR_HIDDEN) or entry.label)
                if entry.hidden then
                    item.text:SetTextColor(0.6, 0.6, 0.6, 1)
                else
                    item.text:SetTextColor(1, 1, 1, 1)
                end
                item:SetScript("OnClick", function()
                    SetAnchorFrame(entry.name)
                end)
            end
            item:Show()
        end
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

    local pointLabel = popup:CreateFontString(nil, "OVERLAY")
    ApplyFont(pointLabel, 10)
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
    ApplyFont(pointText, 11, "")
    pointText:SetPoint("LEFT", 6, 0)
    pointText:SetTextColor(1, 1, 1, 1)

    local pointArrow = pointBtn:CreateTexture(nil, "OVERLAY")
    pointArrow:SetSize(12, 12)
    pointArrow:SetPoint("RIGHT", -4, 0)
    pointArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    pointArrow:SetRotation(rad(-90))
    pointArrow:SetVertexColor(0.6, 0.6, 0.6, 1)

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
        ApplyFont(itemText, 11, "")
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
            local target = catKey and moverTargets[catKey]
            if target then
                target.SetAnchorPoint(pt)
            elseif catKey then
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

    xEdit:SetScript("OnTabPressed", function()
        yEdit:SetFocus()
    end)

    xEdit:SetScript("OnEnterPressed", function()
        applyBtn:Click()
    end)
    yEdit:SetScript("OnEnterPressed", function()
        applyBtn:Click()
    end)
    yEdit:SetScript("OnTabPressed", function()
        xEdit:SetFocus()
    end)

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
    function popup:RefreshFonts()
        RefreshFonts(popupFonts)
    end
    popup:SetScript("OnHide", HideAllMenus)
    popup:Hide()
    return popup
end

-- Show the shared popup anchored to a specific mover, populated with its coords
local function ShowCoordinatePopup(catKey, mover)
    if not coordPopup then
        coordPopup = CreateCoordinatePopup()
    end
    coordPopup:RefreshFonts()
    coordPopup.catKey = catKey
    coordPopup:ClearAllPoints()
    coordPopup:SetPoint("LEFT", mover, "RIGHT", 10, 0)

    local pos = GetSavedPosition(catKey)
    coordPopup.xEdit:SetText(tostring(pos.x or 0))
    coordPopup.yEdit:SetText(tostring(pos.y or 0))

    local isDetached = IsIconDetached(catKey)
    local target = moverTargets[catKey]
    local anchorName, anchorPoint
    if target then
        anchorName, anchorPoint = target.GetAnchor()
        anchorPoint = anchorPoint or "CENTER"
    elseif not isDetached then
        local db = BR.profile
        local catSettings = db.categorySettings and db.categorySettings[catKey]
        anchorName = catSettings and catSettings.anchorFrame
        anchorPoint = catSettings and catSettings.anchorPoint or "CENTER"
    end
    coordPopup.anchorText:SetText(AnchorFrameLabel(anchorName) or L["Mover.NoneScreenCenter"])
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

-- The mover matches the category's iconSize for accurate positioning.
local function CreateMoverFrame(catKey, displayName)
    local ApplyFont = BR.DisplayFonts.Apply
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

    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.7, 0, 0.6)

    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    ApplyFont(mover.label, 11)
    mover.label:SetTextColor(0.4, 1, 0.4, 1)
    mover.label:SetText(displayName or catKey)

    mover.anchorText = mover:CreateFontString(nil, "OVERLAY")
    mover.anchorText:SetPoint("TOP", mover, "BOTTOM", 0, -4)
    ApplyFont(mover.anchorText, 11)
    mover.anchorText:SetTextColor(0.4, 1, 0.4, 1)

    mover.catKey = catKey

    -- The mover is built once, so it keeps the font it was created with. UpdateSize
    -- re-applies the label font on every VisualsRefresh.
    function mover:UpdateSize()
        local settings = GetCategorySettings(catKey)
        local size = settings.iconSize or 64
        self:SetSize(settings.iconWidth or size, size)
        ApplyFont(self.label, 11)
        ApplyFont(self.anchorText, 11)
    end

    local pos = GetSavedPosition(catKey)
    local initDirection = GetCategorySettings(catKey).growDirection or "CENTER"
    local initAnchor = DIRECTION_ANCHORS[initDirection] or "CENTER"
    local extFrame, extPoint = ResolveAnchorParent(catKey)
    if extFrame then
        local extAnchor = EXT_DIRECTION_ANCHORS[extPoint] and EXT_DIRECTION_ANCHORS[extPoint][initDirection]
            or initAnchor
        mover:SetPoint(extAnchor, extFrame, extPoint, pos.x or 0, pos.y or 0)
    else
        mover:SetPoint(initAnchor, UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end

    BR.SetupTooltip(mover, L["Mover.BuffAnchor"], L["Mover.DragTooltip"])

    mover:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        DimContainer(catKey)
        -- Hide sub-icon action buttons so they do not linger at old positions during drag
        if BR.SecureButtons then
            BR.SecureButtons.HideSecureFramesForCatKey(catKey)
        end
        self.isDragging = true
        self:StartMoving()
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
        -- Do not overwrite text while the user edits it
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

    local ApplyFont = BR.DisplayFonts.Apply
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

    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    ApplyFont(mover.label, 11)
    mover.label:SetTextColor(1, 0.85, 0.3, 1)
    mover.label:SetText(displayName or key)

    mover.anchorText = mover:CreateFontString(nil, "OVERLAY")
    mover.anchorText:SetPoint("TOP", mover, "BOTTOM", 0, -4)
    ApplyFont(mover.anchorText, 11)
    mover.anchorText:SetTextColor(1, 0.85, 0.3, 1)
    mover.anchorText:SetText(L["Mover.Detached"])

    mover.catKey = key

    -- The mover is built once, so it keeps the font it was created with. UpdateSize
    -- re-applies the label font on every VisualsRefresh.
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
        ApplyFont(self.label, 11)
        ApplyFont(self.anchorText, 11)
    end

    local pos = GetDetachedSavedPosition(key)
    mover:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)

    BR.SetupTooltip(mover, L["Mover.BuffAnchor"], L["Mover.DragTooltip"])

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

local function AreAllCategoriesSplit()
    for _, category in ipairs(CATEGORIES) do
        if not IsCategorySplit(category) then
            return false
        end
    end
    return true
end

-- Update mover frame visibility and labels based on lock/split state.
-- ClearAllPoints cancels an active StartMoving() drag, so PositionMoverFrame returns
-- early while mover.isDragging is true. Never bypass that guard.
local function UpdateAnchor()
    if not BR.Display.mainFrame then
        return
    end

    local db = BR.profile
    local unlocked = not BR.Display.IsFrameLocked()

    local allSplit = AreAllCategoriesSplit()
    local mainMover = moverFrames["main"]
    if mainMover then
        if unlocked and not allSplit then
            mainMover.label:SetText(GetMainFrameLabel())
            UpdateMoverCaption("main")
            PositionMoverFrame("main")
            mainMover:Show()
        else
            mainMover:Hide()
        end
    end

    for _, category in ipairs(CATEGORIES) do
        local mover = moverFrames[category]
        if mover then
            if unlocked and IsCategorySplit(category) then
                mover.label:SetText(CATEGORY_LABELS[category])
                UpdateMoverCaption(category)
                PositionMoverFrame(category)
                mover:Show()
            else
                mover:Hide()
            end
        end
    end

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

-- Must run before LayoutRefresh on a profile switch. A stale oldDir makes
-- ConvertDirectionPositions convert a position that did not change direction.
local function SyncDirectionCache()
    lastDirection["main"] = (GetCategorySettings("main").growDirection or "CENTER")
    for _, category in ipairs(CATEGORIES) do
        lastDirection[category] = (GetCategorySettings(category).growDirection or "CENTER")
    end
end

-- Reposition all mover frames from the active profile's saved positions.
local function RepositionAllFrames()
    PositionMoverFrame("main")
    for _, category in ipairs(CATEGORIES) do
        PositionMoverFrame(category)
    end
    local db = BR.profile
    if db.detachedIcons then
        for key in pairs(db.detachedIcons) do
            local container = BR.Display.detachedFrames and BR.Display.detachedFrames[key]
            if container then
                local pos = GetDetachedSavedPosition(key)
                container:ClearAllPoints()
                container:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
            end
            PositionDetachedMoverFrame(key)
        end
    end
end

---Let a display that is not a buff category use the coordinate popup. The adapter
---supplies GetPosition, SetPosition, GetAnchor, SetAnchorFrame, SetAnchorPoint and
---an optional UpdateLabel.
---@param key string Popup key, in the namespace of the category keys
---@param adapter table
local function RegisterTarget(key, adapter)
    moverTargets[key] = adapter
end

BR.Movers = {
    Initialize = InitializeMovers,
    UpdateAnchor = UpdateAnchor,
    HideAll = HideAllMovers,
    SavePosition = SavePosition,
    ScanAnchorFrames = ScanAnchorFrames,
    AnchorFrameLabel = AnchorFrameLabel,
    RegisterTarget = RegisterTarget,
    PickFrame = StartPicking,
    RememberAnchorFrame = RememberAnchorFrame,
    ShowCoordinatePopup = ShowCoordinatePopup,
    HideCoordinatePopup = HidePopupFor,
    IsCoordinatePopupShown = IsPopupShownFor,
    SyncPopupCoords = SyncPopupCoords,
    AnchoredOffsets = AnchoredOffsets,
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
