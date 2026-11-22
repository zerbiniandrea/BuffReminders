local _, ns = ...
---@class BR
local BR = ns

-- Every factory paints from BR.Theme through the shared surface helpers.
local Theme = BR.Theme
local CLEAR = BR.THEME_CLEAR
local CreateSurface = BR.CreateSurface
local PaintSurface = BR.PaintSurface
local PaintStyled = BR.PaintStyled
local CreateRing = BR.CreateRing
local PaintRing = BR.PaintRing
local PaintGradient = BR.PaintGradient
local SetTextColor = BR.SetThemeTextColor
local SetColorTexture = BR.SetThemeColorTexture

---@param isEnabled boolean
---@param isPressed boolean
---@param isHovered boolean
---@return "normal"|"hover"|"pressed"|"disabled"
local function PressState(isEnabled, isPressed, isHovered)
    if not isEnabled then
        return "disabled"
    elseif isPressed then
        return "pressed"
    elseif isHovered then
        return "hover"
    end
    return "normal"
end

---@param label table FontString
---@param enabled boolean
local function SetLabelEnabled(label, enabled)
    SetTextColor(label, enabled and Theme.text or Theme.textDisabled)
end

-- ============================================================================
-- UI COMPONENT FACTORY
-- ============================================================================
-- Reusable UI components for the options panel

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@class ScrollableContainerConfig
---@field contentHeight? number Initial content height (default 600)
---@field scrollbarWidth? number Width reserved for scrollbar (default 24)
---@field width? number Explicit scroll-frame width. Required when nesting inside a parent larger than the scroll area (otherwise contentWidth is derived from parent:GetWidth() and overflows).

---@class VerticalLayoutConfig
---@field x? number Starting X position (default 0)
---@field y? number Starting Y position (default 0)

---@class ToggleConfig
---@field disabledReason? string|fun(): string Shown on hover while the control is disabled
---@field label string
---@field checked? boolean
---@field get? fun(): boolean
---@field enabled? fun(): boolean
---@field onChange fun(checked: boolean)
---@field tooltip? TooltipText
---@field holderWidth? number Override for the holder width (default 200)
---@field labelWidth? number Cap label width and truncate beyond it

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local tinsert = table.insert

local L = BR.L
local Components = BR.Components
local RefreshableComponents = BR.RefreshableComponents

-- ============================================================================
-- TEXT MEASUREMENT
-- ============================================================================
-- Single hidden FontString reused for measuring text dimensions so widgets
-- can size themselves to their content. This is what makes the panel survive
-- font replacers / locale builds with longer strings.
--
-- Calls must be synchronous: each Measure* call configures and reads the
-- shared FontString within one function call. Do NOT save the FontString or
-- defer reads across event boundaries - the next caller will overwrite it.

local _measurer
local _measureFS
local function PrepareMeasurer(text, fontObject, width)
    if not _measurer then
        _measurer = CreateFrame("Frame", nil, UIParent)
        _measurer:Hide()
        _measureFS = _measurer:CreateFontString(nil, "BACKGROUND")
    end
    _measureFS:SetFontObject(fontObject or "GameFontHighlightSmall")
    -- SetWidth gates whether GetStringHeight reports wrapped or single-line
    -- height; pass 0 (or omit) for natural single-line measurement.
    _measureFS:SetWidth(width or 0)
    _measureFS:SetText(text)
end

local function MeasureTextWidth(text, fontObject)
    if not text or text == "" then
        return 0
    end
    PrepareMeasurer(text, fontObject)
    return ceil(_measureFS:GetStringWidth())
end

local function MeasureTextHeight(text, fontObject)
    if not text or text == "" then
        return 0
    end
    PrepareMeasurer(text, fontObject)
    return ceil(_measureFS:GetStringHeight())
end

local function MeasureWrappedHeight(text, fontObject, width)
    if not text or text == "" or not width or width <= 0 then
        return 0
    end
    PrepareMeasurer(text, fontObject, width)
    return ceil(_measureFS:GetStringHeight())
end

---Compute a shared label width for a group of widgets that need to align
---vertically. Pass each widget's label text and the result as labelWidth so
---the column boundary is identical across the group.
---@param labels string[] List of label strings
---@param fontObject? string|table Font object (default "GameFontHighlightSmall")
---@param minWidth? number Floor for the returned width (default 70)
---@return number
function Components.MeasureSharedLabelWidth(labels, fontObject, minWidth)
    local w = minWidth or 70
    for _, t in ipairs(labels) do
        local m = MeasureTextWidth(t, fontObject) + 4
        if m > w then
            w = m
        end
    end
    return w
end

-- ============================================================================
-- TOOLTIP UTILITIES
-- ============================================================================

-- With Theme.ownTooltip, the options UI shows its own tooltip frame in the theme
-- colors. GameTooltip is shared with the game and every addon, so the addon never
-- restyles it. Frames outside the options UI keep GameTooltip.
local OWN_TOOLTIP_MAX_WIDTH = 260
local OWN_TOOLTIP_PAD = 8
local OWN_TOOLTIP_ANCHORS = {
    ANCHOR_TOP = { "BOTTOM", "TOP", 0, 4 },
    ANCHOR_BOTTOM = { "TOP", "BOTTOM", 0, -4 },
    ANCHOR_LEFT = { "BOTTOMRIGHT", "TOPLEFT", 0, 0 },
    ANCHOR_RIGHT = { "BOTTOMLEFT", "TOPRIGHT", 0, 0 },
}
local ownTooltip
local GAME_TOOLTIP_TITLE = { 1, 1, 1 }
local GAME_TOOLTIP_DESC = { 0.7, 0.7, 0.7 }

---True when the frame sits inside a panel or drawer of the options UI.
---@param frame table
---@return boolean
local function IsOnOptionsSurface(frame)
    while frame do
        if frame._br_optionsSurface then
            return true
        end
        frame = frame:GetParent()
    end
    return false
end

local function ShowOwnTooltip(owner, title, desc, anchor)
    if not ownTooltip then
        local style = Theme.tooltip
        ownTooltip = CreateFrame("Frame", nil, UIParent)
        ownTooltip:SetFrameStrata("TOOLTIP")
        ownTooltip:SetClampedToScreen(true)
        PaintSurface(CreateSurface(ownTooltip), style)
        ownTooltip.title = ownTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ownTooltip.title:SetPoint("TOPLEFT", OWN_TOOLTIP_PAD, -OWN_TOOLTIP_PAD)
        ownTooltip.title:SetJustifyH("LEFT")
        SetTextColor(ownTooltip.title, style.title)
        ownTooltip.desc = ownTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ownTooltip.desc:SetPoint("TOPLEFT", ownTooltip.title, "BOTTOMLEFT", 0, -4)
        ownTooltip.desc:SetJustifyH("LEFT")
        ownTooltip.desc:SetWordWrap(true)
        SetTextColor(ownTooltip.desc, style.desc)
        -- A hidden owner sends no OnLeave. OnUpdate runs only while the tooltip shows.
        ownTooltip:SetScript("OnUpdate", function(self)
            local tipOwner = self.owner
            if not tipOwner or not tipOwner:IsVisible() then
                self:Hide()
            end
        end)
        ownTooltip:SetScript("OnHide", function(self)
            self.owner = nil
        end)
    end
    local tip = ownTooltip
    tip.owner = owner
    tip.title:SetWidth(0)
    tip.title:SetText(title)
    local width = min(ceil(tip.title:GetStringWidth()), OWN_TOOLTIP_MAX_WIDTH)
    tip.title:SetWidth(width)
    local height = ceil(tip.title:GetStringHeight())
    if desc then
        tip.desc:SetWidth(0)
        tip.desc:SetText(desc)
        width = max(width, min(ceil(tip.desc:GetStringWidth()), OWN_TOOLTIP_MAX_WIDTH))
        tip.title:SetWidth(width)
        tip.desc:SetWidth(width)
        tip.desc:Show()
        height = ceil(tip.title:GetStringHeight()) + 4 + ceil(tip.desc:GetStringHeight())
    else
        tip.desc:Hide()
    end
    tip:SetSize(width + OWN_TOOLTIP_PAD * 2, height + OWN_TOOLTIP_PAD * 2)
    local spec = OWN_TOOLTIP_ANCHORS[anchor or "ANCHOR_RIGHT"] or OWN_TOOLTIP_ANCHORS.ANCHOR_RIGHT
    tip:ClearAllPoints()
    tip:SetPoint(spec[1], owner, spec[2], spec[3], spec[4])
    tip:Show()
end

