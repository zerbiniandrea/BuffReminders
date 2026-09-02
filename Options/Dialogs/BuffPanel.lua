local _, BR = ...

-- ============================================================================
-- PER-BUFF SETTINGS: DRAWER + EDITOR
-- ============================================================================
-- Opened from an All Buffs row link. There are two surfaces.
--   * DRAWER - a popover anchored beside the row. It holds Sound, Detach, Show
--     where it applies, plus the buff's small special controls inline.
--   * EDITOR - a focused panel for the two buffs whose special section is a
--     full editor (poison priority columns, runeforge-per-spec tabs).
-- Enable is on neither surface: the All Buffs row checkbox owns it.
-- Chrome is built once, the body per open. Teardown must unregister every
-- holder that the body created. The drawer dismisses on click-away or ESC.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Sounds = BR.Sounds

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local tinsert = table.insert
local wipe = wipe

-- Focused-editor default width. A section that names an editor module gets the
-- width that module declares instead.
local PANEL_W = 378

local drawer, drawerBody, drawerIcon, drawerTitle, catcher
local editor, editorBody, editorIcon, editorTitle
-- Active build surface. A build must first point body, bodyW and bodyHolders at
-- the drawer body or at the editor body. The shared row helpers write to these.
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
            -- `checked and nil or false` cannot replace this branch: the idiom always
            -- yields false, because the true-branch value (nil) is itself falsy.
            local override
            if not checked then
                override = false
            end
            BR.Config.Set("readyCheckOnlyOverrides." .. key, override)
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

-- Drawer / editor geometry.
local DRAWER_W = 300
local DRAWER_BODY_X = 14
local DRAWER_BODY_TOP = 40
local DRAWER_LABEL_W = 52
local DRAWER_FIELD_W = 178
local EDITOR_BODY_X = 16
local EDITOR_BODY_TOP = 44

-- ============================================================================
-- BUFF-SPECIFIC SECTIONS
-- ============================================================================
-- Each builder appends this buff's extra controls to the body layout.

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

-- Render a buff's inline editor at the layout cursor, then advance the layout
-- past it. The builder parents its frames to `body` and registers its holders
-- for teardown.
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
-- ROW WARNING
-- ============================================================================

-- True when neither poison category has an enabled entry, so no reminder can
-- fire. GetSpecialState colors the All Buffs row link orange for it.
local function PoisonNeedsSetup()
    local prefs = BR.profile.roguePoisonPreferences
    local function noneEnabled(cat)
        local list = prefs and prefs[cat]
        if not list then
            return true
        end
        for _, entry in ipairs(list) do
            if entry.enabled and entry.spellID then
                return false
            end
        end
        return true
    end
    return noneEnabled("lethal") and noneEnabled("nonLethal")
end

