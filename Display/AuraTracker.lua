local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Retail then
    return
end

-- ============================================================================
-- EXTERNALS
-- ============================================================================
-- A present-based display: shows the defensives and buffs you RECEIVE (Power
-- Infusion, Bloodlust, Prescience, ...) while they are active. This is the inverse of
-- the reminder pipeline and shares nothing with State.lua - Blizzard's AuraContainer
-- does the filtering and rendering, so it works for auras the addon cannot read.
--
-- The constraints this module is shaped around:
--
--   * Decoration is CREATION-WINDOW ONLY. The whole button subtree - the addon's
--     own textures included - becomes forbidden while auras are secret. So every
--     restyle is attempted, and on denial queued for the next restriction lift.
--   * Never read geometry off a button. Its dimensions come back as secret numbers
--     and any arithmetic on them throws. All sizes come from config.
--   * Per-button state lives in a weak-keyed table here, never on the button.
--   * Groups cannot be removed (ClearAuraGroups is deliberately unexposed), so the
--     entry set is changed by reconfiguring the group's filters, never by rebuilding.
--     A live group does not re-parse the auras already on the player when its
--     filters change, so every reconfigure runs inside a container Hide/Show pair.
--   * The engine honors includeSpellIDs only while the player is assistable, and it
--     fails OPEN - a group asking for one spell then renders every buff. Vehicles,
--     cinematics and faction flips all drop assistability, so the display suppresses
--     itself for those windows instead of showing the wrong set.
--
-- One AuraGroup holds every enabled spell ID. Blizzard packs the visible buttons:
-- with five buffs enabled and one active, the row shows one icon, not four gaps.

local min = math.min
local floor = math.floor
local format = string.format
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local UnitCanAssist = UnitCanAssist
local InVehicle = UnitUsingVehicle or UnitInVehicle

local L = BR.L
local Plain = BR.Secret.Plain
local TEXCOORD_INSET = BR.TEXCOORD_INSET
local GetAspectCropInsets = BR.GetAspectCropInsets

local Settings = BR.GetExternalSettings
local Entries = BR.GetExternalEntries
local IsEnabled = BR.AreExternalsEnabled
-- Appearance reads go through the resolver, which inherits from the global
-- defaults unless externals.useCustomAppearance is set.
local Setting = BR.GetExternalSetting

local GROUP_KEY = "externals"
-- Key this display answers to in the shared mover coordinate popup. It is not a
-- buff category, so it can never collide with one.
local MOVER_KEY = "externals"
-- Blizzard allocates aura frames in batches of 10; this caps how many can be
-- visible at once, not how many can be enabled.
local MAX_FRAMES = 20
-- Test mode cap: enough frames to judge spacing and growth direction, few enough
-- that a player with dozens of buffs does not preview a wall of icons.
local TEST_MODE_CAP = 3
-- Matches the category movers' label size in Movers.lua.
local MOVER_LABEL_SIZE = 11

local anchorFrame, container
-- Regions the addon creates, per button. Weak keys: Blizzard owns the buttons' lifetime.
local buttonRegions = setmetatable({}, { __mode = "k" })
-- Set when a reconfigure or restyle was denied, so the lift watcher retries.
local applyPending = false
-- Test mode previews through the REAL container: the spell-ID filter is dropped so
-- the player's current buffs render, capped low. Fake icons must emulate Blizzard's
-- packing, and button geometry is secret, so no emulation can be verified against
-- the real layout.
local testMode = false

---Union of every enabled entry's spell IDs.
---
---The second return is the ENTRY count, not the spell-ID count: it sizes the frame
---pool, and an entry can carry several IDs that are mutually exclusive in practice
---(one Bloodlust variant at a time), so IDs over-allocate.
---@return table<number, boolean> map
---@return number entryCount
local function BuildSpellIDMap()
    local enabled = Settings().entries
    local map, entryCount = {}, 0
    if not enabled then
        return map, entryCount
    end

    for _, entry in ipairs(Entries()) do
        if enabled[entry.key] then
            entryCount = entryCount + 1
            for _, spellID in ipairs(entry.spellIDs) do
                map[spellID] = true
            end
        end
    end

    return map, entryCount
end

