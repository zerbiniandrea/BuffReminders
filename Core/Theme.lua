local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- THEME
-- ============================================================================
-- One token schema with one table per client. BR.Theme is the table of the
-- running client, and every options widget and shell element paints from it.
-- A color is RGB or RGBA, 0 to 1. A fill has a top and a bottom color: equal
-- colors give a flat fill. A part that a theme does not draw has the color CLEAR.

local CLEAR = { 0, 0, 0, 0 }
local WHITE = { 1, 1, 1, 1 }

---@param c number[]
---@param a number
---@return number[]
local function Alpha(c, a)
    return { c[1], c[2], c[3], a }
end

---@param c number
---@return number[]
local function Grey(c)
    return { c, c, c, 1 }
end

---@class ThemeStyle A painted surface state: fill, 1 px edge, 1 px line under the top edge, text
---@field top number[]
---@field bottom number[]
---@field edge number[]
---@field line number[]
---@field text? number[]
---@field offset? number Downward shift of the text in pixels
---@field mark? number[] Checkmark color
---@field ring? number[] Focus ring color
---@field knobTop? number[]
---@field knobBottom? number[]
---@field sheen? number[] Line under the top edge of a knob or segment
---@field divider? number[] Dropdown line between the field and the arrow cap
---@field capTop? number[] Dropdown arrow cap
---@field capBottom? number[]
---@field capLine? number[]
---@field arrow? number[] Dropdown arrow
---@field title? number[] Tooltip title
---@field desc? number[] Tooltip description

---@class EditBoxTokens
---@field normal ThemeStyle
---@field hover ThemeStyle
---@field focus ThemeStyle
---@field disabled ThemeStyle
---@field readOnly number[]
---@field cursor? number[] nil = the cursor keeps the client color

---@class SwatchTokens
---@field normal number[]
---@field hover number[]
---@field open? number[] Edge while the color picker is open; nil = the state is not drawn
---@field disabled number[]
---@field inner number[]

---@class ScrollbarTokens
---@field trackInset number
---@field trackLeft number[]
---@field trackRight number[]
---@field trackEdge number[]
---@field sheen number[]
---@field normal {left: number[], right: number[]}
---@field hover {left: number[], right: number[]}
---@field drag? {left: number[], right: number[]} nil = the state is not drawn

---@param top number[]
---@param bottom number[]
---@param edge number[]
---@param line number[]
---@param text? number[]
---@param offset? number
---@return ThemeStyle
local function Style(top, bottom, edge, line, text, offset)
    return { top = top, bottom = bottom, edge = edge, line = line, text = text, offset = offset or 0 }
end

---@param fill number[]
---@param edge number[]
---@param text? number[]
---@return ThemeStyle
local function Flat(fill, edge, text)
    return Style(fill, fill, edge, CLEAR, text)
end

---@param base ThemeStyle
---@param fields table
---@return ThemeStyle
local function With(base, fields)
    local copy = {}
    for k, v in pairs(base) do
        copy[k] = v
    end
    for k, v in pairs(fields) do
        copy[k] = v
    end
    return copy
end

-- ============================================================================
-- RETAIL
-- ============================================================================

