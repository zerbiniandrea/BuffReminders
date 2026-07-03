local _, BR = ...

-- ============================================================================
-- PER-BUFF SETTINGS: DRAWER + EDITOR
-- ============================================================================
-- Opened from every All Buffs row link. Two surfaces, split by weight:
--
--   * DRAWER - a light popover anchored beside the row. Holds the universal
--     knobs (Sound, Detach, and Show where it applies) plus this buff's small
--     special controls inline. This is the whole interaction for most buffs.
--     Enable is NOT here - the row's own checkbox owns it.
--   * EDITOR - a focused panel opened from the drawer's "Edit X" door, for the
--     two buffs whose special section is a real editor (poison priority columns,
--     runeforge-per-spec tabs). Single-purpose: just that editor.
--
-- Both are built once (chrome) and rebuilt per open (body); holders created in
-- the body are unregistered on teardown. The drawer dismisses on click-away
-- (catcher), ESC, or its close button. (Chat request messages live on their own
-- page: Alerts > Chat Requests.)
--
-- Healthstone and Soulstone fold their old three-value visibility dropdowns
-- (readyCheck / casterOnly / always) into the same Show toggle everything
-- else uses, plus a "Warlocks always see it" checkbox for the casterOnly
-- middle state.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local LSM = BR.LSM

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local tinsert = table.insert
local tconcat = table.concat
local format = string.format
local abs = math.abs
local wipe = wipe

-- Focused-editor default width; poison / runeforge override it (SPECIAL_WIDTH).
local PANEL_W = 420

-- Buffs whose special section is a full editor (poison columns / runeforge tab
-- strip) - too big for the drawer, so the drawer shows a door to a focused
-- editor panel sized to the buff instead of inline controls.
local SPECIAL_WIDTH = {
    roguePoisons = 520,
    dkRunes = 560,
}

BR.Options.Dialogs = BR.Options.Dialogs or {}

-- drawer = the quick-settings popover anchored beside a row; editor = the
-- focused per-buff panel opened from the drawer's "Edit" door; catcher = the
-- click-away dismiss layer under the drawer.
local drawer, drawerBody, drawerIcon, drawerTitle, catcher
local editor, editorBody, editorIcon, editorTitle
-- Active build surface: pointed at the drawer or editor body (and its holder
-- list / content width) before a build, so the shared AddSpecialCheckbox /
-- AddInlineEditor helpers write to the right one.
local body
local bodyW = 0
local bodyHolders = {}
local drawerHolders = {}
local editorHolders = {}

-- ============================================================================
-- SHOW (ready check) MODELS
-- ============================================================================
-- Regular readyCheckOnly buffs store their override in
-- readyCheckOnlyOverrides[key] (nil = ready-check-only, false = always).
-- Healthstone/Soulstone store a three-value mode in defaults.*Visibility;
-- the caster checkbox covers the middle value.

local function MakeOverrideShowModel(key)
    return {
        isReadyCheck = function()
            local overrides = BR.profile.readyCheckOnlyOverrides
            return not overrides or overrides[key] ~= false
        end,
        setReadyCheck = function(checked)
            BR.Config.Set("readyCheckOnlyOverrides." .. key, checked and nil or false)
        end,
    }
end

local function MakeVisibilityShowModel(configKey)
    local path = "defaults." .. configKey
    local model
    model = {
        isReadyCheck = function()
            return BR.Config.Get(path) ~= "always"
        end,
        setReadyCheck = function(checked)
            if not checked then
                BR.Config.Set(path, "always")
            elseif model.isCasterAlways() then
                BR.Config.Set(path, "casterOnly")
            else
                BR.Config.Set(path, "readyCheck")
            end
        end,
        isCasterAlways = function()
            return BR.Config.Get(path) == "casterOnly"
        end,
        setCasterAlways = function(checked)
            BR.Config.Set(path, checked and "casterOnly" or "readyCheck")
        end,
        hasCasterOption = true,
    }
    return model
end

local SHOW_MODELS = {
    healthstone = function()
        return MakeVisibilityShowModel("healthstoneVisibility")
    end,
    soulstone = function()
        return MakeVisibilityShowModel("soulstoneVisibility")
    end,
}

-- ============================================================================
-- BUFF-SPECIFIC SECTIONS
-- ============================================================================
-- Each builder appends this buff's extra controls to the body layout. The
-- simple checkbox rows share one small factory.

