local _, BR = ...

-- Shared palette tokens (BR.Colors), unpacked once so the per-widget calls below
-- avoid re-indexing the palette table on every build.
local BORDER_R, BORDER_G, BORDER_B = unpack(BR.Colors.Border)
local ACCENT_R, ACCENT_G, ACCENT_B = unpack(BR.Colors.Accent)

-- ============================================================================
-- UI COMPONENT FACTORY
-- ============================================================================
-- Reusable UI components for the options panel
-- These reduce code duplication and provide consistent styling.

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

---@class CollapsibleSectionConfig
---@field title string Header text
---@field defaultCollapsed? boolean Start collapsed (default true)
---@field width? number Optional explicit width override
---@field scrollbarOffset? number Offset to subtract from parent width (used when width not specified)
---@field onToggle? fun(expanded: boolean) Optional callback when toggled

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
local format = string.format
local rad = math.rad
local tinsert = table.insert
local tremove = table.remove

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

-- Wrapped height for a known bounded width. Used by widgets (e.g. Banner)
-- that allow text to flow to multiple lines and need to grow vertically.
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

---Show a tooltip on a widget (title in white, optional description in grey)
---@param owner table Frame that owns the tooltip
---@param title string Tooltip title
---@param desc? string Optional description line
---@param anchor? string Anchor point (default "ANCHOR_RIGHT")
local function ShowTooltip(owner, title, desc, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if desc then
        GameTooltip:AddLine(desc, 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
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
    holder:EnableMouse(true)
    holder:HookScript("OnEnter", function()
        if isEnabledFn() then
            return
        end
        ShowTooltip(holder, L["Component.DisabledReason.Title"], ResolveDisabledReason(reason), "ANCHOR_TOP")
    end)
    holder:HookScript("OnLeave", function()
        if not isEnabledFn() then
            HideTooltip()
        end
    end)
end

-- ============================================================================
-- BUTTON
-- ============================================================================

-- Modern button color constants
local ButtonColors = {
    bg = { 0.15, 0.15, 0.15, 1 },
    bgHover = { 0.22, 0.22, 0.22, 1 },
    bgPressed = { 0.12, 0.12, 0.12, 1 },
    border = BR.Colors.Border,
    borderHover = { 0.5, 0.5, 0.5, 1 },
    borderPressed = BR.Colors.Accent,
    borderDisabled = { 0.25, 0.25, 0.25, 1 },
    text = { 1, 1, 1, 1 },
    textDisabled = { 0.5, 0.5, 0.5, 1 },
}

---Create a modern flat-style button with dark background and thin border
---@param parent Frame
---@param text string
---@param onClick function
---@param tooltip? TooltipText Optional tooltip configuration
---@param colorOverrides? table Partial color table to override defaults (same keys as ButtonColors)
---@return table
function BR.CreateButton(parent, text, onClick, tooltip, colorOverrides)
    local colors = ButtonColors
    if colorOverrides then
        colors = {}
        for k, v in pairs(ButtonColors) do
            colors[k] = colorOverrides[k] or v
        end
    end

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    -- Text
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("CENTER", 0, 0)
    btnText:SetText(text)
    btn.text = btnText

    -- Auto-size based on text with padding
    local textWidth = btnText:GetStringWidth()
    btn:SetSize(max(textWidth + 16, 60), 22)

    -- Visual state tracking
    local isEnabled = true
    local isPressed = false
    local isHovered = false

    local function UpdateVisual()
        if not isEnabled then
            btn:SetBackdropColor(unpack(colors.bg))
            btn:SetBackdropBorderColor(unpack(colors.borderDisabled))
            btnText:SetTextColor(unpack(colors.textDisabled))
        elseif isPressed then
            btn:SetBackdropColor(unpack(colors.bgPressed))
            btn:SetBackdropBorderColor(unpack(colors.borderPressed))
            btnText:SetTextColor(unpack(colors.text))
        elseif isHovered then
            btn:SetBackdropColor(unpack(colors.bgHover))
            btn:SetBackdropBorderColor(unpack(colors.borderHover))
            btnText:SetTextColor(unpack(colors.text))
        else
            btn:SetBackdropColor(unpack(colors.bg))
            btn:SetBackdropBorderColor(unpack(colors.border))
            btnText:SetTextColor(unpack(colors.text))
        end
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

    btn:SetScript("OnClick", function()
        if isEnabled and onClick then
            onClick(btn)
        end
    end)

    -- Public methods
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

-- Panel EditBoxes tracking (populated by CreateOptionsPanel, used by Components)
local panelEditBoxes = nil ---@type table[]?

-- Modern slider color constants
local SliderColors = {
    track = { 0.2, 0.2, 0.2, 1 },
    trackFill = { 0.6, 0.5, 0.1, 1 }, -- Subtle gold fill
    trackDisabled = { 0.15, 0.15, 0.15, 1 },
    thumb = { 0.4, 0.4, 0.4, 1 },
    thumbHover = BR.Colors.Accent, -- Golden on hover
    thumbDisabled = { 0.25, 0.25, 0.25, 1 },
    text = { 1, 1, 1, 1 },
    textDisabled = { 0.5, 0.5, 0.5, 1 },
}

-- TextInput color constants (shared with StyleEditBox and TextArea)
local TextInputColors = {
    bg = { 0.08, 0.08, 0.08, 0.9 },
    bgFocused = { 0.1, 0.1, 0.1, 0.95 },
    border = BR.Colors.Border,
    borderFocused = BR.Colors.Accent,
}

---Style any EditBox with dark flat UI (dark bg, gray border, gold focus highlight).
---Wraps the EditBox in a BackdropTemplate container. Caller should set size/position on the returned container.
---@param editBox table The EditBox to style
---@return table container The backdrop container frame
local function StyleEditBox(editBox)
    local colors = TextInputColors
    local parent = editBox:GetParent()

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(unpack(colors.bg))
    container:SetBackdropBorderColor(unpack(colors.border))

    editBox:SetParent(container)
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", 4, -2)
    editBox:SetPoint("BOTTOMRIGHT", -4, 2)
    editBox:SetTextColor(1, 1, 1, 1)

    editBox:HookScript("OnEditFocusGained", function()
        container:SetBackdropColor(unpack(colors.bgFocused))
        container:SetBackdropBorderColor(unpack(colors.borderFocused))
    end)

    editBox:HookScript("OnEditFocusLost", function()
        container:SetBackdropColor(unpack(colors.bg))
        container:SetBackdropBorderColor(unpack(colors.border))
    end)

    editBox:HookScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return container
end

BR.StyleEditBox = StyleEditBox

---Create a modern flat-style slider with thin track and small thumb
---@param parent table Parent frame
---@param config SliderConfig Configuration table
---@return table holder Frame containing slider with .slider, .valueText, .SetValue(v), .GetValue()
function Components.Slider(parent, config)
    local colors = SliderColors
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

    -- Container frame
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + sliderWidth + valueWidth + 12, 20)

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    if config.label then
        label:SetText(config.label)
    end
    holder.label = label

    -- Slider track container
    local sliderFrame = CreateFrame("Frame", nil, holder)
    sliderFrame:SetPoint("LEFT", label, "RIGHT", 5, 0)
    sliderFrame:SetSize(sliderWidth, 16)
    holder.slider = sliderFrame

    -- Track background
    local trackBg = sliderFrame:CreateTexture(nil, "BACKGROUND")
    trackBg:SetHeight(TRACK_HEIGHT)
    trackBg:SetPoint("LEFT", 0, 0)
    trackBg:SetPoint("RIGHT", 0, 0)
    trackBg:SetColorTexture(unpack(colors.track))
    sliderFrame.trackBg = trackBg

    -- Track fill (shows value progress)
    local trackFill = sliderFrame:CreateTexture(nil, "ARTWORK")
    trackFill:SetHeight(TRACK_HEIGHT)
    trackFill:SetPoint("LEFT", trackBg, "LEFT", 0, 0)
    trackFill:SetColorTexture(unpack(colors.trackFill))
    sliderFrame.trackFill = trackFill

    -- Thumb
    local thumb = CreateFrame("Button", nil, sliderFrame)
    thumb:SetSize(THUMB_WIDTH, THUMB_HEIGHT)
    thumb:SetPoint("CENTER", trackBg, "LEFT", 0, 0)

    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(unpack(colors.thumb))
    thumb.tex = thumbTex

    -- State
    local currentValue = config.get and config.get() or config.value or config.min
    local isEnabled = true
    local isDragging = false
    local isThumbHovered = false

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
        if not isEnabled then
            thumbTex:SetColorTexture(unpack(colors.thumbDisabled))
            trackBg:SetColorTexture(unpack(colors.trackDisabled))
            trackFill:SetColorTexture(0.3, 0.25, 0.05, 1) -- Dimmed fill
        elseif isThumbHovered or isDragging then
            thumbTex:SetColorTexture(unpack(colors.thumbHover))
            trackBg:SetColorTexture(unpack(colors.track))
            trackFill:SetColorTexture(unpack(colors.trackFill))
        else
            thumbTex:SetColorTexture(unpack(colors.thumb))
            trackBg:SetColorTexture(unpack(colors.track))
            trackFill:SetColorTexture(unpack(colors.trackFill))
        end
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

    -- Dragging logic
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

    -- Click on track to jump
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
            UpdateVisual()
            config.onChange(floor(currentValue))
            isDragging = true
        end
    end)

    sliderFrame:SetScript("OnMouseUp", function()
        isDragging = false
        UpdateVisual()
    end)

    -- Edit box (hidden by default)
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

    editBox:SetScript("OnEscapePressed", function()
        editContainer:Hide()
        valueBtn:Show()
    end)

    editBox:SetScript("OnEditFocusLost", function()
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

    -- Initial visual
    UpdateVisual()

    -- Public methods
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
        local color = enabled and 1 or 0.5
        label:SetTextColor(color, color, color)
        valueText:SetTextColor(color, color, color)
        UpdateVisual()
    end

    -- For compatibility with old code checking slider:IsEnabled()
    function sliderFrame:IsEnabled()
        return isEnabled
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- Modern checkbox color constants
local CheckboxColors = {
    bg = { 0.12, 0.12, 0.12, 1 },
    bgHover = { 0.16, 0.16, 0.16, 1 },
    bgChecked = { 0.15, 0.13, 0.08, 1 }, -- Subtle warm tint when checked
    border = BR.Colors.Border,
    borderHover = { 0.45, 0.45, 0.45, 1 },
    borderChecked = { 0.6, 0.5, 0.2, 1 }, -- Subtle golden border when checked
    borderDisabled = { 0.2, 0.2, 0.2, 1 },
    checkmark = BR.Colors.AccentMuted, -- Softer golden checkmark
    checkmarkDisabled = { 0.5, 0.42, 0.1, 1 },
    text = { 1, 1, 1, 1 },
    textDisabled = { 0.5, 0.5, 0.5, 1 },
}

---Create the core checkbox button frame (reusable by Checkbox component)
---@param parent table Parent frame
---@param initialChecked boolean Initial checked state
---@param onChange fun(checked: boolean) Callback when state changes
---@return table cb Checkbox button with .SetChecked(v), .GetChecked(), .SetHovered(v), .SetEnabled(v)
local function CreateCheckboxCore(parent, initialChecked, onChange)
    local colors = CheckboxColors
    local CHECKBOX_SIZE = 16 -- Match icon size for alignment

    local cb = CreateFrame("Button", nil, parent, "BackdropTemplate")
    cb:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    cb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cb:SetBackdropColor(unpack(colors.bg))
    cb:SetBackdropBorderColor(unpack(colors.border))

    -- Checkmark texture (sized to fit within checkbox)
    local checkmark = cb:CreateTexture(nil, "ARTWORK")
    checkmark:SetPoint("CENTER", 0, 0)
    checkmark:SetSize(CHECKBOX_SIZE + 4, CHECKBOX_SIZE + 4) -- Slightly larger for visual punch
    checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkmark:SetVertexColor(unpack(colors.checkmark))
    checkmark:Hide()
    cb.checkmark = checkmark

    -- State
    local isChecked = initialChecked or false
    local isEnabled = true
    local isHovered = false

    local function UpdateVisual()
        if isChecked then
            checkmark:Show()
        else
            checkmark:Hide()
        end

        if not isEnabled then
            cb:SetBackdropBorderColor(unpack(colors.borderDisabled))
            cb:SetBackdropColor(0.08, 0.08, 0.08, 1)
            checkmark:SetVertexColor(unpack(colors.checkmarkDisabled))
        elseif isChecked and isHovered then
            cb:SetBackdropBorderColor(unpack(colors.borderHover))
            cb:SetBackdropColor(unpack(colors.bgHover))
            checkmark:SetVertexColor(unpack(colors.checkmark))
        elseif isChecked then
            cb:SetBackdropBorderColor(unpack(colors.borderChecked))
            cb:SetBackdropColor(unpack(colors.bgChecked))
            checkmark:SetVertexColor(unpack(colors.checkmark))
        elseif isHovered then
            cb:SetBackdropBorderColor(unpack(colors.borderHover))
            cb:SetBackdropColor(unpack(colors.bgHover))
        else
            cb:SetBackdropBorderColor(unpack(colors.border))
            cb:SetBackdropColor(unpack(colors.bg))
        end
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

    -- Public methods
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
    local colors = CheckboxColors
    local initialChecked = config.get and config.get() or config.checked or false

    local CHECKBOX_W = 16
    local ICON_SIZE = 16 -- Match checkbox size
    local ICON_SPACING = 4 -- Consistent spacing
    local LABEL_LEAD = ICON_SPACING + 1 -- gap between last icon (or checkbox) and label
    local INFO_ICON_W = 14 -- info/warning icon shown after the label
    local INFO_ICON_GAP = 4
    local labelFont = config.labelFont or "GameFontHighlightSmall"

    -- Container frame. Holder is intentionally a fixed size: callers like the
    -- Buffs tab anchor gear/detach icons to holder.right and rely on a
    -- consistent column boundary across rows. Pass holderWidth to override.
    local holderWidth = config.holderWidth or 200
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(holderWidth, 20)

    -- Create checkbox using shared core
    local cb = CreateCheckboxCore(holder, initialChecked, config.onChange)
    cb:SetPoint("LEFT", 0, 0)
    holder.checkbox = cb

    -- Build icon chain (optional)
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
    label:SetPoint("LEFT", lastAnchor, "RIGHT", LABEL_LEAD, 0) -- Slightly more space before text
    label:SetWordWrap(false)
    local labelLeftX = CHECKBOX_W + iconCount * (ICON_SPACING + ICON_SIZE) + LABEL_LEAD
    holder.labelOffset = labelLeftX -- exposed so callers can clamp against widgets anchored at holder.right
    -- x of the first icon's left edge (fixed regardless of icon count), so a
    -- caller can align a sub-row under the icon rather than under the label,
    -- which drifts right with 3-4 icon buffs.
    holder.iconOffset = CHECKBOX_W + ICON_SPACING
    if config.labelWidth ~= nil then
        -- Clamp so the label can't extend past holder.right and overlap
        -- whatever the caller is anchoring there (gear/detach icons, etc.).
        local hasInfoIcon = config.infoTooltip or config.warningTooltip
        local trailing = hasInfoIcon and (INFO_ICON_GAP + INFO_ICON_W) or 0
        local maxLabelW = holderWidth - labelLeftX - trailing
        local labelWidth = max(0, min(config.labelWidth, maxLabelW))
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
    end
    label:SetText(config.label)
    holder.label = label
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

    -- Info / warning tooltip icon (optional, shown after label)
    local tooltipData = config.infoTooltip or config.warningTooltip
    if tooltipData then
        local infoIcon = holder:CreateTexture(nil, "ARTWORK")
        infoIcon:SetSize(14, 14)
        infoIcon:SetPoint("LEFT", label, "RIGHT", 4, 0)
        if config.warningTooltip then
            infoIcon:SetAtlas("services-icon-warning")
        else
            infoIcon:SetAtlas("QuestNormal")
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

    -- Public methods
    function holder:SetChecked(checked)
        cb:SetChecked(checked)
    end

    function holder:GetChecked()
        return cb:GetChecked()
    end

    function holder:SetEnabled(enabled)
        cb:SetEnabled(enabled)
        if enabled then
            label:SetTextColor(unpack(colors.text))
        else
            label:SetTextColor(unpack(colors.textDisabled))
        end
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- ============================================================================
-- DIMENSION LINK (chain toggle between Width/Height sliders)
-- ============================================================================

local DimensionLinkColors = {
    linked = BR.Colors.AccentMuted, -- gold when linked
    unlinked = { 0.35, 0.35, 0.35, 1 }, -- dim when unlinked
    hover = BR.Colors.Accent, -- bright gold on hover
    disabled = { 0.2, 0.2, 0.2, 1 },
}

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
    local colors = DimensionLinkColors
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
            -- Aligned bars with bridges
            leftBar:SetPoint("LEFT", holder, "CENTER", -BRIDGE_W / 2, 0)
            rightBar:SetPoint("RIGHT", holder, "CENTER", BRIDGE_W / 2, 0)
            topBridge:SetPoint("TOP", holder, "CENTER", 0, BAR_H / 2 - 1)
            bottomBridge:SetPoint("BOTTOM", holder, "CENTER", 0, -(BAR_H / 2 - 1))
        else
            -- Offset bars: left shifts up, right shifts down (broken chain)
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
            local tipText = config.isLinked() and "Unlink width and height" or "Link width and height"
            ShowTooltip(holder, tipText, "When linked, changing one updates both.", "ANCHOR_TOP")
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

-- Toggle (pill/switch) component colors
local ToggleColors = {
    trackOff = { 0.12, 0.12, 0.12, 1 },
    trackOn = { 0.15, 0.13, 0.08, 1 },
    borderOff = BR.Colors.Border,
    borderOn = { 0.6, 0.5, 0.2, 1 },
    borderHover = { 0.45, 0.45, 0.45, 1 },
    borderDisabled = { 0.2, 0.2, 0.2, 1 },
    thumbOff = { 0.4, 0.4, 0.4, 1 },
    thumbOn = BR.Colors.AccentMuted,
    thumbHover = BR.Colors.Accent,
    thumbDisabled = { 0.25, 0.25, 0.25, 1 },
    text = { 1, 1, 1, 1 },
    textDisabled = { 0.5, 0.5, 0.5, 1 },
}

---@param parent Frame
---@param config ToggleConfig
---@return Frame
function Components.Toggle(parent, config)
    local colors = ToggleColors
    local checked = config.checked or false

    local TRACK_W = 32
    local LABEL_GAP = 6

    -- Holder defaults to a fixed 200 so callers can anchor neighbours to
    -- holder.right; pass holderWidth to override.
    local holderWidth = config.holderWidth or 200
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(holderWidth, 20)

    -- Track (the pill background)
    local track = CreateFrame("Button", nil, holder, "BackdropTemplate")
    track:SetSize(TRACK_W, 16)
    track:SetPoint("LEFT", 0, 0)
    track:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeFile = "Interface\\BUTTONS\\WHITE8x8",
        edgeSize = 1,
    })

    -- Thumb (the sliding circle)
    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 12)
    thumb:SetColorTexture(1, 1, 1, 1)

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", track, "RIGHT", LABEL_GAP, 0)
    label:SetWordWrap(false)
    if config.labelWidth ~= nil then
        -- Clamp so label can't extend past holder.right and overlap
        -- anything the caller anchors there.
        local maxLabelW = holderWidth - TRACK_W - LABEL_GAP
        label:SetWidth(max(0, min(config.labelWidth, maxLabelW)))
        label:SetJustifyH("LEFT")
    end
    label:SetText(config.label)
    holder.label = label

    local enabled = true

    local function UpdateVisual()
        if not enabled then
            track:SetBackdropColor(unpack(colors.trackOff))
            track:SetBackdropBorderColor(unpack(colors.borderDisabled))
            thumb:SetVertexColor(unpack(colors.thumbDisabled))
            label:SetTextColor(unpack(colors.textDisabled))
        elseif checked then
            track:SetBackdropColor(unpack(colors.trackOn))
            track:SetBackdropBorderColor(unpack(colors.borderOn))
            thumb:SetVertexColor(unpack(colors.thumbOn))
            label:SetTextColor(unpack(colors.text))
        else
            track:SetBackdropColor(unpack(colors.trackOff))
            track:SetBackdropBorderColor(unpack(colors.borderOff))
            thumb:SetVertexColor(unpack(colors.thumbOff))
            label:SetTextColor(unpack(colors.text))
        end

        thumb:ClearAllPoints()
        if checked then
            thumb:SetPoint("LEFT", track, "LEFT", 18, 0) -- on position
        else
            thumb:SetPoint("LEFT", track, "LEFT", 2, 0) -- off position
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
        if not enabled then
            return
        end
        if checked then
            thumb:SetVertexColor(unpack(colors.thumbHover))
        else
            track:SetBackdropBorderColor(unpack(colors.borderHover))
        end
    end)

    track:SetScript("OnLeave", function()
        if not enabled then
            return
        end
        UpdateVisual()
    end)

    -- Tooltip support (same pattern as Checkbox)
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

    -- Public methods
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    UpdateVisual()

    return holder