---Show a tooltip on a widget (title in white, optional description in grey)
---@param owner table Frame that owns the tooltip
---@param title string Tooltip title
---@param desc? string Optional description line
---@param anchor? string Anchor point (default "ANCHOR_RIGHT")
---@param titled? boolean GameTooltip shows the title in the title color and the description in the text color
local function ShowTooltip(owner, title, desc, anchor, titled)
    if Theme.ownTooltip and IsOnOptionsSurface(owner) then
        ShowOwnTooltip(owner, title, desc, anchor)
        return
    end
    local titleColor = titled and Theme.title or GAME_TOOLTIP_TITLE
    local descColor = titled and Theme.text or GAME_TOOLTIP_DESC
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(title, titleColor[1], titleColor[2], titleColor[3])
    if desc then
        GameTooltip:AddLine(desc, descColor[1], descColor[2], descColor[3], true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    if ownTooltip then
        ownTooltip:Hide()
    end
    GameTooltip:Hide()
end

---Setup tooltip on a widget using SetScript (replaces existing OnEnter/OnLeave)
local function SetupTooltip(widget, tooltipTitle, tooltipDesc, anchor)
    widget:SetScript("OnEnter", function(self)
        ShowTooltip(self, tooltipTitle, tooltipDesc, anchor)
    end)
    widget:SetScript("OnLeave", HideTooltip)
end

---Setup tooltip on a widget using HookScript (chains with existing OnEnter/OnLeave)
local function HookTooltip(widget, tooltipTitle, tooltipDesc, anchor)
    widget:HookScript("OnEnter", function(self)
        ShowTooltip(self, tooltipTitle, tooltipDesc, anchor)
    end)
    widget:HookScript("OnLeave", HideTooltip)
end

BR.ShowTooltip = ShowTooltip
BR.HideTooltip = HideTooltip

---Hide the tooltip of an options control. A GameTooltip that another frame owns stays.
function BR.HideOptionsTooltip()
    if ownTooltip then
        ownTooltip:Hide()
    end
    if IsOnOptionsSurface(GameTooltip:GetOwner()) then
        GameTooltip:Hide()
    end
end
BR.SetupTooltip = SetupTooltip
BR.HookTooltip = HookTooltip

---Resolve a disabled-reason value: reasons can be static strings or getters
---(for messages that depend on current state).
---@param reason string|fun(): string
---@return string
local function ResolveDisabledReason(reason)
    if type(reason) == "function" then
        return reason()
    end
    return reason
end

---Attach an explanatory hover tooltip that appears only while a control is
---disabled, telling the user WHY it is disabled and where to change that.
---Disabled controls must never be mute: a greyed-out widget with no reason
---reads as broken. Pass the same predicate that drives the control's
---`enabled` state.
---@param holder table Component holder frame (hover target)
---@param isEnabledFn fun(): boolean Predicate driving the control's enabled state
---@param reason string|fun(): string Why the control is disabled and how to enable it
function Components.AttachDisabledReason(holder, isEnabledFn, reason)
    -- Always anchored to the holder, so the tooltip does not move while the
    -- cursor crosses the parts of the control.
    local reasonShown = false
    local function showReason()
        if isEnabledFn() then
            return
        end
        ShowTooltip(holder, L["Component.DisabledReason.Title"], ResolveDisabledReason(reason), "ANCHOR_TOP")
        reasonShown = true
    end
    -- The control can turn enabled while the reason shows, so the hide does not ask isEnabledFn.
    local function hideReason()
        if reasonShown then
            reasonShown = false
            HideTooltip()
        end
    end

    holder:EnableMouse(true)
    holder:HookScript("OnEnter", showReason)
    holder:HookScript("OnLeave", hideReason)

    -- A part that takes the mouse (a value box, a slider thumb, a label with its
    -- own tooltip) hides the holder from the cursor. Its own tooltip runs first,
    -- then this hook replaces it with the reason while the control is disabled.
    local function hookParts(frame)
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:IsMouseEnabled() then
                child:HookScript("OnEnter", showReason)
                child:HookScript("OnLeave", hideReason)
            end
            hookParts(child)
        end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsMouseEnabled and region.HookScript and region:IsMouseEnabled() then
                region:HookScript("OnEnter", showReason)
                region:HookScript("OnLeave", hideReason)
            end
        end
    end
    hookParts(holder)
end

-- ============================================================================
-- BUTTON
-- ============================================================================

---Create a button that paints its normal, hover, pressed and disabled states
---@param parent Frame
---@param text string
---@param onClick? function
---@param tooltip? TooltipText Optional tooltip configuration
---@param styles? table<string, ThemeStyle> State styles (default Theme.button)
---@return table
function BR.CreateButton(parent, text, onClick, tooltip, styles)
    styles = styles or Theme.button

    local btn = CreateFrame("Button", nil, parent)
    local surface = CreateSurface(btn)
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("CENTER", 0, 0)
    btnText:SetText(text)
    btn.text = btnText

    local textWidth = btnText:GetStringWidth()
    btn:SetSize(max(textWidth + 16, 60), 22)

    local isEnabled = true
    local isPressed = false
    local isHovered = false

    local function UpdateVisual()
        PaintStyled(surface, btnText, styles[PressState(isEnabled, isPressed, isHovered)])
    end

    UpdateVisual()

    btn:SetScript("OnEnter", function()
        isHovered = true
        UpdateVisual()
        if not isEnabled and btn._disabledReason then
            ShowTooltip(
                btn,
                L["Component.DisabledReason.Title"],
                ResolveDisabledReason(btn._disabledReason),
                "ANCHOR_TOP"
            )
        elseif tooltip then
            ShowTooltip(btn, tooltip.title, tooltip.desc, "ANCHOR_TOP")
        end
    end)

    btn:SetScript("OnLeave", function()
        isHovered = false
        isPressed = false
        UpdateVisual()
        if tooltip or btn._disabledReason then
            HideTooltip()
        end
    end)

    btn:SetScript("OnMouseDown", function()
        if isEnabled then
            isPressed = true
            UpdateVisual()
        end
    end)

    btn:SetScript("OnMouseUp", function()
        isPressed = false
        UpdateVisual()
    end)

    -- A click can hide the button under the cursor, and then OnLeave does not fire.
    btn:HookScript("OnHide", function()
        isHovered, isPressed = false, false
        UpdateVisual()
    end)

    btn:SetScript("OnClick", function()
        if isEnabled and onClick then
            onClick(btn)
        end
    end)

    function btn:SetText(newText)
        btnText:SetText(newText)
        local newWidth = btnText:GetStringWidth()
        self:SetSize(max(newWidth + 16, 60), 22)
    end

    function btn:GetText()
        return btnText:GetText()
    end

    function btn:SetEnabled(enabled)
        isEnabled = enabled
        if enabled then
            self:Enable()
        else
            self:Disable()
        end
        -- A disabled button can miss OnLeave, so the hover and press flags can go stale.
        isHovered = enabled and self:IsMouseOver()
        isPressed = isPressed and isHovered
        UpdateVisual()
    end

    -- Disabled buttons explain themselves on hover. Requires motion scripts
    -- while disabled: Button:Disable() otherwise stops OnEnter from firing.
    ---@param reason string|fun(): string Why the button is disabled and how to enable it
    function btn:SetDisabledReason(reason)
        btn._disabledReason = reason
        btn:SetMotionScriptsWhileDisabled(true)
    end

    -- Opt this button into the OnShow refresh pattern: enabledFn is re-evaluated
    -- by Components.RefreshAll() and applied via :SetEnabled. Use this instead
    -- of imperative :SetEnabled cascades hooked to other widgets' OnClick.
    function btn:BindEnabled(enabledFn)
        btn._enabledGetter = enabledFn
        btn:SetEnabled(enabledFn() and true or false)
        if not btn._registeredForRefresh then
            btn._registeredForRefresh = true
            tinsert(RefreshableComponents, btn)
        end
    end

    function btn:Refresh()
        if btn._enabledGetter then
            btn:SetEnabled(btn._enabledGetter() and true or false)
        end
    end

    return btn
end

---@class ComponentConfig
---@field disabledReason? string|fun(): string Shown on hover while the control is disabled: why, and where to change it
---@field inherited? fun(): boolean True while the value follows the Defaults page: a disabled control keeps the value readable
---@class SliderConfig : ComponentConfig
---@field label string Display label for the slider
---@field min number Minimum value
---@field max number Maximum value
---@field step? number Step increment (default 1)
---@field value? number Initial value (deprecated: prefer get)
---@field get? fun(): number Getter for initial value and refresh (preferred over value)
---@field enabled? fun(): boolean Getter for enabled state, evaluated on Refresh()
---@field suffix? string Value suffix (e.g., "px", "%")
---@field formatValue? fun(val: number): string Custom value formatter (overrides suffix)
---@field onChange fun(val: number) Callback when value changes
---@field tooltip? TooltipText Tooltip shown on hover
---@field labelWidth? number Width of label (default 70)
---@field sliderWidth? number Width of slider (default 100)

---@class DirectionButtonsConfig : ComponentConfig
---@field label? string Optional label (default "Direction:")
---@field selected? string Initial direction (deprecated: prefer get)
---@field get? fun(): string Getter for initial value and refresh (preferred over selected)
---@field enabled? fun(): boolean Getter for enabled state, evaluated on Refresh()
---@field onChange fun(dir: string) Callback when direction changes
---@field width? number Dropdown width (default 90)
---@field labelWidth? number Label width (default 70)

local panelEditBoxes = nil ---@type table[]?

---Paint an edit box container from Theme.editBox, with hover, focus and disabled
---states. Adds container:SetBoxEnabled(enabled) and container:SetBoxTextColor(color).
---@param container table
---@param editBox table
local function DecorateEditBox(container, editBox)
    local styles = Theme.editBox
    local surface = CreateSurface(container)
    local ring = CreateRing(container, "BACKGROUND", -4, 1, true)
    local isHovered, isFocused, isEnabled = false, false, true
    local textColor

    local function Paint()
        local style = styles.normal
        if not isEnabled then
            style = styles.disabled
        elseif isFocused then
            style = styles.focus
        elseif isHovered then
            style = styles.hover
        end
        PaintSurface(surface, style)
        PaintRing(ring, style.ring)
        local text = isEnabled and textColor or style.text --[[@as number[] ]]
        SetTextColor(editBox, text)
    end

    editBox:HookScript("OnEnter", function()
        isHovered = true
        Paint()
    end)
    editBox:HookScript("OnLeave", function()
        isHovered = false
        Paint()
    end)
    editBox:HookScript("OnEditFocusGained", function()
        isFocused = true
        Paint()
    end)
    editBox:HookScript("OnEditFocusLost", function()
        isFocused = false
        Paint()
    end)
    local cursor = styles.cursor
    if cursor and editBox.SetCursorColor then
        editBox:SetCursorColor(cursor[1], cursor[2], cursor[3])
    end

    function container:SetBoxEnabled(enabled)
        isEnabled = enabled
        Paint()
    end
    function container:SetBoxTextColor(color)
        textColor = color
        Paint()
    end
    Paint()
end

---Wrap an EditBox in a themed container. Caller must set size and position on the returned container.
---@param editBox table The EditBox to style
---@return table container
local function StyleEditBox(editBox)
    local container = CreateFrame("Frame", nil, editBox:GetParent())
    editBox:SetParent(container)
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", 4, -2)
    editBox:SetPoint("BOTTOMRIGHT", -4, 2)
    DecorateEditBox(container, editBox)
    editBox:HookScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return container
end

BR.StyleEditBox = StyleEditBox

---Add the track edge, track shade, fill line and knob of the theme to a slider.
---The track, fill and thumb textures keep their anchors, so the thumb position
---math does not change.
---@return fun(state: "normal"|"hover"|"drag"|"disabled") paint
local function DecorateSlider(trackBg, trackFill, thumbTex)
    local trackEdge = trackBg:GetParent():CreateTexture(nil, "BACKGROUND", nil, -1)
    trackEdge:SetPoint("TOPLEFT", trackBg, "TOPLEFT", -1, 1)
    trackEdge:SetPoint("BOTTOMRIGHT", trackBg, "BOTTOMRIGHT", 1, -1)
    local trackShade = trackBg:GetParent():CreateTexture(nil, "BACKGROUND", nil, 1)
    trackShade:SetPoint("TOPLEFT", trackBg, "TOPLEFT", 0, 0)
    trackShade:SetPoint("TOPRIGHT", trackBg, "TOPRIGHT", 0, 0)
    trackShade:SetHeight(1)

    local fillLine = trackFill:GetParent():CreateTexture(nil, "ARTWORK", nil, 1)
    fillLine:SetPoint("TOPLEFT", trackFill, "TOPLEFT", 0, 0)
    fillLine:SetPoint("TOPRIGHT", trackFill, "TOPRIGHT", 0, 0)
    fillLine:SetHeight(1)

    local knob = thumbTex:GetParent():CreateTexture(nil, "OVERLAY", nil, 1)
    knob:SetPoint("TOPLEFT", 1, -1)
    knob:SetPoint("BOTTOMRIGHT", -1, 1)

    return function(state)
        local s = Theme.slider[state]
        SetColorTexture(trackEdge, s.trackEdge)
        PaintGradient(trackBg, "VERTICAL", s.trackBottom, s.trackTop)
        SetColorTexture(trackShade, s.trackShade)
        PaintGradient(trackFill, "HORIZONTAL", s.fillLeft, s.fillRight)
        SetColorTexture(fillLine, s.fillLine)
        SetColorTexture(thumbTex, s.thumb)
        PaintGradient(knob, "VERTICAL", s.knobBottom, s.knobTop)
    end
end

---Create a modern flat-style slider with thin track and small thumb
---@param parent table Parent frame
---@param config SliderConfig Configuration table
---@return table holder Frame containing slider with .slider, .valueText, .SetValue(v), .GetValue()
function Components.Slider(parent, config)
    local sliderWidth = config.sliderWidth or 100
    local step = config.step or 1
    local suffix = config.suffix or ""
    local formatValue = config.formatValue
    local function displayText(val)
        if formatValue then
            return formatValue(val)
        end
        return floor(val) .. suffix
    end
    local TRACK_HEIGHT = 4
    local THUMB_WIDTH = 8
    local THUMB_HEIGHT = 14

    -- Label width: explicit labelWidth is treated as a HARD target so columns
    -- of sliders stay aligned (label clips/extends past the boundary if too
    -- long; the caller is responsible for picking a value that fits - see
    -- AppearanceGrid for the measurement-based pattern). Omitting labelWidth
    -- falls back to auto-grow for ad-hoc usage.
    local labelWidth
    if config.labelWidth ~= nil then
        labelWidth = config.labelWidth
    elseif config.label then
        labelWidth = max(70, MeasureTextWidth(config.label, "GameFontHighlightSmall") + 4)
    else
        labelWidth = 0
    end

    -- Auto-grow value box: measure widest displayText(min..max). Without this,
    -- 4-digit numbers or "%" strings overflow the 40-wide button at bigger fonts.
    local minValW = MeasureTextWidth(displayText(config.min or 0), "GameFontHighlightSmall")
    local maxValW = MeasureTextWidth(displayText(config.max or 0), "GameFontHighlightSmall")
    local valueWidth = max(40, max(minValW, maxValW) + 8)

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + sliderWidth + valueWidth + 12, 20)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    if config.label then
        label:SetText(config.label)
    end
    holder.label = label
    SetTextColor(label, Theme.text)

    local sliderFrame = CreateFrame("Frame", nil, holder)
    sliderFrame:SetPoint("LEFT", label, "RIGHT", 5, 0)
    sliderFrame:SetSize(sliderWidth, 16)
    holder.slider = sliderFrame

    local trackBg = sliderFrame:CreateTexture(nil, "BACKGROUND")
    trackBg:SetHeight(TRACK_HEIGHT)
    trackBg:SetPoint("LEFT", 0, 0)
    trackBg:SetPoint("RIGHT", 0, 0)
    sliderFrame.trackBg = trackBg

    local trackFill = sliderFrame:CreateTexture(nil, "ARTWORK")
    trackFill:SetHeight(TRACK_HEIGHT)
    trackFill:SetPoint("LEFT", trackBg, "LEFT", 0, 0)
    sliderFrame.trackFill = trackFill

    local thumb = CreateFrame("Button", nil, sliderFrame)
    thumb:SetSize(THUMB_WIDTH, THUMB_HEIGHT)
    thumb:SetPoint("CENTER", trackBg, "LEFT", 0, 0)

    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumb.tex = thumbTex

    local currentValue = config.get and config.get() or config.value or config.min
    local isEnabled = true
    local isDragging = false
    local isThumbHovered = false

    local paintSlider = DecorateSlider(trackBg, trackFill, thumbTex)
    local valueColor = Theme.text

    -- Clickable value display button (declared early for event handlers)
    local valueBtn = CreateFrame("Button", nil, holder)
    valueBtn:SetPoint("LEFT", sliderFrame, "RIGHT", 6, 0)
    valueBtn:SetSize(valueWidth, 16)

    local valueText = valueBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetAllPoints()
    valueText:SetWordWrap(false)
    valueText:SetJustifyH("LEFT")
    valueText:SetText(displayText(currentValue))
    holder.valueText = valueText

    local function ValueToPosition(val)
        local range = config.max - config.min
        if range == 0 then
            return 0
        end
        local pct = (val - config.min) / range
        return pct * (sliderWidth - THUMB_WIDTH)
    end

    local function PositionToValue(pos)
        local pct = pos / (sliderWidth - THUMB_WIDTH)
        pct = max(0, min(1, pct))
        local val = config.min + pct * (config.max - config.min)
        -- Snap to nearest multiple of step (aligned to 0, not min)
        val = floor(val / step + 0.5) * step
        return max(config.min, min(config.max, val))
    end

    local function UpdateThumbPosition()
        local pos = ValueToPosition(currentValue)
        thumb:SetPoint("CENTER", trackBg, "LEFT", pos + THUMB_WIDTH / 2, 0)
        trackFill:SetWidth(max(1, pos + THUMB_WIDTH / 2))
    end

    local function UpdateVisual()
        local state = "normal"
        if not isEnabled then
            state = "disabled"
        elseif isDragging then
            state = "drag"
        elseif isThumbHovered then
            state = "hover"
        end
        paintSlider(state)
        SetTextColor(valueText, isEnabled and isDragging and Theme.slider.valueDrag or valueColor)
        UpdateThumbPosition()
    end

    thumb:SetScript("OnEnter", function()
        isThumbHovered = true
        UpdateVisual()
    end)

    thumb:SetScript("OnLeave", function()
        isThumbHovered = false
        UpdateVisual()
    end)

    thumb:SetScript("OnMouseDown", function()
        if isEnabled then
            isDragging = true
            UpdateVisual()
        end
    end)

    thumb:SetScript("OnMouseUp", function()
        isDragging = false
        UpdateVisual()
    end)

    sliderFrame:SetScript("OnUpdate", function()
        if isDragging and isEnabled then
            local mouseX = GetCursorPosition()
            local scale = sliderFrame:GetEffectiveScale()
            local frameLeft = sliderFrame:GetLeft() * scale
            local localX = (mouseX - frameLeft) / scale - THUMB_WIDTH / 2
            local newVal = PositionToValue(localX)
            if newVal ~= currentValue then
                currentValue = newVal
                valueText:SetText(displayText(currentValue))
                UpdateThumbPosition()
                config.onChange(floor(currentValue))
            end
        end
    end)

    sliderFrame:EnableMouse(true)
    sliderFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and isEnabled then
            local mouseX = GetCursorPosition()
            local scale = sliderFrame:GetEffectiveScale()
            local frameLeft = sliderFrame:GetLeft() * scale
            local localX = (mouseX - frameLeft) / scale - THUMB_WIDTH / 2
            local newVal = PositionToValue(localX)
            currentValue = newVal
            valueText:SetText(displayText(currentValue))
            isDragging = true
            UpdateVisual()
            config.onChange(floor(currentValue))
        end
    end)

    sliderFrame:SetScript("OnMouseUp", function()
        isDragging = false
        UpdateVisual()
    end)

    local editBox = CreateFrame("EditBox", nil, holder)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetAutoFocus(false)
    local editContainer = StyleEditBox(editBox)
    editContainer:SetSize(max(35, valueWidth), 16)
    editContainer:SetPoint("LEFT", sliderFrame, "RIGHT", 6, 0)
    editContainer:Hide()

    editBox:SetScript("OnEnterPressed", function(self)
        local num = tonumber(self:GetText())
        if num then
            num = max(config.min, min(config.max, num))
            currentValue = num
            valueText:SetText(displayText(currentValue))
            UpdateVisual()
            config.onChange(floor(currentValue))
        end
        editContainer:Hide()
        valueBtn:Show()
    end)

    editBox:HookScript("OnEscapePressed", function()
        editContainer:Hide()
        valueBtn:Show()
    end)

    editBox:HookScript("OnEditFocusLost", function()
        editContainer:Hide()
        valueBtn:Show()
    end)

    -- Track editbox for focus cleanup on panel hide
    if panelEditBoxes then
        tinsert(panelEditBoxes, editBox)
    end

    valueBtn:SetScript("OnClick", function()
        valueBtn:Hide()
        editBox:SetText(tostring(floor(currentValue)))
        editContainer:Show()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    SetupTooltip(valueBtn, L["Component.AdjustValue"], L["Component.AdjustValue.ClickHint"], "ANCHOR_TOP")

    -- Hover tooltip (on all interactive children, chained with existing scripts)
    local clickHint = L["Component.AdjustValue.ClickHint"]
    if config.tooltip then
        local title = config.tooltip.title
        local desc = config.tooltip.desc
        local fullDesc = desc and (desc .. "\n\n" .. clickHint) or clickHint
        holder:EnableMouse(true)
        local function showTip()
            ShowTooltip(holder, title, fullDesc, "ANCHOR_TOP")
        end
        local function hideTip()
            HideTooltip()
        end
        holder:HookScript("OnEnter", showTip)
        holder:HookScript("OnLeave", hideTip)
        thumb:HookScript("OnEnter", showTip)
        thumb:HookScript("OnLeave", hideTip)
        sliderFrame:HookScript("OnEnter", showTip)
        sliderFrame:HookScript("OnLeave", hideTip)
        valueBtn:HookScript("OnEnter", showTip)
        valueBtn:HookScript("OnLeave", hideTip)
    else
        local function showHint()
            ShowTooltip(holder, L["Component.AdjustValue"], clickHint, "ANCHOR_TOP")
        end
        thumb:HookScript("OnEnter", showHint)
        thumb:HookScript("OnLeave", HideTooltip)
        sliderFrame:SetScript("OnEnter", showHint)
        sliderFrame:SetScript("OnLeave", HideTooltip)
    end

    UpdateVisual()

    function holder:SetValue(val)
        currentValue = val
        valueText:SetText(displayText(currentValue))
        UpdateVisual()
    end

    function holder:GetValue()
        return currentValue
    end

    function holder:SetEnabled(enabled)
        isEnabled = enabled
        SetLabelEnabled(label, enabled)
        -- An inherited value is real and applies, so it stays readable.
        local readable = enabled or (config.inherited and config.inherited())
        valueColor = readable and Theme.text or Theme.textDisabled
        UpdateVisual()
    end

    -- Refresh method for OnShow pattern (re-reads value and enabled state from DB)
    function holder:Refresh()
        if config.get then
            currentValue = config.get()
            valueText:SetText(displayText(currentValue))
            UpdateVisual()
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

---Create the core checkbox button frame (reusable by Checkbox component)
---@param parent table Parent frame
---@param initialChecked boolean Initial checked state
---@param onChange fun(checked: boolean) Callback when state changes
---@return table cb Checkbox button with .SetChecked(v), .GetChecked(), .SetHovered(v), .SetEnabled(v)
local function CreateCheckboxCore(parent, initialChecked, onChange)
    local styles = Theme.checkbox
    local CHECKBOX_SIZE = 16 -- Match icon size for alignment

    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    local surface = CreateSurface(cb)

    local checkmark = cb:CreateTexture(nil, "ARTWORK")
    checkmark:SetPoint("CENTER", 0, 0)
    checkmark:SetSize(CHECKBOX_SIZE + 4, CHECKBOX_SIZE + 4)
    checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkmark:Hide()
    cb.checkmark = checkmark

    local isChecked = initialChecked or false
    local isEnabled = true
    local isHovered = false

    local function UpdateVisual()
        local style
        if not isEnabled then
            style = isChecked and styles.disabledChecked or styles.disabled
        elseif isChecked then
            style = isHovered and styles.checkedHover or styles.checked
        else
            style = isHovered and styles.hover or styles.normal
        end
        PaintSurface(surface, style)
        local mark = style.mark --[[@as number[] ]]
        checkmark:SetVertexColor(mark[1], mark[2], mark[3], mark[4] or 1)
        checkmark:SetShown(isChecked)
    end

    cb:SetScript("OnEnter", function()
        isHovered = true
        UpdateVisual()
    end)

    cb:SetScript("OnLeave", function()
        isHovered = false
        UpdateVisual()
    end)

    cb:SetScript("OnClick", function()
        if isEnabled then
            isChecked = not isChecked
            UpdateVisual()
            if onChange then
                onChange(isChecked)
            end
        end
    end)

    function cb:SetChecked(checked)
        isChecked = checked
        UpdateVisual()
    end

    function cb:GetChecked()
        return isChecked
    end

    function cb:SetHovered(hovered)
        isHovered = hovered
        UpdateVisual()
    end

    function cb:SetEnabled(enabled)
        isEnabled = enabled
        UpdateVisual()
    end

    function cb:IsEnabled()
        return isEnabled
    end

    UpdateVisual()
    return cb
end

---@class CheckboxConfig : ComponentConfig
---@field label string Display label
---@field checked? boolean Initial checked state (deprecated: prefer get)
---@field get? fun(): boolean Getter for initial value and refresh (preferred over checked)
---@field enabled? fun(): boolean Getter for enabled state, evaluated on Refresh()
---@field tooltip? TooltipText Tooltip shown on hover
---@field onChange fun(checked: boolean) Callback when checked state changes
---@field icons? number[] Optional texture ID(s) to show between checkbox and label
---@field infoTooltip? TooltipText Optional info icon tooltip
---@field warningTooltip? TooltipText Optional warning icon tooltip
---@field onRightClick? fun() Optional right-click callback (wired on all interactive children)
---@field labelFont? string Font object name for the label (default "GameFontHighlightSmall")
---@field holderWidth? number Override for the holder width (default 200)
---@field labelWidth? number Cap label width and truncate beyond it

---Create a modern flat-style checkbox with label and optional icons/tooltip
---@param parent table Parent frame
---@param config CheckboxConfig Configuration table
---@return table holder Frame containing checkbox with .checkbox, .SetChecked(v), .GetChecked()
function Components.Checkbox(parent, config)
    local initialChecked = config.get and config.get() or config.checked or false

    local CHECKBOX_W = 16
    local ICON_SIZE = 16 -- Match checkbox size
    local ICON_SPACING = 4
    local LABEL_LEAD = ICON_SPACING + 1 -- gap between last icon (or checkbox) and label
    local INFO_ICON_W = 14 -- info/warning icon shown after the label
    local INFO_ICON_GAP = 4
    local labelFont = config.labelFont or "GameFontHighlightSmall"

    -- Holder keeps a fixed size: callers anchor trailing icons to holder.right
    -- and need a constant column boundary across rows. Pass holderWidth to override.
    local holderWidth = config.holderWidth or 200
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(holderWidth, 20)

    local cb = CreateCheckboxCore(holder, initialChecked, config.onChange)
    cb:SetPoint("LEFT", 0, 0)
    holder.checkbox = cb

    local lastAnchor = cb
    local iconCount = 0
    if config.icons then
        local CreateBuffIcon = BR.CreateBuffIcon
        for _, textureID in ipairs(config.icons) do
            local icon = CreateBuffIcon(holder, ICON_SIZE, textureID)
            icon:SetPoint("LEFT", lastAnchor, "RIGHT", ICON_SPACING, 0)
            lastAnchor = icon
            iconCount = iconCount + 1
        end
    end

    -- Label. Free-flowing by default; pass labelWidth to cap (truncate) it
    -- when the caller needs predictable label/holder alignment in a list.
    local label = holder:CreateFontString(nil, "OVERLAY", labelFont)
    label:SetPoint("LEFT", lastAnchor, "RIGHT", LABEL_LEAD, 0)
    label:SetWordWrap(false)
    local labelLeftX = CHECKBOX_W + iconCount * (ICON_SPACING + ICON_SIZE) + LABEL_LEAD
    holder.labelOffset = labelLeftX -- exposed so callers can clamp against widgets anchored at holder.right
    -- x of the first icon's left edge (fixed regardless of icon count), so a
    -- caller can align a sub-row under the icon rather than under the label,
    -- which drifts right with 3-4 icon buffs.
    holder.iconOffset = CHECKBOX_W + ICON_SPACING
    if config.labelWidth ~= nil then
        -- Clamp so the label cannot extend past holder.right and overlap
        -- whatever the caller anchors there.
        local hasInfoIcon = config.infoTooltip or config.warningTooltip
        local trailing = hasInfoIcon and (INFO_ICON_GAP + INFO_ICON_W) or 0
        local maxLabelW = holderWidth - labelLeftX - trailing
        local labelWidth = max(0, min(config.labelWidth, maxLabelW))
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
    end
    label:SetText(config.label)
    holder.label = label
    SetTextColor(label, Theme.text)
    cb.label = label

    -- Hover tooltip (on all interactive children, chained with hover visuals)
    if config.tooltip then
        local title = config.tooltip.title
        local desc = config.tooltip.desc
        holder:EnableMouse(true)
        local function showTip()
            ShowTooltip(holder, title, desc, "ANCHOR_TOP")
        end
        local function hideTip()
            HideTooltip()
        end
        holder:HookScript("OnEnter", showTip)
        holder:HookScript("OnLeave", hideTip)
        cb:HookScript("OnEnter", showTip)
        cb:HookScript("OnLeave", hideTip)
    end

    local tooltipData = config.infoTooltip or config.warningTooltip
    if tooltipData then
        local infoIcon = holder:CreateTexture(nil, "ARTWORK")
        infoIcon:SetSize(14, 14)
        if config.warningTooltip then
            infoIcon:SetAtlas("services-icon-warning")
            infoIcon:SetPoint("LEFT", label, "RIGHT", 4, 0)
        else
            -- Custom atlases center differently than QuestNormal's "!"; nudge them
            -- down a touch so the glyph sits on the label's text row.
            local customAtlas = tooltipData.atlas
            infoIcon:SetAtlas(customAtlas or "QuestNormal")
            infoIcon:SetPoint("LEFT", label, "RIGHT", 4, customAtlas and -1 or 0)
        end

        local infoBtn = CreateFrame("Button", nil, holder)
        infoBtn:SetSize(14, 14)
        infoBtn:SetPoint("CENTER", infoIcon, "CENTER", 0, 0)

        SetupTooltip(infoBtn, tooltipData.title, tooltipData.desc)
        holder.infoIcon = infoIcon -- exposed so callers can anchor trailing widgets past it
    end

    -- Right-click callback (wired on all interactive children)
    if config.onRightClick then
        local function handleRightClick(_, button)
            if button == "RightButton" then
                config.onRightClick()
            end
        end
        holder:EnableMouse(true)
        holder:SetScript("OnMouseUp", handleRightClick)
        cb:HookScript("OnMouseUp", handleRightClick)
    end

    function holder:SetChecked(checked)
        cb:SetChecked(checked)
    end

    function holder:GetChecked()
        return cb:GetChecked()
    end

    function holder:SetEnabled(enabled)
        cb:SetEnabled(enabled)
        SetLabelEnabled(label, enabled)
    end

    -- Refresh method for OnShow pattern
    function holder:Refresh()
        if config.get then
            cb:SetChecked(config.get())
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- ============================================================================
-- DIMENSION LINK (chain toggle between Width/Height sliders)
-- ============================================================================

---@class DimensionLinkConfig
---@field isLinked fun(): boolean
---@field onLink fun()
---@field onUnlink fun()
---@field enabled? fun(): boolean

---Create a small link/unlink toggle button for pairing Width and Height sliders
---@param parent Frame
---@param config DimensionLinkConfig
---@return Frame
function Components.DimensionLink(parent, config)
    local colors = Theme.link
    local ICON_SIZE = 16
    local BAR_W = 2
    local BAR_H = 10
    local BRIDGE_W = 6
    local BRIDGE_H = 2
    local BREAK_OFFSET = 3 -- vertical offset for broken chain look

    local holder = CreateFrame("Button", nil, parent)
    holder:SetSize(ICON_SIZE, 20)

    -- Draw a chain/link icon: two vertical bars connected by horizontal bridges
    local leftBar = holder:CreateTexture(nil, "ARTWORK")
    leftBar:SetSize(BAR_W, BAR_H)

    local rightBar = holder:CreateTexture(nil, "ARTWORK")
    rightBar:SetSize(BAR_W, BAR_H)

    local topBridge = holder:CreateTexture(nil, "ARTWORK")
    topBridge:SetSize(BRIDGE_W, BRIDGE_H)

    local bottomBridge = holder:CreateTexture(nil, "ARTWORK")
    bottomBridge:SetSize(BRIDGE_W, BRIDGE_H)

    local allParts = { leftBar, rightBar, topBridge, bottomBridge }
    local isEnabled = true

    local function PositionParts(linked)
        leftBar:ClearAllPoints()
        rightBar:ClearAllPoints()
        topBridge:ClearAllPoints()
        bottomBridge:ClearAllPoints()
        if linked then
            leftBar:SetPoint("LEFT", holder, "CENTER", -BRIDGE_W / 2, 0)
            rightBar:SetPoint("RIGHT", holder, "CENTER", BRIDGE_W / 2, 0)
            topBridge:SetPoint("TOP", holder, "CENTER", 0, BAR_H / 2 - 1)
            bottomBridge:SetPoint("BOTTOM", holder, "CENTER", 0, -(BAR_H / 2 - 1))
        else
            leftBar:SetPoint("LEFT", holder, "CENTER", -BRIDGE_W / 2, BREAK_OFFSET)
            rightBar:SetPoint("RIGHT", holder, "CENTER", BRIDGE_W / 2, -BREAK_OFFSET)
            topBridge:SetPoint("TOP", holder, "CENTER", 0, BAR_H / 2 - 1)
            bottomBridge:SetPoint("BOTTOM", holder, "CENTER", 0, -(BAR_H / 2 - 1))
        end
    end

    local function UpdateVisual()
        local linked = config.isLinked()
        local color = isEnabled and (linked and colors.linked or colors.unlinked) or colors.disabled
        for _, part in ipairs(allParts) do
            part:SetColorTexture(unpack(color))
        end
        topBridge:SetShown(linked)
        bottomBridge:SetShown(linked)
        PositionParts(linked)
    end

    holder:SetScript("OnClick", function()
        if not isEnabled then
            return
        end
        if config.isLinked() then
            config.onUnlink()
        else
            config.onLink()
        end
        UpdateVisual()
    end)

    holder:SetScript("OnEnter", function()
        if isEnabled then
            local color = colors.hover
            for _, part in ipairs(allParts) do
                part:SetColorTexture(unpack(color))
            end
            local tipText = config.isLinked() and L["DimensionLink.Unlink"] or L["DimensionLink.Link"]
            ShowTooltip(holder, tipText, L["DimensionLink.Desc"], "ANCHOR_TOP")
        end
    end)

    holder:SetScript("OnLeave", function()
        HideTooltip()
        UpdateVisual()
    end)

    function holder:SetEnabled(enabled)
        isEnabled = enabled
        UpdateVisual()
    end

    function holder:Refresh()
        if config.enabled then
            isEnabled = config.enabled()
        end
        UpdateVisual()
    end

    tinsert(RefreshableComponents, holder)

    UpdateVisual()
    return holder
end

---@param parent Frame
---@param config ToggleConfig
---@return Frame
function Components.Toggle(parent, config)
    local checked
    if config.get then
        checked = config.get() and true or false
    else
        checked = config.checked or false
    end

    local TRACK_W = 32
    local LABEL_GAP = 6

    -- Holder defaults to a fixed 200 so callers can anchor neighbours to
    -- holder.right; pass holderWidth to override.
    local holderWidth = config.holderWidth or 200
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(holderWidth, 20)

    local track = CreateFrame("Button", nil, holder)
    track:SetSize(TRACK_W, 16)
    track:SetPoint("LEFT", 0, 0)
    local surface = CreateSurface(track)

    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 12)
    local knobSheen = track:CreateTexture(nil, "OVERLAY", nil, 1)
    knobSheen:SetPoint("TOPLEFT", thumb, "TOPLEFT", 0, 0)
    knobSheen:SetPoint("TOPRIGHT", thumb, "TOPRIGHT", 0, 0)
    knobSheen:SetHeight(1)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", track, "RIGHT", LABEL_GAP, 0)
    label:SetWordWrap(false)
    if config.labelWidth ~= nil then
        -- Clamp so the label cannot extend past holder.right and overlap
        -- anything the caller anchors there.
        local maxLabelW = holderWidth - TRACK_W - LABEL_GAP
        label:SetWidth(max(0, min(config.labelWidth, maxLabelW)))
        label:SetJustifyH("LEFT")
    end
    label:SetText(config.label)
    holder.label = label
    SetTextColor(label, Theme.text)

    local enabled = true
    local hovered = false

    local function UpdateVisual()
        local styles = Theme.toggle
        local style
        if not enabled then
            style = styles.disabled
        elseif checked then
            style = hovered and styles.onHover or styles.on
        else
            style = hovered and styles.offHover or styles.off
        end
        PaintSurface(surface, style)
        PaintGradient(thumb, "VERTICAL", style.knobBottom, style.knobTop)
        SetColorTexture(knobSheen, style.sheen)
        SetLabelEnabled(label, enabled)

        thumb:ClearAllPoints()
        if checked then
            thumb:SetPoint("LEFT", track, "LEFT", 18, 0)
        else
            thumb:SetPoint("LEFT", track, "LEFT", 2, 0)
        end
    end

    track:SetScript("OnClick", function()
        if not enabled then
            return
        end
        checked = not checked
        UpdateVisual()
        if config.onChange then
            config.onChange(checked)
        end
    end)

    track:SetScript("OnEnter", function()
        hovered = true
        UpdateVisual()
    end)

    track:SetScript("OnLeave", function()
        hovered = false
        UpdateVisual()
    end)

    if config.tooltip then
        local title = config.tooltip.title
        local desc = config.tooltip.desc
        holder:EnableMouse(true)
        local function showTip()
            ShowTooltip(holder, title, desc, "ANCHOR_TOP")
        end
        local function hideTip()
            HideTooltip()
        end
        holder:HookScript("OnEnter", showTip)
        holder:HookScript("OnLeave", hideTip)
        track:HookScript("OnEnter", showTip)
        track:HookScript("OnLeave", hideTip)
    end

    function holder:SetChecked(value)
        checked = value and true or false
        UpdateVisual()
    end

    function holder:GetChecked()
        return checked
    end

    function holder:SetEnabled(value)
        enabled = value and true or false
        track:EnableMouse(enabled)
        -- A track without mouse input gets no OnLeave, so the hover flag can go stale.
        hovered = enabled and track:IsMouseOver()
        UpdateVisual()
    end

    function holder:Refresh()
        if config.get then
            checked = config.get() and true or false
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
        UpdateVisual()
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    UpdateVisual()

    return holder