local function BuildRetail()
    local BORDER = BR.Colors.Border
    local ACCENT = BR.Colors.Accent
    local MUTED = BR.Colors.AccentMuted
    local TEXT = WHITE
    local TEXT_DISABLED = Grey(0.5)
    local GOLD_TEXT = { 1, 0.8, 0, 1 }
    local DARK_GOLD = { 0.4, 0.32, 0.05, 0.6 }
    local ON_FILL = { 0.15, 0.13, 0.08, 1 }
    local ON_EDGE = { 0.6, 0.5, 0.2, 1 }

    local button = {
        normal = Flat(Grey(0.15), BORDER, TEXT),
        hover = Flat(Grey(0.22), Grey(0.5), TEXT),
        pressed = Flat(Grey(0.12), ACCENT, TEXT),
        disabled = Flat(Grey(0.15), Grey(0.25), TEXT_DISABLED),
    }
    local editNormal = With(Flat({ 0.08, 0.08, 0.08, 0.9 }, BORDER, TEXT), { ring = CLEAR })
    local dropdownHover = With(Flat(Grey(0.2), Grey(0.5), TEXT), {
        divider = CLEAR,
        capTop = CLEAR,
        capBottom = CLEAR,
        capLine = CLEAR,
        arrow = ACCENT,
    })
    local panelLines = { BORDER, BORDER }
    local function FlatSlider(track, fill, thumb)
        return {
            trackEdge = CLEAR,
            trackTop = track,
            trackBottom = track,
            trackShade = CLEAR,
            fillLeft = fill,
            fillRight = fill,
            fillLine = CLEAR,
            thumb = thumb,
            knobTop = thumb,
            knobBottom = thumb,
        }
    end
    local SLIDER_FILL = { 0.6, 0.5, 0.1, 1 }
    local sliderHover = FlatSlider(Grey(0.2), SLIDER_FILL, ACCENT)

    ---@class BRTheme
    local theme = {
        text = TEXT,
        textDisabled = TEXT_DISABLED,
        title = { 1, 0.82, 0 },
        titleText = GOLD_TEXT,
        note = { 0.502, 0.502, 0.502 },
        ownTooltip = false,
        tooltip = With(Flat({ 0.12, 0.12, 0.12, 0.98 }, BORDER), { title = TEXT, desc = Grey(0.7) }),

        shell = {
            panel = {
                lines = panelLines,
                body = { top = { 0.09, 0.09, 0.107, 0.97 }, bottom = { 0.09, 0.09, 0.107, 0.97 } },
            },
            dialog = {
                lines = panelLines,
                body = { top = { 0.130, 0.130, 0.152, 1 }, bottom = { 0.094, 0.094, 0.112, 1 } },
            },
            drawer = {
                lines = { BORDER },
                body = { top = { 0.10, 0.10, 0.122, 0.98 }, bottom = { 0.10, 0.10, 0.122, 0.98 } },
            },
            bracket = CLEAR,
        },
        groove = {
            dialog = { color = BORDER, shade = CLEAR, fadeLeft = 0, fadeRight = 0 },
            header = { color = BORDER, shade = CLEAR, fadeLeft = 0, fadeRight = 0 },
            drawer = { color = { 0.4, 0.32, 0.05, 0.45 }, shade = CLEAR, fadeLeft = 0, fadeRight = 0 },
        },
        drawerStripe = { color = { 0.9, 0.72, 0.26, 1 }, width = 3 },
        headerBrand = { TEXT, GOLD_TEXT },
        headerDot = Grey(1 / 3),
        version = { 0.502, 0.502, 0.502 },
        zoom = { idle = TEXT, limit = Grey(0.4), hover = ACCENT },
        sidebar = { top = { 0, 0, 0.04, 0.35 }, bottom = { 0, 0, 0.04, 0.35 }, edge = BORDER, inset = 0 },
        sidebarGroup = { text = GOLD_TEXT, left = DARK_GOLD, right = DARK_GOLD },
        nav = {
            idle = { left = CLEAR, right = CLEAR, text = Grey(0.85) },
            hover = { left = { 1, 1, 1, 0.06 }, right = { 1, 1, 1, 0.06 }, text = Grey(0.85) },
            active = { left = Alpha(ACCENT, 0.12), right = Alpha(ACCENT, 0.12), text = TEXT },
            bar = ACCENT,
            barHeight = 18,
        },
        footer = {
            normal = Style(CLEAR, CLEAR, BORDER, CLEAR, Grey(0.85)),
            hover = Style({ 1, 1, 1, 0.06 }, { 1, 1, 1, 0.06 }, { accent = 0.8 }, CLEAR, TEXT),
            active = Style({ accent = 0.22 }, { accent = 0.22 }, { accent = 1 }, CLEAR, TEXT),
        },
        footerRule = { ends = Alpha(BORDER, 0.7), center = Alpha(BORDER, 0.7) },
        stripMask = { 0.09, 0.09, 0.107, 1 },
        sectionRule = { ends = DARK_GOLD, center = DARK_GOLD },
        tabRule = { ends = { 1, 1, 1, 0.08 }, center = { 1, 1, 1, 0.08 } },

        button = button,
        closeButton = button,
        arrowButton = {
            normal = Flat({ 0.1, 0.1, 0.1, 0.7 }, BORDER, Grey(0.7)),
            hover = Flat({ 0.2, 0.2, 0.2, 0.85 }, BORDER, ACCENT),
            disabled = Flat({ 0.05, 0.05, 0.05, 0.5 }, { 0.2, 0.2, 0.2, 0.6 }, Grey(0.4)),
        },
        stepper = {
            normal = Flat(Grey(0.2), BORDER, TEXT),
            hover = Flat(Grey(0.25), Grey(0.5), TEXT),
            pressed = Flat(Grey(0.25), Grey(0.5), TEXT),
            limit = Flat(Grey(0.15), Grey(0.2), Grey(0.35)),
            disabled = Flat(Grey(0.15), Grey(0.2), TEXT_DISABLED),
        },
        checkbox = {
            normal = With(Flat(Grey(0.12), BORDER), { mark = MUTED }),
            hover = With(Flat(Grey(0.16), Grey(0.45)), { mark = MUTED }),
            checked = With(Flat(ON_FILL, ON_EDGE), { mark = MUTED }),
            checkedHover = With(Flat(Grey(0.16), Grey(0.45)), { mark = MUTED }),
            disabled = With(Flat(Grey(0.08), Grey(0.2)), { mark = { 0.5, 0.42, 0.1, 1 } }),
            disabledChecked = With(Flat(Grey(0.08), Grey(0.2)), { mark = { 0.5, 0.42, 0.1, 1 } }),
        },
        toggle = {
            off = With(Flat(Grey(0.12), BORDER), { knobTop = Grey(0.4), knobBottom = Grey(0.4), sheen = CLEAR }),
            offHover = With(
                Flat(Grey(0.12), Grey(0.45)),
                { knobTop = Grey(0.4), knobBottom = Grey(0.4), sheen = CLEAR }
            ),
            on = With(Flat(ON_FILL, ON_EDGE), { knobTop = MUTED, knobBottom = MUTED, sheen = CLEAR }),
            onHover = With(Flat(ON_FILL, ON_EDGE), { knobTop = ACCENT, knobBottom = ACCENT, sheen = CLEAR }),
            disabled = With(
                Flat(Grey(0.12), Grey(0.2)),
                { knobTop = Grey(0.25), knobBottom = Grey(0.25), sheen = CLEAR }
            ),
        },
        link = { linked = MUTED, unlinked = Grey(0.35), hover = ACCENT, disabled = Grey(0.2) },
        slider = {
            normal = FlatSlider(Grey(0.2), SLIDER_FILL, Grey(0.4)),
            hover = sliderHover,
            drag = sliderHover,
            disabled = FlatSlider(Grey(0.15), { 0.3, 0.25, 0.05, 1 }, Grey(0.25)),
            valueDrag = TEXT,
        },
        dropdown = {
            normal = With(Flat(Grey(0.15), BORDER, TEXT), {
                divider = CLEAR,
                capTop = CLEAR,
                capBottom = CLEAR,
                capLine = CLEAR,
                arrow = Grey(0.7),
            }),
            hover = dropdownHover,
            open = dropdownHover,
            disabled = With(Flat(Grey(0.1), Grey(0.2), TEXT_DISABLED), {
                divider = CLEAR,
                capTop = CLEAR,
                capBottom = CLEAR,
                capLine = CLEAR,
                arrow = Grey(0.4),
            }),
            capWidth = 22,
        },
        menu = Flat({ 0.12, 0.12, 0.12, 0.98 }, BORDER),
        menuItem = {
            hoverLeft = { 0.25, 0.22, 0.1, 1 },
            hoverRight = { 0.25, 0.22, 0.1, 1 },
            bar = CLEAR,
            text = TEXT,
            textHover = ACCENT,
            check = MUTED,
        },
        segmentBar = Flat({ 0.1, 0.1, 0.1, 0.8 }, BORDER),
        segmentDivider = Alpha(BORDER, 0.8),
        ---@type {on: SegmentStyle, partial: SegmentStyle, off: SegmentStyle, disabled: SegmentStyle}
        segment = {
            on = {
                top = { 0.18, 0.15, 0.08, 1 },
                bottom = { 0.18, 0.15, 0.08, 1 },
                text = MUTED,
                sheen = CLEAR,
                tintTop = 0.25,
                tintBottom = 0.25,
                tintText = 1,
                tintAlpha = 1,
            },
            partial = {
                top = { 0.12, 0.08, 0.02, 1 },
                bottom = { 0.12, 0.08, 0.02, 1 },
                text = { 0.7, 0.5, 0.1, 1 },
                sheen = CLEAR,
                tintTop = 0.15,
                tintBottom = 0.15,
                tintText = 0.7,
                tintAlpha = 1,
            },
            off = { top = CLEAR, bottom = CLEAR, text = Grey(0.4), sheen = CLEAR },
            disabled = { top = CLEAR, bottom = CLEAR, text = Grey(0.25), sheen = CLEAR },
        },
        tab = {
            line = ACCENT,
            hoverAlpha = 0.25,
            washTop = CLEAR,
            washBottom = CLEAR,
            active = ACCENT,
            idle = { 0.6, 0.6, 0.62 },
            hover = Grey(0.85),
        },
        ---@type EditBoxTokens
        editBox = {
            normal = editNormal,
            hover = editNormal,
            focus = With(Flat({ 0.1, 0.1, 0.1, 0.95 }, ACCENT, TEXT), { ring = CLEAR }),
            disabled = With(Flat({ 0.08, 0.08, 0.08, 0.9 }, Alpha(BORDER, 0.4), TEXT), { ring = CLEAR }),
            readOnly = TEXT,
        },
        ---@type SwatchTokens
        swatch = { normal = BORDER, hover = Grey(0.5), disabled = Grey(0.2), inner = CLEAR },
        ---@type ScrollbarTokens
        scrollbar = {
            trackInset = 5,
            trackLeft = { 0.1, 0.1, 0.11, 0.5 },
            trackRight = { 0.1, 0.1, 0.11, 0.5 },
            trackEdge = CLEAR,
            sheen = CLEAR,
            normal = { left = Grey(0.3), right = Grey(0.3) },
            hover = { left = Grey(0.45), right = Grey(0.45) },
        },
        scrollFade = { height = 20, color = { 0.05, 0.05, 0.06, 0.95 } },
        banner = {
            red = {
                bg = { 0.18, 0.06, 0.06, 0.6 },
                text = { 0.85, 0.7, 0.65 },
                accentBottom = { 0.7, 0.12, 0.1, 0.8 },
                accentLeft = CLEAR,
                line = CLEAR,
            },
            orange = {
                bg = { 0.18, 0.12, 0.04, 0.6 },
                text = { 0.9, 0.78, 0.6 },
                accentBottom = { 0.7, 0.45, 0.1, 0.8 },
                accentLeft = CLEAR,
                line = CLEAR,
            },
        },
        mover = { body = { 0, 0.7, 0, 0.6 }, edge = CLEAR, text = { 0.4, 1, 0.4, 1 } },
        cell = { edge = BORDER, selected = ACCENT, check = ACCENT },
    }
    return theme