---Icon dimensions from config. iconWidth nil = square (same as iconSize).
---@return number width
---@return number height
local function GetIconDimensions()
    local height = Setting("iconSize") or 40
    return Setting("iconWidth") or height, height
end

---A suffix-free countdown formatter, built once and handed to SetDurationText.
---
---Blizzard's DefaultAuraDurationFormatter is a SecondsFormatter, which always names
---its unit - its "abbreviation" setting only picks how ("13 Seconds" / "13 sec" /
---"13 s"), never nothing. A NumericRuleFormatter takes raw format strings instead,
---so this renders a bare number under a minute and m:ss above it.
local function BuildDurationFormatter()
    local ok, formatter = pcall(function()
        local f = C_StringUtil.CreateNumericRuleFormatter()
        f:SetBreakpoints({
            {
                threshold = 0,
                format = "%d",
                step = 1,
                -- Round up, so a buff with 0.4s left reads "1" rather than "0".
                rounding = Enum.NumericRuleFormatRounding.Up,
            },
            {
                threshold = 60,
                format = "%d:%02d",
                components = {
                    { div = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down },
                    { mod = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down },
                },
            },
        })
        return f
    end)
    return ok and formatter or nil
end

local durationFormatter

-- dx/dy point away from the icon and scale the border gap.
local CASTER_NAME_SIDES = {
    TOP = { from = "BOTTOM", to = "TOP", justify = "CENTER", dx = 0, dy = 1 },
    BOTTOM = { from = "TOP", to = "BOTTOM", justify = "CENTER", dx = 0, dy = -1 },
    LEFT = { from = "RIGHT", to = "LEFT", justify = "RIGHT", dx = -1, dy = 0 },
    RIGHT = { from = "LEFT", to = "RIGHT", justify = "LEFT", dx = 1, dy = 0 },
}

---Apply the configured look to one button. The call is legal at frame creation only.
---A later call is denied while auras are secret, so callers pcall it.
local function StyleButton(button)
    local regions = buttonRegions[button]
    if not regions then
        return
    end

    local width, height = GetIconDimensions()
    local borderSize = Setting("borderSize") or 0

    button:SetSize(width, height)

    -- Base crop hides texture edge artifacts; iconZoom adds on top, and the insets
    -- are aspect-aware so non-square icons show a centered slice instead of
    -- stretching. Blizzard's per-aura update only calls SetTexture, so this
    -- survives every icon swap.
    local inset = TEXCOORD_INSET + (Setting("iconZoom") or 0) / 100
    local xInset, yInset = GetAspectCropInsets(inset, width, height)
    regions.icon:SetTexCoord(xInset, 1 - xInset, yInset, 1 - yInset)
    regions.icon:SetAlpha(Setting("iconAlpha") or 1)

    -- Duration text: the addon places and fonts it, Blizzard writes it. The call
    -- stores nothing on the region - per-button state on this subtree goes forbidden.
    BR.DisplayFonts.Apply(regions.duration, Setting("durationSize") or 16)

    -- SetDrawSwipe, not Hide: Blizzard calls SetCooldown on this frame on every
    -- aura refresh, and that call re-shows the frame. Swipe drawing is persistent
    -- cooldown style instead, which SetCooldown leaves alone. The frame must also
    -- stay registered - it is the button's duration SOURCE, so unregistering it
    -- takes the countdown text away with the swipe.
    if regions.cooldown.SetDrawSwipe then
        regions.cooldown:SetDrawSwipe(Setting("showSwipe") ~= false)
    end

    -- Border protrudes past the button's bounds, same as the reminder icons.
    -- Regions can extend outside a button; only their parentage is constrained.
    if borderSize > 0 then
        regions.border:ClearAllPoints()
        regions.border:SetPoint("TOPLEFT", -borderSize, borderSize)
        regions.border:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
        regions.border:Show()
    else
        regions.border:Hide()
    end

    -- Blizzard writes the caster, whose identity is secret in restricted contexts.
    local casterName = regions.casterName
    local anchor = CASTER_NAME_SIDES[Setting("casterNamePosition")] or CASTER_NAME_SIDES.BOTTOM
    local gap = borderSize + 2
    local x = anchor.dx * gap + (Setting("casterNameOffsetX") or 0)
    local y = anchor.dy * gap + (Setting("casterNameOffsetY") or 0)
    BR.DisplayFonts.Apply(casterName, Setting("casterNameSize") or 12)
    casterName:ClearAllPoints()
    if anchor.dy ~= 0 then
        -- Two anchors cap the name at the icon width, and the missing word wrap
        -- truncates it, so it never covers a neighbor in a row.
        casterName:SetPoint(anchor.from .. "LEFT", button, anchor.to .. "LEFT", x, y)
        casterName:SetPoint(anchor.from .. "RIGHT", button, anchor.to .. "RIGHT", x, y)
    else
        casterName:SetPoint(anchor.from, button, anchor.to, x, y)
    end
    casterName:SetJustifyH(anchor.justify)
    regions.casterHost:SetShown(Setting("showCasterName") == true)

    -- Last, because these are the calls most likely to be denied: a denial must not
    -- cost the styling above. The engine draws the tooltip for an aura the addon
    -- cannot read, and it needs mouse motion on the button. Clicks stay off in both
    -- states, so the icons never take a click away from what is under them.
    button:SetMouseClickEnabled(false)
    button:SetMouseMotionEnabled(Setting("showTooltips") == true)