end

-- Modern dropdown styling colors
local DropdownColors = {
    bg = { 0.15, 0.15, 0.15, 1 },
    bgHover = { 0.2, 0.2, 0.2, 1 },
    bgDisabled = { 0.1, 0.1, 0.1, 1 },
    border = BR.Colors.Border,
    borderHover = { 0.5, 0.5, 0.5, 1 },
    borderDisabled = { 0.2, 0.2, 0.2, 1 },
    arrow = { 0.7, 0.7, 0.7, 1 },
    arrowHover = BR.Colors.Accent,
    arrowDisabled = { 0.4, 0.4, 0.4, 1 },
    text = { 1, 1, 1, 1 },
    textDisabled = { 0.5, 0.5, 0.5, 1 },
    -- Menu colors
    menuBg = { 0.12, 0.12, 0.12, 0.98 },
    menuBorder = BR.Colors.Border,
    itemBgHover = { 0.25, 0.22, 0.1, 1 },
    itemText = { 1, 1, 1, 1 },
    itemTextHover = BR.Colors.Accent,
    checkmark = BR.Colors.AccentMuted,
}

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
    local colors = DropdownColors
    local BUTTON_HEIGHT = 22
    local ITEM_HEIGHT = 22
    local MENU_PADDING_V = 4
    local CHECK_SIZE = 14
    local CHECK_LEFT = 6
    local LABEL_LEFT = CHECK_LEFT + CHECK_SIZE + 4 -- room for checkmark
    local LABEL_RIGHT_PAD = 8

    -- Find initial label
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

    -- State
    local isEnabled = true
    local isOpen = false
    local isHovered = false

    -- ==================== BUTTON ====================
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, BUTTON_HEIGHT)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

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
    arrow:SetRotation(rad(-90)) -- points down

    -- ==================== MENU ====================
    -- Parent to dropdown parent so it scrolls with container.
    -- When maxItems is set we ALWAYS build the scroll infrastructure (even if the
    -- current option count fits) so the dropdown can be re-populated later via
    -- :SetOptions with any count - the scroll child just resizes. visibleCount is
    -- mutable so SetOptions can recompute the capped menu height.
    local hasScroll = maxItems ~= nil
    local visibleCount = hasScroll and min(#options, maxItems) or #options
    local menuHeight = visibleCount * ITEM_HEIGHT + MENU_PADDING_V * 2
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    menu:SetSize(menuWidth, menuHeight)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(unpack(colors.menuBg))
    menu:SetBackdropBorderColor(unpack(colors.menuBorder))
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

    -- Position menu below button (updated when shown)
    local function PositionMenu()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, 0)
    end

    -- ==================== VISUAL STATE ====================
    local function UpdateButtonVisual()
        if not isEnabled then
            button:SetBackdropColor(unpack(colors.bgDisabled))
            button:SetBackdropBorderColor(unpack(colors.borderDisabled))
            buttonText:SetTextColor(unpack(colors.textDisabled))
            arrow:SetVertexColor(unpack(colors.arrowDisabled))
        elseif isHovered or isOpen then
            button:SetBackdropColor(unpack(colors.bgHover))
            button:SetBackdropBorderColor(unpack(colors.borderHover))
            buttonText:SetTextColor(unpack(colors.text))
            arrow:SetVertexColor(unpack(colors.arrowHover))
        else
            button:SetBackdropColor(unpack(colors.bg))
            button:SetBackdropBorderColor(unpack(colors.border))
            buttonText:SetTextColor(unpack(colors.text))
            arrow:SetVertexColor(unpack(colors.arrow))
        end
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
        -- level - the dialog's own widgets would then paint over the open menu.
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

        -- Detect click (mouse just pressed)
        if isMouseDown and not wasMouseDown then
            -- Check if click is outside menu and button
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
    -- its option through `item.opt` so reused items pick up the new entry. This is
    -- the single source of truth for both the initial build and SetOptions.
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

                local check = item:CreateTexture(nil, "ARTWORK")
                check:SetSize(CHECK_SIZE, CHECK_SIZE)
                check:SetPoint("LEFT", CHECK_LEFT, 0)
                check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                check:SetVertexColor(unpack(colors.checkmark))
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
                    item._bg:SetColorTexture(unpack(colors.itemBgHover))
                    item._label:SetTextColor(unpack(colors.itemTextHover))
                    if item.opt and item.opt.desc then
                        ShowTooltip(item, item.opt.label, item.opt.desc, "ANCHOR_RIGHT")
                    end
                end)
                item:SetScript("OnLeave", function()
                    item._bg:SetColorTexture(0, 0, 0, 0)
                    item._label:SetTextColor(unpack(colors.itemText))
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
            item._label:SetText(opt.label)
            item._label:SetTextColor(unpack(colors.itemText))
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

    -- Initialize visual
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

    -- Build options array
    local options = {}
    for _, dir in ipairs(directions) do
        tinsert(options, { label = dirLabels[dir], value = dir })
    end

    -- Container frame
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + width + 10, 26)

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    holder.label = label

    -- Initial value
    local initialValue = config.get and config.get() or config.selected

    -- Create dropdown core
    local dropdown = CreateDropdownCore(holder, width, options, initialValue, function(value)
        config.onChange(value)
    end)
    dropdown.button:SetPoint("LEFT", label, "RIGHT", 5, 0)
    holder.dropdown = dropdown

    -- Public method to update selection (backwards compatible)
    function holder:SetDirection(dir)
        dropdown:SetValue(dir)
    end

    -- SetEnabled method for toggling interactivity
    function holder:SetEnabled(enabled)
        dropdown:SetEnabled(enabled)
        local color = enabled and 1 or 0.5
        label:SetTextColor(color, color, color)
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    -- Backwards compatibility: empty buttons table (no longer used)
    holder.buttons = {}

    return holder