local function AddSpecialCheckbox(layout, opts)
    local holder = Components.Checkbox(body, {
        label = opts.label,
        get = opts.get,
        tooltip = opts.tooltip,
        onChange = opts.onChange,
    })
    tinsert(bodyHolders, holder)
    layout:Add(holder, nil, COMPONENT_GAP)
    return holder
end

-- Render a buff's inline editor (poison / runeforge) into the panel body at the
-- layout's current cursor, then advance the layout past it. The editor parents
-- its frames to `body` and registers its checkbox holders for teardown.
local function AddInlineEditor(layout, builder)
    local height = builder(body, {
        x = 0,
        y = layout:GetY(),
        width = bodyW,
        registerHolder = function(holder)
            tinsert(bodyHolders, holder)
        end,
    })
    layout:Space(height)
end

-- ============================================================================
-- ROW CAPTION HELPERS
-- ============================================================================
-- The All Buffs row for each special buff carries a second line naming its
-- option and showing the current value (see _BuffRow). These helpers build
-- that value text. Each `caption()` returns (text, isWarning): isWarning flips
-- the line to the orange "needs setup" state for genuinely unset selections.

-- First enabled poison name per category, joined "Lethal + Non-lethal".
-- Warns when a whole category has nothing enabled (the reminder can't fire).
local function PoisonCaption()
    local prefs = BR.profile.roguePoisonPreferences
    local function firstEnabled(cat)
        local list = prefs and prefs[cat]
        if not list then
            return nil
        end
        for _, entry in ipairs(list) do
            if entry.enabled and entry.spellID then
                return BR.GetSpellName(entry.spellID)
            end
        end
        return nil
    end
    local lethal = firstEnabled("lethal")
    local nonLethal = firstEnabled("nonLethal")
    if not lethal and not nonLethal then
        return L["BuffRow.Caption.PoisonsUnset"], true
    end
    local parts = {}
    if lethal then
        tinsert(parts, lethal)
    end
    if nonLethal then
        tinsert(parts, nonLethal)
    end
    return format(L["BuffRow.Caption.Poisons"], tconcat(parts, " + ")), false
end

-- Runeforge choice for the player's current spec (only meaningful for DKs, and
-- only once a spec exists). Falls back to the generic "set per spec" prompt for
-- non-DKs and unconfigured DK specs, so the row still advertises the feature.
local function RuneforgeCaption()
    local specId = BR.StateHelpers.GetPlayerSpecId()
    local specPrefs = specId and BR.profile.dkRunePreferences and BR.profile.dkRunePreferences[specId]
    if specPrefs then
        local isDW = BR.BuffState.HasOffHandWeapon()
        local accepted = specPrefs[isDW and "dw_mainhand" or "mainhand"]
        if accepted then
            for _, rune in ipairs(BR.DK_RUNEFORGES) do
                if accepted[rune.enchantID] then
                    return format(L["BuffRow.Caption.Runeforge"], BR.GetSpellName(rune.spellID) or rune.key), false
                end
            end
        end
    end
    return L["BuffRow.Caption.RuneforgeUnset"], false
end

-- Two-state description for a boolean toggle: on -> onKey, off -> offKey.
local function ToggleCaption(getter, onKey, offKey)
    return function()
        return getter() and L[onKey] or L[offKey], false
    end
end