end

---The one window where addon code can decorate a button: the frame provider calls
---this before applying the access restriction that forbids the subtree.
local function InitializeButton(button)
    local regions = {}
    buttonRegions[button] = regions

    regions.border = button:CreateTexture(nil, "BACKGROUND")
    regions.border:SetColorTexture(0, 0, 0, 1)

    regions.icon = button:CreateTexture(nil, "ARTWORK")
    regions.icon:SetAllPoints(button)
    button:SetIcon(regions.icon)

    -- The radial sweep over the icon. CooldownFrameTemplate carries the swipe
    -- texture - a bare Cooldown frame draws nothing. Blizzard calls SetCooldown on
    -- it from the aura's own duration, so the sweep runs for auras the addon cannot
    -- read. Reverse: the swipe UNCOVERS the icon as the time runs out.
    regions.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    regions.cooldown:SetAllPoints(button)
    regions.cooldown:SetDrawEdge(false)
    regions.cooldown:SetReverse(true)
    -- The countdown text below belongs to the addon; the swipe must not print a second one.
    regions.cooldown:SetHideCountdownNumbers(true)
    button:SetDurationCooldown(regions.cooldown)

    -- The swipe is a child FRAME, so it draws over every region of the button
    -- itself. Text goes on a carrier above it, or the sweep covers the countdown.
    regions.textHost = CreateFrame("Frame", nil, button)
    regions.textHost:SetAllPoints(button)
    regions.textHost:SetFrameLevel(regions.cooldown:GetFrameLevel() + 1)
    -- The button owns the mouse for the tooltip. A carrier that takes motion sits
    -- between the cursor and the button and eats it.
    regions.textHost:EnableMouse(false)

    -- SetDurationText stamps SecretAspect.Text/Alpha/VertexColor on this
    -- fontstring: Blizzard writes and counts it down, the addon must never read it
    -- back. That timer is the one piece of data the addon cannot obtain in a
    -- restricted context, so it is not optional.
    --
    -- Placement and font belong to the addon; only the string is Blizzard's, and the
    -- `textFormatter` option decides how it is rendered. Falls back to the stock
    -- "42 s" formatter if the formatter or the option is rejected.
    regions.duration = regions.textHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    regions.duration:SetPoint("CENTER", button, "CENTER", 0, 0)
    regions.duration:SetJustifyH("CENTER")

    if durationFormatter == nil then
        durationFormatter = BuildDurationFormatter() or false
    end
    if
        not (
            durationFormatter
            and pcall(button.SetDurationText, button, regions.duration, {
                textFormatter = durationFormatter,
            })
        )
    then
        button:SetDurationText(regions.duration)
    end

    regions.count = regions.textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    regions.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button:SetApplicationCount(regions.count)

    -- Registered once, like the countdown. The setting toggles this carrier, because
    -- Blizzard owns the fontstring's own visibility once it writes the name.
    regions.casterHost = CreateFrame("Frame", nil, regions.textHost)
    regions.casterHost:SetAllPoints(button)
    regions.casterName = regions.casterHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    regions.casterName:SetWordWrap(false)
    button:SetCasterName(regions.casterName, { useClassColors = true })

    StyleButton(button)