end

-- Modern dropdown styling colors
---Paint a dropdown field with an arrow cap at the right. The arrow moves onto the
---cap frame, which takes no mouse input.
---@return fun(state: "normal"|"hover"|"open"|"disabled") paint
local function DecorateDropdownField(button, arrow, buttonText)
    local surface = CreateSurface(button)
    local cap = CreateFrame("Frame", nil, button)
    cap:SetPoint("TOPRIGHT", -1, -1)
    cap:SetPoint("BOTTOMRIGHT", -1, 1)
    cap:SetWidth(Theme.dropdown.capWidth)
    local capFill = cap:CreateTexture(nil, "BACKGROUND")
    capFill:SetAllPoints()
    local capLine = cap:CreateTexture(nil, "BACKGROUND", nil, 1)
    capLine:SetPoint("TOPLEFT", 0, 0)
    capLine:SetPoint("TOPRIGHT", 0, 0)
    capLine:SetHeight(1)
    local divider = cap:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", 0, 0)
    divider:SetPoint("BOTTOMLEFT", 0, 0)
    divider:SetWidth(1)
    arrow:SetParent(cap)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", 0, 0)

    return function(state)
        local style = Theme.dropdown[state] --[[@as ThemeStyle]]
        PaintSurface(surface, style)
        SetColorTexture(divider, style.divider)
        PaintGradient(capFill, "VERTICAL", style.capBottom, style.capTop)
        SetColorTexture(capLine, style.capLine)
        local c = style.arrow --[[@as number[] ]]
        arrow:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        SetTextColor(buttonText, style.text)
    end
end