-- Each entry: `caption()` returns (text, isWarning) for the All Buffs row's
-- second line (see _BuffRow); `build(layout)` appends this buff's extra
-- controls to the panel body.
local SPECIAL_SECTIONS = {
    healthstone = {
        caption = function()
            if not BR.Config.Get("defaults.healthstoneLowStock") then
                return L["BuffRow.Caption.HealthstoneOff"], false
            end
            return format(L["BuffRow.Caption.Healthstone"], BR.Config.Get("defaults.healthstoneThreshold") or 1), false
        end,
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.Healthstone.LowStock"],
                get = function()
                    return BR.Config.Get("defaults.healthstoneLowStock")
                end,
                tooltip = { title = L["Options.Healthstone.LowStock"], desc = L["Options.Healthstone.LowStock.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.healthstoneLowStock", checked)
                    Components.RefreshAll()
                end,
            })
            local thresholdHolder = Components.Slider(body, {
                label = L["Options.Healthstone.Threshold"],
                labelWidth = 110,
                min = 1,
                max = 2,
                step = 1,
                get = function()
                    return BR.Config.Get("defaults.healthstoneThreshold")
                end,
                enabled = function()
                    return BR.Config.Get("defaults.healthstoneLowStock")
                end,
                disabledReason = L["DisabledReason.HealthstoneThreshold"],
                tooltip = { title = L["Options.Healthstone.Threshold"], desc = L["Options.Healthstone.Threshold.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.healthstoneThreshold", val)
                end,
            })
            tinsert(bodyHolders, thresholdHolder)
            layout:Add(thresholdHolder, nil, COMPONENT_GAP)
        end,
    },

    soulstone = {
        caption = ToggleCaption(function()
            return BR.Config.Get("defaults.soulstoneHideCooldown")
        end, "BuffRow.Caption.SoulstoneHidden", "BuffRow.Caption.SoulstoneShown"),
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.Soulstone.HideCooldown"],
                get = function()
                    return BR.Config.Get("defaults.soulstoneHideCooldown")
                end,
                tooltip = {
                    title = L["Options.Soulstone.HideCooldown"],
                    desc = L["Options.Soulstone.HideCooldown.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.soulstoneHideCooldown", checked)
                end,
            })
        end,
    },

    bronze = {
        caption = ToggleCaption(function()
            return BR.profile.bronzeHideInCombat == true
        end, "BuffRow.Caption.BronzeHidden", "BuffRow.Caption.BronzeShown"),
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.BronzeHideInCombat"],
                get = function()
                    return BR.profile.bronzeHideInCombat == true
                end,
                tooltip = { title = L["Options.BronzeHideInCombat"], desc = L["Options.BronzeHideInCombat.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("bronzeHideInCombat", checked)
                end,
            })
        end,
    },

    druidWrongForm = {
        caption = ToggleCaption(function()
            return BR.profile.druidIgnoreTravelForm ~= false
        end, "BuffRow.Caption.TravelIgnored", "BuffRow.Caption.TravelCounts"),
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.DruidIgnoreTravelForm"],
                get = function()
                    return BR.profile.druidIgnoreTravelForm ~= false
                end,
                tooltip = {
                    title = L["Options.DruidIgnoreTravelForm"],
                    desc = L["Options.DruidIgnoreTravelForm.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("druidIgnoreTravelForm", checked)
                end,
            })
        end,
    },

    petPassive = {
        caption = ToggleCaption(function()
            return BR.profile.petPassiveOnlyInCombat == true
        end, "BuffRow.Caption.PetPassiveCombat", "BuffRow.Caption.PetPassiveAlways"),
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.PetPassiveCombat"],
                get = function()
                    return BR.profile.petPassiveOnlyInCombat == true
                end,
                tooltip = { title = L["Options.PetPassiveCombat"], desc = L["Options.PetPassiveCombat.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("petPassiveOnlyInCombat", checked)
                end,
            })
        end,
    },

    pets = {
        caption = ToggleCaption(function()
            return BR.Config.Get("defaults.useFelDomination")
        end, "BuffRow.Caption.FelOn", "BuffRow.Caption.FelOff"),
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.FelDomination"],
                get = function()
                    return BR.Config.Get("defaults.useFelDomination")
                end,
                tooltip = { title = L["Options.FelDomination.Title"], desc = L["Options.FelDomination.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.useFelDomination", checked)
                end,
            })
        end,
    },

    delveFood = {
        caption = ToggleCaption(function()
            return BR.Config.Get("defaults.delveFoodTimer") == true
        end, "BuffRow.Caption.FoodTimerOn", "BuffRow.Caption.FoodTimerOff"),
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.DelveFoodTimer"],
                get = function()
                    return BR.Config.Get("defaults.delveFoodTimer") == true
                end,
                tooltip = { title = L["Options.DelveFoodTimer"], desc = L["Options.DelveFoodTimer.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.delveFoodTimer", checked)
                end,
            })
        end,
    },

    dkRunes = {
        caption = RuneforgeCaption,
        build = function(layout)
            AddInlineEditor(layout, BR.Options.Dialogs.Runeforge.BuildInline)
        end,
    },

    roguePoisons = {
        caption = PoisonCaption,
        build = function(layout)
            AddInlineEditor(layout, BR.Options.Dialogs.RoguePoison.BuildInline)
        end,
    },
}