-- `build(layout)` appends this buff's extra controls to the panel body. A
-- section too big for the drawer names an `editor` module instead: the drawer
-- shows a door to the focused editor, which renders that module inline.
local SPECIAL_SECTIONS = {
    healthstone = {
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

    rune = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.PreferReusableRunes"],
                get = function()
                    return BR.Config.Get("defaults.preferReusableRunes") == true
                end,
                tooltip = {
                    title = L["Options.PreferReusableRunes.Title"],
                    desc = L["Options.PreferReusableRunes.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.preferReusableRunes", checked)
                end,
            })
        end,
    },

    repairGear = {
        build = function(layout)
            local thresholdHolder = Components.Slider(body, {
                label = L["Options.Repair.Threshold"],
                labelWidth = 110,
                min = 5,
                max = 95,
                step = 5,
                suffix = "%",
                get = function()
                    return BR.Config.Get("defaults.repairThreshold") or 20
                end,
                tooltip = { title = L["Options.Repair.Threshold"], desc = L["Options.Repair.Threshold.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.repairThreshold", val)
                end,
            })
            tinsert(bodyHolders, thresholdHolder)
            layout:Add(thresholdHolder, nil, COMPONENT_GAP)
            AddSpecialCheckbox(layout, {
                label = L["Options.RepairHideInCombat"],
                get = function()
                    return BR.Config.Get("defaults.repairHideInCombat") ~= false
                end,
                tooltip = { title = L["Options.RepairHideInCombat"], desc = L["Options.RepairHideInCombat.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.repairHideInCombat", checked)
                end,
            })
        end,
    },

    soulstone = {
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
            local pinHolder = Components.TextInput(body, {
                label = L["Options.Soulstone.PinnedTarget"],
                width = 120,
                get = function()
                    return BR.Config.Get("defaults.soulstonePinnedTarget") or ""
                end,
                onChange = function(text)
                    -- Strip macro-structural characters: the name is spliced into
                    -- macrotext and must never break out of the [@...] conditional
                    text = strtrim(((text or ""):gsub("[%[%]\r\n]", "")))
                    BR.Config.Set("defaults.soulstonePinnedTarget", text ~= "" and text or nil)
                    Components.RefreshAll()
                end,
            })
            pinHolder.editBox:SetMaxLetters(48)
            tinsert(bodyHolders, pinHolder)
            layout:Add(pinHolder, nil, COMPONENT_GAP)
        end,
    },

    bronze = {
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

    mageFood = {
        build = function(layout)
            local drop = Components.Dropdown(body, {
                label = L["BuffPanel.MageFoodContent"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.MageFoodContent.All"], value = "all" },
                    { label = L["BuffPanel.MageFoodContent.Dungeon"], value = "dungeon" },
                    { label = L["BuffPanel.MageFoodContent.Raid"], value = "raid" },
                },
                get = function()
                    return BR.Config.Get("defaults.mageFoodContent", "all")
                end,
                onChange = function(val)
                    BR.Config.Set("defaults.mageFoodContent", val)
                    Components.RefreshAll()
                end,
            })
            tinsert(bodyHolders, drop)
            layout:Add(drop, 26, COMPONENT_GAP)
        end,
    },

    dkRunes = {
        editor = "Runeforge",
    },

    roguePoisons = {
        warn = PoisonNeedsSetup,
        editor = "RoguePoison",
    },
}

---Editor module of a section, or nil when the section builds inline. The
---section holds the module name, not the table, so a load-order change cannot
---break the link.
---@param section table
---@return table? module
local function EditorModule(section)
    return section.editor and BR.Options.Dialogs[section.editor] or nil
end

---Render a section into the current body: the module's editor, or the
---section's own inline controls.
---@param section table
---@param layout table
local function BuildSpecial(section, layout)
    local module = EditorModule(section)
    if module then
        AddInlineEditor(layout, module.BuildInline)
    else
        section.build(layout)
    end
end

-- ============================================================================
-- DRAWER + EDITOR
-- ============================================================================

-- ---- Shared row builders (write into the active `body` surface) ---------------

---The drawer takes a sound model rather than a buff key, so the Externals rows
---can reuse the row with their own storage.
---@param key string
---@return table
local function MakeBuffSoundModel(key)
    return {
        get = function()
            local sounds = BR.profile.buffSounds
            return sounds and sounds[key]
        end,
        set = function(value)
            -- Shipped storage holds a name or nothing, never the sentinel.
            BR.Helpers.SetBuffSound(key, value ~= Sounds.NO_SOUND and value or nil)
        end,
    }
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

---One sound control. `model.override` is optional: with it the row gains an
---Override checkbox, and while the override is off the dropdown shows the
---inherited sound, dimmed.
---@param layout table
---@param model table { get, set, override? = { isOn, setOn, desc, effective } }
local function AddSoundRow(layout, model)
    local override = model.override
    local function effectiveValue()
        if override and not override.isOn() then
            return override.effective()
        end
        return model.get()
    end

    if override then
        BR.Options.Helpers.AddOverrideRow(body, layout, {
            get = override.isOn,
            desc = override.desc,
            onChange = function(checked)
                override.setOn(checked)
                Components.RefreshAll()
            end,
        })
    end

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
        width = DRAWER_FIELD_W,
        maxItems = 15,
        options = Sounds.BuildOptions(),
        enabled = override and override.isOn or nil,
        disabledReason = override and L["DisabledReason.SoundOverride"] or nil,
        get = function()
            return effectiveValue() or Sounds.NO_SOUND
        end,
        onChange = function(val)
            -- The raw value: each model decides whether the sentinel is stored.
            model.set(val)
            -- Repaint the row that opened the drawer so its sound glyph follows.
            Components.RefreshAll()
        end,
    })
    soundDrop:SetPoint("LEFT", soundRow, "LEFT", DRAWER_LABEL_W + 4, 0)
    tinsert(bodyHolders, soundDrop)

    local playBtn = BR.Options.Helpers.SoundPreviewButton(soundRow, effectiveValue)
    playBtn:SetPoint("LEFT", soundDrop, "RIGHT", 8, 0)
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

    -- 18px icon centered in the 32px header strip, so it clears the -32 title
    -- separator.
    editorIcon = BR.CreateBuffIcon(editor, 18)
    editorIcon:SetPoint("TOPLEFT", EDITOR_BODY_X, -7)
    editorTitle = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editorTitle:SetPoint("LEFT", editorIcon, "RIGHT", 8, 0)

    BR.Options.Helpers.AddCloseButton(editor)
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

    local section = SPECIAL_SECTIONS[key]
    local module = EditorModule(section)
    local panelW = module and module.Width or PANEL_W
    editor:SetWidth(panelW)

    bodyW = panelW - EDITOR_BODY_X * 2
    editorBody = CreateFrame("Frame", nil, editor)
    editorBody:SetPoint("TOPLEFT", EDITOR_BODY_X, -EDITOR_BODY_TOP)
    editorBody:SetSize(bodyW, 100)
    body = editorBody
    bodyHolders = editorHolders

    local layout = Components.VerticalLayout(editorBody, { x = 0, y = 0 })
    BuildSpecial(section, layout)

    local h = math.abs(layout:GetY())
    editorBody:SetHeight(h)
    editor:SetHeight(EDITOR_BODY_TOP + h + 16)
    BR.ApplyDialogScale(editor)
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
    -- The drawer constants are written in screen pixels, not in panel units.
    BR.RegisterScaledDialog(drawer, 1)

    for i = 1, 4 do
        local outset = 5 - i
        local shadow = drawer:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
        shadow:SetPoint("TOPLEFT", -outset, outset)
        shadow:SetPoint("BOTTOMRIGHT", outset, -outset)
        shadow:SetColorTexture(0, 0, 0, 0.05 + (i - 1) * 0.05)
    end

    local stripe = drawer:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", 1, 1)
    stripe:SetWidth(3)
    stripe:SetColorTexture(0.9, 0.72, 0.26)

    drawerIcon = BR.CreateBuffIcon(drawer, 16)
    drawerIcon:SetPoint("TOPLEFT", DRAWER_BODY_X, -9)
    drawerTitle = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    drawerTitle:SetPoint("RIGHT", drawer, "RIGHT", -10, 0)
    drawerTitle:SetJustifyH("LEFT")
    drawerTitle:SetWordWrap(false)

    local headSep = drawer:CreateTexture(nil, "ARTWORK")
    headSep:SetHeight(1)
    headSep:SetPoint("TOPLEFT", DRAWER_BODY_X, -30)
    headSep:SetPoint("TOPRIGHT", -10, -30)
    headSep:SetColorTexture(0.4, 0.32, 0.05, 0.45)

    -- Modeless ESC-to-dismiss. Other keys propagate, so the drawer does not
    -- block keyboard input.
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