end

-- ============================================================================
-- ZONE PICKER (vertical + alignment dropdowns)
-- ============================================================================
-- Two compact dropdowns covering the same 15 zones as the old spatial picker:
-- Vertical (Above / Inside top / Inside middle / Inside bottom / Below) +
-- Align (Left / Center / Right). Decomposition is handled by
-- BR.TextPositions.ToVA / FromVA so the widget speaks zone strings to its
-- callers. Reuses Components.Dropdown for both axes - no custom widget code,
-- ~26px per row vs the old picker's 90px.

---@class ZonePickerConfig
---@field label string Item name shown to the left of the dropdowns
---@field labelWidth? number Default 70
---@field verticalWidth? number Width of the Vertical dropdown (default 110)
---@field alignWidth? number Width of the Align dropdown (default 85)
---@field get fun(): string Returns current zone name
---@field enabled? fun(): boolean
---@field onChange fun(zone: string)

-- Each Dropdown holder reserves an extra 10px past its `width` for the
-- chevron + internal padding (see Components.Dropdown). The container has
-- to include that or anything anchored to picker.RIGHT lands inside the
-- align dropdown.
local ZONE_PICKER_DD_PADDING = 10
local ZONE_PICKER_LABEL_COLOR = { 1, 1, 1, 1 }
local ZONE_PICKER_LABEL_DISABLED_COLOR = { 0.5, 0.5, 0.5, 1 }