end

-- ============================================================================
-- WOW FOREVER
-- ============================================================================
-- Bronze on near-black. A well is a recessed field: dark at the top, with a shade
-- line under the top edge. A raised part is lit at the top, with a sheen line.

local function BuildForever()
    -- Colors from the Camelot TITLE_COLOR and SUBTEXT_COLOR of Blizzard.
    local TITLE = { 1.0, 0.929, 0.824 }
    local NOTE = { 0.922, 0.804, 0.635 }
    local P = {
        fieldTop = { 0.024, 0.022, 0.020 },
        fieldBottom = { 0.055, 0.052, 0.047 },
        fieldOnBottom = { 0.157, 0.137, 0.106 },
        fieldShade = { 0, 0, 0, 0.55 },
        edge = { 0.478, 0.349, 0.180 },
        edgeHover = { 0.667, 0.502, 0.278 },
        edgeActive = { 0.851, 0.675, 0.384 },
        edgeDisabled = { 0.149, 0.137, 0.122 },
        raiseTop = { 0.212, 0.200, 0.184 },
        raiseBottom = { 0.125, 0.118, 0.106 },
        raiseHoverTop = { 0.290, 0.267, 0.231 },
        raiseHoverBottom = { 0.153, 0.141, 0.125 },
        raisePressedTop = { 0.071, 0.067, 0.063 },
        raisePressedBottom = { 0.169, 0.149, 0.125 },
        raiseDisabledTop = { 0.110, 0.106, 0.098 },
        raiseDisabledBottom = { 0.071, 0.067, 0.063 },
        sheen = { 1, 0.886, 0.667, 0.22 },
        focusRing = { 0.886, 0.722, 0.431, 0.28 },
        accent = { 0.886, 0.722, 0.431 },
        accentLow = { 0.541, 0.388, 0.188 },
        accentDisabled = { 0.431, 0.337, 0.204 },
        fillDisabled = { 0.208, 0.196, 0.176 },
        knobTop = { 0.953, 0.851, 0.643 },
        knobBottom = { 0.655, 0.475, 0.231 },
        knobHoverTop = { 1, 0.941, 0.8 },
        knobHoverBottom = { 0.753, 0.553, 0.282 },
        text = { 0.961, 0.925, 0.851 },
        textIdle = { 0.757, 0.718, 0.643 },
        textDisabled = { 0.451, 0.427, 0.388 },
        menuBg = { 0.051, 0.047, 0.043, 0.97 },
        menuHover = { 0.886, 0.722, 0.431, 0.30 },
        frameOuter = { 0, 0, 0, 0.85 },
        frameTop = { 0.725, 0.541, 0.290 },
        frameBottom = { 0.290, 0.204, 0.098 },
        panelTop = { 0.102, 0.096, 0.086 },
        panelBottom = { 0.071, 0.067, 0.059 },
        headerTop = { 0.133, 0.125, 0.112 },
        sidebarTop = { 0.051, 0.048, 0.044 },
        sidebarBottom = { 0.039, 0.036, 0.033 },
        navHover = { 0.886, 0.722, 0.431, 0.14 },
        scrollShade = { 0, 0, 0, 0.45 },
    }

    local SHADE_BLACK = { 0, 0, 0, 1 }
    local FILL_LINE = { 1, 1, 1, 0.35 }

    local function Raised(state, text, offset)
        if state == "hover" then
            return Style(P.raiseHoverTop, P.raiseHoverBottom, P.edgeHover, P.sheen, text, offset)
        elseif state == "pressed" then
            return Style(P.raisePressedTop, P.raisePressedBottom, P.edgeActive, P.fieldShade, text, offset)
        elseif state == "disabled" then
            return Style(P.raiseDisabledTop, P.raiseDisabledBottom, P.edgeDisabled, CLEAR, text, offset)
        end
        return Style(P.raiseTop, P.raiseBottom, P.edge, P.sheen, text, offset)
    end

    ---@param edge number[]
    ---@param bottom? number[]
    local function Well(edge, bottom, text)
        return Style(P.fieldTop, bottom or P.fieldBottom, edge, P.fieldShade, text)
    end

    local function Cap(state)
        local raised = Raised(state)
        return { capTop = raised.top, capBottom = raised.bottom, capLine = raised.line }
    end

    local function WellSlider(trackEdge, thumb, knobTop, knobBottom, disabled)
        return {
            trackEdge = trackEdge,
            trackTop = P.fieldTop,
            trackBottom = P.fieldBottom,
            trackShade = SHADE_BLACK,
            fillLeft = disabled and P.fillDisabled or P.accentLow,
            fillRight = disabled and P.fillDisabled or P.accent,
            fillLine = disabled and CLEAR or FILL_LINE,
            thumb = thumb,
            knobTop = knobTop,
            knobBottom = knobBottom,
        }
    end

    local lines = { P.frameOuter, { top = P.frameTop, bottom = P.frameBottom }, Alpha(P.fieldTop, 1) }
    local band = { top = P.headerTop, bottom = P.panelTop }
    local body = { top = P.panelTop, bottom = P.panelBottom }
    local stepperLimit = Raised("disabled", P.textDisabled)

    ---@type BRTheme
    local theme = {
        text = P.text,
        textDisabled = P.textDisabled,
        title = TITLE,
        titleText = TITLE,
        note = NOTE,
        ownTooltip = true,
        tooltip = With(Style(P.menuBg, P.menuBg, P.edgeHover, CLEAR), { title = TITLE, desc = NOTE }),

        shell = {
            panel = { lines = lines, band = band, body = body },
            dialog = { lines = lines, band = band, body = body },
            drawer = { lines = { lines[1], lines[2] }, body = body },
            bracket = P.frameTop,
        },
        groove = {
            dialog = { color = P.frameTop, shade = P.fieldShade, fadeLeft = 40, fadeRight = 40 },
            header = { color = P.frameTop, shade = P.fieldShade, fadeLeft = 80, fadeRight = 80 },
            drawer = { color = P.frameTop, shade = P.fieldShade, fadeLeft = 0, fadeRight = 40 },
        },
        drawerStripe = { color = P.accent, width = 2 },
        headerBrand = { P.text, P.accent },
        headerDot = P.textDisabled,
        version = P.textDisabled,
        zoom = { idle = P.textIdle, limit = P.textDisabled, hover = P.accent },
        sidebar = { top = P.sidebarTop, bottom = P.sidebarBottom, edge = P.edge, inset = 1 },
        sidebarGroup = { text = NOTE, left = P.edge, right = Alpha(P.edge, 0) },
        nav = {
            idle = { left = CLEAR, right = CLEAR, text = P.textIdle },
            hover = { left = P.navHover, right = Alpha(P.navHover, 0), text = P.text },
            active = { left = P.menuHover, right = Alpha(P.menuHover, 0), text = TITLE },
            bar = P.accent,
            barHeight = 24,
        },
        footer = {
            normal = Raised("normal", P.text),
            hover = Raised("hover", TITLE),
            active = Raised("pressed", P.accent, 1),
        },
        footerRule = { ends = Alpha(P.edgeHover, 0), center = P.edgeHover },
        stripMask = Alpha(P.panelTop, 1),
        sectionRule = { ends = Alpha(P.accent, 0), center = Alpha(P.accent, 1) },
        tabRule = { ends = Alpha(P.edgeHover, 0), center = P.edgeHover },

        button = {
            normal = Raised("normal", P.text),
            hover = Raised("hover", TITLE),
            pressed = Raised("pressed", P.text, 1),
            disabled = Raised("disabled", P.textDisabled),
        },
        closeButton = {
            normal = Style(CLEAR, CLEAR, CLEAR, CLEAR, P.textIdle),
            hover = Raised("hover", TITLE),
            pressed = Raised("pressed", P.accent, 1),
            disabled = Style(CLEAR, CLEAR, CLEAR, CLEAR, P.textDisabled),
        },
        arrowButton = {
            normal = Raised("normal", P.textIdle),
            hover = Raised("hover", P.accent),
            disabled = Raised("disabled", P.textDisabled),
        },
        stepper = {
            normal = Raised("normal", P.text),
            hover = Raised("hover", TITLE),
            pressed = Raised("pressed", P.text),
            limit = stepperLimit,
            disabled = stepperLimit,
        },
        checkbox = {
            normal = With(Well(P.edge), { mark = P.accent }),
            hover = With(Well(P.edgeHover), { mark = P.accent }),
            checked = With(Well(P.edgeActive, P.fieldOnBottom), { mark = P.accent }),
            checkedHover = With(Well(P.edgeHover, P.fieldOnBottom), { mark = P.accent }),
            disabled = With(Well(P.edgeDisabled), { mark = P.accentDisabled }),
            disabledChecked = With(Well(P.edgeDisabled, P.fieldOnBottom), { mark = P.accentDisabled }),
        },
        toggle = {
            off = With(Well(P.edge), { knobTop = P.raiseHoverTop, knobBottom = P.raiseBottom, sheen = P.sheen }),
            offHover = With(
                Well(P.edgeHover),
                { knobTop = P.edgeHover, knobBottom = P.raiseHoverBottom, sheen = P.sheen }
            ),
            on = With(
                Well(P.edgeActive, P.fieldOnBottom),
                { knobTop = P.knobTop, knobBottom = P.knobBottom, sheen = CLEAR }
            ),
            onHover = With(
                Well(P.edgeHover, P.fieldOnBottom),
                { knobTop = P.knobHoverTop, knobBottom = P.knobHoverBottom, sheen = CLEAR }
            ),
            disabled = With(
                Well(P.edgeDisabled),
                { knobTop = P.raiseDisabledTop, knobBottom = P.raiseDisabledBottom, sheen = CLEAR }
            ),
        },
        link = { linked = P.accent, unlinked = P.edge, hover = TITLE, disabled = P.edgeDisabled },
        slider = {
            normal = WellSlider(P.edge, P.raiseDisabledBottom, P.knobTop, P.knobBottom),
            hover = WellSlider(P.edge, P.raiseDisabledBottom, P.knobHoverTop, P.knobHoverBottom),
            drag = WellSlider(P.edgeHover, P.accent, P.knobHoverTop, P.knobHoverBottom),
            disabled = WellSlider(P.edgeDisabled, P.raiseDisabledBottom, P.textDisabled, P.edgeDisabled, true),
            valueDrag = P.accent,
        },
        dropdown = {
            normal = With(Well(P.edge, nil, P.text), With(Cap("normal"), { divider = P.edge, arrow = P.textIdle })),
            hover = With(
                Well(P.edgeHover, nil, P.text),
                With(Cap("hover"), { divider = P.edgeHover, arrow = P.accent })
            ),
            open = With(
                Well(P.edgeActive, nil, P.text),
                With(Cap("pressed"), { divider = P.edgeActive, arrow = P.accent })
            ),
            disabled = With(
                Well(P.edgeDisabled, nil, P.textDisabled),
                With(Cap("disabled"), { divider = P.edgeDisabled, arrow = P.textDisabled })
            ),
            capWidth = 18,
        },
        menu = Style(P.menuBg, P.menuBg, P.edgeHover, { 1, 1, 1, 0.08 }),
        menuItem = {
            hoverLeft = P.menuHover,
            hoverRight = Alpha(P.menuHover, 0),
            bar = Alpha(P.accent, 1),
            text = P.text,
            textHover = TITLE,
            check = P.accent,
        },
        segmentBar = Well(P.edge),
        segmentDivider = P.edge,
        segment = {
            on = {
                top = P.raiseTop,
                bottom = P.raiseBottom,
                text = P.accent,
                sheen = P.sheen,
                tintTop = 0.35,
                tintBottom = 0.18,
                tintText = 1,
                tintAlpha = 1,
            },
            partial = {
                top = P.raiseBottom,
                bottom = P.fieldBottom,
                text = Alpha(P.accent, 0.65),
                sheen = CLEAR,
                tintText = 1,
                tintAlpha = 0.65,
            },
            off = { top = CLEAR, bottom = CLEAR, text = Alpha(P.textIdle, 0.65), sheen = CLEAR },
            disabled = { top = CLEAR, bottom = CLEAR, text = P.textDisabled, sheen = CLEAR },
        },
        tab = {
            line = P.accent,
            hoverAlpha = 0.35,
            washTop = Alpha(P.accent, 0),
            washBottom = Alpha(P.accent, 0.16),
            active = TITLE,
            idle = P.textIdle,
            hover = P.text,
        },
        editBox = {
            normal = With(Well(P.edge, nil, P.text), { ring = CLEAR }),
            hover = With(Well(P.edgeHover, nil, P.text), { ring = CLEAR }),
            focus = With(Well(P.edgeActive, nil, P.text), { ring = P.focusRing }),
            disabled = With(Well(P.edgeDisabled, nil, P.textDisabled), { ring = CLEAR }),
            readOnly = P.textIdle,
            cursor = P.accent,
        },
        swatch = {
            normal = P.edge,
            hover = P.edgeHover,
            open = P.edgeActive,
            disabled = P.edgeDisabled,
            inner = SHADE_BLACK,
        },
        scrollbar = {
            trackInset = 4,
            trackLeft = P.fieldTop,
            trackRight = P.fieldBottom,
            trackEdge = P.edge,
            sheen = P.sheen,
            normal = { left = P.raiseHoverTop, right = P.raiseBottom },
            hover = { left = P.edgeHover, right = P.raiseHoverBottom },
            drag = { left = P.knobTop, right = P.knobBottom },
        },
        scrollFade = { height = 8, color = P.scrollShade },
        banner = {
            red = {
                bg = { 0.16, 0.05, 0.03, 0.7 },
                text = { 0.94, 0.80, 0.75 },
                accentBottom = CLEAR,
                accentLeft = { 0.69, 0.25, 0.18, 1 },
                line = P.edge,
            },
            orange = {
                bg = Alpha(P.fieldOnBottom, 0.7),
                text = NOTE,
                accentBottom = CLEAR,
                accentLeft = P.edgeActive,
                line = P.edge,
            },
        },
        mover = { body = { 0.08, 0.055, 0.03, 0.88 }, edge = { 0.72, 0.54, 0.29, 1 }, text = { 1.0, 0.929, 0.824, 1 } },
        cell = { edge = P.edge, selected = P.edgeActive, check = P.accent },
    }
    return theme