---Open the drawer with a body built by `fill`. Header, sizing and the slide-in
---are the same for every caller; only the body differs.
---@param title string
---@param icon number|string|nil
---@param anchor? table Frame to anchor the drawer beside
---@param fill fun(layout: table, body: table, width: number)
---@param width? number Card width; defaults to the one the per-buff cards use
local function OpenDrawer(title, icon, anchor, fill, width)
    EnsureDrawer()
    TearDownDrawerBody()

    -- The drawer covers the widget that opened it. That widget gets no OnLeave,
    -- so its tooltip stays over the drawer until the pointer crosses the row.
    BR.HideTooltip()

    drawer:SetWidth(width or DRAWER_W)

    drawerTitle:SetText("|cffffcc00" .. title .. "|r")

    -- With no icon, the title moves into the icon position. -17 is the header
    -- strip midpoint, where the icon centers.
    drawerIcon:SetShown(icon ~= nil)
    drawerTitle:SetPoint("LEFT", drawer, "TOPLEFT", icon and DRAWER_BODY_X + 23 or DRAWER_BODY_X, -17)
    if icon then
        drawerIcon:SetTexture(icon)
    end

    bodyW = (width or DRAWER_W) - DRAWER_BODY_X * 2
    drawerBody = CreateFrame("Frame", nil, drawer)
    drawerBody:SetPoint("TOPLEFT", DRAWER_BODY_X, -DRAWER_BODY_TOP)
    drawerBody:SetSize(bodyW, 100)
    body = drawerBody
    bodyHolders = drawerHolders

    local layout = Components.VerticalLayout(drawerBody, { x = 0, y = 0 })
    fill(layout, drawerBody, bodyW)

    local h = math.abs(layout:GetY())
    drawerBody:SetHeight(h)
    drawer:SetHeight(DRAWER_BODY_TOP + h + 12)
    -- The height decides the scale clamp, and a reopen on an already-shown
    -- drawer skips OnShow.
    BR.ApplyDialogScale(drawer)

    drawer:ClearAllPoints()
    catcher:Show()
    drawer:Show()

    if anchor then
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
    local key = info.key
    OpenDrawer(info.displayName or key, info.icons and info.icons[1], anchor, function(layout)
        local special = SPECIAL_SECTIONS[key]
        if special then
            local module = EditorModule(special)
            if module then
                local editBtn = CreateButton(
                    drawerBody,
                    string.format(L["BuffPanel.EditOption"], module.Name or key),
                    function()
                        HideDrawer()
                        OpenEditor(info)
                    end
                )
                editBtn:SetSize(bodyW, 24)
                layout:Add(editBtn, 24, COMPONENT_GAP)
            else
                BuildSpecial(special, layout)
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
        AddSoundRow(layout, MakeBuffSoundModel(key))
        AddDetachRow(layout, key)
    end)