-- Localized option lists, built once at file load (locale strings are stable
-- per session). Lifted out of Components.ZonePicker so each call doesn't
-- re-allocate the option tables.
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
    local GAP = 8

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(LW + GAP + (V_W + ZONE_PICKER_DD_PADDING) + GAP + (A_W + ZONE_PICKER_DD_PADDING), 26)

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

    local verticalDD = Components.Dropdown(holder, {
        label = "",
        labelWidth = 0,
        width = V_W,
        options = ZONE_PICKER_VERTICAL_OPTIONS,
        get = function()
            local v = BR.TextPositions.ToVA(currentZone())
            return v
        end,
        enabled = config.enabled,
        onChange = function(v)
            local _, a = BR.TextPositions.ToVA(currentZone())
            if config.onChange then
                config.onChange(BR.TextPositions.FromVA(v, a))
            end
        end,
    })
    verticalDD:SetPoint("LEFT", itemLabel, "RIGHT", GAP, 0)

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
        local enabledNow = not config.enabled or config.enabled()
        if enabledNow then
            itemLabel:SetTextColor(unpack(ZONE_PICKER_LABEL_COLOR))
        else
            itemLabel:SetTextColor(unpack(ZONE_PICKER_LABEL_DISABLED_COLOR))
        end
    end

    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
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

---@type ToggleDef[]
local SCENARIO_DIFF_DEFS = {
    { key = "delves", label = "D", tooltip = { title = L["Content.Delves"] } },
    { key = "others", label = "O", tooltip = { title = L["Content.OtherScenarios"] } },
}

---@type ToggleDef[]
local DUNGEON_DIFF_DEFS = {
    { key = "normal", label = "N", tooltip = { title = L["Content.NormalDungeons"] } },
    { key = "heroic", label = "H", tooltip = { title = L["Content.HeroicDungeons"] } },
    { key = "mythic", label = "M", tooltip = { title = L["Content.MythicDungeons"] } },
    { key = "mythicPlus", label = "M+", tooltip = { title = L["Content.MythicPlus"] } },
    { key = "timewalking", label = "TW", tooltip = { title = L["Content.TimewalkingDungeons"] } },
    { key = "follower", label = "F", tooltip = { title = L["Content.FollowerDungeons"] } },
}

---@type ToggleDef[]
local RAID_DIFF_DEFS = {
    { key = "lfr", label = "LFR", tooltip = { title = L["Content.LFR"] } },
    { key = "normal", label = "N", tooltip = { title = L["Content.NormalRaids"] } },
    { key = "heroic", label = "H", tooltip = { title = L["Content.HeroicRaids"] } },
    { key = "mythic", label = "M", tooltip = { title = L["Content.MythicRaids"] } },
}

---@type ToggleDef[]
local PVP_TYPE_DEFS = {
    { key = "arena", label = "A", tooltip = { title = L["Content.Arena"] } },
    { key = "bg", label = "B", tooltip = { title = L["Content.Battlegrounds"] } },
}

---@type ToggleDef[]
local CONTENT_TOGGLE_DEFS = {
    { key = "openWorld", label = "W", tooltip = { title = L["Content.OpenWorld"] } },
    { key = "housing", label = "H", tooltip = { title = L["Content.Housing"] } },
    {
        key = "scenario",
        label = "S",
        tooltip = { title = L["Content.Scenarios"] },
        diffDbKey = "scenarioDifficulty",
        diffDefs = SCENARIO_DIFF_DEFS,
    },
    {
        key = "dungeon",
        label = "D",
        tooltip = { title = L["Content.Dungeons"] },
        diffDbKey = "dungeonDifficulty",
        diffDefs = DUNGEON_DIFF_DEFS,
    },
    {
        key = "raid",
        label = "R",
        tooltip = { title = L["Content.Raids"] },
        diffDbKey = "raidDifficulty",
        diffDefs = RAID_DIFF_DEFS,
    },
    {
        key = "pvp",
        label = "P",
        tooltip = { title = L["Content.PvP"] },
        diffDbKey = "pvpType",
        diffDefs = PVP_TYPE_DEFS,
    },
}

-- Lookup: contentKey -> toggle def (for data-driven submenu access)
local contentToggleByKey = {}
-- Content toggles that have a difficulty submenu, with their button index
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