-- Editor names for the drawer's "Edit X" door. Only the two rich editors are
-- named; every other special buff shows the generic gold "Extras" link on the
-- row and its small controls inline in the drawer (no per-buff name needed).
local SPECIAL_LABELS = {
    dkRunes = L["BuffRow.Option.Runeforge"],
    roguePoisons = L["BuffRow.Option.Poisons"],
}

-- ============================================================================
-- DRAWER + EDITOR
-- ============================================================================
-- The row link opens a light popover DRAWER anchored beside the row: Sound +
-- Detach (+ Show), plus this buff's small special controls inline - or, for the
-- two rich editors (poison / runeforge), an "Edit X" door to a focused EDITOR
-- panel. Enable is NOT here; the All Buffs row checkbox owns it.

-- Buffs whose special section is a full editor -> the drawer shows a door to
-- the focused editor instead of rendering the controls inline.
local HAS_EDITOR = {
    roguePoisons = true,
    dkRunes = true,
}

local DRAWER_W = 300
local DRAWER_BODY_X = 14
local DRAWER_BODY_TOP = 40
local DRAWER_LABEL_W = 52
local EDITOR_BODY_X = 16
local EDITOR_BODY_TOP = 44

-- ---- Shared row builders (write into the active `body` surface) ---------------

local function BuildSoundOptions()
    local opts = { { label = L["BuffPanel.Sound.None"], value = "__none" } }
    for _, soundName in ipairs(LSM:List("sound")) do
        if soundName ~= "None" then
            tinsert(opts, { label = soundName, value = soundName })
        end
    end
    return opts
end

local function AddShowRow(layout, info)
    local key = info.key
    local showModelFactory = SHOW_MODELS[key]
    local showModel
    if showModelFactory then
        showModel = showModelFactory()
    elseif info.readyCheckOnly and not info.freeConsumable then
        showModel = MakeOverrideShowModel(key)
    end
    if not showModel then
        return
    end

    local function ToggleLabel(checked)
        return checked and L["Options.ReadyCheck"] or L["Options.Always"]
    end
    local showRow = CreateFrame("Frame", nil, body)
    showRow:SetSize(bodyW, 22)
    local showLabel = showRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showLabel:SetPoint("LEFT", 0, 0)
    showLabel:SetWidth(DRAWER_LABEL_W)
    showLabel:SetJustifyH("LEFT")
    showLabel:SetText(L["BuffPanel.Show"])

    local toggle
    toggle = Components.Toggle(showRow, {
        label = ToggleLabel(showModel.isReadyCheck()),
        get = showModel.isReadyCheck,
        onChange = function(checked)
            showModel.setReadyCheck(checked)
            toggle.label:SetText(ToggleLabel(checked))
            Components.RefreshAll()
        end,
    })
    toggle:SetPoint("LEFT", showRow, "LEFT", DRAWER_LABEL_W + 4, 0)
    local origToggleRefresh = toggle.Refresh
    function toggle:Refresh()
        origToggleRefresh(self)
        self.label:SetText(ToggleLabel(showModel.isReadyCheck()))
    end
    tinsert(bodyHolders, toggle)
    layout:Add(showRow, 22, COMPONENT_GAP)

    if showModel.hasCasterOption then
        layout:SetX(DRAWER_LABEL_W + 4)
        local casterHolder = Components.Checkbox(body, {
            label = L["BuffPanel.CasterAlways"],
            get = showModel.isCasterAlways,
            enabled = showModel.isReadyCheck,
            disabledReason = L["DisabledReason.CasterAlways"],
            tooltip = { title = L["BuffPanel.CasterAlways"], desc = L["BuffPanel.CasterAlways.Desc"] },
            onChange = function(checked)
                showModel.setCasterAlways(checked)
            end,
        })
        tinsert(bodyHolders, casterHolder)
        layout:Add(casterHolder, nil, COMPONENT_GAP)
        layout:SetX(0)
    end
end