---Create the core dropdown (button + menu) - reusable by Dropdown and DirectionButtons
---@param parent table Parent frame
---@param width number Dropdown width
---@param options table[] Array of {label, value} options
---@param initialValue any Initial selected value
---@param onChange fun(value: any, label: string) Callback when selection changes
---@param maxItems? number Max visible items before scrolling (nil = no limit)
---@param itemInit? fun(item: table, label: FontString, opt: table) Optional per-item setup callback
---@return table dropdown Core dropdown with .button, .menu, .SetValue(), .GetValue(), .SetEnabled()
local function CreateDropdownCore(parent, width, options, initialValue, onChange, maxItems, itemInit)
    local itemColors = Theme.menuItem
    local BUTTON_HEIGHT = 22
    local ITEM_HEIGHT = 22
    local MENU_PADDING_V = 4
    local CHECK_SIZE = 14
    local CHECK_LEFT = 6
    local LABEL_LEFT = CHECK_LEFT + CHECK_SIZE + 4 -- room for checkmark
    local LABEL_RIGHT_PAD = 8

    local currentValue = initialValue
    local currentLabel = ""
    for _, opt in ipairs(options) do
        if opt.value == currentValue then
            currentLabel = opt.label
            break
        end
    end

    -- Auto-grow menu width to fit the longest option label. Without this, item
    -- text clips when labels are longer than the button (or font is bigger).
    local longestItemW = 0
    for _, opt in ipairs(options) do
        local w = MeasureTextWidth(opt.label or "", "GameFontHighlightSmall")
        if w > longestItemW then
            longestItemW = w
        end
    end
    local menuWidth = max(width, longestItemW + LABEL_LEFT + LABEL_RIGHT_PAD + 2)

    local isEnabled = true
    local isOpen = false
    local isHovered = false

    -- ==================== BUTTON ====================
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, BUTTON_HEIGHT)

    local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    buttonText:SetPoint("LEFT", 8, 0)
    buttonText:SetPoint("RIGHT", -20, 0)
    buttonText:SetWordWrap(false)
    buttonText:SetJustifyH("LEFT")
    buttonText:SetText(currentLabel)

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetRotation(math.rad(-90)) -- points down

    local paintField = DecorateDropdownField(button, arrow, buttonText)

    -- ==================== MENU ====================
    -- Parent to the dropdown parent so the menu scrolls with the container.
    -- If maxItems is set, always build the scroll infrastructure, even when the
    -- current option count fits: :SetOptions can repopulate with any count and
    -- the scroll child resizes. visibleCount stays mutable so SetOptions can
    -- recompute the capped menu height.
    local hasScroll = maxItems ~= nil
    local visibleCount = hasScroll and min(#options, maxItems) or #options
    local menuHeight = visibleCount * ITEM_HEIGHT + MENU_PADDING_V * 2
    local menu = CreateFrame("Frame", nil, parent)
    menu:SetSize(menuWidth, menuHeight)
    PaintSurface(CreateSurface(menu), Theme.menu)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    menu:Hide()

    local scrollFrame, scrollChild
    if hasScroll then
        scrollFrame = CreateFrame("ScrollFrame", nil, menu)
        scrollFrame:SetPoint("TOPLEFT", 1, -MENU_PADDING_V)
        scrollFrame:SetPoint("BOTTOMRIGHT", -1, MENU_PADDING_V)

        scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(menuWidth - 2, #options * ITEM_HEIGHT)
        scrollFrame:SetScrollChild(scrollChild)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(_, delta)
            local current = scrollFrame:GetVerticalScroll()
            local maxScroll = max(0, #options * ITEM_HEIGHT - visibleCount * ITEM_HEIGHT)
            local newScroll = max(0, min(maxScroll, current - delta * ITEM_HEIGHT * 3))
            scrollFrame:SetVerticalScroll(newScroll)
        end)
    end

    local function PositionMenu()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, 0)
    end

    -- ==================== VISUAL STATE ====================
    local function UpdateButtonVisual()
        local state = "normal"
        if not isEnabled then
            state = "disabled"
        elseif isOpen then
            state = "open"
        elseif isHovered then
            state = "hover"
        end
        paintField(state)
    end

    -- Track if mouse was down last frame (for click-outside detection)
    local wasMouseDown = false

    local function CloseMenu()
        isOpen = false
        menu:Hide()
        wasMouseDown = false
        UpdateButtonVisual()
    end

    local function OpenMenu()
        isOpen = true
        PositionMenu()
        -- The menu sits on FULLSCREEN_DIALOG so it floats over the main options
        -- panel (DIALOG strata). But dialogs also live on FULLSCREEN_DIALOG, so
        -- inside a dialog the strata ties and draw order falls back to frame
        -- level - the dialog's own widgets then paint over the open menu.
        -- Raise the menu well above the button's level (recomputed each open so
        -- it tracks a reparented/relevelled dropdown) so it always reads on top.
        menu:SetFrameLevel((button:GetFrameLevel() or 0) + 50)
        menu:Show()
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
        end
        wasMouseDown = IsMouseButtonDown("LeftButton") -- Prevent immediate close from the opening click
        UpdateButtonVisual()
    end

    -- OnUpdate to detect clicks outside menu (only runs while menu is visible)
    menu:SetScript("OnUpdate", function()
        local isMouseDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")

        if isMouseDown and not wasMouseDown then
            if not menu:IsMouseOver() and not button:IsMouseOver() then
                CloseMenu()
            end
        end

        wasMouseDown = isMouseDown
    end)

    -- ==================== MENU ITEMS ====================
    local itemParent = scrollChild or menu
    local items = {}

    -- (Re)build menu items from the current `options`. Items are pooled across
    -- :SetOptions calls (created on demand, surplus hidden), and each item reads
    -- its option through `item.opt` so reused items pick up the new entry.
    local function renderItems()
        -- Auto-grow the menu to the widest current label, recomputed here so a
        -- later :SetOptions with longer labels still fits (the button keeps its
        -- fixed width; only the dropdown menu widens).
        local longest = 0
        for _, opt in ipairs(options) do
            local w = MeasureTextWidth(opt.label or "", "GameFontHighlightSmall")
            if w > longest then
                longest = w
            end
        end
        menuWidth = max(width, longest + LABEL_LEFT + LABEL_RIGHT_PAD + 2)

        visibleCount = hasScroll and min(#options, maxItems) or #options
        menu:SetSize(menuWidth, visibleCount * ITEM_HEIGHT + MENU_PADDING_V * 2)
        if scrollChild then
            scrollChild:SetSize(menuWidth - 2, #options * ITEM_HEIGHT)
        end

        for i = #options + 1, #items do
            items[i]:Hide()
        end

        for i, opt in ipairs(options) do
            local item = items[i]
            if not item then
                item = CreateFrame("Button", nil, itemParent)
                item:SetSize(menuWidth - 2, ITEM_HEIGHT)

                local itemBg = item:CreateTexture(nil, "BACKGROUND")
                itemBg:SetAllPoints()
                item._bg = itemBg
                local bar = item:CreateTexture(nil, "BORDER")
                bar:SetPoint("TOPLEFT", 0, 0)
                bar:SetPoint("BOTTOMLEFT", 0, 0)
                bar:SetWidth(2)
                SetColorTexture(bar, itemColors.bar)
                bar:Hide()
                item._bar = bar

                local check = item:CreateTexture(nil, "ARTWORK")
                check:SetSize(CHECK_SIZE, CHECK_SIZE)
                check:SetPoint("LEFT", CHECK_LEFT, 0)
                check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                check:SetVertexColor(unpack(itemColors.check))
                item.check = check

                local label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", LABEL_LEFT, 0)
                label:SetPoint("RIGHT", -LABEL_RIGHT_PAD, 0)
                label:SetWordWrap(false)
                label:SetJustifyH("LEFT")
                item._label = label

                -- Scripts read item.opt (refreshed each render) so a reused item
                -- always acts on its current option, not a stale captured one.
                item:SetScript("OnEnter", function()
                    PaintGradient(item._bg, "HORIZONTAL", itemColors.hoverLeft, itemColors.hoverRight)
                    item._bar:Show()
                    SetTextColor(item._label, itemColors.textHover)
                    if item.opt and item.opt.desc then
                        ShowTooltip(item, item.opt.label, item.opt.desc, "ANCHOR_RIGHT")
                    end
                end)
                item:SetScript("OnLeave", function()
                    item._bg:SetColorTexture(0, 0, 0, 0)
                    item._bar:Hide()
                    SetTextColor(item._label, itemColors.text)
                    HideTooltip()
                end)
                item:SetScript("OnClick", function()
                    currentValue = item.opt.value
                    currentLabel = item.opt.label
                    buttonText:SetText(currentLabel)
                    for _, it in ipairs(items) do
                        if it:IsShown() then
                            it.check:SetShown(it.value == currentValue)
                        end
                    end
                    CloseMenu()
                    onChange(currentValue, currentLabel)
                end)

                if scrollFrame then
                    item:EnableMouseWheel(true)
                    item:SetScript("OnMouseWheel", function(_, delta)
                        local current = scrollFrame:GetVerticalScroll()
                        local maxScroll = max(0, #options * ITEM_HEIGHT - visibleCount * ITEM_HEIGHT)
                        local newScroll = max(0, min(maxScroll, current - delta * ITEM_HEIGHT * 3))
                        scrollFrame:SetVerticalScroll(newScroll)
                    end)
                end

                items[i] = item
            end

            item:ClearAllPoints()
            item:SetWidth(menuWidth - 2)
            item:SetPoint("TOPLEFT", 0, -(hasScroll and 0 or MENU_PADDING_V) - (i - 1) * ITEM_HEIGHT)
            item.opt = opt
            item.value = opt.value
            item._bg:SetColorTexture(0, 0, 0, 0)
            item._bar:Hide()
            item._label:SetText(opt.label)
            SetTextColor(item._label, itemColors.text)
            item.check:SetShown(opt.value == currentValue)
            -- Custom per-item setup (e.g., font preview); re-run so reused items
            -- adopt the new option's styling.
            if itemInit then
                itemInit(item, item._label, opt)
            end
            item:Show()
        end
    end

    renderItems()

    -- ==================== BUTTON EVENTS ====================
    button:SetScript("OnEnter", function()
        isHovered = true
        UpdateButtonVisual()
    end)
    button:SetScript("OnLeave", function()
        isHovered = false
        UpdateButtonVisual()
    end)
    button:SetScript("OnClick", function()
        if isEnabled then
            if isOpen then
                CloseMenu()
            else
                OpenMenu()
            end
        end
    end)

    UpdateButtonVisual()

    -- ==================== PUBLIC API ====================
    local dropdown = { button = button, menu = menu }

    function dropdown:SetValue(value)
        currentValue = value
        for _, opt in ipairs(options) do
            if opt.value == value then
                currentLabel = opt.label
                break
            end
        end
        buttonText:SetText(currentLabel)
        for _, item in ipairs(items) do
            item.check:SetShown(item.value == currentValue)
        end
    end

    function dropdown:GetValue()
        return currentValue
    end

    function dropdown:SetEnabled(enabled)
        isEnabled = enabled
        button:EnableMouse(enabled)
        if not enabled and isOpen then
            CloseMenu()
        end
        -- A button without mouse input gets no OnLeave, so the hover flag can go stale.
        isHovered = enabled and button:IsMouseOver()
        UpdateButtonVisual()
    end

    function dropdown:IsEnabled()
        return isEnabled
    end

    ---Replace the dropdown options and rebuild the menu. Scroll-aware: the menu
    ---height is capped at maxItems and the scroll child resizes to the new count.
    ---@param newOptions table[] Array of {value, label} entries
    function dropdown:SetOptions(newOptions)
        options = newOptions
        -- Keep the current selection if it survives; otherwise fall back to the
        -- first option so the button label and checkmarks stay consistent.
        local found = false
        for _, opt in ipairs(options) do
            if opt.value == currentValue then
                currentLabel = opt.label
                found = true
                break
            end
        end
        if not found then
            currentValue = options[1] and options[1].value or nil
            currentLabel = (options[1] and options[1].label) or ""
        end
        buttonText:SetText(currentLabel)
        renderItems()
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
        end
    end

    return dropdown
end

---Create direction buttons (LEFT, CENTER, RIGHT, UP, DOWN)
---@param parent table Parent frame
---@param config DirectionButtonsConfig Configuration table
---@return table holder Frame containing direction dropdown with .SetDirection(dir)
function Components.DirectionButtons(parent, config)
    local directions = { "LEFT", "CENTER", "RIGHT", "UP", "DOWN" }
    local dirLabels = {
        LEFT = L["Direction.Left"],
        CENTER = L["Direction.Center"],
        RIGHT = L["Direction.Right"],
        UP = L["Direction.Up"],
        DOWN = L["Direction.Down"],
    }
    local width = config.width or 90
    local labelText = config.label or L["Direction.Label"]
    -- Explicit labelWidth -> hard. Omitted -> auto-grow.
    local labelWidth
    if config.labelWidth ~= nil then
        labelWidth = config.labelWidth
    else
        labelWidth = max(70, MeasureTextWidth(labelText, "GameFontHighlightSmall") + 4)
    end

    local options = {}
    for _, dir in ipairs(directions) do
        tinsert(options, { label = dirLabels[dir], value = dir })
    end

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + width + 10, 26)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    holder.label = label
    SetTextColor(label, Theme.text)

    local initialValue = config.get and config.get() or config.selected

    local dropdown = CreateDropdownCore(holder, width, options, initialValue, function(value)
        config.onChange(value)
    end)
    dropdown.button:SetPoint("LEFT", label, "RIGHT", 5, 0)
    holder.dropdown = dropdown

    function holder:SetDirection(dir)
        dropdown:SetValue(dir)
    end

    function holder:SetEnabled(enabled)
        dropdown:SetEnabled(enabled)
        SetLabelEnabled(label, enabled)
    end

    -- Refresh method for OnShow pattern
    function holder:Refresh()
        if config.get then
            dropdown:SetValue(config.get())
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- ============================================================================
-- ZONE PICKER (vertical + alignment dropdowns)
-- ============================================================================
-- Vertical (Above / Inside top / Inside middle / Inside bottom / Below) and
-- Align (Left / Center / Right) dropdowns. BR.TextPositions.ToVA / FromVA
-- convert between the two axes and the zone strings the callers use.

---@class ZonePickerConfig
---@field label string Item name shown to the left of the dropdowns
---@field labelWidth? number Default 70
---@field verticalWidth? number Width of the Vertical dropdown (default 110)
---@field alignWidth? number Width of the Align dropdown (default 85)
---@field get fun(): string Returns current zone name
---@field enabled? fun(): boolean
---@field disabledReason? string|fun(): string Hover text while `enabled` returns false
---@field onChange fun(zone: string)
---@field off? TextOffToggle Adds "Off" as the first position

---@class TextOffToggle
---@field get fun(): boolean True while the text is hidden
---@field set fun(off: boolean) Writes the show/hide flag the text owns

-- Each Dropdown holder reserves an extra 10px past its `width` for the
-- chevron + internal padding (see Components.Dropdown). The container has
-- to include that or anything anchored to picker.RIGHT lands inside the
-- align dropdown.
local ZONE_PICKER_DD_PADDING = 10

-- Localized option lists, built once at file load. Locale strings stay stable
-- for the session.
local ZONE_PICKER_VERTICAL_OPTIONS = {}
for _, opt in ipairs(BR.TextPositions.VERTICAL_OPTIONS) do
    ZONE_PICKER_VERTICAL_OPTIONS[#ZONE_PICKER_VERTICAL_OPTIONS + 1] = {
        value = opt.value,
        label = BR.L[opt.labelKey],
    }
end
local ZONE_PICKER_ALIGN_OPTIONS = {}
for _, opt in ipairs(BR.TextPositions.ALIGN_OPTIONS) do
    ZONE_PICKER_ALIGN_OPTIONS[#ZONE_PICKER_ALIGN_OPTIONS + 1] = {
        value = opt.value,
        label = BR.L[opt.labelKey],
    }
end

---Create a zone picker (label + vertical + align dropdowns).
---@param parent Frame
---@param config ZonePickerConfig
function Components.ZonePicker(parent, config)
    local LW = config.labelWidth or 70
    local V_W = config.verticalWidth or 110
    local A_W = config.alignWidth or 85
    -- The label -> visible-box distance has to come out at 5 to match
    -- Slider/Dropdown/NumericStepper, or a ZonePicker stacked with them breaks
    -- the column's vertical line. The nested Dropdown holders already inset
    -- their own box by that 5 (empty label, then button at label RIGHT + 5), so
    -- this anchors flush to the label and lets the inner inset supply the gap.
    local LABEL_GAP = 0
    local GAP = 8

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(LW + LABEL_GAP + (V_W + ZONE_PICKER_DD_PADDING) + GAP + (A_W + ZONE_PICKER_DD_PADDING), 26)

    local itemLabel = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemLabel:SetPoint("LEFT", 0, 0)
    itemLabel:SetWidth(LW)
    itemLabel:SetJustifyH("LEFT")
    itemLabel:SetWordWrap(false)
    itemLabel:SetText(config.label or "")
    holder.label = itemLabel

    local function currentZone()
        return (config.get and config.get()) or "INSIDE_C"
    end

    local off = config.off --[[@as TextOffToggle?]]
    local function isOff()
        return off ~= nil and off.get() == true
    end

    local verticalOptions = ZONE_PICKER_VERTICAL_OPTIONS
    if off then
        verticalOptions = { { value = "OFF", label = L["Options.Off"] } }
        for _, opt in ipairs(ZONE_PICKER_VERTICAL_OPTIONS) do
            verticalOptions[#verticalOptions + 1] = opt
        end
    end

    local verticalDD = Components.Dropdown(holder, {
        label = "",
        labelWidth = 0,
        width = V_W,
        options = verticalOptions,
        get = function()
            if isOff() then
                return "OFF"
            end
            local v = BR.TextPositions.ToVA(currentZone())
            return v
        end,
        enabled = config.enabled,
        onChange = function(v)
            if off and v == "OFF" then
                off.set(true)
                Components.RefreshAll()
                return
            end
            local wasOff = isOff()
            if off and wasOff then
                off.set(false)
            end
            local _, a = BR.TextPositions.ToVA(currentZone())
            if config.onChange then
                config.onChange(BR.TextPositions.FromVA(v, a))
            end
            if wasOff then
                Components.RefreshAll()
            end
        end,
    })
    verticalDD:SetPoint("LEFT", itemLabel, "RIGHT", LABEL_GAP, 0)

    local alignDD = Components.Dropdown(holder, {
        label = "",
        labelWidth = 0,
        width = A_W,
        options = ZONE_PICKER_ALIGN_OPTIONS,
        get = function()
            local _, a = BR.TextPositions.ToVA(currentZone())
            return a
        end,
        enabled = config.enabled,
        onChange = function(a)
            local v = BR.TextPositions.ToVA(currentZone())
            if config.onChange then
                config.onChange(BR.TextPositions.FromVA(v, a))
            end
        end,
    })
    alignDD:SetPoint("LEFT", verticalDD, "RIGHT", GAP, 0)

    holder.verticalDropdown = verticalDD
    holder.alignDropdown = alignDD

    -- Mirror the dropdowns' enabled state on the item label so the whole row
    -- reads as one disabled element (otherwise the label stays white while
    -- everything to its right is greyed).
    function holder:Refresh()
        SetLabelEnabled(itemLabel, not config.enabled or config.enabled())
        alignDD:SetShown(not isOff())
    end

    if config.get or config.enabled or off then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    holder:Refresh()
    return holder
end

---@class ToggleDef
---@field key string
---@field label string
---@field tooltip TooltipText
---@field color? number[]
---@field diffDbKey? string
---@field diffDefs? ToggleDef[]

-- Every content segment and sub-toggle of both clients. BR.INSTANCE_CONTENT picks the
-- ones that this client renders.
---@type table<string, ToggleDef>
local CONTENT_DEFS = {
    openWorld = { key = "openWorld", label = "W", tooltip = { title = L["Content.OpenWorld"] } },
    housing = { key = "housing", label = "H", tooltip = { title = L["Content.Housing"] } },
    scenario = {
        key = "scenario",
        label = "S",
        tooltip = { title = L["Content.Scenarios"] },
        diffDbKey = "scenarioDifficulty",
    },
    dungeon = {
        key = "dungeon",
        label = "D",
        tooltip = { title = L["Content.Dungeons"] },
        diffDbKey = "dungeonDifficulty",
    },
    raid = { key = "raid", label = "R", tooltip = { title = L["Content.Raids"] }, diffDbKey = "raidDifficulty" },
    pvp = { key = "pvp", label = "P", tooltip = { title = L["Content.PvP"] }, diffDbKey = "pvpType" },
}

---@type table<string, table<string, ToggleDef>>
local DIFFICULTY_DEFS = {
    scenario = {
        delves = { key = "delves", label = "D", tooltip = { title = L["Content.Delves"] } },
        others = { key = "others", label = "O", tooltip = { title = L["Content.OtherScenarios"] } },
    },
    dungeon = {
        normal = { key = "normal", label = "N", tooltip = { title = L["Content.NormalDungeons"] } },
        heroic = { key = "heroic", label = "H", tooltip = { title = L["Content.HeroicDungeons"] } },
        mythic = { key = "mythic", label = "M", tooltip = { title = L["Content.MythicDungeons"] } },
        mythicPlus = { key = "mythicPlus", label = "M+", tooltip = { title = L["Content.MythicPlus"] } },
        timewalking = { key = "timewalking", label = "TW", tooltip = { title = L["Content.TimewalkingDungeons"] } },
        follower = { key = "follower", label = "F", tooltip = { title = L["Content.FollowerDungeons"] } },
    },
    raid = {
        lfr = { key = "lfr", label = "LFR", tooltip = { title = L["Content.LFR"] } },
        normal = { key = "normal", label = "N", tooltip = { title = L["Content.NormalRaids"] } },
        heroic = { key = "heroic", label = "H", tooltip = { title = L["Content.HeroicRaids"] } },
        mythic = { key = "mythic", label = "M", tooltip = { title = L["Content.MythicRaids"] } },
        raid40 = { key = "raid40", label = "40", tooltip = { title = L["Content.Raids40"] } },
        raid20 = { key = "raid20", label = "20", tooltip = { title = L["Content.Raids20"] } },
    },
    pvp = {
        arena = { key = "arena", label = "A", tooltip = { title = L["Content.Arena"] } },
        bg = { key = "bg", label = "B", tooltip = { title = L["Content.Battlegrounds"] } },
    },
}

Components.ContentToggleCatalog = { content = CONTENT_DEFS, difficulties = DIFFICULTY_DEFS }

---@type ToggleDef[]
local CONTENT_TOGGLE_DEFS = {}
do
    local instanceContent = BR.INSTANCE_CONTENT
    local titles = instanceContent.titles or {}
    for _, key in ipairs(instanceContent.contentTypes) do
        local def = CONTENT_DEFS[key]
        local title = titles[key]
        local toggle = { key = key, label = def.label, tooltip = title and { title = title } or def.tooltip }
        local diffKeys = instanceContent.difficulties[key]
        if diffKeys then
            local diffDefs = {}
            for i, diffKey in ipairs(diffKeys) do
                diffDefs[i] = DIFFICULTY_DEFS[key][diffKey]
            end
            toggle.diffDbKey = def.diffDbKey
            toggle.diffDefs = diffDefs
        end
        CONTENT_TOGGLE_DEFS[#CONTENT_TOGGLE_DEFS + 1] = toggle
    end
end

local contentToggleByKey = {}
local DIFF_MAPPINGS = {}
for i, toggle in ipairs(CONTENT_TOGGLE_DEFS) do
    contentToggleByKey[toggle.key] = toggle
    if toggle.diffDefs then
        DIFF_MAPPINGS[#DIFF_MAPPINGS + 1] =
            { contentKey = toggle.key, diffDbKey = toggle.diffDbKey, diffDefs = toggle.diffDefs, btnIndex = i }
    end
end

local SEGMENT_H = 16
local DIVIDER_W = 1
local DEFAULT_SEGMENT_W = 22

---Compute bar width for a given number of segments and segment width
---@param numSegments number
---@param segW number
---@return number
local function ComputeBarWidth(numSegments, segW)
    return numSegments * segW + (numSegments - 1) * DIVIDER_W + 2
end

local BAR_H = SEGMENT_H + 2

---@class SegmentedBarConfig
---@field toggleDefs ToggleDef[]
---@field segmentWidth? number
---@field getState fun(key: string): boolean
---@field getVisualState? fun(key: string): "on"|"partial"|"off"
---@field setState fun(key: string)
---@field onChange? fun()

---@class SegmentStyle
---@field top number[]
---@field bottom number[]
---@field text number[]
---@field sheen number[]
---@field tintTop? number Fill factors on a per-content color; nil keeps top and bottom
---@field tintBottom? number
---@field tintText? number Text factor on a per-content color; nil keeps text
---@field tintAlpha? number

-- A sub-toggle that the caller blocks: dark red, not clickable.
---@type SegmentStyle
local BLOCKED_SEGMENT = {
    top = { 0.08, 0.02, 0.02, 1 },
    bottom = { 0.08, 0.02, 0.02, 1 },
    text = { 0.5, 0.2, 0.2, 1 },
    sheen = CLEAR,
}

---@param c number[]
---@param f number
---@param a? number
---@return number[]
local function Scale(c, f, a)
    return { c[1] * f, c[2] * f, c[3] * f, a or 1 }
end

-- Tinted colors per content color and style. Callers must not change a content color.
local tintCache = setmetatable({}, { __mode = "k" })

---@param style SegmentStyle
---@param c number[]
---@return {top: number[], bottom: number[], text: number[]}
local function Tinted(style, c)
    local byStyle = tintCache[c]
    if not byStyle then
        byStyle = {}
        tintCache[c] = byStyle
    end
    local tint = byStyle[style]
    if not tint then
        tint = { top = style.top, bottom = style.bottom, text = style.text }
        if style.tintTop then
            tint.top, tint.bottom = Scale(c, style.tintTop), Scale(c, style.tintBottom)
        end
        if style.tintText then
            tint.text = Scale(c, style.tintText, style.tintAlpha)
        end
        byStyle[style] = tint
    end
    return tint
end

---Paint one segment of a segmented bar.
---@param btn table Segment button with .bg, .sheen, .label
---@param style SegmentStyle
---@param c? number[] Per-content color
local function PaintSegment(btn, style, c)
    local colors = c and Tinted(style, c) or style
    PaintGradient(btn.bg, "VERTICAL", colors.bottom, colors.top)
    SetColorTexture(btn.sheen, style.sheen)
    SetTextColor(btn.label, colors.text)
end

---Create a generic segmented toggle bar
---@param parent table Parent frame
---@param barConfig SegmentedBarConfig
---@return table container The bar container frame
---@return table toggleButtons Array of segment button frames
local function CreateSegmentedBar(parent, barConfig)
    local toggleDefs = barConfig.toggleDefs
    local segW = barConfig.segmentWidth or DEFAULT_SEGMENT_W
    local barW = ComputeBarWidth(#toggleDefs, segW)

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(barW, BAR_H)
    PaintSurface(CreateSurface(container), Theme.segmentBar)

    local barDisabled = false
    local toggleButtons = {}
    for i, toggle in ipairs(toggleDefs) do
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(segW, SEGMENT_H)
        local xOff = 1 + (i - 1) * (segW + DIVIDER_W)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, -1)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()

        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnLabel:SetPoint("CENTER", 0, -1)
        btnLabel:SetText(toggle.label)

        local sheen = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
        sheen:SetPoint("TOPLEFT", 0, 0)
        sheen:SetPoint("TOPRIGHT", 0, 0)
        sheen:SetHeight(1)

        btn.bg = bg
        btn.label = btnLabel
        btn.sheen = sheen

        local function UpdateToggleVisual()
            local state = "disabled"
            if not barDisabled then
                if barConfig.getVisualState then
                    state = barConfig.getVisualState(toggle.key)
                else
                    state = barConfig.getState(toggle.key) and "on" or "off"
                end
            end
            PaintSegment(btn, Theme.segment[state], toggle.color)
        end
        btn.UpdateVisual = UpdateToggleVisual
        UpdateToggleVisual()

        btn:SetScript("OnClick", function()
            if barDisabled then
                return
            end
            barConfig.setState(toggle.key)
            UpdateToggleVisual()
            if barConfig.onChange then
                barConfig.onChange()
            end
        end)

        local tipTitle = toggle.tooltip.title
        SetupTooltip(btn, tipTitle, string.format(L["Content.ClickToToggleVisibility"], tipTitle:lower()), "ANCHOR_TOP")

        if i < #toggleDefs then
            local divider = container:CreateTexture(nil, "ARTWORK")
            divider:SetSize(DIVIDER_W, SEGMENT_H)
            divider:SetPoint("LEFT", btn, "RIGHT", 0, 0)
            SetColorTexture(divider, Theme.segmentDivider)
        end

        toggleButtons[i] = btn
    end

    ---Set whether the entire bar is disabled (non-interactive, all gray)
    ---@param disabled boolean
    function container:SetBarDisabled(disabled)
        barDisabled = disabled
        for _, btn in ipairs(toggleButtons) do
            btn.UpdateVisual()
        end
    end

    return container, toggleButtons
end

Components.CreateSegmentedBar = CreateSegmentedBar

---@class VisibilityTogglesConfig : ComponentConfig
---@field category? CategoryName Category for DB-backed visibility toggles
---@field store? VisibilityStore Custom data source (overrides category DB access)
---@field onChange fun() Callback when visibility changes
---@field noAutoRefresh? boolean Skip auto-registration in RefreshableComponents
---@field disabledSubToggles? table<string, table<string, {tooltip: TooltipText}>> Per-diffDbKey per-subKey overrides: greyed out, unclickable

---@class VisibilityStore
---@field getContent fun(key: string): boolean Whether content type is enabled
---@field setContent fun(key: string) Toggle content type
---@field getDiffTable fun(dbKey: string): table? Get difficulty sub-table (nil = all enabled)
---@field ensureDiffTable fun(dbKey: string): table Get or create difficulty sub-table

---Build a DB-backed VisibilityStore for a category
---@param category CategoryName
---@return VisibilityStore
local function MakeCategoryStore(category)
    return {
        getContent = function(key)
            local db = BR.profile
            local vis = db.categoryVisibility and db.categoryVisibility[category]
            return not vis or vis[key] ~= false
        end,
        setContent = function(key)
            local db = BR.profile
            if not db.categoryVisibility then
                db.categoryVisibility = {}
            end
            if not db.categoryVisibility[category] then
                db.categoryVisibility[category] = {
                    openWorld = true,
                    scenario = true,
                    dungeon = true,
                    raid = true,
                    housing = false,
                    pvp = true,
                    hideInPvPMatch = true,
                }
            end
            db.categoryVisibility[category][key] = not db.categoryVisibility[category][key]
        end,
        getDiffTable = function(dbKey)
            local db = BR.profile
            local vis = db.categoryVisibility and db.categoryVisibility[category]
            return vis and vis[dbKey]
        end,
        ensureDiffTable = function(dbKey)
            local db = BR.profile
            if not db.categoryVisibility then
                db.categoryVisibility = {}
            end
            if not db.categoryVisibility[category] then
                db.categoryVisibility[category] = {
                    openWorld = true,
                    scenario = true,
                    dungeon = true,
                    raid = true,
                    housing = false,
                    pvp = true,
                    hideInPvPMatch = true,
                }
            end
            if not db.categoryVisibility[category][dbKey] then
                db.categoryVisibility[category][dbKey] = {}
            end
            return db.categoryVisibility[category][dbKey]
        end,
    }
end

---Create standalone content + difficulty visibility toggles (D/R expand to the right)
---@param parent table Parent frame
---@param config VisibilityTogglesConfig Configuration table
---@return table holder Frame containing segmented toggle bar with D/R difficulty expansion
function Components.VisibilityToggles(parent, config)
    local store = config.store or MakeCategoryStore(config.category)
    local DIFF_SEGMENT_W = 26

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(200, BAR_H)

    -- All toggle buttons across all bars (content + difficulty bars) for Refresh
    local allToggleButtons = {}

    -- Compute tri-state visual for D/R buttons: "on" (all diffs enabled), "partial" (some), "off" (content disabled)
    local function getDiffVisualState(contentKey, diffDbKey, diffDefs)
        if not store.getContent(contentKey) then
            return "off"
        end
        local diffTable = store.getDiffTable(diffDbKey)
        if not diffTable then
            return "on" -- nil = all enabled
        end
        local anyOn, anyOff = false, false
        for _, def in ipairs(diffDefs) do
            if diffTable[def.key] == false then
                anyOff = true
            else
                anyOn = true
            end
        end
        if anyOn and anyOff then
            return "partial"
        elseif anyOn then
            return "on"
        else
            return "off"
        end
    end

    -- Forward-declare refreshAll so diff bar onChange can call it
    local refreshAll

    -- Content label (LEFT anchor centers vertically in holder)
    local contentLabel = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contentLabel:SetPoint("LEFT", 0, 0)
    contentLabel:SetText(L["Content.ShowIn"])

    local contentBar, contentButtons = CreateSegmentedBar(holder, {
        toggleDefs = CONTENT_TOGGLE_DEFS,
        segmentWidth = DEFAULT_SEGMENT_W,
        getState = function(key)
            return store.getContent(key)
        end,
        getVisualState = function(key)
            local toggle = contentToggleByKey[key]
            if toggle and toggle.diffDbKey then
                return getDiffVisualState(key, toggle.diffDbKey, toggle.diffDefs)
            end
            return store.getContent(key) and "on" or "off"
        end,
        setState = function(key)
            store.setContent(key)
        end,
        onChange = config.onChange,
    })
    contentBar:SetPoint("LEFT", contentLabel, "RIGHT", 6, 0)

    for _, btn in ipairs(contentButtons) do
        allToggleButtons[#allToggleButtons + 1] = btn
    end

    local diffBars = {} -- keyed by contentKey ("dungeon", "raid")
    local activeDiffKey = nil -- which difficulty bar is currently shown

    local expandArrow = CreateFrame("Frame", nil, holder)
    expandArrow:SetSize(10, BAR_H)
    expandArrow:SetPoint("LEFT", contentBar, "RIGHT", 2, 0)
    local arrowTex = expandArrow:CreateTexture(nil, "OVERLAY")
    arrowTex:SetSize(8, 8)
    arrowTex:SetPoint("CENTER", 0, 0)
    arrowTex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrowTex:SetVertexColor(0.5, 0.5, 0.5, 1)
    expandArrow:Hide()

    -- Pre-create difficulty bars
    for _, mapping in ipairs(DIFF_MAPPINGS) do
        -- Resolve disabled sub-toggles before bar creation so setState can reference them
        local disabledSubs = config.disabledSubToggles and config.disabledSubToggles[mapping.diffDbKey]

        local bar, buttons = CreateSegmentedBar(holder, {
            toggleDefs = mapping.diffDefs,
            segmentWidth = DIFF_SEGMENT_W,
            getState = function(key)
                local diffTable = store.getDiffTable(mapping.diffDbKey)
                return not diffTable or diffTable[key] ~= false
            end,
            setState = function(key)
                local t = store.ensureDiffTable(mapping.diffDbKey)
                local wasEnabled = t[key] ~= false
                t[key] = not wasEnabled

                -- Auto-manage content type toggle
                if wasEnabled then
                    -- Turned off: check if ALL toggleable subs are now off -> disable content type
                    -- Skip force-disabled keys (e.g. arena for consumables) so they do not
                    -- cause the parent to auto-disable when the only interactive sub is turned off.
                    local anyStillOn = false
                    for _, def in ipairs(mapping.diffDefs) do
                        if not (disabledSubs and disabledSubs[def.key]) and t[def.key] ~= false then
                            anyStillOn = true
                            break
                        end
                    end
                    if not anyStillOn and store.getContent(mapping.contentKey) then
                        store.setContent(mapping.contentKey)
                    end
                else
                    -- Turned on from off: if content type was disabled, re-enable it
                    -- and set only the clicked difficulty to true (others stay off)
                    if not store.getContent(mapping.contentKey) then
                        store.setContent(mapping.contentKey)
                        for _, def in ipairs(mapping.diffDefs) do
                            t[def.key] = def.key == key
                        end
                    end
                end
            end,
            onChange = function()
                -- Auto-manage can change multiple states; refresh everything
                refreshAll()
                config.onChange()
            end,
        })
        bar:SetPoint("LEFT", expandArrow, "RIGHT", 2, 0)
        bar:Hide()
        if disabledSubs then
            for j, subDef in ipairs(mapping.diffDefs) do
                local disabledInfo = disabledSubs[subDef.key]
                if disabledInfo then
                    local subBtn = buttons[j]
                    subBtn:SetScript("OnClick", function() end)
                    subBtn.UpdateVisual = function()
                        PaintSegment(subBtn, BLOCKED_SEGMENT)
                    end
                    subBtn.UpdateVisual()
                    if disabledInfo.tooltip then
                        SetupTooltip(subBtn, disabledInfo.tooltip.title, disabledInfo.tooltip.desc, "ANCHOR_TOP")
                    end
                end
            end
        end

        for _, btn in ipairs(buttons) do
            allToggleButtons[#allToggleButtons + 1] = btn
        end

        diffBars[mapping.contentKey] = bar
    end

    local function closeDiffBar()
        if activeDiffKey then
            diffBars[activeDiffKey]:Hide()
            activeDiffKey = nil
            expandArrow:Hide()
        end
    end

    local function showDiffBar(contentKey)
        if activeDiffKey == contentKey then
            closeDiffBar()
            return
        end
        if activeDiffKey then
            diffBars[activeDiffKey]:Hide()
        end
        diffBars[contentKey]:Show()
        expandArrow:Show()
        activeDiffKey = contentKey
    end

    -- Override D and R button click to toggle difficulty bar to the right
    for _, mapping in ipairs(DIFF_MAPPINGS) do
        local btn = contentButtons[mapping.btnIndex]
        btn:SetScript("OnClick", function()
            showDiffBar(mapping.contentKey)
        end)
        local toggle = CONTENT_TOGGLE_DEFS[mapping.btnIndex]
        SetupTooltip(
            btn,
            toggle.tooltip.title,
            string.format(L["Content.ClickToFilter"], toggle.tooltip.title),
            "ANCHOR_TOP"
        )
    end

    refreshAll = function()
        for _, btn in ipairs(allToggleButtons) do
            btn.UpdateVisual()
        end
    end

    holder.toggleButtons = contentButtons
    holder.allToggleButtons = allToggleButtons

    holder:SetScript("OnHide", closeDiffBar)

    function holder:Refresh()
        refreshAll()
    end

    if not config.noAutoRefresh then
        tinsert(RefreshableComponents, holder)
    end

    return holder
end

---@class DropdownOption
---@field label string Display text
---@field value any Value to pass to callback
---@field desc? string Optional description shown as tooltip on hover

---@class DropdownConfig : ComponentConfig
---@field label string Label text
---@field options DropdownOption[] Available options
---@field selected? any Initial selected value (deprecated: prefer get)
---@field get? fun(): any Getter for initial value and refresh (preferred over selected)
---@field enabled? fun(): boolean Getter for enabled state, evaluated on Refresh()
---@field tooltip? TooltipText Tooltip on hover
---@field width? number Dropdown width (default 100)
---@field labelWidth? number Label width (default 70)
---@field maxItems? number Max visible items before scrolling (nil = no limit)
---@field itemInit? fun(item: table, label: FontString, opt: table) Optional per-item setup callback
---@field onChange fun(value: any) Callback when selection changes

---Create a dropdown with label
---@param parent table Parent frame
---@param config DropdownConfig Configuration table
---@param _ string? Unused (was uniqueName for UIDropDownMenu, kept for API compatibility)
---@return table holder Frame containing dropdown with .SetValue(v), .GetValue(), .SetEnabled(bool)
function Components.Dropdown(parent, config, _)
    local width = config.width or 100
    -- Explicit labelWidth -> hard target (preserves column alignment).
    -- Omitted -> auto-grow from measured text.
    local labelWidth
    if config.labelWidth ~= nil then
        labelWidth = config.labelWidth
    else
        labelWidth = max(70, MeasureTextWidth(config.label or "", "GameFontHighlightSmall") + 4)
    end

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + width + 10, 26)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(config.label)
    holder.label = label
    SetTextColor(label, Theme.text)

    local initialValue = config.get and config.get() or config.selected

    local dropdown = CreateDropdownCore(holder, width, config.options, initialValue, function(value)
        config.onChange(value)
    end, config.maxItems, config.itemInit)
    dropdown.button:SetPoint("LEFT", label, "RIGHT", 5, 0)
    holder.dropdown = dropdown

    function holder:SetValue(value)
        dropdown:SetValue(value)
    end

    function holder:GetValue()
        return dropdown:GetValue()
    end

    function holder:SetEnabled(enabled)
        dropdown:SetEnabled(enabled)
        SetLabelEnabled(label, enabled)
    end

    -- Hover tooltip (attached to label only, not the entire holder)
    if config.tooltip then
        local tipTitle = config.tooltip.title
        local tipDesc = config.tooltip.desc
        label:EnableMouse(true)
        local function showTip()
            ShowTooltip(label, tipTitle, tipDesc, "ANCHOR_TOP")
        end
        label:SetScript("OnEnter", showTip)
        label:SetScript("OnLeave", HideTooltip)
    end

    -- Refresh method for OnShow pattern
    function holder:Refresh()
        if config.get then
            dropdown:SetValue(config.get())
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

---@class TabConfig : ComponentConfig
---@field name string Internal tab name
---@field label string Display label
---@field width? number Tab width (default 90)
---@field height? number Tab height (default 22)

---Create a flat-style tab button
---@param parent table Parent frame
---@param config TabConfig Configuration table
---@return table tab Tab button with .SetActive(bool), .isActive
function Components.Tab(parent, config)
    -- NOTE: config.width is treated as a MINIMUM, not a target. The tab grows
    -- past it to fit a wider label. This is safe for callers that chain tabs
    -- via `LEFT, prev, RIGHT, gap, 0`. Callers that place tabs at fixed X
    -- coordinates must compute final widths themselves.
    local minWidth = config.width or 90
    local height = config.height or 22

    -- Auto-grow tab width to fit text + side padding so labels never clip.
    -- The active (GameFontHighlightSmall) and inactive (GameFontNormalSmall)
    -- variants render at the same width, so either font gives the measurement.
    local textW = MeasureTextWidth(config.label or "", "GameFontNormalSmall")
    local width = max(minWidth, textW + 16)

    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(width, height)
    tab.tabName = config.name

    local colors = Theme.tab
    local lineR, lineG, lineB = colors.line[1], colors.line[2], colors.line[3]

    local underline = tab:CreateTexture(nil, "ARTWORK")
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT", 1, 0)
    underline:SetPoint("BOTTOMRIGHT", -1, 0)
    underline:SetColorTexture(lineR, lineG, lineB, 0)
    tab.underline = underline

    local wash = tab:CreateTexture(nil, "BORDER")
    wash:SetHeight(14)
    wash:SetPoint("BOTTOMLEFT", 1, 0)
    wash:SetPoint("BOTTOMRIGHT", -1, 0)
    PaintGradient(wash, "VERTICAL", colors.washBottom, colors.washTop)
    wash:Hide()

    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 1)
    text:SetWordWrap(false)
    text:SetText(config.label)
    tab.text = text

    tab:SetScript("OnEnter", function(self)
        if not self.isActive then
            SetTextColor(self.text, colors.hover)
            self.underline:SetColorTexture(lineR, lineG, lineB, colors.hoverAlpha)
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if not self.isActive then
            SetTextColor(self.text, colors.idle)
            self.underline:SetColorTexture(lineR, lineG, lineB, 0)
        end
    end)

    function tab:SetActive(active)
        self.isActive = active
        wash:SetShown(active)
        if active then
            self.text:SetFontObject("GameFontHighlightSmall")
            SetTextColor(self.text, colors.active)
            self.underline:SetColorTexture(lineR, lineG, lineB, 1)
        else
            self.text:SetFontObject("GameFontNormalSmall")
            SetTextColor(self.text, colors.idle)
            self.underline:SetColorTexture(lineR, lineG, lineB, 0)
        end
    end

    tab:SetActive(false)

    return tab
end

---Hairline under a tab strip. Drawn on the BORDER layer, so each tab's ARTWORK
---underline covers it. Anchor to the strip's left-most tab and pass the total
---strip width.
---@param parent table Frame owning the strip
---@param anchorTab table The left-most tab in the strip
---@param width number Total strip width the line should span
---@return table line The left half of the line; the right half anchors to it
function Components.TabBaseline(parent, anchorTab, width)
    local left, right = BR.CreateRule(parent, "BORDER", Theme.tabRule)
    left:SetPoint("BOTTOMLEFT", anchorTab, "BOTTOMLEFT", 0, 0)
    left:SetWidth(width / 2)
    right:SetPoint("LEFT", left, "RIGHT", 0, 0)
    right:SetWidth(width / 2)
    return left
end

---@class TextInputConfig : ComponentConfig
---@field label string Display label
---@field value? string Initial value (deprecated: prefer get)
---@field get? fun(): string Getter for initial value and refresh (preferred over value)
---@field enabled? fun(): boolean Predicate for enabled state (refreshed on RefreshAll)
---@field width? number Input width (default 150)
---@field labelWidth? number Label width (default 80)
---@field numeric? boolean Numeric only input
---@field onChange? fun(text: string) Callback when text changes (on enter/focus lost)

---Create a labeled text input
---@param parent table Parent frame
---@param config TextInputConfig Configuration table
---@return table holder Frame with .editBox, .SetValue(v), .GetValue(), .SetTextColor(c)
function Components.TextInput(parent, config)
    local width = config.width or 150
    -- Explicit labelWidth -> hard. Omitted -> auto-grow.
    local labelWidth
    if config.labelWidth ~= nil then
        labelWidth = config.labelWidth
    elseif config.label then
        labelWidth = max(80, MeasureTextWidth(config.label, "GameFontHighlightSmall") + 4)
    else
        labelWidth = 80
    end

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + width + 5, 20)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(config.label)
    holder.label = label
    SetTextColor(label, Theme.text)

    local editBox = CreateFrame("EditBox", nil, holder)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetAutoFocus(false)
    local inputContainer = StyleEditBox(editBox)
    inputContainer:SetSize(width, 18)
    inputContainer:SetPoint("LEFT", label, "RIGHT", 5, 0)
    if config.numeric then
        editBox:SetNumeric(true)
    end
    local initialText = config.get and config.get() or config.value
    if initialText then
        editBox:SetText(initialText)
    end
    holder.editBox = editBox

    -- Track editbox for focus cleanup
    if panelEditBoxes then
        tinsert(panelEditBoxes, editBox)
    end

    -- OnEditFocusLost uses HookScript: SetScript replaces StyleEditBox's
    -- focus-color reset.
    if config.onChange then
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            config.onChange(self:GetText())
        end)
        editBox:HookScript("OnEditFocusLost", function(self)
            config.onChange(self:GetText())
        end)
    else
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
    end

    function holder:SetValue(text)
        editBox:SetText(text or "")
    end

    function holder:GetValue()
        return editBox:GetText()
    end

    function holder:SetEnabled(enabled)
        editBox:SetEnabled(enabled)
        SetLabelEnabled(label, enabled)
        inputContainer:SetBoxEnabled(enabled)
    end

    ---@param color? number[] nil = the text color of the theme state
    function holder:SetTextColor(color)
        inputContainer:SetBoxTextColor(color)
    end

    -- Refresh method for OnShow pattern
    function holder:Refresh()
        if config.get then
            editBox:SetText(config.get() or "")
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- ============================================================================
-- NUMERIC STEPPER
-- ============================================================================

---Create a compact numeric stepper with [-] value [+] buttons
---@param parent table Parent frame
---@param config table Configuration: label, min, max, step?, labelWidth?, get?, enabled?, inherited?, onChange?, formatValue?, tooltip?
---@return table holder Frame with .SetValue(n), .GetValue(), .SetEnabled(bool), .Refresh()
function Components.NumericStepper(parent, config)
    local step = config.step or 1
    local BTN_SIZE = 16
    -- Explicit labelWidth -> hard. Omitted -> auto-grow.
    local labelWidth
    if config.labelWidth ~= nil then
        labelWidth = config.labelWidth
    elseif config.label then
        labelWidth = max(70, MeasureTextWidth(config.label, "GameFontHighlightSmall") + 4)
    else
        labelWidth = 70
    end

    local displayText = config.formatValue or tostring

    -- Auto-grow value box: at the default font 4-digit numbers fit in 26px, at
    -- bigger fonts they do not. Measure the actual extents of min and max.
    local minTxt = displayText(config.min or 0)
    local maxTxt = displayText(config.max or 100)
    local VALUE_WIDTH = max(
        26,
        max(MeasureTextWidth(minTxt, "GameFontHighlightSmall"), MeasureTextWidth(maxTxt, "GameFontHighlightSmall")) + 8
    )

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + BTN_SIZE * 2 + VALUE_WIDTH + 16, 20)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(config.label)
    holder.label = label
    SetTextColor(label, Theme.text)

    if config.tooltip then
        local labelHover = CreateFrame("Frame", nil, holder)
        labelHover:SetAllPoints(label)
        labelHover:EnableMouse(true)
        SetupTooltip(labelHover, config.tooltip.title, config.tooltip.desc, "ANCHOR_TOP")
    end

    local currentValue = config.min or 0
    if config.get then
        currentValue = config.get()
    end
    local isEnabled = true

    local valueBtn = CreateFrame("Button", nil, holder)
    valueBtn:SetSize(VALUE_WIDTH, BTN_SIZE)

    local valueText = valueBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetAllPoints()
    valueText:SetWordWrap(false)
    valueText:SetJustifyH("CENTER")
    SetTextColor(valueText, Theme.text)

    -- Forward declarations (buttons needed by UpdateButtonStates, defined below)
    local UpdateButtonStates

    local function UpdateValueText()
        valueText:SetText(displayText(currentValue))
        if UpdateButtonStates then
            UpdateButtonStates()
        end
    end

    local function ClampAndSet(val)
        val = max(config.min or 0, min(config.max or 100, val))
        val = floor(val / step + 0.5) * step
        if val ~= currentValue then
            currentValue = val
            UpdateValueText()
            if config.onChange then
                config.onChange(currentValue)
            end
        else
            UpdateButtonStates()
        end
    end

    local minusBtn = CreateFrame("Button", nil, holder)
    minusBtn:SetSize(BTN_SIZE, BTN_SIZE)
    minusBtn:SetPoint("LEFT", label, "RIGHT", 5, 0)
    local minusSurface = CreateSurface(minusBtn)

    local minusLabel = minusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minusLabel:SetPoint("CENTER", 0, 0)
    minusLabel:SetText("-")

    valueBtn:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)

    local plusBtn = CreateFrame("Button", nil, holder)
    plusBtn:SetSize(BTN_SIZE, BTN_SIZE)
    plusBtn:SetPoint("LEFT", valueBtn, "RIGHT", 2, 0)
    local plusSurface = CreateSurface(plusBtn)

    local plusLabel = plusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plusLabel:SetPoint("CENTER", 0, 0)
    plusLabel:SetText("+")

    local hoveredBtn, pressedBtn
    local parts = {
        { minusBtn, minusSurface, minusLabel, true },
        { plusBtn, plusSurface, plusLabel, false },
    }
    UpdateButtonStates = function()
        local atMin = currentValue <= (config.min or 0)
        local atMax = currentValue >= (config.max or 100)
        for _, part in ipairs(parts) do
            local btn = part[1]
            local atLimit = atMax
            if part[4] then
                atLimit = atMin
            end
            local state = "normal"
            if not isEnabled then
                state = "disabled"
            elseif atLimit then
                state = "limit"
            elseif pressedBtn == btn then
                state = "pressed"
            elseif hoveredBtn == btn then
                state = "hover"
            end
            PaintStyled(part[2], part[3], Theme.stepper[state])
        end
    end

    local editBox = CreateFrame("EditBox", nil, holder)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetAutoFocus(false)
    local editContainer = StyleEditBox(editBox)
    editContainer:SetSize(VALUE_WIDTH + 4, BTN_SIZE)
    editContainer:SetPoint("LEFT", minusBtn, "RIGHT", 0, 0)
    editContainer:Hide()

    editBox:SetScript("OnEnterPressed", function(self)
        local num = tonumber(self:GetText())
        if num then
            ClampAndSet(num)
        end
        editContainer:Hide()
        valueBtn:Show()
    end)

    editBox:HookScript("OnEscapePressed", function()
        editContainer:Hide()
        valueBtn:Show()
    end)

    editBox:HookScript("OnEditFocusLost", function()
        editContainer:Hide()
        valueBtn:Show()
    end)

    -- Track editbox for focus cleanup on panel hide
    if panelEditBoxes then
        tinsert(panelEditBoxes, editBox)
    end

    valueBtn:SetScript("OnClick", function()
        if not isEnabled then
            return
        end
        valueBtn:Hide()
        editBox:SetText(tostring(floor(currentValue)))
        editContainer:Show()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    SetupTooltip(valueBtn, L["Component.AdjustValue"], L["Component.AdjustValue.Desc"], "ANCHOR_TOP")

    for _, btn in ipairs({ minusBtn, plusBtn }) do
        btn:SetScript("OnEnter", function(self)
            hoveredBtn = self
            UpdateButtonStates()
        end)
        btn:SetScript("OnLeave", function()
            hoveredBtn = nil
            pressedBtn = nil
            UpdateButtonStates()
        end)
        btn:SetScript("OnMouseDown", function(self)
            pressedBtn = self
            UpdateButtonStates()
        end)
        btn:SetScript("OnMouseUp", function()
            pressedBtn = nil
            UpdateButtonStates()
        end)
    end

    minusBtn:SetScript("OnClick", function()
        if isEnabled then
            ClampAndSet(currentValue - step)
        end
    end)
    plusBtn:SetScript("OnClick", function()
        if isEnabled then
            ClampAndSet(currentValue + step)
        end
    end)

    holder:EnableMouseWheel(true)
    holder:SetScript("OnMouseWheel", function(_, delta)
        if isEnabled then
            ClampAndSet(currentValue + delta * step)
        end
    end)

    UpdateValueText()

    function holder:SetValue(val)
        currentValue = max(config.min or 0, min(config.max or 100, val))
        UpdateValueText()
    end

    function holder:GetValue()
        return currentValue
    end

    function holder:SetEnabled(enabled)
        isEnabled = enabled
        -- An inherited value is real and applies, so it stays readable.
        local readable = enabled or (config.inherited and config.inherited())
        SetLabelEnabled(label, enabled)
        SetLabelEnabled(valueText, readable)
        if not enabled then
            editContainer:Hide()
            valueBtn:Show()
        end
        UpdateButtonStates()
    end

    -- Refresh method for OnShow pattern
    function holder:Refresh()
        if config.get then
            currentValue = config.get()
            UpdateValueText()
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- ============================================================================
-- COLOR SWATCH
-- ============================================================================

---@class ColorSwatchConfig : ComponentConfig
---@field label? string Display label
---@field get? fun(): number, number, number, number? Getter returning r, g, b [, a]
---@field enabled? fun(): boolean Getter for enabled state
---@field onChange fun(r: number, g: number, b: number, a?: number) Callback when color changes
---@field hasOpacity? boolean Show opacity/alpha slider (default false)
---@field labelWidth? number Width of label (default 70)

-- One swatch at a time owns the color picker. Its close callback runs when the
-- picker hides, or when another swatch takes the picker over.
local colorPickerOnClose
local colorPickerHooked = false

---@param onClose fun()
local function WatchColorPicker(onClose)
    if not colorPickerHooked then
        colorPickerHooked = true
        ColorPickerFrame:HookScript("OnHide", function()
            local callback = colorPickerOnClose
            colorPickerOnClose = nil
            if callback then
                callback()
            end
        end)
    end
    local previous = colorPickerOnClose
    colorPickerOnClose = onClose
    if previous and previous ~= onClose then
        previous()
    end
end

---Create a small color swatch that opens WoW's ColorPickerFrame on click
---@param parent table Parent frame
---@param config ColorSwatchConfig Configuration table
---@return table holder Frame containing color swatch with .SetColor(r,g,b,a?), .GetColor(), .SetEnabled(bool)
function Components.ColorSwatch(parent, config)
    -- Explicit labelWidth -> hard. Omitted -> auto-grow (or 0 if no label).
    local labelWidth
    if config.labelWidth ~= nil then
        labelWidth = config.labelWidth
    elseif config.label then
        labelWidth = max(70, MeasureTextWidth(config.label, "GameFontHighlightSmall") + 4)
    else
        labelWidth = 0
    end
    local SWATCH_SIZE = 16

    -- Reserve room after the swatch for "100%" alpha text (when present); a
    -- bigger font makes "100%" wider than the 50px floor.
    local alphaW = config.hasOpacity and (4 + MeasureTextWidth("100%", "GameFontHighlightSmall") + 4) or 0
    local trailingW = max(50, alphaW)

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + 5 + SWATCH_SIZE + trailingW, 20)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    if config.label then
        label:SetText(config.label)
    end
    holder.label = label
    SetTextColor(label, Theme.text)

    local swatchBtn = CreateFrame("Button", nil, holder)
    swatchBtn:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    swatchBtn:SetPoint("LEFT", label, "RIGHT", 5, 0)
    local swatchColors = Theme.swatch
    local swatchFill = swatchBtn:CreateTexture(nil, "BACKGROUND", nil, -7)
    swatchFill:SetAllPoints()
    local swatchEdge = CreateRing(swatchBtn, "BACKGROUND", -6, 0)
    PaintRing(CreateRing(swatchBtn, "BACKGROUND", -5, 1, true), swatchColors.inner)

    local currentR, currentG, currentB, currentA = 1, 1, 1, 1
    if config.get then
        local r, g, b, a = config.get()
        currentR, currentG, currentB = r, g, b
        currentA = a or 1
    end
    local isEnabled = true
    local isHovered, isPickerOpen = false, false
    local openEdge = swatchColors.open
    local function PaintSwatchEdge()
        local edge = swatchColors.normal
        if not isEnabled then
            edge = swatchColors.disabled
        elseif isPickerOpen and openEdge then
            edge = openEdge
        elseif isHovered then
            edge = swatchColors.hover
        end
        PaintRing(swatchEdge, edge)
    end

    local alphaText
    if config.hasOpacity then
        alphaText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        alphaText:SetPoint("LEFT", swatchBtn, "RIGHT", 4, 0)
        alphaText:SetWordWrap(false)
        alphaText:SetText(floor(currentA * 100) .. "%")
        SetTextColor(alphaText, Theme.text)
    end

    local function UpdateSwatchColor()
        swatchFill:SetColorTexture(currentR, currentG, currentB, 1)
        if alphaText then
            alphaText:SetText(floor(currentA * 100) .. "%")
        end
    end
    UpdateSwatchColor()
    PaintSwatchEdge()

    swatchBtn:SetScript("OnEnter", function()
        isHovered = true
        PaintSwatchEdge()
    end)
    swatchBtn:SetScript("OnLeave", function()
        isHovered = false
        PaintSwatchEdge()
    end)

    swatchBtn:SetScript("OnClick", function()
        if not isEnabled then
            return
        end
        -- The watch runs the close callback of the previous owner, which can be this swatch.
        WatchColorPicker(function()
            isPickerOpen = false
            PaintSwatchEdge()
        end)
        isPickerOpen = true
        PaintSwatchEdge()
        local prevR, prevG, prevB, prevA = currentR, currentG, currentB, currentA
        local info = {
            r = currentR,
            g = currentG,
            b = currentB,
            hasOpacity = config.hasOpacity or false,
            opacity = config.hasOpacity and currentA or nil,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                currentR, currentG, currentB = r, g, b
                if config.hasOpacity then
                    currentA = ColorPickerFrame:GetColorAlpha()
                end
                UpdateSwatchColor()
                config.onChange(currentR, currentG, currentB, config.hasOpacity and currentA or nil)
            end,
            cancelFunc = function()
                currentR, currentG, currentB, currentA = prevR, prevG, prevB, prevA
                UpdateSwatchColor()
                config.onChange(prevR, prevG, prevB, config.hasOpacity and prevA or nil)
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    function holder:SetColor(r, g, b, a)
        currentR, currentG, currentB = r, g, b
        if a then
            currentA = a
        end
        UpdateSwatchColor()
    end

    function holder:GetColor()
        return currentR, currentG, currentB, currentA
    end

    function holder:SetEnabled(enabled)
        isEnabled = enabled
        SetLabelEnabled(label, enabled)
        if alphaText then
            SetLabelEnabled(alphaText, enabled)
        end
        swatchBtn:SetAlpha(enabled and 1 or 0.35)
        PaintSwatchEdge()
    end

    -- Refresh method for OnShow pattern
    function holder:Refresh()
        if config.get then
            local r, g, b, a = config.get()
            currentR, currentG, currentB = r, g, b
            currentA = a or 1
            UpdateSwatchColor()
        end
        if config.enabled then
            holder:SetEnabled(config.enabled())
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

---Paint a legacy scrollbar: a track with a 1 px edge and a thumb with hover and
---drag states. The thumb texture keeps its role as the drag handle, so its
---proportional height and hit area do not change.
---@param scrollBar table
---@param thumb? table
local function DecorateScrollbar(scrollBar, thumb)
    local colors = Theme.scrollbar
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOPLEFT", colors.trackInset, 0)
    track:SetPoint("BOTTOMRIGHT", -colors.trackInset, 0)
    PaintGradient(track, "HORIZONTAL", colors.trackLeft, colors.trackRight)
    local frame = CreateFrame("Frame", nil, scrollBar)
    frame:SetAllPoints(track)
    frame:EnableMouse(false)
    PaintRing(CreateRing(frame, "BACKGROUND", 0, 0, true), colors.trackEdge)
    if not thumb then
        return
    end

    thumb:SetSize(6, 40)
    local sheen = scrollBar:CreateTexture(nil, "OVERLAY", nil, 7)
    sheen:SetPoint("TOPLEFT", thumb, "TOPLEFT", 0, 0)
    sheen:SetPoint("TOPRIGHT", thumb, "TOPRIGHT", 0, 0)
    sheen:SetHeight(1)
    SetColorTexture(sheen, colors.sheen)

    local isHovered, isDragging = false, false
    local dragColors = colors.drag
    local function Paint()
        local state = colors.normal
        if isDragging and dragColors then
            state = dragColors
        elseif isHovered then
            state = colors.hover
        end
        PaintGradient(thumb, "HORIZONTAL", state.left, state.right)
    end
    scrollBar:HookScript("OnEnter", function()
        isHovered = true
        Paint()
    end)
    scrollBar:HookScript("OnLeave", function()
        isHovered = false
        Paint()
    end)
    scrollBar:HookScript("OnMouseDown", function()
        isDragging = true
        Paint()
    end)
    scrollBar:HookScript("OnMouseUp", function()
        isDragging = false
        Paint()
    end)
    Paint()
end

local function ApplyModernScrollbarStyle(scrollBar)
    if not scrollBar then
        return
    end

    local trackBg = scrollBar.trackBg or scrollBar.Track
    if trackBg then
        trackBg:SetAlpha(0)
    end

    -- Try to find and hide the track textures
    for _, region in pairs({ scrollBar:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            local name = region:GetName() or ""
            if name:find("Track") or name:find("Border") or name:find("BG") then
                region:SetAlpha(0)
            end
        end
    end

    -- The thumb height is managed proportionally by SetupProportionalScrollbar.
    DecorateScrollbar(scrollBar, scrollBar.ThumbTexture or scrollBar.thumbTexture)

    local scrollUp = scrollBar.ScrollUpButton or scrollBar.scrollUp or _G[scrollBar:GetName() .. "ScrollUpButton"]
    local scrollDown = scrollBar.ScrollDownButton
        or scrollBar.scrollDown
        or _G[scrollBar:GetName() .. "ScrollDownButton"]
    if scrollUp then
        scrollUp:SetAlpha(0)
        scrollUp:SetSize(1, 1)
        scrollUp:EnableMouse(false)
    end
    if scrollDown then
        scrollDown:SetAlpha(0)
        scrollDown:SetSize(1, 1)
        scrollDown:EnableMouse(false)
    end
end

-- Size a legacy scrollbar's thumb to reflect how much content there is (thumb
-- length = viewport / content), and hide the whole bar when the page fits. Hooked
-- to the scroll frame's range/size events so it stays correct as pages rebuild.
local SCROLLBAR_MIN_THUMB = 24
local SCROLLBAR_MAX_THUMB_RATIO = 0.28 -- keep the handle compact, never near-full-track
local function SetupProportionalScrollbar(scrollFrame, scrollBar)
    local thumb = scrollBar.ThumbTexture or scrollBar.thumbTexture
    local function Update()
        local viewH = scrollFrame:GetHeight() or 0
        local range = scrollFrame:GetVerticalScrollRange() or 0
        if range <= 1 or viewH <= 0 then
            scrollBar:Hide()
            return
        end
        scrollBar:Show()
        if thumb then
            local trackH = scrollBar:GetHeight() or viewH
            local contentH = viewH + range
            local cap = floor(trackH * SCROLLBAR_MAX_THUMB_RATIO)
            local thumbH = min(floor(trackH * viewH / contentH), cap)
            thumb:SetHeight(max(thumbH, min(SCROLLBAR_MIN_THUMB, trackH)))
        end
    end
    scrollFrame:HookScript("OnScrollRangeChanged", Update)
    scrollFrame:HookScript("OnSizeChanged", Update)
    scrollFrame:HookScript("OnShow", Update)
    Update() -- sync initial state before any event fires
end

---@class TextAreaConfig : ComponentConfig
---@field width number Width of the text area
---@field height number Height of the text area
---@field readOnly? boolean If true, text cannot be edited (default false)
---@field onTextChanged? fun(text: string) Callback when text changes
---@field onFocusGained? fun() Callback when focus gained
---@field onFocusLost? fun() Callback when focus lost

---Create a multiline text area (no scrollbar, mouse wheel scrolls)
---@param parent table Parent frame
---@param config TextAreaConfig Configuration table
---@return table holder Frame with .editBox, .SetText(v), .GetText(), .HighlightText(), .SetFocus()
function Components.TextArea(parent, config)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(config.width, config.height)

    local scrollFrame = CreateFrame("ScrollFrame", nil, holder)
    scrollFrame:SetPoint("TOPLEFT", 1, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", -1, 1)
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = max(0, self:GetScrollChild():GetHeight() - self:GetHeight())
        local newScroll = max(0, min(maxScroll, current - delta * 20))
        self:SetVerticalScroll(newScroll)
    end)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetSize(config.width - 4, config.height)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(6, 6, 6, 6)
    editBox:EnableMouse(true)

    if config.readOnly then
        editBox:SetScript("OnChar", function() end)
        editBox:SetScript("OnKeyDown", function() end)
    end

    scrollFrame:SetScrollChild(editBox)
    holder.editBox = editBox
    holder.scrollFrame = scrollFrame

    editBox:SetScript("OnEditFocusGained", function(self)
        if config.onFocusGained then
            config.onFocusGained()
        end
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        if config.onFocusLost then
            config.onFocusLost()
        end
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local _, fontHeight = self:GetFont()
        local lineCount = select(2, string.gsub(text, "\n", "\n")) + 1
        local contentHeight = max(config.height - 4, fontHeight * lineCount + 12)
        self:SetHeight(contentHeight)

        if config.onTextChanged then
            config.onTextChanged(text)
        end
    end)

    -- After the SetScript calls above, so they do not replace the paint hooks.
    DecorateEditBox(holder, editBox)
    if config.readOnly then
        holder:SetBoxTextColor(Theme.editBox.readOnly)
    end

    -- Track editbox for focus cleanup
    if panelEditBoxes then
        tinsert(panelEditBoxes, editBox)
    end

    function holder:SetText(text)
        editBox:SetText(text or "")
    end

    function holder:GetText()
        return editBox:GetText()
    end

    function holder:HighlightText()
        editBox:HighlightText()
    end

    function holder:SetFocus()
        editBox:SetFocus()
    end

    function holder:ClearFocus()
        editBox:ClearFocus()
    end

    return holder
end

-- ============================================================================
-- APPEARANCE GRID
-- ============================================================================
-- Declarative 2-column, 3-row grid of appearance controls:
--   Row 1: Width [link] Height
--   Row 2: Zoom         Border
--   Row 3: Spacing      Alpha

---@class AppearanceGridConfig
---@field get fun(key: string, default: any): any  Read setting value
---@field set fun(key: string, value: any)          Write setting value
---@field setMulti fun(changes: table)              Batch write settings
---@field isLinked fun(): boolean                   Are width/height linked?
---@field onLink fun()                              Called when user re-links dimensions
---@field onUnlink fun()                            Called when user unlinks dimensions
---@field enabled? fun(): boolean                   Wraps all controls (nil = always enabled)
---@field masqueCheck? fun(): boolean               Returns true when Masque is active (disables zoom/border)
---@field inherited? fun(): boolean                 True while the values follow the Defaults page
---@field disabledReason? string|fun(): string     Hover text while `enabled` returns false
---@field labelWidth? number                        Shared label column; omitted = measured from the grid labels
---@field spacingPx? boolean                       Spacing in absolute pixels (0-32), not a fraction of the icon width
---@field zoomMax? number                           Zoom slider maximum (default 15)
---@field borderBlocked? fun(): boolean               True when the border does not draw (disables the border slider)
---@field borderBlockedReason? string|fun(): string Hover text while `borderBlocked` returns true

---Text size stepper + color swatch on one row. The swatch writes textColor and
---textAlpha as a pair.
---@param parent Frame
---@param config AppearanceGridConfig Same get/set/setMulti/enabled contract as AppearanceGrid
---@param labelWidth number?
---@return Frame holder The size stepper; the swatch is anchored to its right
function Components.TextStyleRow(parent, config, labelWidth)
    local enabled = config.enabled

    local sizeHolder = Components.NumericStepper(parent, {
        label = L["Appearance.Text"],
        labelWidth = labelWidth,
        min = 6,
        max = 32,
        get = function()
            return config.get("textSize", BR.defaults.defaults.textSize)
        end,
        enabled = enabled,
        inherited = config.inherited,
        disabledReason = config.disabledReason,
        onChange = function(val)
            config.set("textSize", val)
        end,
    })

    local colorHolder = Components.ColorSwatch(parent, {
        hasOpacity = true,
        get = function()
            local tc = config.get("textColor", { 1, 1, 1 })
            local ta = config.get("textAlpha", 1)
            return tc[1], tc[2], tc[3], ta
        end,
        enabled = enabled,
        onChange = function(r, g, b, a)
            config.setMulti({
                textColor = { r, g, b },
                textAlpha = a or 1,
            })
        end,
    })
    colorHolder:SetPoint("LEFT", sizeHolder, "RIGHT", 12, 0)

    sizeHolder.colorSwatch = colorHolder
    return sizeHolder
end

---Create a 2-column appearance grid with standard layout
---@param parent Frame
---@param config AppearanceGridConfig
---@return {frame: Frame, height: number, holders: table, labelWidth: number}
function Components.AppearanceGrid(parent, config)
    -- Compute label width from the longest row label so columns align
    -- regardless of locale or font replacement. The grid is icon geometry only;
    -- text size and color live in Components.TextStyleRow.
    local labels = {
        L["Appearance.Width"],
        L["Appearance.Height"],
        L["Appearance.Zoom"],
        L["Appearance.Border"],
        L["Appearance.Spacing"],
        L["Appearance.Alpha"],
    }
    local LW = 50
    for _, t in ipairs(labels) do
        local w = MeasureTextWidth(t, "GameFontHighlightSmall") + 4
        if w > LW then
            LW = w
        end
    end
    LW = max(LW, config.labelWidth or 0)

    -- Conservative value-box width estimate: sliders auto-size their own value
    -- text but COL2 needs to clear the widest possible col-1 right edge so
    -- col-2 widgets never overlap. "100%" is the widest display string used.
    local SLIDER_W = 100
    local VALUE_W = max(40, MeasureTextWidth("100%", "GameFontHighlightSmall") + 8)
    local LINK_BTN_W = 16
    local LINK_X = LW + 5 + SLIDER_W + 6 + VALUE_W + 6
    local COL2 = LINK_X + LINK_BTN_W + 8
    local ROW_H = max(24, MeasureTextHeight("Wg", "GameFontHighlightSmall") + 8)
    local FRAME_W = COL2 + LW + 5 + SLIDER_W + 6 + VALUE_W + 12
    local GRID_HEIGHT = ROW_H * 3

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT")
    frame:SetSize(FRAME_W, GRID_HEIGHT)

    local enabled = config.enabled
    local masqueCheck = config.masqueCheck

    local function baseEnabled()
        return not enabled or enabled()
    end
    local function masqueEnabled()
        return baseEnabled() and (not masqueCheck or not masqueCheck())
    end

    -- Masque owns zoom and border, so they are neither inherited nor overridable.
    local function masqueActive()
        return masqueCheck ~= nil and masqueCheck()
    end
    local function masqueInherited()
        return config.inherited ~= nil and config.inherited() and not masqueActive()
    end
    local function masqueDisabledReason()
        if masqueActive() then
            return L["Options.MasqueNote"]
        end
        local reason = config.disabledReason
        if type(reason) == "function" then
            return reason()
        end
        return reason
    end

    -- Forward declarations for cross-refresh
    local widthHolder, heightHolder

    widthHolder = Components.Slider(frame, {
        label = L["Appearance.Width"],
        min = 16,
        max = 128,
        labelWidth = LW,
        inherited = config.inherited,
        disabledReason = config.disabledReason,
        get = function()
            local w = config.get("iconWidth", nil)
            return w or config.get("iconSize", 64)
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(val)
            if config.isLinked() then
                config.set("iconSize", val)
            else
                config.set("iconWidth", val)
            end
            if heightHolder then
                heightHolder:Refresh()
            end
        end,
    })
    widthHolder:SetPoint("TOPLEFT", 0, 0)

    local linkBtn = Components.DimensionLink(frame, {
        isLinked = config.isLinked,
        enabled = enabled and baseEnabled or nil,
        onLink = config.onLink,
        onUnlink = config.onUnlink,
    })
    linkBtn:SetPoint("TOPLEFT", LINK_X, 0)

    heightHolder = Components.Slider(frame, {
        label = L["Appearance.Height"],
        min = 16,
        max = 128,
        labelWidth = LW,
        inherited = config.inherited,
        disabledReason = config.disabledReason,
        get = function()
            return config.get("iconSize", 64)
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(val)
            config.set("iconSize", val)
            if widthHolder then
                widthHolder:Refresh()
            end
        end,
    })
    heightHolder:SetPoint("TOPLEFT", COL2, 0)

    local zoomHolder = Components.Slider(frame, {
        label = L["Appearance.Zoom"],
        min = 0,
        max = config.zoomMax or 15,
        labelWidth = LW,
        inherited = masqueInherited,
        disabledReason = masqueDisabledReason,
        suffix = "%",
        get = function()
            return config.get("iconZoom", BR.DEFAULT_ICON_ZOOM)
        end,
        enabled = masqueCheck and masqueEnabled or (enabled and baseEnabled or nil),
        onChange = function(val)
            config.set("iconZoom", val)
        end,
    })
    zoomHolder:SetPoint("TOPLEFT", 0, -ROW_H)

    local borderEnabled = masqueCheck and masqueEnabled or (enabled and baseEnabled or nil)
    local borderInherited, borderDisabledReason = masqueInherited, masqueDisabledReason
    local borderBlocked = config.borderBlocked
    if borderBlocked then
        local gate = borderEnabled
        borderEnabled = function()
            return (not gate or gate()) and not borderBlocked()
        end
        borderInherited = function()
            return masqueInherited() and not borderBlocked()
        end
        borderDisabledReason = function()
            if not masqueActive() and borderBlocked() then
                return ResolveDisabledReason(config.borderBlockedReason)
            end
            return masqueDisabledReason()
        end
    end

    local borderHolder = Components.Slider(frame, {
        label = L["Appearance.Border"],
        min = 0,
        max = 8,
        labelWidth = LW,
        inherited = borderInherited,
        disabledReason = borderDisabledReason,
        suffix = "px",
        get = function()
            return config.get("borderSize", BR.DEFAULT_BORDER_SIZE)
        end,
        enabled = borderEnabled,
        onChange = function(val)
            config.set("borderSize", val)
        end,
    })
    borderHolder:SetPoint("TOPLEFT", COL2, -ROW_H)

    -- Spacing is a fraction of the icon width, or absolute pixels with spacingPx.
    local spacingPx = config.spacingPx == true
    local spacingHolder = Components.Slider(frame, {
        label = L["Appearance.Spacing"],
        min = 0,
        max = spacingPx and 32 or 50,
        labelWidth = LW,
        inherited = config.inherited,
        disabledReason = config.disabledReason,
        suffix = spacingPx and "px" or "%",
        get = function()
            if spacingPx then
                return config.get("spacing", 4)
            end
            return floor((config.get("spacing", 0.2)) * 100)
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(val)
            config.set("spacing", spacingPx and val or val / 100)
        end,
    })
    spacingHolder:SetPoint("TOPLEFT", 0, -ROW_H * 2)

    local alphaHolder = Components.Slider(frame, {
        label = L["Appearance.Alpha"],
        min = 10,
        max = 100,
        labelWidth = LW,
        inherited = config.inherited,
        disabledReason = config.disabledReason,
        suffix = "%",
        get = function()
            return floor((config.get("iconAlpha", 1)) * 100)
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(val)
            config.set("iconAlpha", val / 100)
        end,
    })
    alphaHolder:SetPoint("TOPLEFT", COL2, -ROW_H * 2)

    frame:SetSize(FRAME_W, GRID_HEIGHT)

    return {
        frame = frame,
        height = GRID_HEIGHT,
        labelWidth = LW,
        holders = {
            width = widthHolder,
            height = heightHolder,
            link = linkBtn,
            zoom = zoomHolder,
            border = borderHolder,
            spacing = spacingHolder,
            alpha = alphaHolder,
        },
    }
end

---Initialize panelEditBoxes reference (called from CreateOptionsPanel)
---@param editBoxes table[] The editboxes array from the options panel
function Components.SetEditBoxesRef(editBoxes)
    panelEditBoxes = editBoxes
end

---True when nothing in the frame's ancestry reaches UIParent, which is how a
---dialog signals that it tore its body down (SetParent(nil) on the body).
local function IsDetached(frame)
    local node = frame
    while node do
        if node == UIParent then
            return false
        end
        node = node.GetParent and node:GetParent() or nil
    end
    return true
end

---Drop tracked edit boxes whose dialog body is gone. Every edit box a factory
---builds registers here, including the ones in a dialog that rebuilds its body
---per open, so without this the list grows for the whole session. Call it from
---a dialog teardown after the body is unparented. Mirrors the auto-prune in
---RefreshAll. Iterate in reverse so table.remove during the walk is safe.
function Components.PruneEditBoxes()
    if not panelEditBoxes then
        return
    end
    for i = #panelEditBoxes, 1, -1 do
        if IsDetached(panelEditBoxes[i]) then
            table.remove(panelEditBoxes, i)
        end
    end
end

---Clear focus on every tracked edit box that is still attached.
function Components.ClearEditBoxFocus()
    Components.PruneEditBoxes()
    if not panelEditBoxes then
        return
    end
    for _, editBox in ipairs(panelEditBoxes) do
        editBox:ClearFocus()
    end
end

---Refresh all registered components (call on panel OnShow)
---
---Drops each holder whose ancestry no longer reaches UIParent instead of
---refreshing it. A teardown unparents a body frame, not each holder, so a
---direct GetParent() check misses the holders inside that body.
---Plain refresh hooks (tables without a frame) have no GetParent and are never
---pruned. Iterate in reverse so table.remove during the walk is safe.
function Components.RefreshAll()
    for i = #RefreshableComponents, 1, -1 do
        local component = RefreshableComponents[i]
        if component.GetParent and IsDetached(component) then
            table.remove(RefreshableComponents, i)
        elseif component.Refresh then
            component:Refresh()
        end
    end
end

---Unregister a single holder from the refresh registry.
---Use when tearing down dynamic components whose parent frame is being destroyed,
---so Components.RefreshAll() does not keep invoking their :Refresh() on stale state.
---@param holder table Component holder previously added via a factory
function Components.Unregister(holder)
    if not holder then
        return
    end
    for i = #RefreshableComponents, 1, -1 do
        if RefreshableComponents[i] == holder then
            table.remove(RefreshableComponents, i)
            return
        end
    end
end

---Create a scrollable content container with auto-calculated width
---@param parent Frame Parent frame
---@param config ScrollableContainerConfig Configuration table
---@return table scrollFrame Scroll frame with :GetContentFrame(), :SetContentHeight(h), :GetContentWidth()
---@return table content Content frame
function Components.ScrollableContainer(parent, config)
    local contentHeight = config.contentHeight or 600
    local scrollbarWidth = config.scrollbarWidth or 24
    -- Explicit width is required when this container is nested inside a
    -- larger parent (e.g. a sub-list inside a page). Without it, contentWidth
    -- comes from parent:GetWidth() and overflows the visible scroll area: the
    -- caller sizes the scroll frame smaller than the parent, but the inner
    -- content child cannot know that.
    local explicitWidth = config.width

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetClipsChildren(true)
    if explicitWidth then
        scrollFrame:SetWidth(explicitWidth)
    end

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -18, -4)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -18, 4)
        ApplyModernScrollbarStyle(scrollBar)
        SetupProportionalScrollbar(scrollFrame, scrollBar)
    end

    -- Fixed wheel step. The template's default steps by half the scrollbar height,
    -- which jumps ~half a page per tick on a tall bar; a fixed step (~1.5 rows)
    -- feels consistent regardless of page length.
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self:GetVerticalScrollRange() or 0
        local newScroll = max(0, min(maxScroll, self:GetVerticalScroll() - delta * 45))
        self:SetVerticalScroll(newScroll)
    end)

    -- Content frame. Width tracks the scroll frame's visible area minus the
    -- scrollbar so anchored-RIGHT children clear the scrollbar instead of
    -- being painted under it.
    local content = CreateFrame("Frame", nil, scrollFrame)
    local effectiveWidth = explicitWidth or (parent.GetWidth and parent:GetWidth() or 540)
    local contentWidth = effectiveWidth - scrollbarWidth
    content:SetSize(contentWidth, contentHeight)
    scrollFrame:SetScrollChild(content)

    -- Edge fades show that content continues past an edge. They live on a
    -- mouse-transparent overlay above the scrolling child and stop short of the
    -- scrollbar column.
    local fadeOverlay = CreateFrame("Frame", nil, scrollFrame)
    fadeOverlay:SetAllPoints(scrollFrame)
    fadeOverlay:SetFrameLevel(scrollFrame:GetFrameLevel() + 20)
    fadeOverlay:EnableMouse(false)

    local FADE_HEIGHT = Theme.scrollFade.height
    local fadeColor = Theme.scrollFade.color
    local opaque = CreateColor(fadeColor[1], fadeColor[2], fadeColor[3], fadeColor[4])
    local clear = CreateColor(fadeColor[1], fadeColor[2], fadeColor[3], 0)
    local function MakeFade(edge, bottomColor, topColor)
        local tex = fadeOverlay:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(1, 1, 1)
        tex:SetHeight(FADE_HEIGHT)
        tex:SetPoint(edge .. "LEFT", 0, 0)
        tex:SetPoint(edge .. "RIGHT", -scrollbarWidth, 0)
        -- SetGradient VERTICAL: first color is the bottom vertex, second the top.
        tex:SetGradient("VERTICAL", bottomColor, topColor)
        tex:Hide()
        return tex
    end
    local topFade = MakeFade("TOP", clear, opaque) -- opaque at the very top edge
    local bottomFade = MakeFade("BOTTOM", opaque, clear) -- opaque at the very bottom edge

    local function UpdateFades()
        local scroll = scrollFrame:GetVerticalScroll() or 0
        local range = scrollFrame:GetVerticalScrollRange() or 0
        topFade:SetShown(scroll > 1)
        bottomFade:SetShown(range - scroll > 1)
    end
    scrollFrame:HookScript("OnVerticalScroll", UpdateFades)
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateFades)
    scrollFrame:HookScript("OnSizeChanged", UpdateFades)
    scrollFrame:HookScript("OnShow", UpdateFades)
    UpdateFades()

    function scrollFrame:GetContentFrame()
        return content
    end

    function scrollFrame:GetContentWidth()
        return contentWidth
    end

    function scrollFrame:GetContentHeight()
        return contentHeight
    end

    function scrollFrame:SetContentHeight(height)
        contentHeight = height
        content:SetHeight(height)
    end

    return scrollFrame, content