end

local function Round(value)
    return floor(value + 0.5)
end

---The frame this display is attached to, chosen in the mover coordinate popup.
---@return table? frame, string? point nil when unset, or when the frame does not exist
local function ResolveAnchor()
    local frame = BR.ResolveAnchorFrame(Settings().anchorFrame)
    if frame then
        return frame, Settings().anchorPoint or "CENTER"
    end
    return nil, nil
end

---The corner of this display that meets the anchor frame's point. Growth has no
---centered value, so the CENTER column of the map never applies.
---@param point string Anchor point on the anchor frame
---@return string
local function SelfPoint(point)
    local map = BR.EXT_DIRECTION_ANCHORS[point]
    return map and map[Settings().growDirection or "RIGHT"] or point
end

---Where the display sits now, in the coordinates it is saved in: relative to the
---anchor frame when one is set, otherwise to the center of the screen.
---@return number? x, number? y, string? selfPoint, table? parent, string? parentPoint
local function ComputeCoords()
    local parent, point = ResolveAnchor()
    if parent and point then
        local selfPoint = SelfPoint(point)
        local x, y = BR.Movers.AnchoredOffsets(anchorFrame, selfPoint, parent, point)
        if not x or not y then
            -- The anchor frame has no laid-out rect yet. The next refresh then saves
            -- screen coordinates against the anchor, which moves the display.
            return nil
        end
        return x, y, selfPoint, parent, point
    end
    local cx, cy = anchorFrame:GetCenter()
    local px, py = UIParent:GetCenter()
    if not cx or not px then
        return nil
    end
    return Round(cx - px), Round(cy - py)
end

---Persist the position after a drag. An anchored display keeps its anchor: the
---offsets are recomputed against the anchor frame, so a nudge never converts the
---display back to screen coordinates.
local function SavePosition()
    local x, y, selfPoint, parent, point = ComputeCoords()
    if not x then
        return
    end
    -- Screen placement is stored center-relative, like every category frame, so the
    -- coordinates typed in the popup mean the same thing on both.
    Settings().position = { point = "CENTER", x = x, y = y }
    anchorFrame:ClearAllPoints()
    if parent then
        anchorFrame:SetPoint(selfPoint, parent, point, x, y)
    else
        anchorFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
    BR.Movers.SyncPopupCoords(MOVER_KEY, x, y)
end

local function ApplyPosition()
    local position = Settings().position or BR.defaults.externals.position
    local x, y = position.x or 0, position.y or 0
    local parent, point = ResolveAnchor()
    anchorFrame:ClearAllPoints()
    if parent and point then
        anchorFrame:SetPoint(SelfPoint(point), parent, point, x, y)
    else
        -- Older saves carry the screen point the drag left behind, so it still
        -- drives both sides of the anchor.
        local screenPoint = position.point or "CENTER"
        anchorFrame:SetPoint(screenPoint, UIParent, screenPoint, x, y)
    end
end

---Caption under the mover, matching the category movers.
local function UpdateMoverCaption()
    local mover = anchorFrame and anchorFrame.mover
    if not mover then
        return
    end
    local settings = Settings()
    local dir = settings.growDirection or "RIGHT"
    local label = BR.Movers.AnchorFrameLabel(settings.anchorFrame)
    mover.anchorText:SetText(
        label and format(L["Mover.AnchorGrowthFrame"], dir, label) or format(L["Mover.AnchorGrowth"], dir)
    )
end

-- Flow-layout state per growth direction. `corner` is the fixed start point of the
-- run. `vertical` puts the flow's primary axis on the vertical, which is what makes
-- UP and DOWN stack a column. The cross-axis direction only picks the side a wrapped
-- line goes to, and no maximum line size is set, so every icon stays on one line.
local GROWTH = {
    RIGHT = { corner = "TOPLEFT", h = "Right", v = "Down" },
    LEFT = { corner = "TOPRIGHT", h = "Left", v = "Down" },
    DOWN = { corner = "TOPLEFT", h = "Right", v = "Down", vertical = true },
    UP = { corner = "BOTTOMLEFT", h = "Right", v = "Up", vertical = true },
}