end

BR.Theme = BR.CLIENT == BR.ClientType.Forever and BuildForever() or BuildRetail()
BR.THEME_CLEAR = CLEAR

-- ============================================================================
-- COLORS
-- ============================================================================

---Color escape of an RGB color, for text that mixes colors.
---@param c number[]
---@return string
function BR.ColorCode(c)
    return string.format(
        "|cff%02x%02x%02x",
        math.floor(c[1] * 255 + 0.5),
        math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5)
    )
end

-- Color escape for titles and headers.
BR.TITLE_COLOR_CODE = BR.ColorCode(BR.Theme.titleText)

---@param fontString table
---@param c number[]
---@param alpha? number Overrides the alpha of c
local function SetTextColor(fontString, c, alpha)
    fontString:SetTextColor(c[1], c[2], c[3], alpha or c[4] or 1)
end
BR.SetThemeTextColor = SetTextColor

---@param fontString table
function BR.ApplyTitleColor(fontString)
    SetTextColor(fontString, BR.Theme.title)
end

---@param fontString table
function BR.ApplyNoteColor(fontString)
    SetTextColor(fontString, BR.Theme.note)
end

local GetAtlasInfo = C_Texture.GetAtlasInfo

---@param atlas string?
---@return boolean
function BR.HasThemeAtlas(atlas)
    return atlas ~= nil and GetAtlasInfo(atlas) ~= nil