---Create a generic segmented toggle bar
---@param parent table Parent frame
---@param barConfig SegmentedBarConfig
---@return table container The bar container frame
---@return table toggleButtons Array of segment button frames
local function CreateSegmentedBar(parent, barConfig)
    local toggleDefs = barConfig.toggleDefs
    local segW = barConfig.segmentWidth or DEFAULT_SEGMENT_W
    local barW = ComputeBarWidth(#toggleDefs, segW)

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(barW, BAR_H)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    container:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)

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

        local function UpdateToggleVisual()
            if barDisabled then
                bg:SetColorTexture(0, 0, 0, 0)
                btnLabel:SetTextColor(0.25, 0.25, 0.25, 1)
                return
            end
            -- Tri-state visual: getVisualState returns "on"/"partial"/"off"
            local visualState
            if barConfig.getVisualState then
                visualState = barConfig.getVisualState(toggle.key)
            else
                visualState = barConfig.getState(toggle.key) and "on" or "off"
            end
            local c = toggle.color -- optional per-toggle {r, g, b}
            if visualState == "on" then
                if c then
                    bg:SetColorTexture(c[1] * 0.25, c[2] * 0.25, c[3] * 0.25, 1)
                    btnLabel:SetTextColor(c[1], c[2], c[3], 1)
                else
                    bg:SetColorTexture(0.18, 0.15, 0.08, 1)
                    btnLabel:SetTextColor(unpack(BR.Colors.AccentMuted))
                end
            elseif visualState == "partial" then
                if c then
                    bg:SetColorTexture(c[1] * 0.15, c[2] * 0.15, c[3] * 0.15, 1)
                    btnLabel:SetTextColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 1)
                else
                    bg:SetColorTexture(0.12, 0.08, 0.02, 1)
                    btnLabel:SetTextColor(0.7, 0.5, 0.1, 1)
                end
            else
                bg:SetColorTexture(0, 0, 0, 0)
                btnLabel:SetTextColor(0.4, 0.4, 0.4, 1)
            end
        end
        btn.UpdateVisual = UpdateToggleVisual
        btn.bg = bg
        btn.label = btnLabel
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
        SetupTooltip(btn, tipTitle, "Click to toggle visibility in " .. tipTitle:lower(), "ANCHOR_TOP")

        if i < #toggleDefs then
            local divider = container:CreateTexture(nil, "ARTWORK")
            divider:SetSize(DIVIDER_W, SEGMENT_H)
            divider:SetPoint("LEFT", btn, "RIGHT", 0, 0)
            divider:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 0.8)
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

    -- Content bar
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

    -- Difficulty bar state
    local diffBars = {} -- keyed by contentKey ("dungeon", "raid")
    local activeDiffKey = nil -- which difficulty bar is currently shown

    -- Arrow indicator between content bar and difficulty bar (hidden when no diff bar is open)
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
                    -- Skip force-disabled keys (e.g. arena for consumables) so they don't
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
                -- Auto-manage may change multiple states; refresh everything
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
                        subBtn.bg:SetColorTexture(0.08, 0.02, 0.02, 1)
                        subBtn.label:SetTextColor(0.5, 0.2, 0.2, 1)
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
            -- Toggle off: clicking same button again hides it
            closeDiffBar()
            return
        end
        -- Hide previous bar if any
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
        SetupTooltip(btn, toggle.tooltip.title, format(L["Content.ClickToFilter"], toggle.tooltip.title), "ANCHOR_TOP")
    end

    -- refreshAll: update all button visuals (used by onChange and Refresh)
    refreshAll = function()
        for _, btn in ipairs(allToggleButtons) do
            btn.UpdateVisual()
        end
    end

    holder.toggleButtons = contentButtons
    holder.allToggleButtons = allToggleButtons

    -- Close difficulty bar when holder is hidden (e.g. options panel closes)
    holder:SetScript("OnHide", closeDiffBar)

    -- Refresh method: update all buttons (content bar + both difficulty bars)
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

    -- Container frame
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + width + 10, 26)

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(config.label)
    holder.label = label

    -- Initial value
    local initialValue = config.get and config.get() or config.selected

    -- Create dropdown core
    local dropdown = CreateDropdownCore(holder, width, config.options, initialValue, function(value)
        config.onChange(value)
    end, config.maxItems, config.itemInit)
    dropdown.button:SetPoint("LEFT", label, "RIGHT", 5, 0)
    holder.dropdown = dropdown

    -- Public methods (delegate to core)
    function holder:SetValue(value)
        dropdown:SetValue(value)
    end

    function holder:GetValue()
        return dropdown:GetValue()
    end

    function holder:SetEnabled(enabled)
        dropdown:SetEnabled(enabled)
        local color = enabled and 1 or 0.5
        label:SetTextColor(color, color, color)
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
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
    -- via `LEFT, prev, RIGHT, gap, 0` (Options.lua does this); callers that
    -- place tabs at fixed X coordinates must compute final widths themselves.
    local minWidth = config.width or 90
    local height = config.height or 22

    -- Auto-grow tab width to fit text + side padding so labels never clip.
    -- Both active (GameFontHighlightSmall) and inactive (GameFontNormalSmall)
    -- variants render at the same width so we can measure either.
    local textW = MeasureTextWidth(config.label or "", "GameFontNormalSmall")
    local width = max(minWidth, textW + 16)

    -- Minimal underline tab, styled to match the main options panel: no boxes or
    -- fills - the active tab is marked by gold text + a gold underline accent
    -- (the panel reserves gold for active/selected cues), inactive tabs are a
    -- muted gray. Keeps dialogs in the panel's restrained, elegant family.
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(width, height)
    tab.tabName = config.name

    -- Underline accent, gold like the panel's active-nav bar; only shown active.
    local underline = tab:CreateTexture(nil, "ARTWORK")
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT", 1, 0)
    underline:SetPoint("BOTTOMRIGHT", -1, 0)
    underline:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0)
    tab.underline = underline

    -- Text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 1)
    text:SetWordWrap(false)
    text:SetText(config.label)
    tab.text = text

    local ACTIVE_TEXT = BR.Colors.Accent
    local IDLE_TEXT = { 0.6, 0.6, 0.62 }
    local HOVER_TEXT = { 0.85, 0.85, 0.85 }

    -- Hover only affects the idle (non-active) state: brighten the label and hint
    -- the underline so the tab reads as clickable without competing with active.
    tab:SetScript("OnEnter", function(self)
        if not self.isActive then
            self.text:SetTextColor(unpack(HOVER_TEXT))
            self.underline:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.25)
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if not self.isActive then
            self.text:SetTextColor(unpack(IDLE_TEXT))
            self.underline:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0)
        end
    end)

    -- Public method to set active state
    function tab:SetActive(active)
        self.isActive = active
        if active then
            self.text:SetFontObject("GameFontHighlightSmall")
            self.text:SetTextColor(unpack(ACTIVE_TEXT))
            self.underline:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
        else
            self.text:SetFontObject("GameFontNormalSmall")
            self.text:SetTextColor(unpack(IDLE_TEXT))
            self.underline:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0)
        end
    end

    tab:SetActive(false)

    return tab
end