end

---Create a vertical layout helper for positioning elements
---@param parent table Parent frame
---@param config VerticalLayoutConfig Configuration table
---@return table layout Layout helper with :Add(component, spacing), :AddText(fontString, height), :Space(amount), :GetY()
function Components.VerticalLayout(parent, config)
    local x = config.x or 0
    local y = config.y or 0
    local currentY = y

    local layout = {}
    -- Every frame anchored through :Add/:AddText/:AddRow, so :ShiftAllBy can
    -- re-anchor the whole stack.
    local items = {}
    -- Every advance in order, so :Reflow can replay the stack after a block
    -- added with :AddDynamic changes height.
    local steps = {}

    ---Add a component at the current Y position and advance
    ---@param component table Component frame to position
    ---@param height? number Height to advance (uses component height if not specified)
    ---@param spacing? number Extra spacing after component (default 0)
    function layout:Add(component, height, spacing)
        component:SetPoint("TOPLEFT", parent, "TOPLEFT", x, currentY)
        tinsert(items, { frame = component, x = x, y = currentY })
        -- A component with dynamic height (e.g. Banner) must recompute after it
        -- is anchored, before :Add reads the height.
        if not height and component.FitHeight then
            component:FitHeight()
        end
        local advanceHeight = height or (component.GetHeight and component:GetHeight()) or 20
        tinsert(steps, { frames = { component }, xs = { x }, height = advanceHeight, spacing = spacing or 0 })
        currentY = currentY - advanceHeight - (spacing or 0)
    end

    ---Add a component whose height can change after the build. Call :Reflow
    ---after the change, so everything below it moves.
    ---@param component table
    ---@param heightFn fun(): number Current height to advance
    ---@param spacing? number
    function layout:AddDynamic(component, heightFn, spacing)
        component:SetPoint("TOPLEFT", parent, "TOPLEFT", x, currentY)
        tinsert(items, { frame = component, x = x, y = currentY })
        tinsert(steps, { frames = { component }, xs = { x }, heightFn = heightFn, spacing = spacing or 0 })
        currentY = currentY - heightFn() - (spacing or 0)
    end

    ---Add a font string at the current Y position and advance
    ---@param fontString table FontString to position
    ---@param height number Height to advance
    ---@param spacing? number Extra spacing after text (default 0)
    function layout:AddText(fontString, height, spacing)
        fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, currentY)
        tinsert(items, { frame = fontString, x = x, y = currentY })
        tinsert(steps, { frames = { fontString }, xs = { x }, height = height, spacing = spacing or 0 })
        currentY = currentY - height - (spacing or 0)
    end

    ---Add vertical space
    ---@param amount number Space to add
    function layout:Space(amount)
        tinsert(steps, { height = amount, spacing = 0 })
        currentY = currentY - amount
    end

    ---Replay every advance with the current height of each :AddDynamic block.
    ---A frame that the caller re-anchored to a sibling keeps its own anchor.
    function layout:Reflow()
        local cy = y
        for _, step in ipairs(steps) do
            if step.frames then
                for i, frame in ipairs(step.frames) do
                    local _, relativeTo = frame:GetPoint(1)
                    if relativeTo == parent then
                        frame:ClearAllPoints()
                        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", step.xs[i], cy)
                    end
                end
            end
            cy = cy - (step.heightFn and step.heightFn() or step.height) - step.spacing
        end
        currentY = cy
    end

    ---Get current Y position
    ---@return number
    function layout:GetY()
        return currentY
    end

    ---Set X position for subsequent items
    ---@param newX number New X position
    function layout:SetX(newX)
        x = newX
    end

    ---Get current X position
    ---@return number
    function layout:GetX()
        return x
    end

    ---Add multiple components on the same row, advancing Y by the tallest
    ---@param rowItems table[] Array of {component, xOffset} pairs
    ---@param spacing? number Extra spacing after row (default 0)
    function layout:AddRow(rowItems, spacing)
        local maxH = 0
        local step = { frames = {}, xs = {}, spacing = spacing or 0 }
        for _, item in ipairs(rowItems) do
            local comp, xOff = item[1], item[2]
            comp:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, currentY)
            tinsert(items, { frame = comp, x = xOff, y = currentY })
            tinsert(step.frames, comp)
            tinsert(step.xs, xOff)
            local h = (comp.GetHeight and comp:GetHeight()) or 20
            if h > maxH then
                maxH = h
            end
        end
        step.height = maxH
        tinsert(steps, step)
        currentY = currentY - maxH - (spacing or 0)
    end

    ---Re-anchor every frame added so far by `dy` (negative = down). Used to
    ---vertically center a finished dialog body. Only re-anchors frames anchored
    ---directly via :Add/:AddText/:AddRow - frames the caller later re-pointed to
    ---a sibling ride along with their anchor automatically.
    ---@param dy number Pixels to shift (added to each frame's stored Y offset)
    function layout:ShiftAllBy(dy)
        if dy == 0 then
            return
        end
        for _, item in ipairs(items) do
            item.frame:ClearAllPoints()
            item.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", item.x, item.y + dy)
        end
    end

    return layout
end

-- ============================================================================
-- BANNER
-- ============================================================================

---Create a warning banner with left accent bar and muted background
---@param parent table Parent frame
---@param config {text: string, icon?: string, color?: string, visible?: function, height?: number, bgAlpha?: number}
---@return table holder Banner frame with :Refresh(), :SetText()
function Components.Banner(parent, config)
    local ICON_SIZE = 14
    local ICON_LEFT = 10
    local ICON_GAP = 6
    local TEXT_RIGHT_PAD = 8
    local TEXT_VERT_PAD = 12 -- padding above and below the text
    local TEXT_NONFLOW_W = ICON_LEFT + ICON_SIZE + ICON_GAP + TEXT_RIGHT_PAD -- the width that is not text

    local hasExplicitHeight = config.height ~= nil
    local BANNER_MIN = 26
    -- Initial height is one line plus padding. FitHeight refines it once the
    -- holder has a width.
    local BANNER_HEIGHT = config.height
        or max(BANNER_MIN, MeasureTextHeight("Wg", "GameFontHighlightSmall") + TEXT_VERT_PAD)

    -- Color presets: "red" (warning) or "orange" (info)
    local c = Theme.banner[config.color] or Theme.banner.red

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(BANNER_HEIGHT)

    local bg = holder:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local bgColor = { unpack(c.bg) }
    if config.bgAlpha then
        bgColor[4] = config.bgAlpha
    end
    bg:SetColorTexture(unpack(bgColor))

    local accentBottom = holder:CreateTexture(nil, "ARTWORK")
    accentBottom:SetPoint("BOTTOMLEFT")
    accentBottom:SetPoint("BOTTOMRIGHT")
    accentBottom:SetHeight(1.5)
    SetColorTexture(accentBottom, c.accentBottom)
    local accentLeft = holder:CreateTexture(nil, "ARTWORK")
    accentLeft:SetPoint("TOPLEFT")
    accentLeft:SetPoint("BOTTOMLEFT")
    accentLeft:SetWidth(2)
    SetColorTexture(accentLeft, c.accentLeft)
    local bottomLine = holder:CreateTexture(nil, "ARTWORK")
    bottomLine:SetPoint("BOTTOMLEFT")
    bottomLine:SetPoint("BOTTOMRIGHT")
    bottomLine:SetHeight(1)
    SetColorTexture(bottomLine, c.line)

    -- Icon (supports atlas names or texture file paths)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", ICON_LEFT, 0)
    local iconPath = config.icon or "services-icon-warning"
    if iconPath:find("\\") or iconPath:find("/") then
        icon:SetTexture(iconPath)
    else
        icon:SetAtlas(iconPath)
    end

    -- Text. Wrap is left enabled so long localized strings flow to multiple
    -- lines instead of clipping; the holder grows vertically to fit (see
    -- OnSizeChanged below). The caller can pin a fixed height via config.height.
    local text = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", ICON_GAP, 0)
    text:SetPoint("RIGHT", -TEXT_RIGHT_PAD, 0)
    text:SetJustifyH("LEFT")
    text:SetText(config.text or "")
    text:SetTextColor(unpack(c.text))

    -- Recompute holder height to fit wrapped text given the current width.
    -- Skipped when caller pinned an explicit height.
    -- IMPORTANT: callers using auto-fit must set BOTH anchors (TOPLEFT/LEFT
    -- and RIGHT) before calling :FitHeight(); the OnSizeChanged hook is a
    -- defensive backup for parent resizes, but the initial layout must
    -- call FitHeight synchronously so siblings positioned afterward see the
    -- final height. VerticalLayout:Add does this automatically.
    local lastWidth
    function holder:FitHeight()
        if hasExplicitHeight then
            return
        end
        local w = holder:GetWidth()
        if w <= 0 then
            return
        end
        local textW = w - TEXT_NONFLOW_W
        if textW <= 0 then
            return
        end
        local h = MeasureWrappedHeight(text:GetText(), "GameFontHighlightSmall", textW)
        if h <= 0 then
            return
        end
        local newH = max(BANNER_MIN, h + TEXT_VERT_PAD)
        if newH ~= holder:GetHeight() then
            holder:SetHeight(newH)
        end
    end

    holder:SetScript("OnSizeChanged", function(_, w)
        -- Respond to width changes only: a height change re-fires OnSizeChanged.
        if w == lastWidth then
            return
        end
        lastWidth = w
        holder:FitHeight()
    end)

    function holder:SetText(newText)
        text:SetText(newText)
        holder:FitHeight()
    end

    function holder:Refresh()
        if config.visible then
            holder:SetShown(config.visible())
        end
    end

    if config.visible then
        tinsert(RefreshableComponents, holder)
    end

    return holder
end