end

---Open a sound-only drawer. Used by the Externals rows, whose entries have no
---other per-entry setting.
---@param info table { title, icon, model }
---@param anchor? table Frame to anchor the drawer beside (the row's glyph)
local function ShowSound(info, anchor)
    OpenDrawer(info.title, info.icon, anchor, function(layout)
        AddSoundRow(layout, info.model)
    end)
end

BR.Options.Dialogs.BuffPanel = {
    Show = Show,
    ShowSound = ShowSound,
    ---Open the drawer with a body of the caller's own. The Externals page uses this
    ---for its custom entries, whose drawer holds more than a sound.
    OpenDrawer = OpenDrawer,
    HideDrawer = HideDrawer,
    ---Add the shared sound row to a drawer body. Valid only inside an OpenDrawer
    ---fill callback, which is what points the shared build surface at that body.
    AddSoundRow = AddSoundRow,
    ---Label and field widths of the drawer body, so a caller's rows line up.
    LABEL_WIDTH = DRAWER_LABEL_W,
    FIELD_WIDTH = DRAWER_FIELD_W,
    ---Whether a buff has its own options (a special section), and whether that
    ---option still needs setup. Drives the All Buffs row trailing link: a gold
    ---"Extras" (orange when isWarning) against the plain gray "Settings".
    ---@return boolean isSpecial, boolean? isWarning
    GetSpecialState = function(key)
        local special = SPECIAL_SECTIONS[key]
        if not special then
            return false
        end
        return true, special.warn ~= nil and special.warn()
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