---Grounding hairline for a tab strip: a faint full-width line sitting on the
---tabs' bottom edge. Each tab's gold underline (ARTWORK) rides on top of it, so
---the active tab reads as a bold segment of a continuous line - a modern,
---grounded tab bar rather than a lone floating accent. Drawn on the BORDER layer
---so the active tab's underline always covers it. Anchor to the strip's left-most
---tab and pass the strip's total width.
---@param parent table Frame owning the strip
---@param anchorTab table The left-most tab in the strip
---@param width number Total strip width the line should span
---@return table line The baseline texture
function Components.TabBaseline(parent, anchorTab, width)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", anchorTab, "BOTTOMLEFT", 0, 0)
    line:SetWidth(width)
    line:SetColorTexture(1, 1, 1, 0.08)
    return line
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
---@return table holder Frame with .editBox, .SetValue(v), .GetValue()
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

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(config.label)
    holder.label = label

    -- Edit box
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

    -- Callbacks. Use HookScript on OnEditFocusLost so we don't clobber
    -- StyleEditBox's focus-color reset (SetScript would replace its hook).
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

    -- Public methods
    function holder:SetValue(text)
        editBox:SetText(text or "")
    end

    function holder:GetValue()
        return editBox:GetText()
    end

    function holder:SetEnabled(enabled)
        editBox:SetEnabled(enabled)
        local color = enabled and 1 or 0.5
        label:SetTextColor(color, color, color)
        local borderAlpha = enabled and 1 or 0.4
        inputContainer:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, borderAlpha)
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
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
---@param config table Configuration: label, min, max, step?, labelWidth?, get?, enabled?, onChange?
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

    -- Auto-grow value box: at default font 4-digit numbers fit in 26px, at
    -- bigger fonts they don't. Measure the actual extents of min and max.
    local minTxt = tostring(config.min or 0)
    local maxTxt = tostring(config.max or 100)
    local VALUE_WIDTH = max(
        26,
        max(MeasureTextWidth(minTxt, "GameFontHighlightSmall"), MeasureTextWidth(maxTxt, "GameFontHighlightSmall")) + 8
    )

    -- Container frame
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + BTN_SIZE * 2 + VALUE_WIDTH + 16, 20)

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    label:SetText(config.label)
    holder.label = label

    -- State
    local currentValue = config.min or 0
    if config.get then
        currentValue = config.get()
    end
    local isEnabled = true

    -- Clickable value display button
    local valueBtn = CreateFrame("Button", nil, holder)
    valueBtn:SetSize(VALUE_WIDTH, BTN_SIZE)

    local valueText = valueBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetAllPoints()
    valueText:SetWordWrap(false)
    valueText:SetJustifyH("CENTER")

    -- Forward declarations (buttons needed by UpdateButtonStates, defined below)
    local UpdateButtonStates

    local function UpdateValueText()
        valueText:SetText(tostring(currentValue))
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

    -- Minus button
    local minusBtn = CreateFrame("Button", nil, holder, "BackdropTemplate")
    minusBtn:SetSize(BTN_SIZE, BTN_SIZE)
    minusBtn:SetPoint("LEFT", label, "RIGHT", 5, 0)
    minusBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    minusBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    minusBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)

    local minusLabel = minusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minusLabel:SetPoint("CENTER", 0, 0)
    minusLabel:SetText("-")

    -- Value positioned between buttons
    valueBtn:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)

    -- Plus button
    local plusBtn = CreateFrame("Button", nil, holder, "BackdropTemplate")
    plusBtn:SetSize(BTN_SIZE, BTN_SIZE)
    plusBtn:SetPoint("LEFT", valueBtn, "RIGHT", 2, 0)
    plusBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    plusBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    plusBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)

    local plusLabel = plusBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plusLabel:SetPoint("CENTER", 0, 0)
    plusLabel:SetText("+")

    -- Update button appearance based on whether value is at min/max
    UpdateButtonStates = function()
        if not isEnabled then
            return
        end
        local atMin = currentValue <= (config.min or 0)
        local atMax = currentValue >= (config.max or 100)
        if atMin then
            minusBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            minusBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            minusLabel:SetTextColor(0.35, 0.35, 0.35)
        else
            minusBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
            minusBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
            minusLabel:SetTextColor(1, 1, 1)
        end
        if atMax then
            plusBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            plusBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            plusLabel:SetTextColor(0.35, 0.35, 0.35)
        else
            plusBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
            plusBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
            plusLabel:SetTextColor(1, 1, 1)
        end
    end

    -- Edit box (hidden by default, shown on value click)
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

    editBox:SetScript("OnEscapePressed", function()
        editContainer:Hide()
        valueBtn:Show()
    end)

    editBox:SetScript("OnEditFocusLost", function()
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

    -- Hover effects (skip if button is at its limit)
    local function IsBtnAtLimit(btn)
        if btn == minusBtn then
            return currentValue <= (config.min or 0)
        end
        return currentValue >= (config.max or 100)
    end

    for _, btn in ipairs({ minusBtn, plusBtn }) do
        btn:SetScript("OnEnter", function(self)
            if isEnabled and not IsBtnAtLimit(self) then
                self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                self:SetBackdropColor(0.25, 0.25, 0.25, 1)
            end
        end)
        btn:SetScript("OnLeave", function()
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

    -- Mouse wheel on entire holder
    holder:EnableMouseWheel(true)
    holder:SetScript("OnMouseWheel", function(_, delta)
        if isEnabled then
            ClampAndSet(currentValue + delta * step)
        end
    end)

    UpdateValueText()

    -- Public methods
    function holder:SetValue(val)
        currentValue = max(config.min or 0, min(config.max or 100, val))
        UpdateValueText()
    end

    function holder:GetValue()
        return currentValue
    end

    function holder:SetEnabled(enabled)
        isEnabled = enabled
        local color = enabled and 1 or 0.5
        label:SetTextColor(color, color, color)
        valueText:SetTextColor(color, color, color)
        if enabled then
            UpdateButtonStates()
        else
            -- Close edit box if open when disabling
            editContainer:Hide()
            valueBtn:Show()
            minusBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            minusBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            plusBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            plusBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            minusLabel:SetTextColor(0.5, 0.5, 0.5)
            plusLabel:SetTextColor(0.5, 0.5, 0.5)
        end
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
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
    -- bigger font makes "100%" wider than the original 50px allowance.
    local alphaW = config.hasOpacity and (4 + MeasureTextWidth("100%", "GameFontHighlightSmall") + 4) or 0
    local trailingW = max(50, alphaW)

    -- Container frame
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(labelWidth + 5 + SWATCH_SIZE + trailingW, 20)

    -- Label
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(labelWidth)
    label:SetWordWrap(false)
    label:SetJustifyH("LEFT")
    if config.label then
        label:SetText(config.label)
    end
    holder.label = label

    -- Swatch button
    local swatchBtn = CreateFrame("Button", nil, holder, "BackdropTemplate")
    swatchBtn:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    swatchBtn:SetPoint("LEFT", label, "RIGHT", 5, 0)
    swatchBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatchBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)

    -- State
    local currentR, currentG, currentB, currentA = 1, 1, 1, 1
    if config.get then
        local r, g, b, a = config.get()
        currentR, currentG, currentB = r, g, b
        currentA = a or 1
    end
    local isEnabled = true

    -- Alpha value text (shown when hasOpacity is true)
    local alphaText
    if config.hasOpacity then
        alphaText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        alphaText:SetPoint("LEFT", swatchBtn, "RIGHT", 4, 0)
        alphaText:SetWordWrap(false)
        alphaText:SetText(floor(currentA * 100) .. "%")
    end

    local function UpdateSwatchColor()
        swatchBtn:SetBackdropColor(currentR, currentG, currentB, 1)
        if alphaText then
            alphaText:SetText(floor(currentA * 100) .. "%")
        end
    end
    UpdateSwatchColor()

    -- Hover effect
    swatchBtn:SetScript("OnEnter", function()
        if isEnabled then
            swatchBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
    end)
    swatchBtn:SetScript("OnLeave", function()
        if isEnabled then
            swatchBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
        end
    end)

    -- Click opens color picker
    swatchBtn:SetScript("OnClick", function()
        if not isEnabled then
            return
        end
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

    -- Public methods
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
        local color = enabled and 1 or 0.5
        label:SetTextColor(color, color, color)
        if alphaText then
            alphaText:SetTextColor(color, color, color)
        end
        if not enabled then
            swatchBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            swatchBtn:SetAlpha(0.35)
        else
            swatchBtn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
            swatchBtn:SetAlpha(1)
        end
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

    -- Auto-register if refreshable
    if config.get or config.enabled then
        tinsert(RefreshableComponents, holder)
    end

    -- Disabled controls explain themselves on hover
    if config.disabledReason and config.enabled then
        Components.AttachDisabledReason(holder, config.enabled, config.disabledReason)
    end

    return holder
end

-- Modern scrollbar colors (defined early for use by TextArea and ScrollableContainer)
local ScrollbarColors = {
    -- Faint recessed rail instead of an opaque boxed track, so it reads as a
    -- subtle groove rather than a second bordered frame competing with the panel.
    track = { 0.1, 0.1, 0.11, 0.5 },
    thumb = { 0.3, 0.3, 0.3, 1 },
    thumbHover = { 0.45, 0.45, 0.45, 1 },
}

-- Helper to apply modern styling to a scrollbar (used by ScrollableContainer)
local function ApplyModernScrollbarStyle(scrollBar)
    if not scrollBar then
        return
    end
    local colors = ScrollbarColors

    -- Hide default textures
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

    -- Faint recessed rail (no hard border) - a thin groove, not a boxed frame.
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(unpack(colors.track))
    track:SetPoint("TOPLEFT", 5, 0)
    track:SetPoint("BOTTOMRIGHT", -5, 0)

    -- Style the thumb (height is managed proportionally by SetupProportionalScrollbar)
    local thumb = scrollBar.ThumbTexture or scrollBar.thumbTexture
    if thumb then
        thumb:SetColorTexture(unpack(colors.thumb))
        thumb:SetSize(6, 40)

        -- Try to set up hover/press effects
        local thumbParent = thumb:GetParent()
        if thumbParent and thumbParent.SetScript then
            thumbParent:HookScript("OnEnter", function()
                thumb:SetColorTexture(unpack(colors.thumbHover))
            end)
            thumbParent:HookScript("OnLeave", function()
                thumb:SetColorTexture(unpack(colors.thumb))
            end)
        end
    end

    -- Hide scroll up/down buttons
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
            -- Nothing to scroll: retire the bar entirely.
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

-- TextArea color constants
local TextAreaColors = {
    bg = { 0.08, 0.08, 0.08, 0.9 },
    bgFocused = { 0.1, 0.1, 0.1, 0.95 },
    border = BR.Colors.Border,
    borderFocused = BR.Colors.Accent,
    text = { 1, 1, 1, 1 },
}

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
    local colors = TextAreaColors

    -- Container frame with backdrop
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetSize(config.width, config.height)
    holder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    holder:SetBackdropColor(unpack(colors.bg))
    holder:SetBackdropBorderColor(unpack(colors.border))

    -- Scroll frame (basic, no scrollbar)
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

    -- Edit box
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetSize(config.width - 4, config.height)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(6, 6, 6, 6)
    editBox:EnableMouse(true)
    editBox:SetTextColor(unpack(colors.text))

    if config.readOnly then
        editBox:SetScript("OnChar", function() end)
        editBox:SetScript("OnKeyDown", function() end)
    end

    scrollFrame:SetScrollChild(editBox)
    holder.editBox = editBox
    holder.scrollFrame = scrollFrame

    -- Focus visual state
    local function UpdateFocusVisual(focused)
        if focused then
            holder:SetBackdropColor(unpack(colors.bgFocused))
            holder:SetBackdropBorderColor(unpack(colors.borderFocused))
        else
            holder:SetBackdropColor(unpack(colors.bg))
            holder:SetBackdropBorderColor(unpack(colors.border))
        end
    end

    editBox:SetScript("OnEditFocusGained", function(self)
        UpdateFocusVisual(true)
        if config.onFocusGained then
            config.onFocusGained()
        end
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        UpdateFocusVisual(false)
        if config.onFocusLost then
            config.onFocusLost()
        end
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Auto-resize content height based on text
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

    -- Track editbox for focus cleanup
    if panelEditBoxes then
        tinsert(panelEditBoxes, editBox)
    end

    -- Public methods
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
-- Declarative 2-column, 4-row grid of appearance controls:
--   Row 1: Width [link] Height
--   Row 2: Zoom         Border
--   Row 3: Spacing      Alpha
--   Row 4: Text [+-] [color]

---@class AppearanceGridConfig
---@field get fun(key: string, default: any): any  Read setting value
---@field set fun(key: string, value: any)          Write setting value
---@field setMulti fun(changes: table)              Batch write settings
---@field isLinked fun(): boolean                   Are width/height linked?
---@field onLink fun()                              Called when user re-links dimensions
---@field onUnlink fun()                            Called when user unlinks dimensions
---@field enabled? fun(): boolean                   Wraps all controls (nil = always enabled)
---@field masqueCheck? fun(): boolean               Returns true when Masque is active (disables zoom/border)

---Create a 2-column appearance grid with standard layout
---@param parent Frame
---@param config AppearanceGridConfig
---@return {frame: Frame, height: number, holders: table}
function Components.AppearanceGrid(parent, config)
    -- Compute label width from the longest of all 7 row labels so columns align
    -- regardless of locale or font replacement. Text offset X/Y rows moved to
    -- the dedicated TextPositions section (per-text-item zone + nudge), so the
    -- grid stays focused on size/zoom/border/spacing/alpha/text size/color.
    local labels = {
        L["Appearance.Width"],
        L["Appearance.Height"],
        L["Appearance.Zoom"],
        L["Appearance.Border"],
        L["Appearance.Spacing"],
        L["Appearance.Alpha"],
        L["Appearance.Text"],
    }
    local LW = 50
    for _, t in ipairs(labels) do
        local w = MeasureTextWidth(t, "GameFontHighlightSmall") + 4
        if w > LW then
            LW = w
        end
    end

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
    local GRID_HEIGHT = ROW_H * 4

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT")
    frame:SetSize(FRAME_W, GRID_HEIGHT)

    local enabled = config.enabled
    local masqueCheck = config.masqueCheck

    -- Enabled helpers
    local function baseEnabled()
        return not enabled or enabled()
    end
    local function masqueEnabled()
        return baseEnabled() and (not masqueCheck or not masqueCheck())
    end

    -- Forward declarations for cross-refresh
    local widthHolder, heightHolder

    -- Row 1: Width [link] Height
    widthHolder = Components.Slider(frame, {
        label = L["Appearance.Width"],
        min = 16,
        max = 128,
        labelWidth = LW,
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

    -- Row 2: Zoom, Border
    local zoomHolder = Components.Slider(frame, {
        label = L["Appearance.Zoom"],
        min = 0,
        max = 15,
        labelWidth = LW,
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

    local borderHolder = Components.Slider(frame, {
        label = L["Appearance.Border"],
        min = 0,
        max = 8,
        labelWidth = LW,
        suffix = "px",
        get = function()
            return config.get("borderSize", BR.DEFAULT_BORDER_SIZE)
        end,
        enabled = masqueCheck and masqueEnabled or (enabled and baseEnabled or nil),
        onChange = function(val)
            config.set("borderSize", val)
        end,
    })
    borderHolder:SetPoint("TOPLEFT", COL2, -ROW_H)

    -- Row 3: Spacing, Alpha
    local spacingHolder = Components.Slider(frame, {
        label = L["Appearance.Spacing"],
        min = 0,
        max = 50,
        labelWidth = LW,
        suffix = "%",
        get = function()
            return floor((config.get("spacing", 0.2)) * 100)
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(val)
            config.set("spacing", val / 100)
        end,
    })
    spacingHolder:SetPoint("TOPLEFT", 0, -ROW_H * 2)

    local alphaHolder = Components.Slider(frame, {
        label = L["Appearance.Alpha"],
        min = 10,
        max = 100,
        labelWidth = LW,
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

    -- Row 4: Text size stepper + color swatch
    local textSizeHolder = Components.NumericStepper(frame, {
        label = L["Appearance.Text"],
        labelWidth = LW,
        min = 6,
        max = 32,
        get = function()
            return config.get("textSize", BR.defaults.defaults.textSize)
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(val)
            config.set("textSize", val)
        end,
    })
    textSizeHolder:SetPoint("TOPLEFT", 0, -ROW_H * 3)

    local textColorHolder = Components.ColorSwatch(frame, {
        hasOpacity = true,
        get = function()
            local tc = config.get("textColor", { 1, 1, 1 })
            local ta = config.get("textAlpha", 1)
            return tc[1], tc[2], tc[3], ta
        end,
        enabled = enabled and baseEnabled or nil,
        onChange = function(r, g, b, a)
            config.setMulti({
                textColor = { r, g, b },
                textAlpha = a or 1,
            })
        end,
    })
    textColorHolder:SetPoint("LEFT", textSizeHolder, "RIGHT", 12, 0)

    frame:SetSize(FRAME_W, GRID_HEIGHT)

    return {
        frame = frame,
        height = GRID_HEIGHT,
        holders = {
            width = widthHolder,
            height = heightHolder,
            link = linkBtn,
            zoom = zoomHolder,
            border = borderHolder,
            spacing = spacingHolder,
            alpha = alphaHolder,
            textSize = textSizeHolder,
            textColor = textColorHolder,
        },
    }
end

---Initialize panelEditBoxes reference (called from CreateOptionsPanel)
---@param editBoxes table[] The editboxes array from the options panel
function Components.SetEditBoxesRef(editBoxes)
    panelEditBoxes = editBoxes
end

---Refresh all registered components (call on panel OnShow)
---
---Auto-prunes orphaned component frames as it goes: any holder that has been
---SetParent(nil)'d (the teardown signal for a transient widget in a dialog or
---re-rendered list) is dropped from the registry instead of refreshed. This is
---a safety net behind explicit Components.Unregister calls -- a call site that
---forgets to unregister no longer leaks a holder that fires :Refresh() forever
---and pins its dead dialog alive. Plain refresh hooks (tables without a frame)
---have no GetParent and are never pruned, so persistent page hooks survive.
---Iterate in reverse so table.remove during the walk is safe.
function Components.RefreshAll()
    for i = #RefreshableComponents, 1, -1 do
        local component = RefreshableComponents[i]
        if component.GetParent and component:GetParent() == nil then
            tremove(RefreshableComponents, i)
        elseif component.Refresh then
            component:Refresh()
        end
    end
end

---Clear refreshable components registry (call before recreating panel)
function Components.ClearRegistry()
    for i = #RefreshableComponents, 1, -1 do
        RefreshableComponents[i] = nil
    end
end

---Unregister a single holder from the refresh registry.
---Use when tearing down dynamic components whose parent frame is being destroyed,
---so Components.RefreshAll() doesn't keep invoking their :Refresh() on stale state.
---@param holder table Component holder previously added via a factory
function Components.Unregister(holder)
    if not holder then
        return
    end
    for i = #RefreshableComponents, 1, -1 do
        if RefreshableComponents[i] == holder then
            tremove(RefreshableComponents, i)
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
    -- larger parent (e.g. a sub-list inside a page). Without it we'd derive
    -- contentWidth from parent:GetWidth(), which overflows the visible
    -- scroll area (the scroll frame itself is sized smaller than the parent
    -- by the caller, but the inner content child wouldn't know that).
    local explicitWidth = config.width

    -- Holder frame (the scroll frame itself)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetClipsChildren(true)
    if explicitWidth then
        scrollFrame:SetWidth(explicitWidth)
    end

    -- Scrollbar: hand-styled legacy slider (faint rail + neutral thumb, matching
    -- the panel's square thin-edge chrome), with a proportional thumb that reflects
    -- page length and auto-hides when the page fits.
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

    -- Edge fades: ambient "there's more" affordance (a scroll shadow). A short
    -- gradient hugging each edge, shown only when content extends past it - the
    -- top fade once scrolled down, the bottom fade while more remains below - so
    -- the content reads as fading under the chrome. Live on a mouse-transparent
    -- overlay above the scrolling child; stop short of the scrollbar column.
    local fadeOverlay = CreateFrame("Frame", nil, scrollFrame)
    fadeOverlay:SetAllPoints(scrollFrame)
    fadeOverlay:SetFrameLevel(scrollFrame:GetFrameLevel() + 20)
    fadeOverlay:EnableMouse(false)

    local FADE_HEIGHT = 20
    local opaque = CreateColor(0.05, 0.05, 0.06, 0.95)
    local clear = CreateColor(0.05, 0.05, 0.06, 0)
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

    -- Public methods
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
    -- Tracks every anchored frame as { frame, x, y } so the whole stack can be
    -- nudged after layout (see :ShiftAllBy, used to vertically center dialogs).
    local items = {}

    ---Add a component at the current Y position and advance
    ---@param component table Component frame to position
    ---@param height? number Height to advance (uses component height if not specified)
    ---@param spacing? number Extra spacing after component (default 0)
    function layout:Add(component, height, spacing)
        component:SetPoint("TOPLEFT", parent, "TOPLEFT", x, currentY)
        tinsert(items, { frame = component, x = x, y = currentY })
        -- Components with dynamic height (e.g. Banner) need to recompute now
        -- that they're anchored, before we read their height.
        if not height and component.FitHeight then
            component:FitHeight()
        end
        local advanceHeight = height or (component.GetHeight and component:GetHeight()) or 20
        currentY = currentY - advanceHeight - (spacing or 0)
    end

    ---Add a font string at the current Y position and advance
    ---@param fontString table FontString to position
    ---@param height number Height to advance
    ---@param spacing? number Extra spacing after text (default 0)
    function layout:AddText(fontString, height, spacing)
        fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, currentY)
        tinsert(items, { frame = fontString, x = x, y = currentY })
        currentY = currentY - height - (spacing or 0)
    end

    ---Add vertical space
    ---@param amount number Space to add
    function layout:Space(amount)
        currentY = currentY - amount
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
        for _, item in ipairs(rowItems) do
            local comp, xOff = item[1], item[2]
            comp:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, currentY)
            tinsert(items, { frame = comp, x = xOff, y = currentY })
            local h = (comp.GetHeight and comp:GetHeight()) or 20
            if h > maxH then
                maxH = h
            end
        end
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

---Create an accordion-style collapsible section
---@param parent table Parent frame
---@param config CollapsibleSectionConfig Configuration table
---@return table holder Frame with :SetCollapsed(bool), :IsCollapsed(), :GetContentFrame(), :GetContentHeight(), :SetContentHeight(h)
function Components.CollapsibleSection(parent, config)
    -- Header height grows with font so big-font users don't see clipped titles.
    local HEADER_HEIGHT = max(24, MeasureTextHeight("Wg", "GameFontNormal") + 10)
    local CONTENT_PADDING = 10
    local BORDER_COLOR = { 0.25, 0.25, 0.25, 1 }
    local CONTENT_BG_COLOR = { 0.08, 0.08, 0.08, 0.95 }

    -- Container frame with backdrop for border
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")

    -- Calculate width: explicit > parent-based with scrollbar offset > parent > default
    local sectionWidth = config.width
    if not sectionWidth then
        local parentWidth = parent.GetWidth and parent:GetWidth() or 480
        local scrollbarOffset = config.scrollbarOffset or 0
        sectionWidth = parentWidth - scrollbarOffset
    end
    holder:SetSize(sectionWidth, HEADER_HEIGHT)
    holder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    holder:SetBackdropColor(0, 0, 0, 0) -- Transparent bg (header/content have their own)
    holder:SetBackdropBorderColor(unpack(BORDER_COLOR))

    -- Header button (clickable)
    local header = CreateFrame("Button", nil, holder)
    header:SetSize(holder:GetWidth() - 2, HEADER_HEIGHT - 1) -- Account for border
    header:SetPoint("TOPLEFT", 1, -1)

    -- Header background
    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.18, 0.18, 0.18, 1)

    -- Collapse indicator (chevron style)
    local indicator = header:CreateTexture(nil, "OVERLAY")
    indicator:SetSize(12, 12)
    indicator:SetPoint("LEFT", 10, 0)
    indicator:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    indicator:SetVertexColor(0.6, 0.6, 0.6)

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", indicator, "RIGHT", 8, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    title:SetWordWrap(false)
    title:SetJustifyH("LEFT")
    title:SetText(config.title)

    -- Content container (has background)
    local contentBg = CreateFrame("Frame", nil, holder)
    contentBg:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    contentBg:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    contentBg:SetHeight(100)
    contentBg:Hide()

    -- Content background texture
    local contentBgTex = contentBg:CreateTexture(nil, "BACKGROUND")
    contentBgTex:SetAllPoints()
    contentBgTex:SetColorTexture(unpack(CONTENT_BG_COLOR))

    -- Separator line between header and content
    local separator = contentBg:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", 0, 0)
    separator:SetPoint("TOPRIGHT", 0, 0)
    separator:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- Content frame (where children go, with padding)
    local content = CreateFrame("Frame", nil, contentBg)
    content:SetPoint("TOPLEFT", CONTENT_PADDING, -CONTENT_PADDING)
    content:SetPoint("TOPRIGHT", -CONTENT_PADDING, -CONTENT_PADDING)
    content:SetHeight(100) -- Default height, will be set by caller

    -- State
    local isCollapsed = config.defaultCollapsed ~= false -- Default to collapsed
    local contentHeight = 100

    -- Update visual state
    local function UpdateVisual()
        if isCollapsed then
            indicator:SetRotation(0) -- points right (native orientation)
            contentBg:Hide()
            holder:SetHeight(HEADER_HEIGHT)
        else
            indicator:SetRotation(rad(-90)) -- points down
            contentBg:Show()
            holder:SetHeight(HEADER_HEIGHT + contentHeight + CONTENT_PADDING * 2)
        end

        if config.onToggle then
            config.onToggle(not isCollapsed)
        end
    end

    -- Hover effect
    header:SetScript("OnEnter", function()
        headerBg:SetColorTexture(0.22, 0.22, 0.22, 1)
        indicator:SetVertexColor(0.8, 0.8, 0.8)
    end)
    header:SetScript("OnLeave", function()
        headerBg:SetColorTexture(0.18, 0.18, 0.18, 1)
        indicator:SetVertexColor(0.6, 0.6, 0.6)
    end)

    -- Click to toggle
    header:SetScript("OnClick", function()
        isCollapsed = not isCollapsed
        UpdateVisual()
    end)

    -- Public methods
    function holder:SetCollapsed(collapsed)
        isCollapsed = collapsed
        UpdateVisual()
    end

    function holder:IsCollapsed()
        return isCollapsed
    end

    function holder:GetContentFrame()
        return content
    end

    function holder:GetContentHeight()
        return contentHeight
    end

    function holder:SetContentHeight(height)
        contentHeight = height
        content:SetHeight(height)
        contentBg:SetHeight(height + CONTENT_PADDING * 2)
        if not isCollapsed then
            holder:SetHeight(HEADER_HEIGHT + contentHeight + CONTENT_PADDING * 2)
        end
    end

    function holder:SetTitle(newTitle)
        title:SetText(newTitle)
    end

    -- Refresh method (re-apply collapsed state)
    function holder:Refresh()
        UpdateVisual()
    end

    -- Initialize
    UpdateVisual()

    return holder
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
    local TEXT_VERT_PAD = 12 -- breathing room above + below the text
    local TEXT_NONFLOW_W = ICON_LEFT + ICON_SIZE + ICON_GAP + TEXT_RIGHT_PAD -- everything that's NOT text

    local hasExplicitHeight = config.height ~= nil
    local BANNER_MIN = 26
    -- Initial height is single-line + padding. Refined once the holder gets
    -- a width (via OnSizeChanged) and we can measure wrapped text height.
    local BANNER_HEIGHT = config.height
        or max(BANNER_MIN, MeasureTextHeight("Wg", "GameFontHighlightSmall") + TEXT_VERT_PAD)

    -- Color presets: "red" (warning) or "orange" (info)
    local colors = {
        red = { bg = { 0.18, 0.06, 0.06, 0.6 }, accent = { 0.7, 0.12, 0.1, 0.8 }, text = { 0.85, 0.7, 0.65 } },
        orange = { bg = { 0.18, 0.12, 0.04, 0.6 }, accent = { 0.7, 0.45, 0.1, 0.8 }, text = { 0.9, 0.78, 0.6 } },
    }
    local c = colors[config.color] or colors.red

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(BANNER_HEIGHT)

    -- Subtle translucent background
    local bg = holder:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local bgColor = { unpack(c.bg) }
    if config.bgAlpha then
        bgColor[4] = config.bgAlpha
    end
    bg:SetColorTexture(unpack(bgColor))

    -- Thin accent line at the bottom
    local accent = holder:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetPoint("BOTTOMRIGHT")
    accent:SetHeight(1.5)
    accent:SetColorTexture(unpack(c.accent))

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
    -- defensive backup for parent resizes, but the initial layout should
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
        -- Only respond to width changes; setting our own height re-fires this.
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