---Growth is container-level flow-layout state, public on the container (unlike
---per-button styling): SetFlowLayout* since 68914, SetAuraLayout* before - resolve
---per call so either API generation works. Direction values are
---AnchorUtil.FlowDirection members, and there is no centered growth. The flow
---layout places buttons from its INTERNAL anchor point (default TOPLEFT),
---independent of the container's own anchor - the same corner must feed both, or
---the first icon lands on the wrong side of the mover.
local function ApplyGrowth(settings)
    local growth = GROWTH[settings.growDirection or "RIGHT"] or GROWTH.RIGHT
    container:ClearAllPoints()
    container:SetPoint(growth.corner, anchorFrame, growth.corner)

    local setAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    if setAnchor then
        setAnchor(container, growth.corner)
    end

    -- SetFlowLayoutAxis has no pre-68914 name. Without it the primary axis stays
    -- horizontal, so UP and DOWN degrade to a row instead of faulting.
    local axes = AnchorUtil and AnchorUtil.FlowLayoutAxis
    if axes and container.SetFlowLayoutAxis then
        container:SetFlowLayoutAxis(growth.vertical and axes.Vertical or axes.Horizontal)
    end

    local directions = AnchorUtil and AnchorUtil.FlowDirection
    local setGrowth = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    if directions and setGrowth then
        setGrowth(container, directions[growth.h], directions[growth.v])
    end
end

-- ============================================================================
-- ASSISTABILITY GATE
-- ============================================================================
-- AuraContainerUtil.CanApplyIdentityCandidateFilters applies includeSpellIDs to a
-- helpful aura only while UnitCanAssist holds, and the check fails OPEN: the aura
-- then passes on its filter string alone, so this group renders every buff on the
-- player wearing the tracked buffs' styling. Membership is cached per aura instance
-- and UNIT_AURA re-parses only what changed, so the wrong set outlives the window
-- that caused it.

-- Period, minimum wait and give-up point of the settle watch. The restore lands a
-- measurable moment after the event that ends the window, so a probe taken on the
-- event itself still reads degraded.
local SETTLE_PERIOD = 0.1
local SETTLE_MIN_TICKS = 5
local SETTLE_MAX_TICKS = 20

local settleTicker
local recoveryPending = false
local WatchForSettle, ScheduleRecovery

---True while the engine honors this group's spell-ID filters.
---
---UnitUsingVehicle over UnitInVehicle: it also reads true across the boarding and
---exiting transitions, where the filters are already degraded.
---
---An unreadable UnitCanAssist counts as assistable, against the addon's usual
---fail-closed default. This display exists to run in combat, so a secret return
---must not blank it for a whole fight.
---@return boolean
local function IsAssistable()
    if InVehicle("player") then
        return false
    end
    local ok, canAssist = pcall(UnitCanAssist, "player", "player")
    return not (ok and Plain(canAssist) == false)
end

---True while the display must stay hidden. Test mode drops the spell-ID filter
---entirely, so it has nothing to degrade.
---@return boolean
local function IsSuppressed()
    return not testMode and not IsAssistable()
end

---Hide or show without touching the container's config. A reparse taken while
---assistability is down re-bakes the unfiltered set.
local function ApplyVisibility()
    if anchorFrame then
        anchorFrame:SetShown(IsEnabled() and not IsSuppressed())
    end
end

local function StopSettleWatch()
    if settleTicker then
        settleTicker:Cancel()
        settleTicker = nil
    end
end