local function AddSoundRow(layout, key)
    local soundRow = CreateFrame("Frame", nil, body)
    soundRow:SetSize(bodyW, 24)
    local soundLabel = soundRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLabel:SetPoint("LEFT", 0, 0)
    soundLabel:SetWidth(DRAWER_LABEL_W)
    soundLabel:SetJustifyH("LEFT")
    soundLabel:SetText(L["BuffPanel.Sound"])

    local soundDrop = Components.Dropdown(soundRow, {
        label = "",
        labelWidth = 0,
        width = 178,
        maxItems = 15,
        options = BuildSoundOptions(),
        get = function()
            local sounds = BR.profile.buffSounds
            return (sounds and sounds[key]) or "__none"
        end,
        onChange = function(val)
            BR.Helpers.SetBuffSound(key, val ~= "__none" and val or nil)
            -- Repaint the All Buffs row so its sound glyph appears/disappears live.
            Components.RefreshAll()
        end,
    })
    soundDrop:SetPoint("LEFT", soundRow, "LEFT", DRAWER_LABEL_W + 4, 0)
    tinsert(bodyHolders, soundDrop)

    -- A small speaker icon instead of a "Preview" button - plays the current
    -- sound on click, costing far less width than a labelled button.
    local playBtn = CreateFrame("Button", nil, soundRow)
    playBtn:SetSize(16, 16)
    playBtn:SetPoint("LEFT", soundDrop, "RIGHT", 8, 0)
    local playTex = playBtn:CreateTexture(nil, "ARTWORK")
    playTex:SetAllPoints()
    playTex:SetAtlas("chatframe-button-icon-voicechat")
    playTex:SetVertexColor(0.72, 0.72, 0.76)
    playBtn:SetScript("OnEnter", function(self)
        playTex:SetVertexColor(1, 1, 1)
        BR.ShowTooltip(self, L["Options.Sound.Preview"], nil, "ANCHOR_RIGHT")
    end)
    playBtn:SetScript("OnLeave", function()
        playTex:SetVertexColor(0.72, 0.72, 0.76)
        BR.HideTooltip()
    end)
    playBtn:SetScript("OnClick", function()
        local sounds = BR.profile.buffSounds
        local soundName = sounds and sounds[key]
        if soundName then
            local file = LSM:Fetch("sound", soundName)
            if file then
                PlaySoundFile(file, "Master")
            end
        end
    end)
    layout:Add(soundRow, 24, COMPONENT_GAP)
end

local function AddDetachRow(layout, key)
    local detachRow = CreateFrame("Frame", nil, body)
    detachRow:SetSize(bodyW, 22)
    local detachHolder = Components.Checkbox(detachRow, {
        label = L["BuffPanel.Detached"],
        get = function()
            return BR.Helpers.IsIconDetached(key)
        end,
        tooltip = { title = L["BuffPanel.Detached"], desc = L["BuffPanel.Detached.Desc"] },
        onChange = function(checked)
            if checked then
                BR.Helpers.DetachIcon(key)
            else
                BR.Helpers.ReattachIcon(key)
            end
            BR.Display.Update()
            Components.RefreshAll()
        end,
    })
    detachHolder:SetPoint("LEFT", 0, 0)
    tinsert(bodyHolders, detachHolder)

    local resetPosBtn = CreateButton(detachRow, L["DetachedIcons.ResetPos"], function()
        BR.Helpers.ResetDetachedPosition(key)
    end)
    resetPosBtn:SetPoint("LEFT", detachHolder.infoIcon or detachHolder.label, "RIGHT", 8, 0)
    resetPosBtn:BindEnabled(function()
        return BR.Helpers.IsIconDetached(key)
    end)
    resetPosBtn:SetDisabledReason(L["DisabledReason.NotDetached"])
    tinsert(bodyHolders, resetPosBtn)
    layout:Add(detachRow, 22, COMPONENT_GAP)
end

-- ---- Focused editor (poison / runeforge) --------------------------------------

local function EnsureEditor()
    if editor then
        return
    end
    editor = BR.CreatePanel("BuffRemindersBuffEditor", PANEL_W, 200, { dialog = true, level = 220 })

    -- 18px icon centered in the 32px header strip so it clears the -32 title
    -- separator (the old 22px icon at -12 overlapped it).
    editorIcon = BR.CreateBuffIcon(editor, 18)
    editorIcon:SetPoint("TOPLEFT", EDITOR_BODY_X, -7)
    editorTitle = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editorTitle:SetPoint("LEFT", editorIcon, "RIGHT", 8, 0)

    local closeBtn = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        editor:Hide()
    end)
end