end

-- One color object per color table and alpha. Callers must not change a returned color.
local colorCache = setmetatable({}, { __mode = "k" })

---@param c number[]
---@param alpha? number Overrides the alpha of c
---@return table color
local function ThemeColor(c, alpha)
    local a = alpha or c[4] or 1
    local byAlpha = colorCache[c]
    if not byAlpha then
        byAlpha = {}
        colorCache[c] = byAlpha
    end
    local color = byAlpha[a]
    if not color then
        color = CreateColor(c[1], c[2], c[3], a)
        byAlpha[a] = color
    end
    return color
end

---@param texture table
---@param c number[]
local function SetColorTexture(texture, c)
    texture:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end
BR.SetThemeColorTexture = SetColorTexture

---Paint a white texture with a gradient. SetGradient takes the bottom or left color first.
---@param texture table
---@param orientation "VERTICAL"|"HORIZONTAL"
---@param first number[] Bottom or left color
---@param second number[] Top or right color
local function PaintGradient(texture, orientation, first, second)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient(orientation, ThemeColor(first), ThemeColor(second))
end
BR.PaintGradient = PaintGradient

-- ============================================================================
-- SURFACES
-- ============================================================================

---A 1 px frame of four textures inside a region. With overlap, the top and bottom
---lines also cover the corners that the sides cover.
---@param frame table
---@param layer string
---@param sublevel number
---@param inset number
---@param overlap? boolean
---@return table[] sides Top, bottom, left, right
local function CreateRing(frame, layer, sublevel, inset, overlap)
    local sides = {}
    for i = 1, 4 do
        sides[i] = frame:CreateTexture(nil, layer, nil, sublevel)
    end
    -- Without overlap, the sides own the corners, so a gradient side keeps the
    -- gradient of a full-size rectangle.
    local cut = overlap and 0 or 1
    sides[1]:SetPoint("TOPLEFT", inset + cut, -inset)
    sides[1]:SetPoint("TOPRIGHT", -inset - cut, -inset)
    sides[1]:SetHeight(1)
    sides[2]:SetPoint("BOTTOMLEFT", inset + cut, inset)
    sides[2]:SetPoint("BOTTOMRIGHT", -inset - cut, inset)
    sides[2]:SetHeight(1)
    sides[3]:SetPoint("TOPLEFT", inset, -inset)
    sides[3]:SetPoint("BOTTOMLEFT", inset, inset)
    sides[3]:SetWidth(1)
    sides[4]:SetPoint("TOPRIGHT", -inset, -inset)
    sides[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
    sides[4]:SetWidth(1)
    return sides
end
BR.CreateRing = CreateRing

---@param sides table[]
---@param c number[]|{top: number[], bottom: number[]}
local function PaintRing(sides, c)
    if c.top then
        SetColorTexture(sides[1], c.top)
        SetColorTexture(sides[2], c.bottom)
        PaintGradient(sides[3], "VERTICAL", c.bottom, c.top)
        PaintGradient(sides[4], "VERTICAL", c.bottom, c.top)
        return
    end
    for i = 1, 4 do
        SetColorTexture(sides[i], c)
    end
end
BR.PaintRing = PaintRing

---@class ThemeSurface
---@field fill table
---@field edge table[]
---@field line table

---A fill under a 1 px edge, and a 1 px line under the top edge. The fill spans
---the whole frame, so a translucent edge blends over it, as on a backdrop.
---@param frame table
---@return ThemeSurface
local function CreateSurface(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    local line = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", -1, -1)
    line:SetHeight(1)
    return { fill = fill, edge = CreateRing(frame, "BACKGROUND", -6, 0), line = line }
end
BR.CreateSurface = CreateSurface

---A color { accent = a } resolves to the accent at alpha a.
---@param c table
---@param accent number[]
---@return number[]
local function Resolve(c, accent)
    if c.accent then
        return Alpha(accent, c.accent)
    end
    return c
end

---Copy a style with its accent colors resolved.
---@param style ThemeStyle
---@param accent number[]
---@return ThemeStyle
function BR.ResolveStyle(style, accent)
    return With(style, {
        top = Resolve(style.top, accent),
        bottom = Resolve(style.bottom, accent),
        edge = Resolve(style.edge, accent),
        line = Resolve(style.line, accent),
    })
end

---@param surface ThemeSurface
---@param style ThemeStyle
local function PaintSurface(surface, style)
    PaintGradient(surface.fill, "VERTICAL", style.bottom, style.top)
    PaintRing(surface.edge, style.edge)
    SetColorTexture(surface.line, style.line)
end
BR.PaintSurface = PaintSurface

---Paint a style on a surface and its label: text color and pressed offset.
---@param surface ThemeSurface
---@param label table FontString
---@param style ThemeStyle
function BR.PaintStyled(surface, label, style)
    PaintSurface(surface, style)
    SetTextColor(label, style.text)
    label:SetPoint("CENTER", 0, -style.offset)
end

---A 1 px line in two halves that the caller anchors to meet in the middle. Each
---half runs from the ends color to the center color.
---@param parent table
---@param layer string
---@param colors {ends: number[], center: number[]}
---@return table left
---@return table right
function BR.CreateRule(parent, layer, colors)
    local left = parent:CreateTexture(nil, layer)
    left:SetHeight(1)
    PaintGradient(left, "HORIZONTAL", colors.ends, colors.center)
    local right = parent:CreateTexture(nil, layer)
    right:SetHeight(1)
    PaintGradient(right, "HORIZONTAL", colors.center, colors.ends)
    return left, right
end

-- ============================================================================
-- SHELL
-- ============================================================================

local BRACKET_LENGTH = 10
local BRACKET_INSET = 4
local KNOT_SIZE = 2
local KNOT_INSET = 7

---@class ShellTokens
---@field lines (number[]|{top: number[], bottom: number[]})[] Frame lines from the outside in, 1 px each
---@field band? {top: number[], bottom: number[]} Header band; nil draws no band
---@field body {top: number[], bottom: number[]}

---Draw a panel shell: the frame lines, a header band when the theme has one, and
---the body. Every texture sits on the frame itself, so child frames stay above it.
---@param frame table
---@param shell ShellTokens
---@param bandHeight? number Bottom of the header band, from the top of the frame
---@return number inset Width of the frame lines
function BR.AddShell(frame, shell, bandHeight)
    local inset = #shell.lines
    for i, c in ipairs(shell.lines) do
        PaintRing(CreateRing(frame, "BACKGROUND", i - 1, i - 1), c)
    end

    local bodyTop = inset
    if shell.band and bandHeight then
        local band = frame:CreateTexture(nil, "BORDER", nil, -7)
        band:SetPoint("TOPLEFT", inset, -inset)
        band:SetPoint("TOPRIGHT", -inset, -inset)
        band:SetHeight(bandHeight - inset)
        PaintGradient(band, "VERTICAL", shell.band.bottom, shell.band.top)
        bodyTop = bandHeight
    end
    local body = frame:CreateTexture(nil, "BORDER", nil, -7)
    body:SetPoint("TOPLEFT", inset, -bodyTop)
    body:SetPoint("BOTTOMRIGHT", -inset, inset)
    PaintGradient(body, "VERTICAL", shell.body.bottom, shell.body.top)
    return inset
end

---Paint a 1 px line as a groove: the middle in the groove color, fades at the
---ends, and a shade line under it. The line keeps its anchors, so frames that
---hang from it do not move.
---@param line table Texture
---@param groove {color: number[], shade: number[], fadeLeft: number, fadeRight: number}
function BR.AddGroove(line, groove)
    local parent = line:GetParent()
    local layer, sublevel = line:GetDrawLayer()
    local c = groove.color
    local leftFade, rightFade = groove.fadeLeft, groove.fadeRight
    line:SetColorTexture(0, 0, 0, 0)

    local middle = parent:CreateTexture(nil, layer, nil, sublevel)
    middle:SetPoint("TOPLEFT", line, "TOPLEFT", leftFade, 0)
    middle:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -rightFade, 0)
    SetColorTexture(middle, c)
    if leftFade > 0 then
        local fade = parent:CreateTexture(nil, layer, nil, sublevel)
        fade:SetPoint("TOPLEFT", line, "TOPLEFT")
        fade:SetPoint("BOTTOMRIGHT", middle, "BOTTOMLEFT")
        PaintGradient(fade, "HORIZONTAL", Alpha(c, 0), c)
    end
    if rightFade > 0 then
        local fade = parent:CreateTexture(nil, layer, nil, sublevel)
        fade:SetPoint("TOPLEFT", middle, "TOPRIGHT")
        fade:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT")
        PaintGradient(fade, "HORIZONTAL", c, Alpha(c, 0))
    end

    local shade = parent:CreateTexture(nil, layer, nil, sublevel)
    shade:SetPoint("TOPLEFT", line, "BOTTOMLEFT")
    shade:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT")
    shade:SetHeight(1)
    SetColorTexture(shade, groove.shade)
end

---@param frame table
function BR.AddCornerBrackets(frame)
    local c = BR.Theme.shell.bracket
    -- Each corner: anchor point, then the x and y signs that point inward.
    local corners = { { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }
    for _, corner in ipairs(corners) do
        local point, sx, sy = corner[1], corner[2], corner[3]
        local parts = {
            { BRACKET_LENGTH, 1, BRACKET_INSET },
            { 1, BRACKET_LENGTH, BRACKET_INSET },
            { KNOT_SIZE, KNOT_SIZE, KNOT_INSET },
        }
        for _, part in ipairs(parts) do
            local tex = frame:CreateTexture(nil, "BORDER", nil, 1)
            tex:SetSize(part[1], part[2])
            tex:SetPoint(point, sx * part[3], sy * part[3])
            SetColorTexture(tex, c)
        end
    end
end