---Push the current config into the container. Every button-touching call here can
---be denied while auras are secret. A denial is flagged and retried on the next lift.
local function ApplyConfig()
    if not container then
        return
    end

    local settings = Settings()
    local map, entryCount = BuildSpellIDMap()
    local width, height = GetIconDimensions()

    -- The Hide/Show pair around the reconfigure is what makes a filter change take
    -- effect: a live group keeps serving the set it parsed, and
    -- AuraContainerPrivateMixin:OnShow_Intrinsic is the call that forces a full
    -- reparse. Without it, ticking a buff that is already on the player shows
    -- nothing until the aura is reapplied.
    local ok = pcall(function()
        container:Hide()
        if testMode then
            -- No candidate filters at all: any HELPFUL aura on the player qualifies,
            -- so the preview has something to show regardless of what is enabled.
            container:SetAuraGroupCandidateFilters(GROUP_KEY, {})
            container:SetAuraGroupMaxFrameCount(GROUP_KEY, TEST_MODE_CAP)
        else
            container:SetAuraGroupCandidateFilters(GROUP_KEY, { includeSpellIDs = map })
            container:SetAuraGroupMaxFrameCount(GROUP_KEY, min(entryCount, MAX_FRAMES))
        end
        -- elementWidth/Height feed the flow math only (packing, spacing); the
        -- visible size is StyleButton's SetSize. The two must agree.
        container:SetAuraGroupLayout(GROUP_KEY, {
            elementSpacing = Setting("spacing") or 0,
            elementWidth = width,
            elementHeight = height,
        })
        ApplyGrowth(settings)
    end)

    -- Outside the pcall above: a denial part-way through the reconfigure must not
    -- leave the container hidden for the rest of the session.
    if not pcall(container.Show, container) then
        ok = false
    end

    for button in pairs(buttonRegions) do
        if not pcall(StyleButton, button) then
            ok = false
        end
    end

    applyPending = not ok
end

---The green drag box, matching the category movers in Movers.lua. A frame of its own
---rather than a texture on the anchor: it needs HIGH strata to sit above the icons,
---and HIGH strata on the anchor drags the container's whole subtree up with it.
local function CreateMover()
    local mover = CreateFrame("Frame", nil, anchorFrame)
    mover:SetAllPoints()
    mover:SetFrameStrata("HIGH")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.7, 0, 0.6)

    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    mover.label = label

    local anchorText = mover:CreateFontString(nil, "OVERLAY")
    anchorText:SetPoint("TOP", mover, "BOTTOM", 0, -4)
    mover.anchorText = anchorText

    -- The mover is built once, so font setting changes must be pushed to its
    -- labels explicitly. The frame belongs to the addon, not to a forbidden
    -- button subtree, so the apply is safe.
    function mover:UpdateFont()
        BR.DisplayFonts.Apply(self.label, MOVER_LABEL_SIZE)
        BR.DisplayFonts.Apply(self.anchorText, MOVER_LABEL_SIZE)
    end
    -- Must run before SetText: SetText on a font-less FontString raises an error.
    mover:UpdateFont()

    label:SetTextColor(0.4, 1, 0.4, 1)
    label:SetText(L["Externals.Title"])
    anchorText:SetTextColor(0.4, 1, 0.4, 1)

    BR.SetupTooltip(mover, L["Externals.Title"], L["Mover.DragTooltip"])

    local function FinishDrag()
        mover.isDragging = false
        mover:SetScript("OnUpdate", nil)
        anchorFrame:StopMovingOrSizing()
        SavePosition()
    end

    mover:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self.isDragging = true
        anchorFrame:StartMoving()
        self:SetScript("OnUpdate", function()
            local x, y = ComputeCoords()
            if x then
                BR.Movers.SyncPopupCoords(MOVER_KEY, x, y)
            end
        end)
    end)
    mover:SetScript("OnDragStop", FinishDrag)
    mover:SetScript("OnHide", function(self)
        if self.isDragging then
            FinishDrag()
        end
    end)

    mover:SetScript("OnMouseUp", function(self, button)
        if self.isDragging or button ~= "LeftButton" then
            return
        end
        if BR.Movers.IsCoordinatePopupShown(MOVER_KEY) then
            BR.Movers.HideCoordinatePopup(MOVER_KEY)
        else
            BR.Movers.ShowCoordinatePopup(MOVER_KEY, self)
        end
    end)

    mover:Hide()
    return mover
end