local function TearDownEditorBody()
    for _, holder in ipairs(editorHolders) do
        Components.Unregister(holder)
    end
    wipe(editorHolders)
    if editorBody then
        editorBody:Hide()
        editorBody:SetParent(nil)
        editorBody = nil
    end
end

local function OpenEditor(info)
    EnsureEditor()
    TearDownEditorBody()

    local key = info.key
    editorTitle:SetText("|cffffcc00" .. (info.displayName or key) .. "|r")
    editorIcon:SetTexture(info.icons and info.icons[1] or 134400)

    local panelW = SPECIAL_WIDTH[key] or PANEL_W
    editor:SetWidth(panelW)

    -- Point the shared build surface at the editor body.
    bodyW = panelW - EDITOR_BODY_X * 2
    editorBody = CreateFrame("Frame", nil, editor)
    editorBody:SetPoint("TOPLEFT", EDITOR_BODY_X, -EDITOR_BODY_TOP)
    editorBody:SetSize(bodyW, 100)
    body = editorBody
    bodyHolders = editorHolders

    local layout = Components.VerticalLayout(editorBody, { x = 0, y = 0 })
    SPECIAL_SECTIONS[key].build(layout)

    local h = abs(layout:GetY())
    editorBody:SetHeight(h)
    editor:SetHeight(EDITOR_BODY_TOP + h + 16)
    editor:Show()
    Components.RefreshAll()
end

-- ---- Drawer (quick-settings popover) ------------------------------------------

local function HideDrawer()
    if drawer then
        drawer:Hide()
    end
end