local function EnsureFrames()
    if container then
        return true
    end

    -- Guarded separately from the container: if the container ever fails to build,
    -- this is retried from the lift watcher and from VisualsRefresh, and a second
    -- anchor orphans the previous one under the same global name (WoW frames are
    -- never collected) along with its textures and fontstring.
    if not anchorFrame then
        -- The container's parent is a plain frame the addon owns: the mover and any future
        -- animated chrome must live OUTSIDE the button subtree, and a frame anchored
        -- *to* a container inherits its layout restrictions.
        anchorFrame = CreateFrame("Frame", "BuffRemindersExternals", UIParent)
        anchorFrame:SetSize(GetIconDimensions())
        anchorFrame:SetMovable(true)
        anchorFrame:SetClampedToScreen(true)
        ApplyPosition()
    end

    -- Its own step, so a mover that failed to build is retried on the next refresh
    -- instead of leaving the anchor permanently moverless (every later refresh then
    -- faults on it, and the display stays undraggable for the session).
    if not anchorFrame.mover then
        anchorFrame.mover = CreateMover()
    end

    local ok = pcall(function()
        container = CreateFrame("AuraContainer", nil, anchorFrame, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        ApplyGrowth(Settings())
        container:AddAuraGroup(GROUP_KEY, "HELPFUL", {
            maxFrameCount = MAX_FRAMES,
            candidateFilters = { includeSpellIDs = BuildSpellIDMap() },
            initializeFrame = InitializeButton,
            layout = { elementSpacing = Setting("spacing") or 0 },
        })
        container:SetUnit("player")
        container:UpdateAllAuras()
    end)

    if not ok then
        container = nil
        applyPending = true
    end
    return container ~= nil
end

---Show the mover with the global frame lock. Hidden, it takes no mouse input, so
---the display never eats clicks while locked.
local function SetUnlocked(unlocked)
    -- The frame lock owns every category, so this must not fault before the display
    -- is built, or when its mover failed to build.
    local mover = anchorFrame and anchorFrame.mover
    if not mover then
        return
    end
    local shown = unlocked and IsEnabled()
    mover:SetShown(shown)
    if not shown then
        BR.Movers.HideCoordinatePopup(MOVER_KEY)
    end
end

local function Refresh()
    if not IsEnabled() then
        StopSettleWatch()
        if anchorFrame then
            anchorFrame:Hide()
        end
        BR.Movers.HideCoordinatePopup(MOVER_KEY)
        return
    end

    if not EnsureFrames() then
        return
    end

    ApplyPosition()
    anchorFrame:SetSize(GetIconDimensions())
    anchorFrame.mover:UpdateFont()
    UpdateMoverCaption()
    ApplyConfig()
    local suppressed = IsSuppressed()
    anchorFrame:SetShown(not suppressed)
    if suppressed then
        -- The display restores itself from here, whichever path suppressed it:
        -- nothing else announces the moment assistability comes back.
        WatchForSettle()
    end
    -- Re-sync the handle: the display can be created or enabled while the frames
    -- are already unlocked, in which case SetFrameLocked fired long before.
    SetUnlocked(not BR.Display.IsFrameLocked())
end

---Wait out a restore that no event announces. Armed only while suppressed, and it
---self-cancels on the first clean probe. A watch that times out leaves the display
---hidden. The next trigger edge re-arms it.
function WatchForSettle()
    if settleTicker then
        return
    end
    local ticks = 0
    settleTicker = C_Timer.NewTicker(SETTLE_PERIOD, function()
        ticks = ticks + 1
        if ticks < SETTLE_MIN_TICKS or not IsAssistable() then
            if ticks >= SETTLE_MAX_TICKS then
                StopSettleWatch()
            end
            return
        end
        StopSettleWatch()
        ScheduleRecovery()
    end)
end

---Repair the display after a window that degraded the filters. Deferred one tick so
---the transition ends first, and coalesced so a start-and-end burst costs one pass.
function ScheduleRecovery()
    if recoveryPending then
        return
    end
    recoveryPending = true
    C_Timer.After(0, function()
        recoveryPending = false
        if not (container and IsEnabled()) then
            return
        end
        if IsSuppressed() then
            -- A reconfigure taken now re-bakes the unfiltered set. If this was the
            -- last trigger edge, nothing else repairs it.
            ApplyVisibility()
            WatchForSettle()
            return
        end
        StopSettleWatch()
        Refresh()
    end)
end

---Driven by Display.lua's ToggleTestMode alongside the reminder categories. A
---denied reconfigure (toggled during combat) is retried by the lift watcher.
local function SetTestMode(enabled)
    testMode = enabled == true
    Refresh()
end

-- Every event that ends a restricted context or a degraded window. A denied restyle
-- otherwise stays stale until the next settings change, and a degraded parse sticks
-- until something forces a rebuild.
local liftWatcher = CreateFrame("Frame")
BR.Client.RegisterEvent(liftWatcher, "PLAYER_REGEN_ENABLED")
BR.Client.RegisterEvent(liftWatcher, "ENCOUNTER_END")
BR.Client.RegisterEvent(liftWatcher, "PLAYER_ENTERING_WORLD")
BR.Client.RegisterEvent(liftWatcher, "ZONE_CHANGED_NEW_AREA")
-- Cinematics drop the player's assistability, and UNIT_FACTION on the player is the
-- only edge an in-world cutscene fires - UNIT_FLAGS does not. CINEMATIC_STOP and
-- STOP_MOVIE cover the skip paths, whose faction restore can order ahead of it.
BR.Client.RegisterEvent(liftWatcher, "CINEMATIC_STOP")
BR.Client.RegisterEvent(liftWatcher, "STOP_MOVIE")
BR.Client.RegisterEvent(liftWatcher, "UNIT_FACTION", "player")
-- A ride keeps assistability down from the BOARDING transition to well past the
-- exit, so ENTERING counts as an edge of its own.
BR.Client.RegisterEvent(liftWatcher, "UNIT_ENTERING_VEHICLE", "player")
BR.Client.RegisterEvent(liftWatcher, "UNIT_ENTERED_VEHICLE", "player")
BR.Client.RegisterEvent(liftWatcher, "UNIT_EXITED_VEHICLE", "player")

local RECOVERY_EVENTS = {
    CINEMATIC_STOP = true,
    STOP_MOVIE = true,
    UNIT_FACTION = true,
    UNIT_ENTERING_VEHICLE = true,
    UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITED_VEHICLE = true,
}

liftWatcher:SetScript("OnEvent", function(_, event)
    if RECOVERY_EVENTS[event] then
        if container and IsEnabled() then
            -- Hide on the event, repair on the next tick. Deferring the hide too
            -- reads as a visible flash of the full buff set.
            ApplyVisibility()
            ScheduleRecovery()
        end
        return
    end
    -- PLAYER_ENTERING_WORLD doubles as first-run creation: the profile is seeded by
    -- then, and creating out of combat keeps the initial styling out of the deferred path.
    if event == "PLAYER_ENTERING_WORLD" or (applyPending and IsEnabled()) then
        -- A loading screen can land mid-transition (teleported out of a vehicle) with
        -- no later edge guaranteed. Refresh arms the settle watch when it suppresses,
        -- so this doubles as the safety net for a missed exit.
        Refresh()
    end
end)

-- Anchor assignment happens in the shared mover coordinate popup, the same place
-- every category is anchored from. This display keeps its own settings table, so
-- the popup drives it through these calls instead of writing categorySettings.
BR.Movers.RegisterTarget(MOVER_KEY, {
    -- Live coordinates, not the stored ones: a save that predates the anchor option
    -- holds offsets from whatever screen point the drag left behind, and the popup
    -- writes center-relative ones. Reading the frame keeps both in the same space.
    GetPosition = function()
        if anchorFrame then
            local x, y = ComputeCoords()
            if x then
                return { x = x, y = y }
            end
        end
        return Settings().position or BR.defaults.externals.position
    end,
    SetPosition = function(x, y)
        Settings().position = { point = "CENTER", x = x, y = y }
        if anchorFrame then
            ApplyPosition()
        end
    end,
    GetAnchor = function()
        local settings = Settings()
        return settings.anchorFrame, settings.anchorPoint
    end,
    SetAnchorFrame = function(name)
        Settings().anchorFrame = name
    end,
    SetAnchorPoint = function(point)
        Settings().anchorPoint = point
        if anchorFrame then
            ApplyPosition()
        end
    end,
    UpdateLabel = UpdateMoverCaption,
})

BR.CallbackRegistry:RegisterCallback("ExternalsRefresh", Refresh)
-- The duration text uses the addon's global font face and outline, which live under
-- `defaults` and fire VisualsRefresh. A change to them must restyle these buttons
-- too. Refresh does nothing while the display is disabled.
BR.CallbackRegistry:RegisterCallback("VisualsRefresh", Refresh)

BR.AuraTracker = {
    Refresh = Refresh,
    SetUnlocked = SetUnlocked,
    SetTestMode = SetTestMode,
    BuildSpellIDMap = BuildSpellIDMap,
    ---True when a reconfigure was denied and waits for a restriction lift.
    IsApplyPending = function()
        return applyPending
    end,
}