local function EnsureDrawer()
    if drawer then
        return
    end
    -- Click-away catcher: a transparent full-screen frame just under the drawer.
    -- A click anywhere outside the drawer lands here and dismisses it. Kept at
    -- the default (low) frame level so the sound dropdown's menu, which opens at
    -- a higher level, stays clickable.
    catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", HideDrawer)

    -- A drawer, not a dialog: a lightweight bordered card with a gold left-edge
    -- stripe - no title bar, no close button, no drag. It slides in from the
    -- anchor and dismisses on click-away or ESC.
    drawer = CreateFrame("Frame", "BuffRemindersBuffDrawer", UIParent, "BackdropTemplate")
    drawer:SetSize(DRAWER_W, 100)
    drawer:SetFrameStrata("FULLSCREEN_DIALOG")
    drawer:SetFrameLevel(230)
    drawer:SetClampedToScreen(true)
    drawer:EnableMouse(true)
    drawer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    drawer:SetBackdropColor(0.10, 0.10, 0.122, 0.98)
    drawer:SetBackdropBorderColor(unpack(BR.Colors.Border))

    -- Soft shadow so the drawer lifts off the list beneath it.
    for i = 1, 4 do
        local outset = 5 - i
        local shadow = drawer:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
        shadow:SetPoint("TOPLEFT", -outset, outset)
        shadow:SetPoint("BOTTOMRIGHT", outset, -outset)
        shadow:SetColorTexture(0, 0, 0, 0.05 + (i - 1) * 0.05)
    end

    -- Gold left-edge accent stripe: marks this as a contextual drawer belonging
    -- to the row that opened it, not a free-floating dialog.
    local stripe = drawer:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", 1, 1)
    stripe:SetWidth(3)
    stripe:SetColorTexture(0.9, 0.72, 0.26)

    drawerIcon = BR.CreateBuffIcon(drawer, 16)
    drawerIcon:SetPoint("TOPLEFT", DRAWER_BODY_X, -9)
    drawerTitle = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    drawerTitle:SetPoint("LEFT", drawerIcon, "RIGHT", 7, 0)
    drawerTitle:SetPoint("RIGHT", drawer, "RIGHT", -10, 0)
    drawerTitle:SetJustifyH("LEFT")
    drawerTitle:SetWordWrap(false)

    -- Thin header separator.
    local headSep = drawer:CreateTexture(nil, "ARTWORK")
    headSep:SetHeight(1)
    headSep:SetPoint("TOPLEFT", DRAWER_BODY_X, -30)
    headSep:SetPoint("TOPRIGHT", -10, -30)
    headSep:SetColorTexture(0.4, 0.32, 0.05, 0.45)

    -- Modeless ESC-to-dismiss (propagate other keys so it doesn't eat input).
    drawer:EnableKeyboard(true)
    drawer:SetScript("OnKeyDown", function(self, keyPressed)
        if keyPressed == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    drawer:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        if catcher then
            catcher:Hide()
        end
    end)
end

local function TearDownDrawerBody()
    for _, holder in ipairs(drawerHolders) do
        Components.Unregister(holder)
    end
    wipe(drawerHolders)
    if drawerBody then
        drawerBody:Hide()
        drawerBody:SetParent(nil)
        drawerBody = nil
    end
end

local function ShowDrawer(info, anchor)
    EnsureDrawer()
    TearDownDrawerBody()

    local key = info.key
    drawerTitle:SetText("|cffffcc00" .. (info.displayName or key) .. "|r")
    drawerIcon:SetTexture(info.icons and info.icons[1] or 134400)

    -- Point the shared build surface at the drawer body.
    bodyW = DRAWER_W - DRAWER_BODY_X * 2
    drawerBody = CreateFrame("Frame", nil, drawer)
    drawerBody:SetPoint("TOPLEFT", DRAWER_BODY_X, -DRAWER_BODY_TOP)
    drawerBody:SetSize(bodyW, 100)
    body = drawerBody
    bodyHolders = drawerHolders

    local layout = Components.VerticalLayout(drawerBody, { x = 0, y = 0 })

    -- Special section first (the buff's own knobs): a door to the focused editor
    -- for the rich ones, the small controls inline for the rest.
    local special = SPECIAL_SECTIONS[key]
    if special then
        if HAS_EDITOR[key] then
            local editBtn = CreateButton(
                drawerBody,
                format(L["BuffPanel.EditOption"], SPECIAL_LABELS[key] or key),
                function()
                    HideDrawer()
                    OpenEditor(info)
                end
            )
            editBtn:SetSize(bodyW, 24)
            layout:Add(editBtn, 24, COMPONENT_GAP)
        else
            special.build(layout)
        end
        layout:Space(4)
        local sep = drawerBody:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetColorTexture(0.4, 0.32, 0.05, 0.6)
        sep:SetPoint("TOPLEFT", drawerBody, "TOPLEFT", 0, layout:GetY())
        sep:SetPoint("TOPRIGHT", drawerBody, "TOPRIGHT", 0, layout:GetY())
        layout:Space(8)
    end

    AddShowRow(layout, info)
    AddSoundRow(layout, key)
    AddDetachRow(layout, key)

    local h = abs(layout:GetY())
    drawerBody:SetHeight(h)
    drawer:SetHeight(DRAWER_BODY_TOP + h + 12)

    drawer:ClearAllPoints()
    catcher:Show()
    drawer:Show()

    if anchor then
        -- Slide in from the anchor: the card eases the last few px to the right
        -- while fading up.
        local restX, dy = 8, 8
        local elapsed = 0
        drawer:SetAlpha(0)
        drawer:SetPoint("TOPLEFT", anchor, "TOPRIGHT", restX, dy)
        drawer:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = elapsed / 0.13
            if t > 1 then
                t = 1
            end
            local e = 1 - (1 - t) * (1 - t)
            self:SetAlpha(e)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", anchor, "TOPRIGHT", restX - 12 * (1 - e), dy)
            if t >= 1 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    else
        drawer:SetAlpha(1)
        drawer:SetPoint("CENTER")
    end

    Components.RefreshAll()
end

---Open the quick-settings drawer for a buff, anchored beside the row link.
---@param info table { key, displayName, icons, readyCheckOnly, freeConsumable }
---@param anchor? table Frame to anchor the drawer beside (the row's link)
local function Show(info, anchor)
    ShowDrawer(info, anchor)
end

BR.Options.Dialogs.BuffPanel = {
    Show = Show,
    ---Whether a buff has its own options (a special section), and whether that
    ---option still needs setup. Drives the All Buffs row's trailing link: a gold
    ---"Extras" (orange when isWarning) vs the plain gray "Settings". Warning is
    ---sourced from the same caption() the drawer uses (only poisons warn today).
    ---@return boolean isSpecial, boolean? isWarning
    GetSpecialState = function(key)
        local special = SPECIAL_SECTIONS[key]
        if not special then
            return false
        end
        local _, warn = special.caption()
        return true, warn
    end,
    Hide = function()
        if drawer then
            drawer:Hide()
        end
        if editor then
            editor:Hide()
        end
    end,
}
