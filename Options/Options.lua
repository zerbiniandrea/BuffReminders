local _, BR = ...

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================
-- Simplified 3-tab layout: Buffs, Display/Behavior, Settings

-- Lua stdlib locals
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local tinsert, tsort, tremove = table.insert, table.sort, table.remove

-- WoW API locals
local PlaySoundFile = PlaySoundFile

-- Aliases from BR namespace
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local CreateSectionHeader = BR.CreateSectionHeader
local CreateBuffIcon = BR.CreateBuffIcon
local StyleEditBox = BR.StyleEditBox

-- Shared constants
local TEXCOORD_INSET = BR.TEXCOORD_INSET
local DEFAULT_BORDER_SIZE = BR.DEFAULT_BORDER_SIZE
local OPTIONS_BASE_SCALE = BR.OPTIONS_BASE_SCALE

-- Buff tables
local BUFF_TABLES = BR.BUFF_TABLES
local BuffGroups = BR.BuffGroups

-- Local aliases for buff arrays
local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable

-- Localization
local L = BR.L

-- Glow module
local Glow = BR.Glow
local GlowTypes = Glow.Types

-- Export references from BuffReminders.lua
local defaults = BR.defaults
local LSM = BR.LSM

-- Helper function aliases
local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit
local IsIconDetached = BR.Helpers.IsIconDetached
local DetachIcon = BR.Helpers.DetachIcon
local ReattachIcon = BR.Helpers.ReattachIcon
local GetBuffTexture = BR.Helpers.GetBuffTexture
local ValidateSpellID = BR.Helpers.ValidateSpellID
local ValidateItemID = BR.Helpers.ValidateItemID
local GenerateCustomBuffKey = BR.Helpers.GenerateCustomBuffKey
local SetBuffSound = BR.Helpers.SetBuffSound

-- Display function aliases
local UpdateDisplay = BR.Display.Update
local ToggleTestMode = BR.Display.ToggleTestMode
local UpdateVisuals = BR.Display.UpdateVisuals
local ResetCategoryFramePosition = BR.Display.ResetCategoryFramePosition
local ReparentBuffFrames = BR.CallbackRegistry.TriggerEvent
        and function()
            BR.CallbackRegistry:TriggerEvent("FramesReparent")
        end
    or function() end

-- Masque state
local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

-- Custom buff management
local CreateCustomBuffFrameRuntime = BR.CustomBuffs.CreateRuntime
local RemoveCustomBuffFrame = BR.CustomBuffs.Remove
local UpdateCustomBuffFrame = BR.CustomBuffs.UpdateFrame

-- Module-level variables
local optionsPanel = nil
local customBuffModal = nil

-- Forward declarations
local ShowGlowAdvanced, ShowCustomBuffModal
local ShowRuneforgeModal, ShowHealthstoneModal, ShowSoulstoneModal, ShowPetPassiveModal, ShowPetSummonModal, ShowDelveFoodModal, ShowSoundAlertModal, ShowBronzeModal, ShowChatRequestModal

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PANEL_WIDTH = 540
local COL_PADDING = 20
local SECTION_SPACING = 12
local ITEM_HEIGHT = 22
local SCROLLBAR_WIDTH = 24

-- Vertical layout spacing constants
local COMPONENT_GAP = 4 -- Standard gap between components
local SECTION_GAP = 8 -- Gap before/after section boundaries
local DROPDOWN_EXTRA = 8 -- Extra clearance after dropdowns (menu overlay space)

local CATEGORY_ORDER = { "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }
local CATEGORY_LABELS = {
    raid = L["Category.RaidBuffs"],
    presence = L["Category.PresenceBuffs"],
    targeted = L["Category.TargetedBuffs"],
    self = L["Category.SelfBuffs"],
    pet = L["Category.PetReminders"],
    consumable = L["Category.Consumables"],
    custom = L["Category.CustomBuffs"],
}

-- Layout-aware section header (uses VerticalLayout instead of manual Y tracking)
local function LayoutSectionHeader(layout, parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText("|cffffcc00" .. text .. "|r")
    layout:AddText(header, 14, COMPONENT_GAP)
    return header
end

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================

local function CreateOptionsPanel()
    local panel = CreatePanel("BuffRemindersOptions", PANEL_WIDTH, 640, { escClose = true })
    panel:Hide()

    -- Forward declarations for banner system
    local UpdateBannerLayout
    local masqueBanner

    -- Track all EditBoxes so we can clear focus when panel hides
    local panelEditBoxes = {}
    Components.SetEditBoxesRef(panelEditBoxes)
    panel:SetScript("OnHide", function()
        for _, editBox in ipairs(panelEditBoxes) do
            editBox:ClearFocus()
        end
    end)

    -- Refresh all component values from DB when panel opens (OnShow pattern)
    panel:SetScript("OnShow", function()
        Components.RefreshAll()
        UpdateBannerLayout()
    end)

    -- Title (inline with tab row)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", COL_PADDING, -10)
    title:SetText("|cffffffffBuff|r|cffffcc00Reminders|r")

    -- Version (next to title, smaller font)
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local addonVersion = C_AddOns.GetAddOnMetadata("BuffReminders", "Version") or ""
    version:SetText(addonVersion)

    -- Discord link (next to version)
    local discordSep = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    discordSep:SetPoint("LEFT", version, "RIGHT", 6, 0)
    discordSep:SetText("|cff555555·|r")

    local discordLink = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    discordLink:SetPoint("LEFT", discordSep, "RIGHT", 6, 0)
    discordLink:SetText("|cff7289da" .. L["Options.JoinDiscord"] .. "|r")

    local discordHit = CreateFrame("Button", nil, panel)
    discordHit:SetAllPoints(discordLink)
    discordHit:SetScript("OnClick", function()
        StaticPopup_Show("BUFFREMINDERS_DISCORD_URL")
    end)
    discordHit:SetScript("OnEnter", function()
        discordLink:SetText("|cff99aaff" .. L["Options.JoinDiscord"] .. "|r")
        BR.ShowTooltip(discordHit, L["Options.JoinDiscord.Title"], L["Options.JoinDiscord.Desc"], "ANCHOR_BOTTOM")
    end)
    discordHit:SetScript("OnLeave", function()
        discordLink:SetText("|cff7289da" .. L["Options.JoinDiscord"] .. "|r")
        BR.HideTooltip()
    end)

    -- Scale controls (top right area) - text link style: < 100% >
    local BASE_SCALE = OPTIONS_BASE_SCALE
    local MIN_PCT, MAX_PCT = 80, 150

    local currentScale = BR.profile.optionsPanelScale or BASE_SCALE
    local currentPct = floor(currentScale / BASE_SCALE * 100 + 0.5)

    -- Close button
    local closeBtn = CreateButton(panel, "x", function()
        panel:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local scaleHolder = CreateFrame("Frame", nil, panel)
    scaleHolder:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    scaleHolder:SetSize(60, 16)

    local scaleDown = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDown:SetPoint("LEFT", 0, 0)
    scaleDown:SetText("<")

    local scaleValue = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleValue:SetPoint("LEFT", scaleDown, "RIGHT", 4, 0)
    scaleValue:SetText(currentPct .. "%")

    local scaleUp = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleUp:SetPoint("LEFT", scaleValue, "RIGHT", 4, 0)
    scaleUp:SetText(">")

    local function UpdateScaleText()
        local pct = floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
        scaleValue:SetText(pct .. "%")
        scaleDown:SetTextColor(pct > MIN_PCT and 1 or 0.4, pct > MIN_PCT and 1 or 0.4, pct > MIN_PCT and 1 or 0.4)
        scaleUp:SetTextColor(pct < MAX_PCT and 1 or 0.4, pct < MAX_PCT and 1 or 0.4, pct < MAX_PCT and 1 or 0.4)
    end

    local function UpdateScale(delta)
        local oldPct = floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
        local newPct = max(MIN_PCT, min(MAX_PCT, oldPct + delta))
        local newScale = newPct / 100 * BASE_SCALE
        BR.profile.optionsPanelScale = newScale
        panel:SetScale(newScale)
        UpdateScaleText()
    end

    -- Clickable regions for < and >
    local downBtn = CreateFrame("Button", nil, scaleHolder)
    downBtn:SetAllPoints(scaleDown)
    downBtn:SetScript("OnClick", function()
        UpdateScale(-10)
    end)
    downBtn:SetScript("OnEnter", function()
        if currentPct > MIN_PCT then
            scaleDown:SetTextColor(1, 0.82, 0)
        end
    end)
    downBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    local upBtn = CreateFrame("Button", nil, scaleHolder)
    upBtn:SetAllPoints(scaleUp)
    upBtn:SetScript("OnClick", function()
        UpdateScale(10)
    end)
    upBtn:SetScript("OnEnter", function()
        local pct = floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
        if pct < MAX_PCT then
            scaleUp:SetTextColor(1, 0.82, 0)
        end
    end)
    upBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    UpdateScaleText()

    if BR.profile.optionsPanelScale then
        panel:SetScale(BR.profile.optionsPanelScale)
    end

    -- ========== TABS ==========
    local tabButtons = {}
    local contentContainers = {}
    local TAB_HEIGHT = 22
    local activeTabName = "buffs"

    local function SetActiveTab(tabName)
        activeTabName = tabName
        for name, tab in pairs(tabButtons) do
            tab:SetActive(name == tabName)
        end
        for name, container in pairs(contentContainers) do
            if name == tabName then
                container:Show()
            else
                container:Hide()
            end
        end
        if masqueBanner then
            masqueBanner:Refresh()
            UpdateBannerLayout()
        end
    end

    -- Create 5 tabs: Buffs, Display & Behavior, Sounds, Settings, Profiles
    tabButtons.buffs = Components.Tab(panel, { name = "buffs", label = L["Tab.Buffs"], width = 50 })
    tabButtons.displayBehavior =
        Components.Tab(panel, { name = "displayBehavior", label = L["Tab.DisplayBehavior"], width = 110 })
    tabButtons.sounds = Components.Tab(panel, { name = "sounds", label = L["Tab.Sounds"], width = 60 })
    tabButtons.settings = Components.Tab(panel, { name = "settings", label = L["Tab.Settings"], width = 65 })
    tabButtons.profiles = Components.Tab(panel, { name = "profiles", label = L["Tab.Profiles"], width = 65 })

    -- Position tabs below title
    tabButtons.buffs:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_PADDING, -30)
    tabButtons.displayBehavior:SetPoint("LEFT", tabButtons.buffs, "RIGHT", 2, 0)
    tabButtons.sounds:SetPoint("LEFT", tabButtons.displayBehavior, "RIGHT", 2, 0)
    tabButtons.settings:SetPoint("LEFT", tabButtons.sounds, "RIGHT", 2, 0)
    tabButtons.profiles:SetPoint("LEFT", tabButtons.settings, "RIGHT", 2, 0)

    for name, tab in pairs(tabButtons) do
        tab:SetScript("OnClick", function()
            SetActiveTab(name)
        end)
    end

    -- Separator line below tabs
    local tabSeparator = panel:CreateTexture(nil, "ARTWORK")
    tabSeparator:SetHeight(1)
    tabSeparator:SetPoint("TOPLEFT", COL_PADDING, -30 - TAB_HEIGHT)
    tabSeparator:SetPoint("TOPRIGHT", -COL_PADDING, -30 - TAB_HEIGHT)
    tabSeparator:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- ========== CONTENT CONTAINERS ==========
    local CONTENT_TOP = -30 - TAB_HEIGHT - 10

    -- Helper to create a scrollable content container using Components
    local function CreateScrollableContent(name)
        local scrollFrame, content = Components.ScrollableContainer(panel, {
            contentHeight = 600,
            scrollbarWidth = SCROLLBAR_WIDTH,
        })
        scrollFrame:SetPoint("TOPLEFT", 0, CONTENT_TOP)
        scrollFrame:SetPoint("BOTTOMRIGHT", 0, 46)
        scrollFrame:Hide()

        contentContainers[name] = scrollFrame
        return content, scrollFrame
    end

    -- ========== BANNERS ==========
    local BANNER_HEIGHT = 28
    local BANNER_TOP_GAP = 6
    local BANNER_BOTTOM_GAP = 0

    masqueBanner = Components.Banner(panel, {
        text = L["Options.MasqueNote"],
        icon = "QuestNormal",
        color = "orange",
        visible = function()
            return IsMasqueActive() and activeTabName == "displayBehavior"
        end,
    })

    UpdateBannerLayout = function()
        local bannerY = -30 - TAB_HEIGHT - BANNER_TOP_GAP
        local bannerOffset = 0

        if masqueBanner:IsShown() then
            masqueBanner:ClearAllPoints()
            masqueBanner:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_PADDING, bannerY)
            masqueBanner:SetPoint("RIGHT", panel, "RIGHT", -COL_PADDING, 0)
            bannerOffset = bannerOffset + BANNER_HEIGHT + BANNER_BOTTOM_GAP
        end

        local newTop = CONTENT_TOP - bannerOffset
        for _, container in pairs(contentContainers) do
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, newTop)
            if container.GetContentFrame then
                container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 46)
            end
        end
    end

    -- Store buff checkboxes for refresh
    panel.buffCheckboxes = {}

    -- ========== HELPER FUNCTIONS ==========

    -- Resolve icon textures from displayIcon texture IDs or spell IDs
    local function ResolveBuffIcons(displayIcon, spellIDs)
        if displayIcon then
            -- Use override textures directly
            if type(displayIcon) == "table" then
                return displayIcon
            else
                return { displayIcon }
            end
        elseif spellIDs then
            -- Look up textures from spell IDs (deduplicated)
            local icons = {}
            local seenTextures = {}
            local spellList = type(spellIDs) == "table" and spellIDs or { spellIDs }
            for _, spellID in ipairs(spellList) do
                local texture = GetBuffTexture(spellID)
                if texture and not seenTextures[texture] then
                    seenTextures[texture] = true
                    tinsert(icons, texture)
                end
            end
            return #icons > 0 and icons or nil
        end
        return nil
    end

    -- Buff-specific settings: key → { tooltip, note, onClick }
    -- Gear icon shown in a fixed column (right of detach pin) for consistent alignment
    local buffSettingsActions = {
        healthstone = {
            tooltip = L["Options.HealthstoneSettings"],
            note = L["Options.HealthstoneSettings.Note"],
            onClick = function()
                ShowHealthstoneModal()
            end,
        },
        soulstone = {
            tooltip = L["Options.SoulstoneSettings"],
            note = L["Options.SoulstoneSettings.Note"],
            onClick = function()
                ShowSoulstoneModal()
            end,
        },
        dkRunes = {
            tooltip = L["Options.RuneforgePreferences"],
            note = L["Options.RuneforgeNote"],
            onClick = function()
                ShowRuneforgeModal()
            end,
        },
        petPassive = {
            tooltip = L["Options.PetPassiveSettings"],
            note = L["Options.PetPassiveSettings.Note"],
            onClick = function()
                ShowPetPassiveModal()
            end,
        },
        pets = {
            tooltip = L["Options.PetSummonSettings"],
            note = L["Options.PetSummonSettings.Note"],
            onClick = function()
                ShowPetSummonModal()
            end,
        },
        delveFood = {
            tooltip = L["Options.DelveFoodSettings"],
            note = L["Options.DelveFoodSettings.Note"],
            onClick = function()
                ShowDelveFoodModal()
            end,
        },
        bronze = {
            tooltip = L["Options.BronzeSettings"],
            note = L["Options.BronzeSettings.Note"],
            onClick = function()
                ShowBronzeModal()
            end,
        },
    }

    -- Create buff checkbox using Components.Checkbox
    local function CreateBuffCheckbox(
        parent,
        x,
        y,
        spellIDs,
        key,
        displayName,
        infoTooltip,
        displayIcon,
        readyCheckOnly,
        freeConsumable
    )
        local holder = Components.Checkbox(parent, {
            label = displayName,
            icons = ResolveBuffIcons(displayIcon, spellIDs),
            infoTooltip = not readyCheckOnly and infoTooltip or nil,
            get = function()
                return BR.profile.enabledBuffs[key] ~= false
            end,
            onChange = function(checked)
                BR.profile.enabledBuffs[key] = checked
                UpdateDisplay()
                if readyCheckOnly then
                    Components.RefreshAll()
                end
            end,
        })
        holder:SetPoint("TOPLEFT", x, y)
        panel.buffCheckboxes[key] = holder

        -- Inline toggle: "Ready check only" / "Always show" (replaces info tooltip icon)
        -- Skip for free consumables (controlled by dropdown) and soulstone (controlled by gear icon modal)
        if readyCheckOnly and not freeConsumable and key ~= "soulstone" then
            local function GetReadyCheckOnlyState()
                local overrides = BR.profile.readyCheckOnlyOverrides
                return not overrides or overrides[key] ~= false
            end

            local function ToggleLabel(checked)
                return checked and L["Options.ReadyCheck"] or L["Options.Always"]
            end

            local toggle
            toggle = Components.Toggle(holder, {
                label = ToggleLabel(GetReadyCheckOnlyState()),
                get = GetReadyCheckOnlyState,
                enabled = function()
                    return BR.profile.enabledBuffs[key] ~= false
                end,
                onChange = function(checked)
                    if checked then
                        -- Ready check only (default): remove override
                        BR.Config.Set("readyCheckOnlyOverrides." .. key, nil)
                    else
                        -- Always show: store explicit false
                        BR.Config.Set("readyCheckOnlyOverrides." .. key, false)
                    end
                    toggle.label:SetText(ToggleLabel(checked))
                end,
            })
            -- Also update label text on Refresh (wrap original Refresh)
            local origRefresh = toggle.Refresh
            function toggle:Refresh()
                origRefresh(self)
                self.label:SetText(ToggleLabel(GetReadyCheckOnlyState()))
            end
            toggle:SetPoint("LEFT", holder.label, "RIGHT", 6, 0)
        end

        -- Settings gear icon (fixed column, first icon right of checkbox)
        local settings = buffSettingsActions[key]
        if settings then
            local gearBtn = CreateFrame("Button", nil, holder)
            gearBtn:SetSize(14, 14)
            gearBtn:SetPoint("LEFT", holder, "RIGHT", 4, 0)
            gearBtn:SetFrameLevel(holder:GetFrameLevel() + 5)
            local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
            gearTex:SetAllPoints()
            gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
            gearTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            gearBtn:SetScript("OnEnter", function(self)
                gearTex:SetVertexColor(1, 1, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(settings.tooltip, 1, 1, 1)
                GameTooltip:AddLine(settings.note, 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            gearBtn:SetScript("OnLeave", function()
                gearTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
                GameTooltip:Hide()
            end)
            gearBtn:SetScript("OnClick", settings.onClick)
        end

        -- Detach button: small pin icon to toggle detached positioning
        -- Fixed offset from holder right edge (leaves gap for gear icon slot)
        local detachBtn = CreateFrame("Button", nil, holder)
        detachBtn:SetSize(14, 14)
        detachBtn:SetPoint("LEFT", holder, "RIGHT", 22, 0)

        local detachIcon = detachBtn:CreateTexture(nil, "ARTWORK")
        detachIcon:SetAllPoints()
        detachIcon:SetAtlas("Waypoint-MapPin-ChatIcon")

        local function UpdateDetachVisual()
            if IsIconDetached(key) then
                detachIcon:SetVertexColor(1, 0.85, 0.3, 1) -- Gold when detached
                detachIcon:SetDesaturated(false)
            else
                detachIcon:SetVertexColor(0.5, 0.5, 0.5, 0.6) -- Dim when attached
                detachIcon:SetDesaturated(true)
            end
        end
        UpdateDetachVisual()

        detachBtn:SetScript("OnClick", function()
            if IsIconDetached(key) then
                ReattachIcon(key)
            else
                DetachIcon(key)
            end
            UpdateDetachVisual()
            UpdateDisplay()
        end)
        detachBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Options.DetachIcon"], 1, 1, 1)
            GameTooltip:AddLine(L["Options.DetachIcon.Desc"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        detachBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        return y - ITEM_HEIGHT
    end

    -- ========== BUFFS TAB (Two-Column Layout) ==========
    local buffsContent, _ = CreateScrollableContent("buffs")

    -- Render checkboxes for a buff array (single column within each side)
    local function RenderBuffCheckboxes(parent, x, y, buffArray)
        local groupSpells = {}
        local groupDisplaySpells = {}
        local groupIconOverrides = {}
        local groupReadyCheckOnly = {}
        local groupFreeConsumable = {}

        for _, buff in ipairs(buffArray) do
            if buff.groupId then
                groupSpells[buff.groupId] = groupSpells[buff.groupId] or {}
                groupDisplaySpells[buff.groupId] = groupDisplaySpells[buff.groupId] or {}
                if buff.spellID then
                    local spellList = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
                    for _, id in ipairs(spellList) do
                        tinsert(groupSpells[buff.groupId], id)
                    end
                end
                if buff.displaySpells then
                    local displayList = type(buff.displaySpells) == "table" and buff.displaySpells
                        or { buff.displaySpells }
                    for _, id in ipairs(displayList) do
                        tinsert(groupDisplaySpells[buff.groupId], id)
                    end
                end
                -- Resolve display icon(s) per entry: displayIcon > displaySpells > primary spellID
                -- Deduplicate icons within the same group (e.g., MH + OH weapon buffs share icons)
                if not groupIconOverrides[buff.groupId] then
                    groupIconOverrides[buff.groupId] = {}
                    groupIconOverrides[buff.groupId]._seen = {}
                end
                local seen = groupIconOverrides[buff.groupId]._seen
                if buff.displayIcon then
                    local overrides = type(buff.displayIcon) == "table" and buff.displayIcon or { buff.displayIcon }
                    for _, icon in ipairs(overrides) do
                        if not seen[icon] then
                            seen[icon] = true
                            tinsert(groupIconOverrides[buff.groupId], icon)
                        end
                    end
                elseif buff.displaySpells then
                    local displayList = type(buff.displaySpells) == "table" and buff.displaySpells
                        or { buff.displaySpells }
                    for _, id in ipairs(displayList) do
                        local texture = GetBuffTexture(id)
                        if texture and not seen[texture] then
                            seen[texture] = true
                            tinsert(groupIconOverrides[buff.groupId], texture)
                        end
                    end
                elseif buff.spellID then
                    local primarySpell = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID
                    if primarySpell and primarySpell > 0 then
                        local texture = GetBuffTexture(primarySpell)
                        if texture and not seen[texture] then
                            seen[texture] = true
                            tinsert(groupIconOverrides[buff.groupId], texture)
                        end
                    end
                end
                if buff.readyCheckOnly then
                    groupReadyCheckOnly[buff.groupId] = true
                end
                if buff.freeConsumable then
                    groupFreeConsumable[buff.groupId] = true
                end
            end
        end

        local seenGroups = {}
        for _, buff in ipairs(buffArray) do
            if buff.groupId then
                if not seenGroups[buff.groupId] then
                    seenGroups[buff.groupId] = true
                    local groupInfo = BuffGroups[buff.groupId]
                    local displayIcon = groupIconOverrides[buff.groupId]
                    if displayIcon and #displayIcon == 0 then
                        displayIcon = nil
                    end
                    local displaySpells = groupDisplaySpells[buff.groupId]
                    local spells = (#displaySpells > 0) and displaySpells or groupSpells[buff.groupId]
                    if #spells == 0 then
                        spells = nil
                    end
                    y = CreateBuffCheckbox(
                        parent,
                        x,
                        y,
                        spells,
                        buff.groupId,
                        groupInfo and groupInfo.displayName or buff.name,
                        buff.infoTooltip,
                        displayIcon,
                        groupReadyCheckOnly[buff.groupId],
                        groupFreeConsumable[buff.groupId]
                    )
                end
            else
                local displaySpells = buff.displaySpells or buff.spellID
                y = CreateBuffCheckbox(
                    parent,
                    x,
                    y,
                    displaySpells,
                    buff.key,
                    buff.name,
                    buff.infoTooltip,
                    buff.displayIcon,
                    buff.readyCheckOnly,
                    buff.freeConsumable
                )
            end
        end

        return y
    end

    -- Column layout constants
    local COL_WIDTH = (PANEL_WIDTH - COL_PADDING * 3) / 2
    local buffsLeftX = COL_PADDING
    local buffsRightX = COL_PADDING + COL_WIDTH + COL_PADDING
    local buffsLeftY = -6
    local buffsRightY = -6

    -- Detach column headers (text label above pin buttons)
    local function CreateDetachColumnHeader(parent, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(L["Options.DetachIcon"])
    end

    CreateDetachColumnHeader(buffsContent, buffsLeftX + 211, -8)
    CreateDetachColumnHeader(buffsContent, buffsRightX + 211, -8)

    -- LEFT COLUMN: Group-wide buffs
    -- Raid Buffs
    _, buffsLeftY = CreateSectionHeader(buffsContent, L["Category.RaidBuffs"], buffsLeftX, buffsLeftY)
    local raidNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    raidNote:SetPoint("TOPLEFT", buffsLeftX, buffsLeftY)
    raidNote:SetText(L["Category.RaidNote"])
    buffsLeftY = buffsLeftY - 14
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, RaidBuffs)
    buffsLeftY = buffsLeftY - SECTION_SPACING

    -- Targeted Buffs
    _, buffsLeftY = CreateSectionHeader(buffsContent, L["Category.TargetedBuffs"], buffsLeftX, buffsLeftY)
    local targetedNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    targetedNote:SetPoint("TOPLEFT", buffsLeftX, buffsLeftY)
    targetedNote:SetText(L["Category.TargetedNote"])
    buffsLeftY = buffsLeftY - 14
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, TargetedBuffs)
    buffsLeftY = buffsLeftY - SECTION_SPACING

    -- Consumables
    _, buffsLeftY = CreateSectionHeader(buffsContent, L["Category.Consumables"], buffsLeftX, buffsLeftY)
    local consumablesNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    consumablesNote:SetPoint("TOPLEFT", buffsLeftX, buffsLeftY)
    consumablesNote:SetText(L["Category.ConsumableNote"])
    buffsLeftY = buffsLeftY - 14
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, Consumables)

    -- RIGHT COLUMN: Individual buffs
    -- Presence Buffs
    _, buffsRightY = CreateSectionHeader(buffsContent, L["Category.PresenceBuffs"], buffsRightX, buffsRightY)
    local presenceNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    presenceNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    presenceNote:SetText(L["Category.PresenceNote"])
    buffsRightY = buffsRightY - 14
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, PresenceBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Self Buffs
    _, buffsRightY = CreateSectionHeader(buffsContent, L["Category.SelfBuffs"], buffsRightX, buffsRightY)
    local selfNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    selfNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    selfNote:SetText(L["Category.SelfNote"])
    buffsRightY = buffsRightY - 14
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, SelfBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Pet Reminders
    _, buffsRightY = CreateSectionHeader(buffsContent, L["Category.PetReminders"], buffsRightX, buffsRightY)
    local petNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    petNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    petNote:SetText(L["Category.PetNote"])
    buffsRightY = buffsRightY - 14
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, PetBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Custom Buffs (right column)
    _, buffsRightY = CreateSectionHeader(buffsContent, L["Category.CustomBuffs"], buffsRightX, buffsRightY)
    panel.customBuffRows = {}

    local customNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    customNote:SetText(L["Category.CustomNote"])
    buffsRightY = buffsRightY - 14

    local customSectionStartY = buffsRightY
    local customBuffsContainer = CreateFrame("Frame", nil, buffsContent)
    customBuffsContainer:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    customBuffsContainer:SetSize(COL_WIDTH, 200)

    local ADD_BTN_GAP = 4
    local ADD_BTN_HEIGHT = 22
    local CUSTOM_CONTAINER_PAD = ADD_BTN_GAP + ADD_BTN_HEIGHT + 2

    local function RenderCustomBuffRows()
        for _, row in ipairs(panel.customBuffRows) do
            row:Hide()
            row:SetParent(nil)
        end
        panel.customBuffRows = {}

        local db = BR.profile
        local rowY = 0

        local sortedKeys = {}
        if db.customBuffs then
            for key in pairs(db.customBuffs) do
                tinsert(sortedKeys, key)
            end
        end
        tsort(sortedKeys)

        for _, key in ipairs(sortedKeys) do
            local customBuff = db.customBuffs[key]

            -- Use Components.Checkbox for consistent styling
            local holder = Components.Checkbox(customBuffsContainer, {
                label = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID)),
                icons = ResolveBuffIcons(nil, customBuff.spellID),
                get = function()
                    return BR.profile.enabledBuffs[key] ~= false
                end,
                onChange = function(checked)
                    BR.profile.enabledBuffs[key] = checked
                    UpdateDisplay()
                end,
                onRightClick = function()
                    ShowCustomBuffModal(key, RenderCustomBuffRows)
                end,
                tooltip = { title = L["CustomBuff.Tooltip.Title"], desc = L["CustomBuff.Tooltip.Desc"] },
            })
            holder:SetPoint("TOPLEFT", 0, rowY)
            panel.buffCheckboxes[key] = holder

            -- Detach button for custom buffs
            local detachBtn = CreateFrame("Button", nil, holder)
            detachBtn:SetSize(14, 14)
            detachBtn:SetPoint("LEFT", holder, "RIGHT", 4, 0)
            local detachTex = detachBtn:CreateTexture(nil, "ARTWORK")
            detachTex:SetAllPoints()
            detachTex:SetAtlas("Waypoint-MapPin-ChatIcon")
            local function UpdateDetachVis()
                if IsIconDetached(key) then
                    detachTex:SetVertexColor(1, 0.85, 0.3, 1)
                    detachTex:SetDesaturated(false)
                else
                    detachTex:SetVertexColor(0.5, 0.5, 0.5, 0.6)
                    detachTex:SetDesaturated(true)
                end
            end
            UpdateDetachVis()
            detachBtn:SetScript("OnClick", function()
                if IsIconDetached(key) then
                    ReattachIcon(key)
                else
                    DetachIcon(key)
                end
                UpdateDetachVis()
                UpdateDisplay()
            end)
            detachBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["Options.DetachIcon"], 1, 1, 1)
                GameTooltip:AddLine(L["Options.DetachIcon.Desc"], 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            detachBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            tinsert(panel.customBuffRows, holder)
            rowY = rowY - ITEM_HEIGHT
        end

        local addBtn = CreateButton(customBuffsContainer, L["CustomBuff.AddButton"], function()
            ShowCustomBuffModal(nil, RenderCustomBuffRows)
        end)
        addBtn:SetPoint("TOPLEFT", 0, rowY - ADD_BTN_GAP)
        tinsert(panel.customBuffRows, addBtn)

        customBuffsContainer:SetHeight(abs(rowY) + CUSTOM_CONTAINER_PAD)

        -- Recalculate content height when custom buffs change
        local effectiveRightY = customSectionStartY + rowY - CUSTOM_CONTAINER_PAD
        buffsContent:SetHeight(max(abs(buffsLeftY), abs(effectiveRightY)) + 4)

        return rowY
    end

    panel.RenderCustomBuffRows = RenderCustomBuffRows
    RenderCustomBuffRows()

    -- ========== DISPLAY/BEHAVIOR TAB ==========
    local displayBehaviorContent, _ = CreateScrollableContent("displayBehavior")
    local displayBehaviorX = COL_PADDING
    local displayBehaviorLayout = Components.VerticalLayout(displayBehaviorContent, { x = displayBehaviorX, y = -10 })

    -- Global Defaults section
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, L["Options.GlobalDefaults"])

    local defNote = displayBehaviorContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    displayBehaviorLayout:AddText(defNote, 12, COMPONENT_GAP)
    defNote:SetText(L["Options.GlobalDefaults.Note"])

    local function isDefDimensionsLinked()
        local db = BR.profile.defaults
        return not db or db.iconWidth == nil
    end

    local defGrid = Components.AppearanceGrid(displayBehaviorContent, {
        get = function(key, default)
            local d = BR.profile.defaults
            return d and d[key] or default
        end,
        set = function(key, value)
            BR.Config.Set("defaults." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["defaults." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = isDefDimensionsLinked,
        onLink = function()
            BR.Config.Set("defaults.iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local db = BR.profile.defaults
            BR.Config.Set("defaults.iconWidth", db and db.iconSize or 64)
            Components.RefreshAll()
        end,
        masqueCheck = IsMasqueActive,
    })
    displayBehaviorLayout:Add(defGrid.frame, defGrid.height, COMPONENT_GAP)

    -- Font dropdown (global setting, uses LibSharedMedia)
    local function BuildFontOptions()
        local fontList = LSM:List("font")
        local opts = { { label = L["Options.Default"], value = nil } }
        for _, name in ipairs(fontList) do
            tinsert(opts, { label = name, value = name })
        end
        return opts
    end

    local defFontHolder = Components.Dropdown(displayBehaviorContent, {
        label = L["Options.Font"],
        labelWidth = 50,
        options = BuildFontOptions(),
        width = 200,
        maxItems = 15,
        itemInit = function(_, itemLabel, opt)
            if opt.value then
                local path = LSM:Fetch("font", opt.value)
                if path then
                    itemLabel:SetFont(path, 12, "")
                end
            end
        end,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.fontFace or nil
        end,
        onChange = function(val)
            BR.Config.Set("defaults.fontFace", val)
        end,
    })
    displayBehaviorLayout:Add(defFontHolder, nil, COMPONENT_GAP)

    local defDirHolder = Components.DirectionButtons(displayBehaviorContent, {
        labelWidth = 50,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.growDirection or "CENTER"
        end,
        onChange = function(dir)
            BR.Config.Set("defaults.growDirection", dir)
        end,
    })
    displayBehaviorLayout:Add(defDirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    local defGlowHolder = Components.Checkbox(displayBehaviorContent, {
        label = L["Options.GlowReminderIcons"],
        tooltip = {
            title = L["Options.GlowReminderIcons.Title"],
            desc = L["Options.GlowReminderIcons.Desc"],
        },
        get = function()
            local d = BR.profile.defaults
            return d and (d.showExpirationGlow ~= false or d.showMissingGlow ~= false)
        end,
        onChange = function(checked)
            BR.Config.Set("defaults.showExpirationGlow", checked)
            BR.Config.Set("defaults.showMissingGlow", checked)
            Components.RefreshAll()
        end,
    })

    local glowSettingsBtn = CreateButton(displayBehaviorContent, L["Options.Customize"], function()
        ShowGlowAdvanced()
    end)
    glowSettingsBtn:SetPoint("LEFT", defGlowHolder.label, "RIGHT", 8, 0)
    glowSettingsBtn:SetFrameLevel(defGlowHolder:GetFrameLevel() + 5)

    displayBehaviorLayout:Add(defGlowHolder, nil, COMPONENT_GAP)

    -- Expiration Reminder section
    displayBehaviorLayout:Space(8)
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, L["Options.ExpirationReminder"])
    displayBehaviorLayout:Space(COMPONENT_GAP)

    local defThresholdHolder = Components.Slider(displayBehaviorContent, {
        label = L["Options.Threshold"],
        min = 0,
        max = 45,
        step = 5,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.expirationThreshold or 15
        end,
        formatValue = function(val)
            return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
        end,
        onChange = function(val)
            BR.Config.Set("defaults.expirationThreshold", val)
        end,
    })
    displayBehaviorLayout:Add(defThresholdHolder, nil, COMPONENT_GAP)

    -- Per-Category Customization section
    displayBehaviorLayout:Space(8)
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, L["Options.PerCategoryCustomization"])
    displayBehaviorLayout:Space(COMPONENT_GAP)

    -- Create collapsible sections that chain-anchor to each other
    local categorySections = {}
    local previousSection = nil

    local function UpdateAppearanceContentHeight()
        -- Calculate total height: fixed header area + all collapsible sections
        local totalHeight = abs(displayBehaviorLayout:GetY())
        for _, sec in ipairs(categorySections) do
            totalHeight = totalHeight + sec:GetHeight() + 4
        end
        displayBehaviorContent:SetHeight(totalHeight)
    end

    local SECTION_SCROLLBAR_OFFSET = COL_PADDING
    for _, category in ipairs(CATEGORY_ORDER) do
        local section = Components.CollapsibleSection(displayBehaviorContent, {
            title = CATEGORY_LABELS[category],
            defaultCollapsed = true,
            scrollbarOffset = SECTION_SCROLLBAR_OFFSET,
            onToggle = function()
                -- Defer layout update to next frame
                C_Timer.After(0, UpdateAppearanceContentHeight)
            end,
        })

        if previousSection then
            section:SetPoint("TOPLEFT", previousSection, "BOTTOMLEFT", 0, -4)
        else
            section:SetPoint("TOPLEFT", displayBehaviorX, displayBehaviorLayout:GetY())
        end

        local catContent = section:GetContentFrame()
        local catLayout = Components.VerticalLayout(catContent, { x = 0, y = 0 })

        local db = BR.profile

        -- W/S/D/R content visibility + ready check (not for custom — custom uses per-buff loadConditions)
        if category ~= "custom" then
            local function OnCategoryVisibilityChange()
                UpdateDisplay()
            end

            local visToggles = Components.VisibilityToggles(catContent, {
                category = category,
                onChange = function()
                    OnCategoryVisibilityChange()
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(visToggles, nil, SECTION_GAP)

            local hideInPvPMatchHolder = Components.Checkbox(catContent, {
                label = L["Options.HidePvPMatchStart"],
                get = function()
                    local vis = db.categoryVisibility and db.categoryVisibility[category]
                    return vis and vis.hideInPvPMatch or false
                end,
                enabled = function()
                    local vis = db.categoryVisibility and db.categoryVisibility[category]
                    return not vis or vis.pvp ~= false
                end,
                tooltip = {
                    title = L["Options.HidePvPMatchStart.Title"],
                    desc = L["Options.HidePvPMatchStart.Desc"],
                },
                onChange = function(checked)
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
                    db.categoryVisibility[category].hideInPvPMatch = checked
                    OnCategoryVisibilityChange()
                end,
            })
            catLayout:Add(hideInPvPMatchHolder, nil, COMPONENT_GAP)

            local readyCheckHolder = Components.Checkbox(catContent, {
                label = L["Options.ReadyCheckOnly"],
                get = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return cs and cs.showOnlyOnReadyCheck == true
                end,
                tooltip = {
                    title = L["Options.ReadyCheckOnly"],
                    desc = L["Options.ReadyCheckOnly.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showOnlyOnReadyCheck", checked)
                end,
            })
            catLayout:Add(readyCheckHolder, nil, COMPONENT_GAP)

            -- Free consumables sub-section (consumable category only)
            if category == "consumable" then
                local function EnsureFreeVisibility()
                    if not db.defaults then
                        db.defaults = {}
                    end
                    if not db.defaults.freeConsumableVisibility then
                        db.defaults.freeConsumableVisibility = {
                            openWorld = false,
                            scenario = true,
                            dungeon = true,
                            raid = true,
                            housing = false,
                            pvp = true,
                        }
                    end
                    return db.defaults.freeConsumableVisibility
                end
                catLayout:Space(SECTION_GAP)
                local freeHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                freeHeader:SetText("|cffffcc00" .. L["Options.FreeConsumables"] .. "|r")
                catLayout:AddText(freeHeader, 12, COMPONENT_GAP)
                local freeNote = catContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                freeNote:SetText(L["Options.FreeConsumables.Note"])
                catLayout:AddText(freeNote, 10, COMPONENT_GAP)

                local function IsFreeOverride()
                    return BR.Config.Get("defaults.freeConsumableMode", "override") == "override"
                end

                local freeOverrideHolder = Components.Checkbox(catContent, {
                    label = L["Options.FreeConsumables.Override"],
                    get = function()
                        return IsFreeOverride()
                    end,
                    tooltip = {
                        title = L["Options.FreeConsumables.Override"],
                        desc = L["Options.FreeConsumables.Override.Desc"],
                    },
                    onChange = function(checked)
                        BR.Config.Set("defaults.freeConsumableMode", checked and "override" or "follow")
                        Components.RefreshAll()
                    end,
                })
                catLayout:Add(freeOverrideHolder, nil, COMPONENT_GAP)

                -- Override controls (indented under checkbox)
                local INDENT = 12
                catLayout:SetX(catLayout:GetX() + INDENT)

                local freeVisToggles = Components.VisibilityToggles(catContent, {
                    store = {
                        getContent = function(key)
                            local vis = db.defaults and db.defaults.freeConsumableVisibility
                            return not vis or vis[key] ~= false
                        end,
                        setContent = function(key)
                            local vis = EnsureFreeVisibility()
                            vis[key] = not vis[key]
                        end,
                        getDiffTable = function(dbKey)
                            local vis = db.defaults and db.defaults.freeConsumableVisibility
                            return vis and vis[dbKey]
                        end,
                        ensureDiffTable = function(dbKey)
                            local vis = EnsureFreeVisibility()
                            if not vis[dbKey] then
                                vis[dbKey] = {} ---@diagnostic disable-line: assign-type-mismatch
                            end
                            return vis[dbKey]
                        end,
                    },
                    noAutoRefresh = true,
                    onChange = function()
                        UpdateDisplay()
                    end,
                })
                local origVisRefresh = freeVisToggles.Refresh
                function freeVisToggles:Refresh()
                    origVisRefresh(self)
                    local enabled = IsFreeOverride()
                    self:SetAlpha(enabled and 1 or 0.4)
                    for _, btn in ipairs(self.allToggleButtons) do
                        btn:EnableMouse(enabled)
                    end
                end
                tinsert(BR.RefreshableComponents, freeVisToggles)
                catLayout:Add(freeVisToggles, nil, COMPONENT_GAP)

                catLayout:SetX(catLayout:GetX() - INDENT)
                catLayout:Space(SECTION_GAP)
            end
        else
            local banner = Components.Banner(catContent, {
                text = L["CustomBuff.SettingsMovedNote"],
                color = "orange",
                icon = "services-icon-warning",
            })
            catLayout:Add(banner, nil, SECTION_GAP)
            banner:SetPoint("RIGHT", catContent, "RIGHT", 0, 0)
        end

        -- Icons sub-header (all categories except custom)
        if category ~= "custom" then
            local iconsHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            iconsHeader:SetText("|cffffcc00" .. L["Options.Icons"] .. "|r")
            catLayout:AddText(iconsHeader, 12, COMPONENT_GAP)
        end

        -- Show text on icons (not for custom — custom buffs have per-buff missing text)
        if category ~= "custom" then
            local showTextHolder = Components.Checkbox(catContent, {
                label = L["Options.ShowText"],
                get = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return not cs or cs.showText ~= false
                end,
                tooltip = {
                    title = L["Options.ShowText"],
                    desc = L["Options.ShowText.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showText", checked)
                end,
            })
            catLayout:Add(showTextHolder, nil, COMPONENT_GAP)
        end

        -- Missing count only (raid only)
        if category == "raid" then
            local missingCountHolder = Components.Checkbox(catContent, {
                label = L["Options.ShowMissingCountOnly"],
                get = function()
                    return db.showMissingCountOnly == true
                end,
                tooltip = {
                    title = L["Options.ShowMissingCountOnly"],
                    desc = L["Options.ShowMissingCountOnly.Desc"],
                },
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return not cs or cs.showText ~= false
                end,
                onChange = function(checked)
                    BR.Config.Set("showMissingCountOnly", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(missingCountHolder, nil, COMPONENT_GAP)
        end

        -- "BUFF!" text (raid only, grouped under Icons)
        if category == "raid" then
            local reminderHolder = Components.Checkbox(catContent, {
                label = L["Options.ShowBuffReminderText"],
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(checked)
                    BR.Config.Set("categorySettings.raid.showBuffReminder", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(reminderHolder, nil, COMPONENT_GAP)

            local buffTextSizeHolder = Components.NumericStepper(reminderHolder, {
                label = L["Options.Size"],
                labelWidth = 28,
                min = 6,
                max = 40,
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    if cs and cs.buffTextSize then
                        return cs.buffTextSize
                    end
                    local textSize = (cs and cs.textSize) or defaults.defaults.textSize
                    return max(6, floor(textSize * 0.8))
                end,
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(val)
                    BR.Config.Set("categorySettings.raid.buffTextSize", val)
                end,
            })
            buffTextSizeHolder:SetPoint("LEFT", reminderHolder, "LEFT", 210, 0)

            local buffTextOffsetXHolder = Components.Slider(catContent, {
                label = L["Options.BuffTextOffsetX"],
                labelWidth = 60,
                min = -40,
                max = 40,
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return (cs and cs.buffTextOffsetX) or 0
                end,
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(val)
                    BR.Config.Set("categorySettings.raid.buffTextOffsetX", val)
                end,
            })

            local buffTextOffsetYHolder = Components.Slider(catContent, {
                label = L["Options.BuffTextOffsetY"],
                labelWidth = 60,
                min = -40,
                max = 40,
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return (cs and cs.buffTextOffsetY) or 0
                end,
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(val)
                    BR.Config.Set("categorySettings.raid.buffTextOffsetY", val)
                end,
            })

            buffTextOffsetYHolder:SetPoint("LEFT", buffTextOffsetXHolder, "LEFT", 210, 0)
            catLayout:Add(buffTextOffsetXHolder, nil, COMPONENT_GAP)
        end

        -- Click to cast checkbox
        if category ~= "custom" then
            local clickableHolder = Components.Checkbox(catContent, {
                label = L["Options.ClickToCast"],
                get = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return cs and cs.clickable == true
                end,
                tooltip = {
                    title = L["Options.ClickToCast"],
                    desc = L["Options.ClickToCast.DescFull"],
                },
                onChange = function(checked)
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings[category] then
                        db.categorySettings[category] = {}
                    end
                    db.categorySettings[category].clickable = checked
                    BR.Display.UpdateActionButtons(category)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(clickableHolder, nil, 2)

            catLayout:SetX(20)
            local highlightHolder = Components.Checkbox(catContent, {
                label = L["Options.HoverHighlight"],
                get = function()
                    local hcs = db.categorySettings and db.categorySettings[category]
                    return hcs and hcs.clickableHighlight ~= false
                end,
                enabled = function()
                    local hcs = db.categorySettings and db.categorySettings[category]
                    return hcs and hcs.clickable == true
                end,
                tooltip = {
                    title = L["Options.HoverHighlight"],
                    desc = L["Options.HoverHighlight.Desc"],
                },
                onChange = function(checked)
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings[category] then
                        db.categorySettings[category] = {}
                    end
                    db.categorySettings[category].clickableHighlight = checked
                    BR.Display.UpdateActionButtons(category)
                end,
            })
            catLayout:Add(highlightHolder, nil, COMPONENT_GAP)

            if category == "pet" then
                local specIconHolder = Components.Checkbox(catContent, {
                    label = L["Options.PetSpecIcon"],
                    get = function()
                        return BR.Config.Get("defaults.petSpecIconOnHover", true)
                    end,
                    enabled = function()
                        local hcs = db.categorySettings and db.categorySettings[category]
                        return hcs and hcs.clickable == true
                    end,
                    tooltip = {
                        title = L["Options.PetSpecIcon.Title"],
                        desc = L["Options.PetSpecIcon.Desc"],
                    },
                    onChange = function(checked)
                        BR.Config.Set("defaults.petSpecIconOnHover", checked)
                    end,
                })
                catLayout:Add(specIconHolder, nil, COMPONENT_GAP)
            end

            if category == "consumable" then
                local showTooltipsHolder = Components.Checkbox(catContent, {
                    label = L["Options.ShowItemTooltips"],
                    get = function()
                        return BR.Config.Get("defaults.showConsumableTooltips", false) ~= false
                    end,
                    enabled = function()
                        local hcs = db.categorySettings and db.categorySettings[category]
                        return hcs and hcs.clickable == true
                    end,
                    tooltip = {
                        title = L["Options.ShowItemTooltips"],
                        desc = L["Options.ShowItemTooltips.Desc"],
                    },
                    onChange = function(checked)
                        BR.Config.Set("defaults.showConsumableTooltips", checked)
                    end,
                })
                catLayout:Add(showTooltipsHolder, nil, COMPONENT_GAP)
            end

            catLayout:SetX(0)
        end

        -- Pet display settings (pet only)
        if category == "pet" then
            catLayout:Space(SECTION_GAP)

            local updatePetDisplayModePreview -- forward declaration for preview update
            local petDisplayModeHolder = Components.Dropdown(catContent, {
                label = L["Options.PetDisplay"],
                width = 120,
                get = function()
                    return BR.Config.Get("defaults.petDisplayMode", "generic")
                end,
                options = {
                    {
                        value = "generic",
                        label = L["Options.PetDisplay.Generic"],
                        desc = L["Options.PetDisplay.GenericDesc"],
                    },
                    {
                        value = "expanded",
                        label = L["Options.PetDisplay.Summon"],
                        desc = L["Options.PetDisplay.SummonDesc"],
                    },
                },
                tooltip = {
                    title = L["Options.PetDisplay.Mode"],
                    desc = L["Options.PetDisplay.Mode.Desc"],
                },
                onChange = function(val)
                    BR.Config.Set("defaults.petDisplayMode", val)
                    if updatePetDisplayModePreview then
                        updatePetDisplayModePreview(val)
                    end
                end,
            })
            catLayout:Add(petDisplayModeHolder, nil, COMPONENT_GAP)

            -- Pet display mode preview (anchored to the right of the dropdown)
            local PP_ICON = 24
            local PP_BORDER = 2
            local PP_GAP = 3
            local PP_STEP = PP_ICON + PP_GAP + PP_BORDER * 2

            local TEX_PET_GENERIC = 136082 -- Summon Demon flyout icon
            local TEX_PETS = { 136218, 136221, 136217 } -- Imp, Voidwalker, Felhunter

            local petPreviewHeight = PP_ICON + PP_BORDER * 2
            local PET_MODE_ICON_COUNT = { generic = 1, expanded = 3 }

            local petPreviewHolder = CreateFrame("Frame", nil, catContent)
            petPreviewHolder:SetSize(PP_STEP, petPreviewHeight)
            petPreviewHolder:SetPoint("TOPLEFT", petDisplayModeHolder, "TOPRIGHT", 12, 0)

            local petPreviewContainer = CreateFrame("Frame", nil, petPreviewHolder)
            petPreviewContainer:SetPoint("TOPLEFT", 0, 0)
            petPreviewContainer:SetSize(3 * PP_STEP, petPreviewHeight)
            petPreviewContainer:SetAlpha(0.7)

            local function CreatePetPreviewIcon(parent, texture, size)
                local f = CreateFrame("Frame", nil, parent)
                f:SetSize(size, size)
                f.icon = f:CreateTexture(nil, "ARTWORK")
                f.icon:SetAllPoints()
                f.icon:SetTexture(texture)
                local z = TEXCOORD_INSET
                f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
                f.border = f:CreateTexture(nil, "BACKGROUND")
                f.border:SetColorTexture(0, 0, 0, 1)
                f.border:SetPoint("TOPLEFT", -PP_BORDER, PP_BORDER)
                f.border:SetPoint("BOTTOMRIGHT", PP_BORDER, -PP_BORDER)
                return f
            end

            local allPetPreviewFrames = {}

            -- Generic: single icon
            local genericFrame = CreatePetPreviewIcon(petPreviewContainer, TEX_PET_GENERIC, PP_ICON)
            genericFrame:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", 0, 0)
            genericFrame:Hide()
            allPetPreviewFrames[#allPetPreviewFrames + 1] = genericFrame

            -- Expanded: individual summon spell icons
            local expandedPetFrames = {}
            for i = 1, 3 do
                local f = CreatePetPreviewIcon(petPreviewContainer, TEX_PETS[i], PP_ICON)
                f:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", (i - 1) * PP_STEP, 0)
                f:Hide()
                expandedPetFrames[i] = f
                allPetPreviewFrames[#allPetPreviewFrames + 1] = f
            end

            local PET_MODE_FRAMES = {
                generic = { genericFrame },
                expanded = expandedPetFrames,
            }
            updatePetDisplayModePreview = function(mode)
                for _, f in ipairs(allPetPreviewFrames) do
                    f:Hide()
                end
                local shown = PET_MODE_FRAMES[mode]
                if shown then
                    for _, f in ipairs(shown) do
                        f:Show()
                    end
                end
                petPreviewHolder:SetWidth((PET_MODE_ICON_COUNT[mode] or 1) * PP_STEP)
            end

            -- Initial state
            updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))

            -- Register for refresh so reopening the panel re-reads the value
            function petPreviewHolder:Refresh()
                updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))
            end
            tinsert(BR.RefreshableComponents, petPreviewHolder)

            local petLabelsHolder = Components.Checkbox(catContent, {
                label = L["Options.PetLabels"],
                get = function()
                    return BR.Config.Get("defaults.petLabels", true)
                end,
                tooltip = {
                    title = L["Options.PetLabels"],
                    desc = L["Options.PetLabels.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.petLabels", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(petLabelsHolder, nil, COMPONENT_GAP)

            local petLabelScaleHolder = Components.NumericStepper(petLabelsHolder, {
                label = L["Options.PetLabels.SizePct"],
                labelWidth = 36,
                min = 50,
                max = 200,
                step = 10,
                get = function()
                    return BR.Config.Get("defaults.petLabelScale", 100)
                end,
                enabled = function()
                    return BR.Config.Get("defaults.petLabels", true)
                end,
                onChange = function(val)
                    BR.Config.Set("defaults.petLabelScale", val)
                end,
            })
            petLabelScaleHolder:SetPoint("LEFT", petLabelsHolder, "LEFT", 90, 0)

            -- Pet class label toggles (H/W/D/M) — anchored to the right of the scale stepper
            local function classColor(cls)
                local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
                if c then
                    return { c.r, c.g, c.b }
                end
                return { 0.5, 0.5, 0.5 }
            end

            local petClassBar, petClassButtons = Components.CreateSegmentedBar(petLabelsHolder, {
                toggleDefs = {
                    {
                        key = "HUNTER",
                        label = "H",
                        tooltip = { title = L["Class.Hunter"] },
                        color = classColor("HUNTER"),
                    },
                    {
                        key = "WARLOCK",
                        label = "W",
                        tooltip = { title = L["Class.Warlock"] },
                        color = classColor("WARLOCK"),
                    },
                    {
                        key = "DEATHKNIGHT",
                        label = "D",
                        tooltip = { title = L["Class.DeathKnight"] },
                        color = classColor("DEATHKNIGHT"),
                    },
                    { key = "MAGE", label = "M", tooltip = { title = L["Class.Mage"] }, color = classColor("MAGE") },
                },
                getState = function(key)
                    local vis = BR.profile.defaults.petLabelClasses
                    return not vis or vis[key] ~= false
                end,
                setState = function(key)
                    if not BR.profile.defaults.petLabelClasses then
                        BR.profile.defaults.petLabelClasses = {
                            HUNTER = true,
                            WARLOCK = true,
                            DEATHKNIGHT = true,
                            MAGE = true,
                        }
                    end
                    BR.profile.defaults.petLabelClasses[key] = not BR.profile.defaults.petLabelClasses[key]
                end,
                onChange = function()
                    UpdateDisplay()
                end,
            })
            petClassBar:SetPoint("LEFT", petLabelScaleHolder, "RIGHT", 8, 0)

            local function isPetLabelsEnabled()
                return BR.Config.Get("defaults.petLabels", true)
            end
            petClassBar:SetBarDisabled(not isPetLabelsEnabled())

            local petClassBarRefreshHolder = CreateFrame("Frame", nil, petLabelsHolder)
            petClassBarRefreshHolder:SetSize(1, 1)
            function petClassBarRefreshHolder:Refresh()
                petClassBar:SetBarDisabled(not isPetLabelsEnabled())
                for _, btn in ipairs(petClassButtons) do
                    btn.UpdateVisual()
                end
            end
            tinsert(BR.RefreshableComponents, petClassBarRefreshHolder)
        end

        -- Item display mode (consumable only, grouped with icon options)
        if category == "consumable" then
            -- Consumable text scale (count + quality labels as % of icon size)
            local consumableTextScaleHolder = Components.Slider(catContent, {
                label = L["Options.ConsumableTextScale"],
                min = 5,
                max = 80,
                step = 1,
                suffix = "%",
                get = function()
                    return BR.Config.Get("defaults.consumableTextScale", 25)
                end,
                tooltip = {
                    title = L["Options.ConsumableTextScale.Title"],
                    desc = L["Options.ConsumableTextScale.Desc"],
                },
                onChange = function(val)
                    BR.Config.Set("defaults.consumableTextScale", val)
                end,
            })
            catLayout:Add(consumableTextScaleHolder, nil, COMPONENT_GAP)

            local updateDisplayModePreview -- forward declaration for preview update
            local updateSubIconSideVisibility -- forward declaration for sub-icon side visibility
            local displayModeHolder = Components.Dropdown(catContent, {
                label = L["Options.ItemDisplay"],
                get = function()
                    return BR.Config.Get("defaults.consumableDisplayMode", "sub_icons")
                end,
                options = {
                    {
                        value = "icon_only",
                        label = L["Options.ItemDisplay.IconOnly"],
                        desc = L["Options.ItemDisplay.IconOnlyDesc"],
                    },
                    {
                        value = "sub_icons",
                        label = L["Options.ItemDisplay.SubIcons"],
                        desc = L["Options.ItemDisplay.SubIconsDesc"],
                    },
                    {
                        value = "expanded",
                        label = L["Options.ItemDisplay.Expanded"],
                        desc = L["Options.ItemDisplay.ExpandedDesc"],
                    },
                },
                tooltip = {
                    title = L["Options.ItemDisplay.Mode"],
                    desc = L["Options.ItemDisplay.Mode.Desc"],
                },
                onChange = function(val)
                    BR.Config.Set("defaults.consumableDisplayMode", val)
                    if updateDisplayModePreview then
                        updateDisplayModePreview(val)
                    end
                    if updateSubIconSideVisibility then
                        updateSubIconSideVisibility(val)
                    end
                end,
            })
            catLayout:Add(displayModeHolder, nil, COMPONENT_GAP)

            -- Display mode preview (anchored to the right of the dropdown)
            local P_ICON = 24
            local P_SUB = 12
            local P_BORDER = 2
            local P_GAP = 3
            local P_STEP = P_ICON + P_GAP + P_BORDER * 2
            local P_SUB_STEP = P_SUB + P_BORDER * 2 -- sub-icons touch borders
            -- Distinct textures for flask/food/oil and their variants (Midnight icons)
            local TEX_FLASK = { 7548898, 7548899, 7548900 } -- Haranir flasks: blue, green, orange
            local TEX_FOOD = { 4672193, 1045939 } -- Royal Roast, Twilight Angler's Medley
            local TEX_OIL = 7548987 -- Thalassian Phoenix Oil

            local previewHeight = P_ICON + P_SUB + P_GAP + P_BORDER * 2
            local MODE_ICON_COUNT = { icon_only = 3, sub_icons = 3, expanded = 6 }

            local previewHolder = CreateFrame("Frame", nil, catContent)
            previewHolder:SetSize(3 * P_STEP, previewHeight)
            previewHolder:SetPoint("TOPLEFT", displayModeHolder, "TOPRIGHT", 12, 0)

            local previewContainer = CreateFrame("Frame", nil, previewHolder)
            previewContainer:SetPoint("TOPLEFT", 0, 0)
            previewContainer:SetSize(6 * P_STEP, previewHeight)
            previewContainer:SetAlpha(0.7)

            local function CreatePreviewIcon(parent, texture, size)
                local f = CreateFrame("Frame", nil, parent)
                f:SetSize(size, size)
                f.icon = f:CreateTexture(nil, "ARTWORK")
                f.icon:SetAllPoints()
                f.icon:SetTexture(texture)
                local z = TEXCOORD_INSET
                f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
                f.border = f:CreateTexture(nil, "BACKGROUND")
                f.border:SetColorTexture(0, 0, 0, 1)
                f.border:SetPoint("TOPLEFT", -P_BORDER, P_BORDER)
                f.border:SetPoint("BOTTOMRIGHT", P_BORDER, -P_BORDER)
                return f
            end

            local allPreviewFrames = {}

            -- Icon-only: [Flask] [Food] [Oil]
            local iconOnlyFrames = {}
            local iconOnlyTextures = { TEX_FLASK[1], TEX_FOOD[1], TEX_OIL }
            for i = 1, 3 do
                local f = CreatePreviewIcon(previewContainer, iconOnlyTextures[i], P_ICON)
                f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
                f:Hide()
                iconOnlyFrames[i] = f
                allPreviewFrames[#allPreviewFrames + 1] = f
            end

            -- Sub-icons: [Flask] [Food] [Oil] with variant sub-icons below
            local subIconsFrames = { mains = {}, subs = {} }
            local subVariants = { TEX_FLASK, TEX_FOOD, {} } -- oil has no variants
            for i, variants in ipairs(subVariants) do
                local mainTex = (#variants > 0) and variants[1] or TEX_OIL
                local main = CreatePreviewIcon(previewContainer, mainTex, P_ICON)
                main:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
                main:Hide()
                subIconsFrames.mains[i] = main
                allPreviewFrames[#allPreviewFrames + 1] = main
                if #variants > 1 then
                    local subCount = #variants - 1
                    local subRowWidth = (subCount - 1) * P_SUB_STEP + P_SUB
                    local subOffsetX = (P_ICON - subRowWidth) / 2
                    for j = 2, #variants do
                        local sub = CreatePreviewIcon(previewContainer, variants[j], P_SUB)
                        sub:SetPoint("TOPLEFT", main, "BOTTOMLEFT", subOffsetX + (j - 2) * P_SUB_STEP, -P_GAP)
                        sub:Hide()
                        subIconsFrames.subs[#subIconsFrames.subs + 1] = sub
                        allPreviewFrames[#allPreviewFrames + 1] = sub
                    end
                end
            end

            -- Expanded: [F1][F2][F3][Fd1][Fd2][Oil] — each variant at full size
            local expandedFrames = {}
            local expandedTextures = {
                TEX_FLASK[1],
                TEX_FLASK[2],
                TEX_FLASK[3],
                TEX_FOOD[1],
                TEX_FOOD[2],
                TEX_OIL,
            }
            for i = 1, 6 do
                local f = CreatePreviewIcon(previewContainer, expandedTextures[i], P_ICON)
                f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
                f:Hide()
                expandedFrames[i] = f
                allPreviewFrames[#allPreviewFrames + 1] = f
            end

            -- Combine sub-icons mains + subs into one flat list
            local subIconsAll = {}
            for _, f in ipairs(subIconsFrames.mains) do
                subIconsAll[#subIconsAll + 1] = f
            end
            for _, f in ipairs(subIconsFrames.subs) do
                subIconsAll[#subIconsAll + 1] = f
            end

            local MODE_FRAMES = {
                icon_only = iconOnlyFrames,
                sub_icons = subIconsAll,
                expanded = expandedFrames,
            }
            updateDisplayModePreview = function(mode)
                for _, f in ipairs(allPreviewFrames) do
                    f:Hide()
                end
                local shown = MODE_FRAMES[mode]
                if shown then
                    for _, f in ipairs(shown) do
                        f:Show()
                    end
                end
                previewHolder:SetWidth((MODE_ICON_COUNT[mode] or 3) * P_STEP)
            end

            -- Initial state
            updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))

            -- Register for refresh so reopening the panel re-reads the value
            function previewHolder:Refresh()
                updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))
            end
            tinsert(BR.RefreshableComponents, previewHolder)

            -- Sub-icon placement side (anchored below preview, visible only in sub_icons mode)
            local subIconSideHolder = Components.Dropdown(catContent, {
                label = L["Options.SubIconSide"],
                labelWidth = 30,
                width = 85,
                get = function()
                    local catSettings = db.categorySettings and db.categorySettings[category]
                    return catSettings and catSettings.subIconSide or "BOTTOM"
                end,
                options = {
                    { value = "BOTTOM", label = L["Options.SubIconSide.Bottom"] },
                    { value = "TOP", label = L["Options.SubIconSide.Top"] },
                    { value = "LEFT", label = L["Options.SubIconSide.Left"] },
                    { value = "RIGHT", label = L["Options.SubIconSide.Right"] },
                },
                onChange = function(val)
                    BR.Config.Set("categorySettings." .. category .. ".subIconSide", val)
                end,
            })
            subIconSideHolder:SetPoint("TOPLEFT", previewHolder, "TOPRIGHT", 12, 0)

            updateSubIconSideVisibility = function(mode)
                subIconSideHolder:SetShown(mode == "sub_icons")
            end
            updateSubIconSideVisibility(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))

            -- Sub-header for behavior options
            catLayout:Space(SECTION_GAP)
            local behaviorHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            behaviorHeader:SetText("|cffffcc00" .. L["Options.Behavior"] .. "|r")
            catLayout:AddText(behaviorHeader, 12, COMPONENT_GAP)

            local showWithoutItemsHolder = Components.Checkbox(catContent, {
                label = L["Options.ShowWithoutItems"],
                get = function()
                    return BR.Config.Get("defaults.showConsumablesWithoutItems", false) == true
                end,
                tooltip = {
                    title = L["Options.ShowWithoutItems.Title"],
                    desc = L["Options.ShowWithoutItems.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.showConsumablesWithoutItems", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(showWithoutItemsHolder, nil, COMPONENT_GAP)

            local SHOW_WITHOUT_INDENT = 12
            catLayout:SetX(catLayout:GetX() + SHOW_WITHOUT_INDENT)
            local readyCheckOnlyHolder = Components.Checkbox(catContent, {
                label = L["Options.ShowWithoutItemsReadyCheckOnly"],
                get = function()
                    return BR.Config.Get("defaults.showWithoutItemsOnlyOnReadyCheck", false) == true
                end,
                enabled = function()
                    return BR.Config.Get("defaults.showConsumablesWithoutItems", false) == true
                end,
                tooltip = {
                    title = L["Options.ShowWithoutItemsReadyCheckOnly.Title"],
                    desc = L["Options.ShowWithoutItemsReadyCheckOnly.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.showWithoutItemsOnlyOnReadyCheck", checked)
                end,
            })
            catLayout:Add(readyCheckOnlyHolder, nil, COMPONENT_GAP)
            catLayout:SetX(catLayout:GetX() - SHOW_WITHOUT_INDENT)

            local delveFoodOnlyHolder = Components.Checkbox(catContent, {
                label = L["Options.DelveFoodOnly"],
                get = function()
                    return BR.Config.Get("defaults.delveFoodOnly", false) == true
                end,
                tooltip = {
                    title = L["Options.DelveFoodOnly"],
                    desc = L["Options.DelveFoodOnly.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.delveFoodOnly", checked)
                end,
            })
            catLayout:Add(delveFoodOnlyHolder, nil, COMPONENT_GAP)
        end

        -- Layout sub-header
        catLayout:Space(SECTION_GAP)
        local layoutHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        layoutHeader:SetText("|cffffcc00" .. L["Options.Layout"] .. "|r")
        catLayout:AddText(layoutHeader, 12, COMPONENT_GAP)

        -- Priority slider (only relevant when not split)
        local priorityHolder = Components.Slider(catContent, {
            label = L["Options.Priority"],
            min = 1,
            max = 7,
            step = 1,
            get = function()
                local cs = db.categorySettings and db.categorySettings[category]
                return cs and cs.priority or defaults.categorySettings[category].priority
            end,
            enabled = function()
                return not IsCategorySplit(category)
            end,
            tooltip = {
                title = L["Options.DisplayPriority"],
                desc = L["Options.Priority.Desc"],
            },
            onChange = function(val)
                BR.Config.Set("categorySettings." .. category .. ".priority", val)
            end,
        })
        catLayout:Add(priorityHolder, nil, COMPONENT_GAP)

        -- Split frame checkbox
        local splitHolder = Components.Checkbox(catContent, {
            label = L["Options.SplitFrame"],
            get = function()
                return IsCategorySplit(category)
            end,
            tooltip = {
                title = L["Options.SplitFrame"],
                desc = L["Options.SplitFrame.Desc"],
            },
            onChange = function(checked)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                db.categorySettings[category].split = checked
                ReparentBuffFrames()
                UpdateVisuals()
            end,
        })
        catLayout:Add(splitHolder, nil, COMPONENT_GAP)

        -- Reset position button (only relevant when split)
        local resetBtn = CreateButton(catContent, L["Options.ResetPosition"], function()
            local catDefaults = defaults.categorySettings[category]
            if catDefaults and catDefaults.position then
                ResetCategoryFramePosition(category, catDefaults.position.x, catDefaults.position.y)
            end
        end)
        resetBtn:SetPoint("LEFT", splitHolder, "RIGHT", 10, 0)
        resetBtn:SetEnabled(IsCategorySplit(category))

        local origSplitClick = splitHolder.checkbox:GetScript("OnClick")
        splitHolder.checkbox:SetScript("OnClick", function(self)
            if origSplitClick then
                origSplitClick(self)
            end
            resetBtn:SetEnabled(IsCategorySplit(category))
            Components.RefreshAll()
        end)

        -- Shared enabled predicates for this category
        local function isCustomAppearanceEnabled()
            return db.categorySettings
                and db.categorySettings[category]
                and db.categorySettings[category].useCustomAppearance == true
        end

        local function isCustomGlowEnabled()
            return isCustomAppearanceEnabled() and db.categorySettings[category].useCustomGlow == true
        end

        -- Snapshot current effective glow values from defaults into a category
        local function SnapshotGlowDefaults()
            local cs = db.categorySettings[category]
            local glowDefaults = db.defaults or {}
            local glowSnapshotKeys = {
                -- Expiring glow keys
                "glowType",
                "glowSize",
                "glowPixelLines",
                "glowPixelFrequency",
                "glowPixelLength",
                "glowAutocastParticles",
                "glowAutocastFrequency",
                "glowAutocastScale",
                "glowBorderFrequency",
                "glowProcDuration",
                "glowProcStartAnim",
                "glowProcUseCustomColor",
                "glowXOffset",
                "glowYOffset",
                -- Missing glow keys
                "missingGlowType",
                "missingGlowSize",
                "missingGlowPixelLines",
                "missingGlowPixelFrequency",
                "missingGlowPixelLength",
                "missingGlowAutocastParticles",
                "missingGlowAutocastFrequency",
                "missingGlowAutocastScale",
                "missingGlowBorderFrequency",
                "missingGlowProcDuration",
                "missingGlowProcStartAnim",
                "missingGlowProcUseCustomColor",
                "missingGlowXOffset",
                "missingGlowYOffset",
            }
            for _, key in ipairs(glowSnapshotKeys) do
                if cs[key] == nil and glowDefaults[key] ~= nil then
                    cs[key] = glowDefaults[key]
                end
            end
            -- Color: deep copy (table values)
            for _, colorKey in ipairs({ "glowColor", "missingGlowColor" }) do
                if cs[colorKey] == nil and glowDefaults[colorKey] then
                    local gc = glowDefaults[colorKey]
                    cs[colorKey] = { gc[1], gc[2], gc[3], gc[4] }
                end
            end
        end

        -- Use custom appearance checkbox
        catLayout:SetX(0)
        local useCustomAppHolder = Components.Checkbox(catContent, {
            label = L["Options.CustomAppearance"],
            get = function()
                return db.categorySettings
                    and db.categorySettings[category]
                    and db.categorySettings[category].useCustomAppearance == true
            end,
            tooltip = {
                title = L["Options.CustomAppearance"],
                desc = L["Options.CustomAppearance.Desc"],
            },
            onChange = function(checked)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                -- When enabling custom appearance, snapshot current effective values
                -- so the category starts independent from future Global Defaults changes
                if checked then
                    local effective = GetCategorySettings(category)
                    local cs = db.categorySettings[category]
                    local appearanceKeys = {
                        "iconSize",
                        "iconWidth",
                        "textSize",
                        "spacing",
                        "iconZoom",
                        "borderSize",
                        "iconAlpha",
                        "textAlpha",
                        "growDirection",
                    }
                    for _, key in ipairs(appearanceKeys) do
                        if cs[key] == nil and effective[key] ~= nil then
                            cs[key] = effective[key]
                        end
                    end
                    -- textColor: deep copy (table value)
                    if cs.textColor == nil and effective.textColor then
                        local tc = effective.textColor
                        cs.textColor = { tc[1], tc[2], tc[3] }
                    end
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomAppearance", checked)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(useCustomAppHolder, nil, COMPONENT_GAP)

        local baseContentY = catLayout:GetY()

        -- Direction buttons (part of custom appearance)
        catLayout:SetX(10)
        local dirHolder = Components.DirectionButtons(catContent, {
            get = function()
                local catSettings = db.categorySettings and db.categorySettings[category]
                local val = catSettings and catSettings.growDirection
                if val ~= nil then
                    return val
                end
                return db.defaults and db.defaults.growDirection or "CENTER"
            end,
            enabled = function()
                return isCustomAppearanceEnabled() and IsCategorySplit(category)
            end,
            onChange = function(dir)
                BR.Config.Set("categorySettings." .. category .. ".growDirection", dir)
            end,
        })
        catLayout:Add(dirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

        -- Read the category's own saved value, falling back to defaults only if no value was saved.
        -- This avoids showing inherited defaults when useCustomAppearance is off, so toggling
        -- custom appearance off/on preserves the user's previously configured values.
        local function getCatOwnValue(key, default)
            local catSettings = db.categorySettings and db.categorySettings[category]
            local val = catSettings and catSettings[key]
            if val ~= nil then
                return val
            end
            return db.defaults and db.defaults[key] or default
        end

        local function isCatDimensionsLinked()
            local cs = db.categorySettings and db.categorySettings[category]
            return not cs or cs.iconWidth == nil
        end

        -- Appearance controls (2-col declarative grid)
        catLayout:SetX(10)
        local appFrame = CreateFrame("Frame", nil, catContent)
        appFrame:SetSize(480, 50)
        catLayout:Add(appFrame, 0)

        local catGrid = Components.AppearanceGrid(appFrame, {
            get = getCatOwnValue,
            set = function(key, value)
                BR.Config.Set("categorySettings." .. category .. "." .. key, value)
            end,
            setMulti = function(changes)
                local prefixed = {}
                for k, v in pairs(changes) do
                    prefixed["categorySettings." .. category .. "." .. k] = v
                end
                BR.Config.SetMulti(prefixed)
            end,
            isLinked = isCatDimensionsLinked,
            onLink = function()
                BR.Config.Set("categorySettings." .. category .. ".iconWidth", nil)
                Components.RefreshAll()
            end,
            onUnlink = function()
                local size = getCatOwnValue("iconSize", 64)
                BR.Config.Set("categorySettings." .. category .. ".iconWidth", size)
                Components.RefreshAll()
            end,
            enabled = isCustomAppearanceEnabled,
            masqueCheck = IsMasqueActive,
        })

        -- Glow settings (positioned after appearance grid)
        local glowRowY = -catGrid.height
        local gridHeight
        if category == "pet" then
            -- Pets don't expire — single glow on/off checkbox (uses showMissingGlow)
            local catPetGlowHolder = Components.Checkbox(appFrame, {
                label = L["Options.GlowMissingPets"],
                get = function()
                    return getCatOwnValue("showMissingGlow", true) ~= false
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catPetGlowHolder:SetPoint("TOPLEFT", 0, glowRowY)

            -- Per-category custom glow style (pet)
            local catPetCustomGlowHolder = Components.Checkbox(appFrame, {
                label = L["Options.CustomGlowStyle"],
                get = function()
                    return isCustomGlowEnabled()
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    if checked then
                        SnapshotGlowDefaults()
                    end
                    BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catPetCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

            local catPetGlowSettingsBtn = CreateButton(appFrame, L["Options.Customize"], function()
                ShowGlowAdvanced(category, "missing")
            end)
            catPetGlowSettingsBtn:SetPoint("LEFT", catPetCustomGlowHolder.label, "RIGHT", 8, 0)
            catPetGlowSettingsBtn:SetFrameLevel(catPetCustomGlowHolder:GetFrameLevel() + 5)

            local function updatePetGlowBtnEnabled()
                local enabled = isCustomGlowEnabled()
                if enabled then
                    catPetGlowSettingsBtn:Enable()
                    catPetGlowSettingsBtn:SetAlpha(1)
                else
                    catPetGlowSettingsBtn:Disable()
                    catPetGlowSettingsBtn:SetAlpha(0.4)
                end
            end
            updatePetGlowBtnEnabled()
            tinsert(BR.RefreshableComponents, { Refresh = updatePetGlowBtnEnabled })

            gridHeight = catGrid.height + 48
        else
            local catThresholdHolder = Components.Slider(appFrame, {
                label = L["Options.Expiration"],
                labelWidth = 56,
                min = 0,
                max = 45,
                step = 5,
                formatValue = function(val)
                    return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
                end,
                get = function()
                    return getCatOwnValue("expirationThreshold", 15)
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(val)
                    BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", val)
                end,
            })
            catThresholdHolder:SetPoint("TOPLEFT", 0, glowRowY)

            local catGlowCheckHolder = Components.Checkbox(appFrame, {
                label = L["Options.Glow"],
                get = function()
                    local ex = getCatOwnValue("showExpirationGlow", true) ~= false
                    local miss = getCatOwnValue("showMissingGlow", true) ~= false
                    return ex or miss
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showExpirationGlow", checked)
                    BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catGlowCheckHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

            -- Per-category custom glow style
            local catCustomGlowHolder = Components.Checkbox(appFrame, {
                label = L["Options.CustomGlowStyle"],
                get = function()
                    return isCustomGlowEnabled()
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    if checked then
                        SnapshotGlowDefaults()
                    end
                    BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 48)

            local catGlowSettingsBtn = CreateButton(appFrame, L["Options.Customize"], function()
                ShowGlowAdvanced(category)
            end)
            catGlowSettingsBtn:SetPoint("LEFT", catCustomGlowHolder.label, "RIGHT", 8, 0)
            catGlowSettingsBtn:SetFrameLevel(catCustomGlowHolder:GetFrameLevel() + 5)

            -- Register enabled state for the customize button
            local function updateGlowBtnEnabled()
                local enabled = isCustomGlowEnabled()
                if enabled then
                    catGlowSettingsBtn:Enable()
                    catGlowSettingsBtn:SetAlpha(1)
                else
                    catGlowSettingsBtn:Disable()
                    catGlowSettingsBtn:SetAlpha(0.4)
                end
            end
            updateGlowBtnEnabled()
            tinsert(BR.RefreshableComponents, { Refresh = updateGlowBtnEnabled })

            gridHeight = catGrid.height + 72
        end

        -- Advance past the appFrame grid and finalize section height
        catLayout:Space(gridHeight)
        catLayout:SetX(0)

        local fullContentHeight = abs(catLayout:GetY()) + 10
        local baseContentHeight = abs(baseContentY) + 10

        local UpdateCustomAppearanceVisibility = function()
            local show = isCustomAppearanceEnabled()
            if show then
                dirHolder:Show()
                appFrame:Show()
                section:SetContentHeight(fullContentHeight)
            else
                dirHolder:Hide()
                appFrame:Hide()
                section:SetContentHeight(baseContentHeight)
            end
            C_Timer.After(0, UpdateAppearanceContentHeight)
        end

        -- Register so panel OnShow syncs visibility state
        tinsert(BR.RefreshableComponents, { Refresh = UpdateCustomAppearanceVisibility })

        -- Set initial state (inline to avoid deferred timer during loop)
        if isCustomAppearanceEnabled() then
            section:SetContentHeight(fullContentHeight)
        else
            dirHolder:Hide()
            appFrame:Hide()
            section:SetContentHeight(baseContentHeight)
        end
        tinsert(categorySections, section)
        previousSection = section
    end

    UpdateAppearanceContentHeight()

    -- ========== SETTINGS TAB ==========
    -- Simple frame (not scrollable) - content fits without scrolling
    local settingsContent = CreateFrame("Frame", nil, panel)
    settingsContent:SetPoint("TOPLEFT", 0, CONTENT_TOP)
    settingsContent:SetSize(PANEL_WIDTH, 500)
    settingsContent:Hide()
    contentContainers.settings = settingsContent

    local setX = COL_PADDING
    local setLayout = Components.VerticalLayout(settingsContent, { x = setX, y = -10 })

    local loginMsgHolder = Components.Checkbox(settingsContent, {
        label = L["Options.ShowLoginMessages"],
        get = function()
            return BR.profile.showLoginMessages ~= false
        end,
        onChange = function(checked)
            BR.profile.showLoginMessages = checked
        end,
    })
    setLayout:Add(loginMsgHolder, nil, COMPONENT_GAP)

    local minimapHolder = Components.Checkbox(settingsContent, {
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
    setLayout:Add(minimapHolder, nil, COMPONENT_GAP)

    LayoutSectionHeader(setLayout, settingsContent, L["Options.ChatRequests"])

    local requestBuffHolder = Components.Checkbox(settingsContent, {
        label = L["Options.RequestBuffInChat"],
        get = function()
            return BR.profile.requestBuffInChat == true
        end,
        tooltip = {
            title = L["Options.RequestBuffInChat"],
            desc = L["Options.RequestBuffInChat.Desc"],
        },
        onChange = function(checked)
            BR.profile.requestBuffInChat = checked
            BR.Display.UpdateActionButtons("raid")
            BR.Display.UpdateActionButtons("presence")
            Components.RefreshAll()
        end,
    })

    local customizeMsgsBtn = CreateButton(settingsContent, L["Options.CustomizeChatMessages"], function()
        ShowChatRequestModal()
    end)
    customizeMsgsBtn:SetPoint("LEFT", requestBuffHolder.label, "RIGHT", 8, 0)
    customizeMsgsBtn:SetFrameLevel(requestBuffHolder:GetFrameLevel() + 5)

    setLayout:Add(requestBuffHolder, nil, COMPONENT_GAP)

    -- General Settings section
    LayoutSectionHeader(setLayout, settingsContent, L["Options.Visibility"])

    local groupHolder = Components.Checkbox(settingsContent, {
        label = L["Options.ShowOnlyInGroup"],
        get = function()
            return BR.profile.showOnlyInGroup ~= false
        end,
        onChange = function(checked)
            BR.Config.Set("showOnlyInGroup", checked)
        end,
    })
    setLayout:Add(groupHolder, nil, COMPONENT_GAP)

    -- "Hide when:" sub-label with indented checkboxes
    local hideWhenLabel = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideWhenLabel:SetText(L["Options.HideWhen"])
    setLayout:AddText(hideWhenLabel, 12, COMPONENT_GAP)

    local HIDE_INDENT = 16
    setLayout:SetX(setX + HIDE_INDENT)

    local combatHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Combat"],
        get = function()
            return BR.profile.hideInCombat == true
        end,
        onChange = function(checked)
            BR.Config.Set("hideInCombat", checked)
            Components.RefreshAll()
        end,
    })
    setLayout:Add(combatHolder, nil, COMPONENT_GAP)

    local combatExpiringHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Expiring"],
        tooltip = {
            title = L["Options.HideWhen.Expiring.Title"],
            desc = L["Options.HideWhen.Expiring.Desc"],
        },
        get = function()
            return BR.profile.hideExpiringInCombat ~= false
        end,
        enabled = function()
            return BR.profile.hideInCombat ~= true
        end,
        onChange = function(checked)
            BR.Config.Set("hideExpiringInCombat", checked)
        end,
    })
    setLayout:Add(combatExpiringHolder, nil, COMPONENT_GAP)

    local mountedHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Mounted"],
        tooltip = {
            title = L["Options.HideWhen.Mounted.Title"],
            desc = L["Options.HideWhen.Mounted.Desc"],
        },
        get = function()
            return BR.profile.hideWhileMounted == true
        end,
        onChange = function(checked)
            BR.Config.Set("hideWhileMounted", checked)
        end,
    })
    setLayout:Add(mountedHolder, nil, COMPONENT_GAP)

    local vehicleHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Vehicle"],
        tooltip = {
            title = L["Options.HideWhen.Vehicle.Title"],
            desc = L["Options.HideWhen.Vehicle.Desc"],
        },
        get = function()
            return BR.profile.hideAllInVehicle == true
        end,
        onChange = function(checked)
            BR.Config.Set("hideAllInVehicle", checked)
        end,
    })
    setLayout:Add(vehicleHolder, nil, COMPONENT_GAP)

    local restingHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Resting"],
        get = function()
            return BR.profile.hideWhileResting == true
        end,
        tooltip = { title = L["Options.HideWhen.Resting.Title"], desc = L["Options.HideWhen.Resting.Desc"] },
        onChange = function(checked)
            BR.Config.Set("hideWhileResting", checked)
        end,
    })
    setLayout:Add(restingHolder, nil, COMPONENT_GAP)

    local legacyHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Legacy"],
        tooltip = {
            title = L["Options.HideWhen.Legacy.Title"],
            desc = L["Options.HideWhen.Legacy.Desc"],
        },
        get = function()
            return BR.profile.hideInLegacyInstances == true
        end,
        onChange = function(checked)
            BR.Config.Set("hideInLegacyInstances", checked)
        end,
    })
    setLayout:Add(legacyHolder, nil, COMPONENT_GAP)

    local levelingHolder = Components.Checkbox(settingsContent, {
        label = L["Options.HideWhen.Leveling"],
        tooltip = {
            title = L["Options.HideWhen.Leveling.Title"],
            desc = L["Options.HideWhen.Leveling.Desc"],
        },
        get = function()
            return BR.profile.hideWhileLeveling == true
        end,
        onChange = function(checked)
            BR.Config.Set("hideWhileLeveling", checked)
        end,
    })
    setLayout:Add(levelingHolder, nil, COMPONENT_GAP)

    setLayout:SetX(setX)

    local trackingModeHolder = Components.Dropdown(settingsContent, {
        label = L["Options.BuffTracking"],
        width = 200,
        options = {
            {
                value = "all",
                label = L["Options.BuffTracking.All"],
                desc = L["Options.BuffTracking.All.Desc"],
            },
            {
                value = "my_buffs",
                label = L["Options.BuffTracking.MyBuffs"],
                desc = L["Options.BuffTracking.MyBuffs.Desc"],
            },
            {
                value = "personal",
                label = L["Options.BuffTracking.OnlyMine"],
                desc = L["Options.BuffTracking.OnlyMine.Desc"],
            },
            {
                value = "smart",
                label = L["Options.BuffTracking.Smart"],
                desc = L["Options.BuffTracking.Smart.Desc"],
            },
        },
        get = function()
            return BR.Config.Get("buffTrackingMode", "all")
        end,
        tooltip = {
            title = L["Options.BuffTracking.Mode"],
            desc = L["Options.BuffTracking.Mode.Desc"],
        },
        onChange = function(val)
            BR.Config.Set("buffTrackingMode", val)
            UpdateDisplay()
        end,
    })
    setLayout:Add(trackingModeHolder, nil, COMPONENT_GAP)

    -- Custom Anchor Frames section
    LayoutSectionHeader(setLayout, settingsContent, L["Options.CustomAnchorFrames"])

    local customAnchorDesc = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customAnchorDesc:SetWidth(PANEL_WIDTH - COL_PADDING * 2)
    customAnchorDesc:SetJustifyH("LEFT")
    customAnchorDesc:SetText(L["Options.CustomAnchorFrames.Desc"])
    setLayout:AddText(customAnchorDesc, 22, COMPONENT_GAP)

    -- Input row: text input + add button (at top)
    local addAnchorRow = CreateFrame("Frame", nil, settingsContent)
    addAnchorRow:SetSize(PANEL_WIDTH - COL_PADDING * 2, 22)

    local addAnchorInput = Components.TextInput(addAnchorRow, {
        label = "",
        value = "",
        width = 180,
        labelWidth = 0,
    })
    addAnchorInput:SetPoint("LEFT", 0, 0)
    local addAnchorBox = addAnchorInput.editBox

    local addAnchorBtn -- forward declare for editbox callback

    local customAnchorList = CreateFrame("Frame", nil, settingsContent)
    customAnchorList:SetSize(PANEL_WIDTH - COL_PADDING * 2, 1)

    local customAnchorEntries = {} -- holder frames for removal

    local function RebuildCustomAnchorList()
        for _, entry in ipairs(customAnchorEntries) do
            entry:Hide()
            entry:SetParent(nil)
        end
        wipe(customAnchorEntries)

        local db = BR.profile
        local list = db.customAnchorFrames or {}
        local entryY = 0

        for i, name in ipairs(list) do
            local row = CreateFrame("Frame", nil, customAnchorList)
            row:SetSize(PANEL_WIDTH - COL_PADDING * 2, 20)
            row:SetPoint("TOPLEFT", 0, -entryY)

            local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            bullet:SetPoint("LEFT", 4, 0)
            bullet:SetText("-")

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", bullet, "RIGHT", 4, 0)
            text:SetText(name)

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("LEFT", text, "RIGHT", 6, 0)
            removeBtn:SetNormalFontObject("GameFontRedSmall")
            removeBtn:SetText("x")
            removeBtn:SetScript("OnClick", function()
                tremove(list, i)
                if #list == 0 then
                    db.customAnchorFrames = nil
                end
                RebuildCustomAnchorList()
            end)

            tinsert(customAnchorEntries, row)
            entryY = entryY + 22
        end

        customAnchorList:SetHeight(math.max(1, entryY))
    end

    addAnchorBtn = CreateButton(addAnchorRow, L["Options.Add"], function()
        local name = strtrim(addAnchorBox:GetText())
        if name == "" then
            return
        end
        local db = BR.profile
        if not db.customAnchorFrames then
            db.customAnchorFrames = {}
        end
        -- Avoid duplicates
        for _, existing in ipairs(db.customAnchorFrames) do
            if existing == name then
                addAnchorBox:SetText("")
                return
            end
        end
        tinsert(db.customAnchorFrames, name)
        addAnchorBox:SetText("")
        RebuildCustomAnchorList()
    end)
    addAnchorBtn:SetSize(50, 22)
    addAnchorBtn:SetPoint("LEFT", addAnchorInput, "RIGHT", 6, 0)

    addAnchorBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addAnchorBtn:Click()
    end)

    setLayout:Add(addAnchorRow, nil, COMPONENT_GAP)

    RebuildCustomAnchorList()
    setLayout:Add(customAnchorList, nil, COMPONENT_GAP)

    -- ========== SOUNDS TAB ==========
    local soundsContent = CreateFrame("Frame", nil, panel)
    soundsContent:SetPoint("TOPLEFT", 0, CONTENT_TOP)
    soundsContent:SetSize(PANEL_WIDTH, 500)
    soundsContent:Hide()
    contentContainers.sounds = soundsContent

    local SOUND_ROW_HEIGHT = 24
    local SOUND_ICON_SIZE = 20
    local soundRowPool = {} -- Reusable row frames to avoid frame leaks
    local soundRowCount = 0 -- Number of active rows in current render

    -- Build a lookup of all known buff keys to display names and icons.
    -- Static buff info is cached; custom buffs are merged on each call.
    local cachedStaticBuffInfo = nil
    local function GetAllBuffInfo()
        if not cachedStaticBuffInfo then
            cachedStaticBuffInfo = {}
            local seenGroups = {}
            local allBuffArrays = { RaidBuffs, PresenceBuffs, TargetedBuffs, SelfBuffs, PetBuffs, Consumables }
            for _, buffArray in ipairs(allBuffArrays) do
                for _, buff in ipairs(buffArray) do
                    if buff.groupId then
                        if not seenGroups[buff.groupId] then
                            seenGroups[buff.groupId] = true
                            local groupInfo = BuffGroups[buff.groupId]
                            local name = groupInfo and groupInfo.displayName or buff.name
                            cachedStaticBuffInfo[buff.groupId] = {
                                name = name,
                                spellID = buff.displaySpells or buff.spellID,
                            }
                        end
                    else
                        cachedStaticBuffInfo[buff.key] = {
                            name = buff.name,
                            spellID = buff.displaySpells or buff.spellID,
                        }
                    end
                end
            end
        end
        -- Merge custom buffs (may change between calls)
        local info = {}
        for k, v in pairs(cachedStaticBuffInfo) do
            info[k] = v
        end
        local db = BR.profile
        if db.customBuffs then
            for key, customBuff in pairs(db.customBuffs) do
                info[key] = {
                    name = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID)),
                    spellID = customBuff.spellID,
                }
            end
        end
        return info
    end

    -- Get or create a pooled row frame
    local function AcquireSoundRow(index)
        local row = soundRowPool[index]
        if not row then
            row = CreateFrame("Frame", nil, soundsContent)
            row:SetSize(PANEL_WIDTH - COL_PADDING * 2, SOUND_ROW_HEIGHT)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(SOUND_ICON_SIZE, SOUND_ICON_SIZE)
            row.icon:SetPoint("LEFT", 0, 0)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.soundText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.soundText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)
            -- Preview button
            row.previewBtn = CreateFrame("Button", nil, row)
            row.previewBtn:SetSize(14, 14)
            row.previewBtn:SetPoint("RIGHT", row, "RIGHT", -48, 0)
            row.previewTex = row.previewBtn:CreateTexture(nil, "ARTWORK")
            row.previewTex:SetAllPoints()
            row.previewTex:SetAtlas("chatframe-button-icon-voicechat")
            row.previewBtn:SetScript("OnEnter", function()
                row.previewTex:SetVertexColor(1, 1, 1, 1)
            end)
            row.previewBtn:SetScript("OnLeave", function()
                row.previewTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            end)
            -- Edit button
            row.editBtn = CreateFrame("Button", nil, row)
            row.editBtn:SetSize(14, 14)
            row.editBtn:SetPoint("RIGHT", row, "RIGHT", -24, 0)
            row.editTex = row.editBtn:CreateTexture(nil, "ARTWORK")
            row.editTex:SetAllPoints()
            row.editTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
            row.editBtn:SetScript("OnEnter", function()
                row.editTex:SetVertexColor(1, 1, 1, 1)
            end)
            row.editBtn:SetScript("OnLeave", function()
                row.editTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            end)
            -- Remove button
            row.removeBtn = CreateFrame("Button", nil, row)
            row.removeBtn:SetSize(14, 14)
            row.removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.removeTex = row.removeBtn:CreateTexture(nil, "ARTWORK")
            row.removeTex:SetAllPoints()
            row.removeTex:SetAtlas("common-icon-redx")
            row.removeBtn:SetScript("OnEnter", function()
                row.removeTex:SetVertexColor(1, 0.3, 0.3, 1)
            end)
            row.removeBtn:SetScript("OnLeave", function()
                row.removeTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            end)
            soundRowPool[index] = row
        end
        row.previewTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        row.editTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        row.removeTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        row:Show()
        return row
    end

    local function RenderSoundAlertRows()
        -- Hide all previously active rows
        for i = 1, soundRowCount do
            soundRowPool[i]:Hide()
        end
        soundRowCount = 0

        local db = BR.profile
        local buffSounds = db.buffSounds
        local allBuffInfo = GetAllBuffInfo()
        local y = -10

        if not buffSounds or not next(buffSounds) then
            -- Empty state
            if not soundsContent.emptyText then
                soundsContent.emptyText = soundsContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                soundsContent.emptyText:SetPoint("TOPLEFT", COL_PADDING, -10)
                soundsContent.emptyText:SetJustifyH("LEFT")
            end
            soundsContent.emptyText:SetText(L["Options.Sound.NoAlerts"])
            soundsContent.emptyText:Show()
            y = y - SOUND_ROW_HEIGHT
        else
            if soundsContent.emptyText then
                soundsContent.emptyText:Hide()
            end

            -- Sort keys alphabetically by buff name
            local sortedKeys = {}
            for key in pairs(buffSounds) do
                tinsert(sortedKeys, key)
            end
            tsort(sortedKeys, function(a, b)
                local infoA = allBuffInfo[a]
                local infoB = allBuffInfo[b]
                local nameA = infoA and infoA.name or a
                local nameB = infoB and infoB.name or b
                return nameA < nameB
            end)

            for _, key in ipairs(sortedKeys) do
                local soundName = buffSounds[key]
                local buffInfo = allBuffInfo[key]
                local displayName = buffInfo and buffInfo.name or key

                soundRowCount = soundRowCount + 1
                local row = AcquireSoundRow(soundRowCount)
                row:SetPoint("TOPLEFT", COL_PADDING, y)

                -- Update icon
                if buffInfo and buffInfo.spellID then
                    local texture = GetBuffTexture(buffInfo.spellID)
                    if texture then
                        row.icon:SetTexture(texture)
                        row.icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
                    else
                        row.icon:SetTexture(134400)
                        row.icon:SetTexCoord(0, 1, 0, 1)
                    end
                else
                    row.icon:SetTexture(134400)
                    row.icon:SetTexCoord(0, 1, 0, 1)
                end

                row.nameText:SetText(displayName)
                row.soundText:SetText("|cff888888" .. soundName .. "|r")

                row.previewBtn:SetScript("OnClick", function()
                    local soundFile = LSM:Fetch("sound", soundName)
                    if soundFile then
                        PlaySoundFile(soundFile, "Master")
                    end
                end)
                row.editBtn:SetScript("OnClick", function()
                    ShowSoundAlertModal(RenderSoundAlertRows, key, soundName, displayName)
                end)
                row.removeBtn:SetScript("OnClick", function()
                    SetBuffSound(key, nil)
                    RenderSoundAlertRows()
                end)

                y = y - SOUND_ROW_HEIGHT
            end
        end

        -- Add button (always at bottom)
        if not soundsContent.addBtn then
            soundsContent.addBtn = CreateButton(soundsContent, L["Options.Sound.AddAlert"], function()
                ShowSoundAlertModal(RenderSoundAlertRows)
            end)
            soundsContent.addBtn:SetSize(160, 22)
        end
        soundsContent.addBtn:SetPoint("TOPLEFT", COL_PADDING, y - 10)
    end

    -- Render initial state and refresh on tab show
    soundsContent:SetScript("OnShow", function()
        RenderSoundAlertRows()
    end)

    -- ========== PROFILES TAB ==========
    -- Use simple frame (not scrollable) to avoid nested scroll frame issues with edit boxes
    local profilesContent = CreateFrame("Frame", nil, panel)
    profilesContent:SetPoint("TOPLEFT", 0, CONTENT_TOP)
    profilesContent:SetSize(PANEL_WIDTH, 600)
    profilesContent:Hide()
    contentContainers.profiles = profilesContent

    local profX = COL_PADDING
    local profLayout = Components.VerticalLayout(profilesContent, { x = profX, y = -10 })
    local RefreshProfileDropdown -- forward declaration for closures

    -- Profile management section
    LayoutSectionHeader(profLayout, profilesContent, L["Options.ActiveProfile"])

    local profileDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    profileDesc:SetText(L["Options.ActiveProfile.Desc"])
    profLayout:AddText(profileDesc, 12, COMPONENT_GAP)

    local function GetProfileOptions()
        local names = BR.Profiles.ListProfiles()
        local options = {}
        for _, name in ipairs(names) do
            options[#options + 1] = { value = name, label = name }
        end
        return options
    end

    local function GetOtherProfileOptions()
        local names = BR.Profiles.ListProfiles()
        local active = BR.Profiles.GetActiveProfileName()
        local options = { { value = "", label = L["Options.SelectProfile"] } }
        for _, name in ipairs(names) do
            if name ~= active then
                options[#options + 1] = { value = name, label = name }
            end
        end
        return options
    end

    local PROF_LABEL_WIDTH = 70
    local PROF_DROPDOWN_WIDTH = 150

    -- Active profile row: dropdown + New / Reset buttons
    local profileRow = CreateFrame("Frame", nil, profilesContent)
    profileRow:SetSize(PANEL_WIDTH - COL_PADDING * 2, 26)

    local profileDropdown = Components.Dropdown(profileRow, {
        label = L["Options.Profile"],
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetProfileOptions(),
        get = function()
            return BR.Profiles.GetActiveProfileName()
        end,
        onChange = function(value)
            BR.Profiles.SwitchProfile(value)
            RefreshProfileDropdown()
            Components.RefreshAll()
        end,
    })
    profileDropdown:SetPoint("LEFT", 0, 0)

    local btnX = PROF_LABEL_WIDTH + PROF_DROPDOWN_WIDTH + 10

    local newProfileBtn = CreateButton(profileRow, L["Options.New"], function()
        StaticPopup_Show("BUFFREMINDERS_NEW_PROFILE")
    end)
    newProfileBtn:SetSize(50, 22)
    newProfileBtn:SetPoint("LEFT", btnX, 0)

    local resetProfileBtn = CreateButton(profileRow, L["Dialog.Reset"], function()
        StaticPopup_Show("BUFFREMINDERS_RESET_DEFAULTS")
    end)
    resetProfileBtn:SetSize(50, 22)
    resetProfileBtn:SetPoint("LEFT", btnX + 54, 0)

    profLayout:Add(profileRow, 26, COMPONENT_GAP)

    -- Copy From dropdown
    local copyDropdown = Components.Dropdown(profilesContent, {
        label = L["Options.CopyFrom"],
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetOtherProfileOptions(),
        get = function()
            return ""
        end,
        onChange = function(value)
            if value == "" then
                return
            end
            BR.Profiles.CopyProfile(value)
            Components.RefreshAll()
        end,
    })
    profLayout:Add(copyDropdown, 26, COMPONENT_GAP)

    -- Delete dropdown
    local deleteDropdown = Components.Dropdown(profilesContent, {
        label = L["Options.Delete"],
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetOtherProfileOptions(),
        get = function()
            return ""
        end,
        onChange = function(value)
            if value == "" then
                return
            end
            BR.Profiles.DeleteProfile(value)
            -- RefreshProfileDropdown called below (forward ref via closure)
            RefreshProfileDropdown()
        end,
    })
    profLayout:Add(deleteDropdown, 26, SECTION_GAP)

    -- Rebuild all profile dropdowns after CRUD (defined after all dropdowns exist)
    RefreshProfileDropdown = function()
        local opts = GetProfileOptions()
        local otherOpts = GetOtherProfileOptions()
        profileDropdown.dropdown:SetOptions(opts)
        profileDropdown:SetValue(BR.Profiles.GetActiveProfileName())
        copyDropdown.dropdown:SetOptions(otherOpts)
        copyDropdown:SetValue("")
        deleteDropdown.dropdown:SetOptions(otherOpts)
        deleteDropdown:SetValue("")
    end

    -- Per-spec profiles section (LibDualSpec)
    LayoutSectionHeader(profLayout, profilesContent, L["Options.PerSpecProfiles"])

    local specDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    specDesc:SetText(L["Options.PerSpecProfiles.Desc"])
    profLayout:AddText(specDesc, 12, COMPONENT_GAP)

    local specEnabled = Components.Checkbox(profilesContent, {
        label = L["Options.PerSpecProfiles.Enable"],
        get = function()
            return BR.Profiles.IsPerSpecEnabled()
        end,
        onChange = function(checked)
            BR.Profiles.SetPerSpecEnabled(checked)
            Components.RefreshAll()
        end,
    })
    profLayout:Add(specEnabled, 20, COMPONENT_GAP)

    -- Per-spec dropdowns
    local numSpecs = GetNumSpecializations() or 0
    local specDropdowns = {}
    for i = 1, numSpecs do
        local _, specName = GetSpecializationInfo(i)
        if specName then
            local specDropdown = Components.Dropdown(profilesContent, {
                label = specName,
                labelWidth = 100,
                width = 150,
                options = GetProfileOptions(),
                get = function()
                    return BR.Profiles.GetSpecProfile(i)
                end,
                enabled = function()
                    return BR.Profiles.IsPerSpecEnabled()
                end,
                onChange = function(value)
                    BR.Profiles.SetSpecProfile(i, value)
                end,
            })
            profLayout:Add(specDropdown, 26, COMPONENT_GAP)
            specDropdowns[i] = specDropdown
        end
    end

    -- Extend RefreshProfileDropdown to also update spec dropdowns
    local baseRefreshProfileDropdown = RefreshProfileDropdown
    RefreshProfileDropdown = function()
        baseRefreshProfileDropdown()
        local opts = GetProfileOptions()
        for _, sd in pairs(specDropdowns) do
            sd.dropdown:SetOptions(opts)
        end
    end

    -- Export so popup dialogs can call it
    BR.Options.RefreshProfileDropdown = function()
        RefreshProfileDropdown()
    end

    -- Export section
    LayoutSectionHeader(profLayout, profilesContent, L["Options.ExportSettings"])

    local exportDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    exportDesc:SetText(L["Options.ExportSettings.Desc"])
    profLayout:AddText(exportDesc, 12, COMPONENT_GAP)

    local exportTextArea = Components.TextArea(profilesContent, {
        width = PANEL_WIDTH - COL_PADDING * 2,
        height = 50,
    })
    profLayout:Add(exportTextArea, 50, COMPONENT_GAP)

    local exportButton = CreateButton(profilesContent, L["Options.Export"], function()
        local exportString, err = BuffReminders:Export()
        if exportString then
            exportTextArea:SetText(exportString)
            exportTextArea:HighlightText()
            exportTextArea:SetFocus()
        else
            exportTextArea:SetText(L["CustomBuff.Error"] .. " " .. (err or L["Options.FailedExport"]))
        end
    end)
    profLayout:Add(exportButton, 22, SECTION_GAP)

    -- Import section
    LayoutSectionHeader(profLayout, profilesContent, L["Options.ImportSettings"])

    local importDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    importDesc:SetText(
        L["Options.ImportSettings.DescPlain"] .. " |cffff6600" .. L["Options.ImportSettings.Overwrite"] .. "|r"
    )
    profLayout:AddText(importDesc, 12, COMPONENT_GAP)

    local importTextArea = Components.TextArea(profilesContent, {
        width = PANEL_WIDTH - COL_PADDING * 2,
        height = 50,
    })
    profLayout:Add(importTextArea, 50, COMPONENT_GAP)

    local importStatus = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importStatus:SetWidth(PANEL_WIDTH - COL_PADDING * 2 - 120)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetText("")

    local importButton = CreateButton(profilesContent, L["Options.Import"], function()
        local importString = importTextArea:GetText()
        local success, err = BuffReminders:Import(importString)
        if success then
            importStatus:SetText("|cff00ff00" .. L["Options.ImportSuccess"] .. "|r")
            StaticPopup_Show("BUFFREMINDERS_RELOAD_UI")
        else
            importStatus:SetText(
                "|cffff0000" .. L["CustomBuff.Error"] .. " " .. (err or L["Options.UnknownError"]) .. "|r"
            )
        end
    end)
    profLayout:Add(importButton, 22)
    importStatus:SetPoint("LEFT", importButton, "RIGHT", 10, 0)

    profilesContent:SetHeight(abs(profLayout:GetY()) + 50)

    -- ========== BOTTOM BUTTONS ==========
    local bottomFrame = CreateFrame("Frame", nil, panel)
    bottomFrame:SetPoint("BOTTOMLEFT", 0, 0)
    bottomFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomFrame:SetHeight(45)
    bottomFrame:SetFrameLevel(panel:GetFrameLevel() + 10)

    local separator = bottomFrame:CreateTexture(nil, "ARTWORK")
    separator:SetSize(PANEL_WIDTH - 40, 1)
    separator:SetPoint("TOP", 0, -5)
    separator:SetColorTexture(0.3, 0.3, 0.3, 1)

    local btnHolder = CreateFrame("Frame", nil, bottomFrame)
    btnHolder:SetPoint("TOP", separator, "BOTTOM", 0, -8)
    btnHolder:SetSize(1, 22)

    local BTN_WIDTH = 80

    local lockBtn = CreateButton(btnHolder, L["Options.Unlock"], function()
        BR.Display.ToggleLock()
        Components.RefreshAll()
    end, { title = L["Options.LockUnlock"], desc = L["Options.LockUnlock.Desc"] }, {
        border = { 0.7, 0.58, 0, 1 },
        borderHover = { 1, 0.82, 0, 1 },
        text = { 1, 0.82, 0, 1 },
    })
    lockBtn:SetSize(BTN_WIDTH, 22)
    lockBtn:SetPoint("RIGHT", btnHolder, "CENTER", -4, 0)

    function lockBtn:Refresh()
        self.text:SetText(BR.profile.locked and L["Options.Unlock"] or L["Options.Lock"])
    end
    lockBtn:Refresh()
    tinsert(BR.RefreshableComponents, lockBtn)

    local unlockBanner = Components.Banner(panel, {
        text = L["Options.AnchorHint"],
        color = "orange",
        icon = "services-icon-warning",
        bgAlpha = 0.95,
        visible = function()
            return not BR.profile.locked
        end,
    })
    unlockBanner:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, 0)
    unlockBanner:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local testBtn = CreateButton(btnHolder, L["Options.StopTest"], function(self)
        local isOn = ToggleTestMode()
        self.text:SetText(isOn and L["Options.StopTest"] or L["Options.Test"])
    end, {
        title = L["Options.TestAppearance"],
        desc = L["Options.TestAppearance.Desc"],
    })
    testBtn:SetText(L["Options.Test"])
    testBtn:SetSize(BTN_WIDTH, 22)
    testBtn:SetPoint("LEFT", btnHolder, "CENTER", 4, 0)
    panel.testBtn = testBtn

    -- Set initial active tab
    SetActiveTab("buffs")

    return panel
end

local function ShowOptions()
    if not optionsPanel then
        optionsPanel = CreateOptionsPanel()
    end
    if not optionsPanel:IsShown() then
        if optionsPanel.RenderCustomBuffRows then
            optionsPanel.RenderCustomBuffRows()
        end
        if BR.Display.IsTestMode() then
            optionsPanel.testBtn.text:SetText(L["Options.StopTest"])
        else
            optionsPanel.testBtn.text:SetText(L["Options.Test"])
        end
        optionsPanel:Show()
    end
end

local function HideOptions()
    if optionsPanel and optionsPanel:IsShown() then
        optionsPanel:Hide()
    end
end

local function ToggleOptions()
    if optionsPanel and optionsPanel:IsShown() then
        HideOptions()
    else
        ShowOptions()
    end
end

-- Advanced glow settings panel
local glowAdvancedPanel = nil

---@param targetCategory? string nil = global defaults, string = per-category override
---@param glowKind? "expiring"|"missing" Which glow style to edit (default "expiring")
ShowGlowAdvanced = function(targetCategory, glowKind)
    glowKind = glowKind or "expiring"
    local GlowType = Glow.Type

    if glowAdvancedPanel then
        glowAdvancedPanel:Hide()
        glowAdvancedPanel = nil
    end

    -- Key prefix: "glow" for expiring, "missingGlow" for missing
    local keyPrefix = glowKind == "missing" and "missingGlow" or "glow"
    ---@param suffix string e.g. "Type" → "glowType" or "missingGlowType"
    local function K(suffix)
        return keyPrefix .. suffix
    end

    local configPrefix = targetCategory and ("categorySettings." .. targetCategory .. ".") or "defaults."
    local function getSource()
        if targetCategory then
            return (BR.profile.categorySettings and BR.profile.categorySettings[targetCategory]) or {}
        else
            return BR.profile.defaults or {}
        end
    end

    local PANEL_W = 440
    local PANEL_H = 460
    local PREVIEW_SIZE = 64
    local MARGIN = 20

    local panel = CreatePanel("BuffRemindersGlowAdvanced", PANEL_W, PANEL_H, {
        strata = "FULLSCREEN",
        modal = true,
    })

    local titleBase = glowKind == "missing" and L["Options.GlowSettings.Missing"] or L["Options.GlowSettings.Expiring"]
    local titleText = targetCategory
            and (titleBase .. " — " .. targetCategory:sub(1, 1):upper() .. targetCategory:sub(2))
        or titleBase
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffffcc00" .. titleText .. "|r")

    local closeBtn = CreateButton(panel, "x", function()
        panel:Hide()
    end)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    -- Expiring / Missing tab toggle
    local expiringTab = Components.Tab(panel, { label = L["Options.GlowKind.Expiring"] })
    expiringTab:SetPoint("TOPLEFT", MARGIN, -32)
    expiringTab:SetActive(glowKind == "expiring")
    expiringTab:SetScript("OnClick", function()
        ShowGlowAdvanced(targetCategory, "expiring")
    end)

    local missingTab = Components.Tab(panel, { label = L["Options.GlowKind.Missing"] })
    missingTab:SetPoint("LEFT", expiringTab, "RIGHT", 4, 0)
    missingTab:SetActive(glowKind == "missing")
    missingTab:SetScript("OnClick", function()
        ShowGlowAdvanced(targetCategory, "missing")
    end)

    local previewKey = "BR_adv_preview"

    -- Content area
    local dynamicHolders = {}
    local staticLayout = Components.VerticalLayout(panel, { x = MARGIN, y = -56 })

    -- Enabled checkbox (per-kind enable/disable)
    local enableKey = glowKind == "missing" and "showMissingGlow" or "showExpirationGlow"
    local enableHolder = Components.Checkbox(panel, {
        label = L["Options.Glow.Enabled"],
        get = function()
            return getSource()[enableKey] ~= false
        end,
        onChange = function(checked)
            BR.Config.Set(configPrefix .. enableKey, checked)
            Components.RefreshAll()
        end,
    })
    staticLayout:Add(enableHolder, 24, 2)

    -- Type dropdown (always visible, top-left beside preview)
    local typeFallback = glowKind == "missing" and GlowType.Pixel or GlowType.AutoCast
    local typeOptions = {}
    for i, gt in ipairs(GlowTypes) do
        typeOptions[i] = { label = gt.name, value = i }
    end

    local typeHolder = Components.Dropdown(panel, {
        label = L["Options.Glow.Type"],
        labelWidth = 40,
        options = typeOptions,
        get = function()
            return getSource()[K("Type")] or typeFallback
        end,
        width = 140,
        onChange = function(val)
            BR.Config.Set(configPrefix .. K("Type"), val)
        end,
    }, "BuffRemindersGlowAdvTypeDropdown")
    staticLayout:Add(typeHolder, 30, 4)

    -- Separator
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", MARGIN, staticLayout:GetY())
    sep:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    staticLayout:Space(10)

    local DYNAMIC_START_Y = staticLayout:GetY()

    -- Preview icon (below separator, top-right)
    local previewFrame = CreateFrame("Frame", nil, panel)
    previewFrame:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(MARGIN + 20), DYNAMIC_START_Y)

    local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints()
    previewIcon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    previewIcon:SetTexture(GetBuffTexture(1459))

    local previewBorder = previewFrame:CreateTexture(nil, "BACKGROUND")
    previewBorder:SetPoint("TOPLEFT", -DEFAULT_BORDER_SIZE, DEFAULT_BORDER_SIZE)
    previewBorder:SetPoint("BOTTOMRIGHT", DEFAULT_BORDER_SIZE, -DEFAULT_BORDER_SIZE)
    previewBorder:SetColorTexture(0, 0, 0, 1)

    local function RefreshPreview()
        Glow.StopAll(previewFrame, previewKey)
        local d = getSource()
        local typeIdx = d[K("Type")] or typeFallback
        local color = d[K("Color")]
        if typeIdx == GlowType.Proc and not d[K("ProcUseCustomColor")] then
            color = nil
        end
        local size = d[K("Size")] or 2
        local params = Glow.BuildAdvancedParams(d, typeIdx, keyPrefix)
        local xOff = DEFAULT_BORDER_SIZE + (d[K("XOffset")] or 0)
        local yOff = DEFAULT_BORDER_SIZE + (d[K("YOffset")] or 0)
        Glow.Start(previewFrame, typeIdx, color, previewKey, size, xOff, yOff, params)
    end

    local SLIDER_SPACING = 24
    local dynamicLayout

    local function AddSlider(config)
        local holder = Components.Slider(panel, config)
        holder:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    local function AddCheckbox(config)
        local holder = Components.Checkbox(panel, config)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    -- Reset keys per glow type (type-specific only)
    local typeResetKeys = {
        [GlowType.Pixel] = { K("PixelLines"), K("PixelFrequency"), K("PixelLength") },
        [GlowType.AutoCast] = { K("AutocastScale"), K("AutocastParticles"), K("AutocastFrequency") },
        [GlowType.Border] = { K("BorderFrequency") },
        [GlowType.Proc] = { K("ProcDuration"), K("ProcStartAnim"), K("ProcUseCustomColor") },
    }

    local function UnregisterDynamicHolders()
        for _, h in ipairs(dynamicHolders) do
            h:Hide()
            for ri = #BR.RefreshableComponents, 1, -1 do
                if BR.RefreshableComponents[ri] == h then
                    table.remove(BR.RefreshableComponents, ri)
                end
            end
        end
    end

    local function BuildTypeContent()
        -- Hide and unregister old dynamic components
        UnregisterDynamicHolders()
        wipe(dynamicHolders)
        dynamicLayout = Components.VerticalLayout(panel, { x = MARGIN, y = DYNAMIC_START_Y })

        local d = getSource()
        local typeIdx = d[K("Type")] or typeFallback

        -- Size + Color row
        local sizeHolder
        if typeIdx == GlowType.Pixel or typeIdx == GlowType.Border then
            sizeHolder = Components.NumericStepper(panel, {
                label = L["Options.Glow.Size"],
                labelWidth = 34,
                min = 1,
                max = 10,
                step = 1,
                get = function()
                    return getSource()[K("Size")] or 2
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("Size"), val)
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, sizeHolder)
        end

        local colorSwatchHolder
        local procColorCheckbox
        if typeIdx == GlowType.Proc then
            -- Proc: optional custom color (desaturated + vertex color, less vibrant than default)
            procColorCheckbox = Components.Checkbox(panel, {
                label = L["Options.UseCustomColor"],
                tooltip = {
                    title = L["Options.UseCustomColor"],
                    desc = L["Options.UseCustomColor.Desc"],
                },
                get = function()
                    return getSource()[K("ProcUseCustomColor")] or false
                end,
                onChange = function(checked)
                    BR.Config.Set(configPrefix .. K("ProcUseCustomColor"), checked)
                    Components.RefreshAll()
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, procColorCheckbox)

            colorSwatchHolder = Components.ColorSwatch(panel, {
                hasOpacity = true,
                enabled = function()
                    return getSource()[K("ProcUseCustomColor")] or false
                end,
                get = function()
                    local c = getSource()[K("Color")] or Glow.DEFAULT_COLOR
                    return c[1], c[2], c[3], c[4] or 1
                end,
                onChange = function(r, g, b, a)
                    BR.Config.Set(configPrefix .. K("Color"), { r, g, b, a or 1 })
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, colorSwatchHolder)
        else
            colorSwatchHolder = Components.ColorSwatch(panel, {
                hasOpacity = true,
                get = function()
                    local c = getSource()[K("Color")] or Glow.DEFAULT_COLOR
                    return c[1], c[2], c[3], c[4] or 1
                end,
                onChange = function(r, g, b, a)
                    BR.Config.Set(configPrefix .. K("Color"), { r, g, b, a or 1 })
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, colorSwatchHolder)
        end

        if sizeHolder and colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(sizeHolder, 26)
            colorSwatchHolder:SetPoint("LEFT", sizeHolder, "RIGHT", 8, 0)
        elseif sizeHolder then
            dynamicLayout:Add(sizeHolder, 26)
        elseif colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(colorSwatchHolder, 26)
        end

        if procColorCheckbox then
            dynamicLayout:Add(procColorCheckbox, SLIDER_SPACING)
            colorSwatchHolder:SetPoint("LEFT", procColorCheckbox, "RIGHT", 8, 0)
        end

        -- Type-specific parameters
        if typeIdx == GlowType.Pixel then
            -- Pixel
            AddSlider({
                label = L["Options.Glow.Lines"],
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return getSource()[K("PixelLines")] or 8
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("PixelLines"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Frequency"],
                min = 0.01,
                max = 1,
                step = 0.01,
                get = function()
                    return getSource()[K("PixelFrequency")] or 0.25
                end,
                formatValue = function(val)
                    return string.format("%.2f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("PixelFrequency"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Length"],
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return getSource()[K("PixelLength")] or 10
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("PixelLength"), val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.AutoCast then
            -- AutoCast
            AddSlider({
                label = L["Options.Glow.Scale"],
                min = 1,
                max = 3,
                step = 0.1,
                get = function()
                    return getSource()[K("AutocastScale")] or 1
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("AutocastScale"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Particles"],
                min = 1,
                max = 8,
                step = 1,
                get = function()
                    return getSource()[K("AutocastParticles")] or 4
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("AutocastParticles"), val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = L["Options.Glow.Frequency"],
                min = 0.01,
                max = 1,
                step = 0.01,
                get = function()
                    return getSource()[K("AutocastFrequency")] or 0.125
                end,
                formatValue = function(val)
                    return string.format("%.2f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("AutocastFrequency"), val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.Border then
            -- Border
            AddSlider({
                label = L["Options.Glow.Speed"],
                min = 0.1,
                max = 2,
                step = 0.1,
                get = function()
                    return getSource()[K("BorderFrequency")] or 0.6
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("BorderFrequency"), val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.Proc then
            -- Proc
            AddSlider({
                label = L["Options.Glow.Duration"],
                min = 0.1,
                max = 3,
                step = 0.1,
                get = function()
                    return getSource()[K("ProcDuration")] or 1
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. K("ProcDuration"), val)
                    RefreshPreview()
                end,
            })
            AddCheckbox({
                label = L["Options.Glow.StartAnimation"],
                get = function()
                    return getSource()[K("ProcStartAnim")] or false
                end,
                onChange = function(checked)
                    BR.Config.Set(configPrefix .. K("ProcStartAnim"), checked)
                    RefreshPreview()
                end,
            })
        end

        -- Offsets
        AddSlider({
            label = L["Options.Glow.XOffset"],
            min = -10,
            max = 10,
            step = 1,
            get = function()
                return getSource()[K("XOffset")] or 0
            end,
            onChange = function(val)
                BR.Config.Set(configPrefix .. K("XOffset"), val)
                RefreshPreview()
            end,
        })
        AddSlider({
            label = L["Options.Glow.YOffset"],
            min = -10,
            max = 10,
            step = 1,
            get = function()
                return getSource()[K("YOffset")] or 0
            end,
            onChange = function(val)
                BR.Config.Set(configPrefix .. K("YOffset"), val)
                RefreshPreview()
            end,
        })

        -- Reset button (resets current type's params + shared keys)
        dynamicLayout:Space(8)
        local resetBtn = CreateButton(panel, L["Options.ResetToDefaults"], function()
            local keys = { K("Color"), K("Size"), K("XOffset"), K("YOffset") }
            local typeKeys = typeResetKeys[typeIdx]
            if typeKeys then
                for _, k in ipairs(typeKeys) do
                    keys[#keys + 1] = k
                end
            end
            for _, key in ipairs(keys) do
                BR.Config.Set(configPrefix .. key, nil)
            end
            BuildTypeContent()
            RefreshPreview()
            Components.RefreshAll()
        end)
        resetBtn:SetSize(140, 24)
        dynamicLayout:Add(resetBtn, 24)
        table.insert(dynamicHolders, resetBtn)

        -- Adjust panel height
        panel:SetHeight(math.abs(dynamicLayout:GetY()) + 46)

        RefreshPreview()
    end

    BuildTypeContent()

    -- Subscribe to glow type changes to rebuild type-specific content
    local function OnSettingChanged(_, path)
        if path == configPrefix .. K("Type") then
            BuildTypeContent()
        end
    end
    BR.CallbackRegistry:RegisterCallback("SettingChanged", OnSettingChanged, panel)

    panel:SetScript("OnHide", function()
        Glow.StopAll(previewFrame, previewKey)
        BR.CallbackRegistry:UnregisterCallback("SettingChanged", panel)
        UnregisterDynamicHolders()
    end)

    glowAdvancedPanel = panel
end

-- Delete confirmation dialog for custom buffs
StaticPopupDialogs["BUFFREMINDERS_DELETE_CUSTOM"] = {
    text = L["Dialog.DeleteCustomBuff"],
    button1 = L["Options.Delete"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function(_, data)
        if data and data.key then
            BR.profile.customBuffs[data.key] = nil
            BR.profile.enabledBuffs[data.key] = nil
            RemoveCustomBuffFrame(data.key)
            if data.refreshPanel then
                data.refreshPanel()
            end
            UpdateDisplay()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BUFFREMINDERS_RESET_DEFAULTS"] = {
    text = L["Dialog.ResetProfile"],
    button1 = L["Dialog.Reset"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function()
        BR.Profiles.ResetProfile()
        ReloadUI()
    end,
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BUFFREMINDERS_RELOAD_UI"] = {
    text = L["Dialog.ReloadPrompt"],
    button1 = L["Dialog.Reload"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateNewProfile(name)
    if name == "" then
        return
    end
    local copyFrom = BR.Profiles.GetActiveProfileName()
    BR.Profiles.BatchOperation(function()
        BR.aceDB:SetProfile(name)
        BR.aceDB:CopyProfile(copyFrom)
    end)
    if BR.Options.RefreshProfileDropdown then
        BR.Options.RefreshProfileDropdown()
    end
end

StaticPopupDialogs["BUFFREMINDERS_NEW_PROFILE"] = {
    text = L["Dialog.NewProfilePrompt"],
    button1 = L["Dialog.Create"],
    button2 = L["Dialog.Cancel"],
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        CreateNewProfile(self.EditBox:GetText():trim())
    end,
    EditBoxOnEnterPressed = function(self)
        CreateNewProfile(self:GetText():trim())
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BUFFREMINDERS_DISCORD_URL"] = {
    text = L["Dialog.DiscordPrompt"],
    button1 = L["Dialog.Close"],
    hasEditBox = true,
    editBoxWidth = 250,
    OnShow = function(self)
        self.EditBox:SetText("https://discord.gg/qezQ2hXJJ7")
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Custom buff add/edit modal dialog
ShowCustomBuffModal = function(existingKey, refreshPanelCallback)
    if customBuffModal then
        customBuffModal:Hide()
    end

    local MODAL_WIDTH = 460
    local BASE_HEIGHT = 636
    local ROW_HEIGHT = 26
    local CONTENT_LEFT = 20
    local ROWS_START_Y = -60
    local editingBuff = existingKey and BR.profile.customBuffs[existingKey] or nil
    local noop = function() end

    local existingSpellIDs = {}
    if editingBuff then
        if type(editingBuff.spellID) == "table" then
            for _, id in ipairs(editingBuff.spellID) do
                tinsert(existingSpellIDs, id)
            end
        else
            tinsert(existingSpellIDs, editingBuff.spellID)
        end
    end

    local modal = CreatePanel("BuffRemindersCustomBuffModal", MODAL_WIDTH, BASE_HEIGHT, {
        level = 200,
        modal = true,
    })

    local spellRows, nameBox, overlayBox
    local castSpellEditBox, castItemEditBox, macroEditBox, requireItemEditBox, requireItemModeDropdown

    modal:SetScript("OnHide", function()
        if spellRows then
            for _, rowData in ipairs(spellRows) do
                if rowData.editBox then
                    rowData.editBox:ClearFocus()
                end
            end
        end
        if nameBox then
            nameBox:ClearFocus()
        end
        if overlayBox then
            overlayBox:ClearFocus()
        end
        if castSpellEditBox then
            castSpellEditBox:ClearFocus()
        end
        if castItemEditBox then
            castItemEditBox:ClearFocus()
        end
        if macroEditBox then
            macroEditBox:ClearFocus()
        end
        if requireItemEditBox then
            requireItemEditBox:ClearFocus()
        end
    end)

    local modalTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modalTitle:SetPoint("TOP", 0, -12)
    modalTitle:SetText(editingBuff and L["CustomBuff.Edit"] or L["CustomBuff.Add"])

    local modalCloseBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    modalCloseBtn:SetSize(22, 22)
    modalCloseBtn:SetPoint("TOPRIGHT", -5, -5)

    local spellIdsLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellIdsLabel:SetPoint("TOPLEFT", CONTENT_LEFT, -40)
    spellIdsLabel:SetText(L["CustomBuff.SpellIDs"])

    spellRows = {}

    local addSpellBtn, sectionsFrame
    local showIconToggle
    local glowModeDropdown, requireSpellKnownToggle
    local classDropdownHolder
    local specDropdownHolder
    local actionTypeDropdown
    local actionInputHolder

    local function UpdateLayout()
        local rowCount = #spellRows

        for i, rowData in ipairs(spellRows) do
            rowData.frame:ClearAllPoints()
            rowData.frame:SetPoint("TOPLEFT", modal, "TOPLEFT", CONTENT_LEFT, ROWS_START_Y - ((i - 1) * ROW_HEIGHT))
            if rowCount > 1 then
                rowData.removeBtn:Show()
            else
                rowData.removeBtn:Hide()
            end
        end

        local addBtnY = ROWS_START_Y - (rowCount * ROW_HEIGHT) - 4
        addSpellBtn:ClearAllPoints()
        addSpellBtn:SetPoint("TOPLEFT", modal, "TOPLEFT", CONTENT_LEFT, addBtnY)

        sectionsFrame:ClearAllPoints()
        sectionsFrame:SetPoint("TOPLEFT", modal, "TOPLEFT", CONTENT_LEFT, addBtnY - 28)

        local extraRows = max(0, rowCount - 1)
        modal:SetHeight(BASE_HEIGHT + (extraRows * ROW_HEIGHT))
    end

    local function CreateSpellRow(initialSpellID)
        local rowFrame = CreateFrame("Frame", nil, modal)
        rowFrame:SetSize(MODAL_WIDTH - 40, ROW_HEIGHT - 2)

        local editBox = CreateFrame("EditBox", nil, rowFrame)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetAutoFocus(false)
        local editContainer = StyleEditBox(editBox)
        editContainer:SetSize(70, 20)
        editContainer:SetPoint("LEFT", 0, 0)
        if initialSpellID then
            editBox:SetText(tostring(initialSpellID))
        end

        local doLookup -- forward declare for onClick
        local lookupBtn = CreateButton(rowFrame, L["CustomBuff.Lookup"], function()
            doLookup()
        end)
        lookupBtn:SetSize(55, 20)
        lookupBtn:SetPoint("LEFT", editContainer, "RIGHT", 5, 0)

        local icon = CreateBuffIcon(rowFrame, 18)
        icon:SetPoint("LEFT", lookupBtn, "RIGHT", 8, 0)
        icon:Hide()

        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        nameText:SetPoint("RIGHT", rowFrame, "RIGHT", -28, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)

        local removeBtn = CreateButton(rowFrame, "-", nil)
        removeBtn:SetSize(22, 20)
        removeBtn:SetPoint("RIGHT", 0, 0)
        removeBtn:Hide()

        local rowData = {
            frame = rowFrame,
            editBox = editBox,
            icon = icon,
            nameText = nameText,
            removeBtn = removeBtn,
            validated = false,
            spellID = nil,
            spellName = nil,
        }

        removeBtn:SetScript("OnClick", function()
            for i, rd in ipairs(spellRows) do
                if rd == rowData then
                    rowData.frame:Hide()
                    tremove(spellRows, i)
                    UpdateLayout()
                    break
                end
            end
        end)

        doLookup = function()
            local spellID = tonumber(editBox:GetText())
            if not spellID then
                icon:Hide()
                nameText:SetText("|cffff4d4d" .. L["CustomBuff.InvalidID"] .. "|r")
                rowData.validated, rowData.spellID, rowData.spellName = false, nil, nil
                return
            end

            local valid, name, iconID = ValidateSpellID(spellID)
            if valid then
                icon:SetTexture(iconID)
                icon:Show()
                nameText:SetText(name or "")
                rowData.validated, rowData.spellID, rowData.spellName = true, spellID, name
            else
                icon:Hide()
                nameText:SetText("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r")
                rowData.validated, rowData.spellID, rowData.spellName = false, nil, nil
            end
        end

        tinsert(spellRows, rowData)

        if initialSpellID then
            doLookup()
        end

        return rowData
    end

    addSpellBtn = CreateButton(modal, L["CustomBuff.AddSpellID"], function()
        CreateSpellRow(nil)
        UpdateLayout()
    end)

    -- Sections frame (always visible, below add-spell button)
    sectionsFrame = CreateFrame("Frame", nil, modal)
    sectionsFrame:SetSize(MODAL_WIDTH - 40, 456)

    local secLayout = Components.VerticalLayout(sectionsFrame, { x = 0, y = 0 })

    local function LayoutSeparator()
        local line = sectionsFrame:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 0, secLayout:GetY())
        line:SetPoint("RIGHT", 0, 0)
        line:SetColorTexture(0.25, 0.25, 0.25, 0.8)
        secLayout:Space(1)
    end

    -- Appearance section
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.Appearance"])

    local nameHolder = Components.TextInput(sectionsFrame, {
        label = L["CustomBuff.Name"],
        value = editingBuff and editingBuff.name or "",
        width = 250,
        labelWidth = 50,
    })
    secLayout:Add(nameHolder, 20, COMPONENT_GAP)
    nameBox = nameHolder.editBox

    local overlayHolder = Components.TextInput(sectionsFrame, {
        label = L["CustomBuff.Text"],
        value = editingBuff and editingBuff.overlayText and editingBuff.overlayText:gsub("\n", "\\n") or "",
        width = 250,
        labelWidth = 50,
    })
    secLayout:Add(overlayHolder, 20, SECTION_GAP)
    overlayBox = overlayHolder.editBox

    local overlayHint = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    overlayHint:SetPoint("LEFT", overlayHolder, "RIGHT", 5, 0)
    overlayHint:SetText(L["CustomBuff.LineBreakHint"])

    -- Conditions section (merges restrictions, visibility, advanced)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.Conditions"])

    local classOptions = {
        { value = nil, label = L["Class.Any"] },
        { value = "DEATHKNIGHT", label = L["Class.DeathKnight"] },
        { value = "DEMONHUNTER", label = L["Class.DemonHunter"] },
        { value = "DRUID", label = L["Class.Druid"] },
        { value = "EVOKER", label = L["Class.Evoker"] },
        { value = "HUNTER", label = L["Class.Hunter"] },
        { value = "MAGE", label = L["Class.Mage"] },
        { value = "MONK", label = L["Class.Monk"] },
        { value = "PALADIN", label = L["Class.Paladin"] },
        { value = "PRIEST", label = L["Class.Priest"] },
        { value = "ROGUE", label = L["Class.Rogue"] },
        { value = "SHAMAN", label = L["Class.Shaman"] },
        { value = "WARLOCK", label = L["Class.Warlock"] },
        { value = "WARRIOR", label = L["Class.Warrior"] },
    }

    showIconToggle = Components.Toggle(sectionsFrame, {
        label = editingBuff and editingBuff.showWhenPresent and L["CustomBuff.WhenActive"]
            or L["CustomBuff.WhenMissing"],
        checked = editingBuff and editingBuff.showWhenPresent or false,
        onChange = function(isChecked)
            if isChecked then
                showIconToggle.label:SetText(L["CustomBuff.WhenActive"])
            else
                showIconToggle.label:SetText(L["CustomBuff.WhenMissing"])
            end
        end,
    })

    requireSpellKnownToggle = Components.Toggle(sectionsFrame, {
        label = L["CustomBuff.OnlyIfSpellKnown"],
        checked = editingBuff and editingBuff.requireSpellKnown or false,
        onChange = noop,
    })
    secLayout:AddRow({ { showIconToggle, 0 }, { requireSpellKnownToggle, 210 } }, COMPONENT_GAP)

    local classRowY = secLayout:GetY()

    local function CreateSpecDropdown(classToken, selectedSpecId)
        if specDropdownHolder then
            specDropdownHolder:Hide()
            specDropdownHolder = nil
        end
        if not classToken then
            return
        end
        local specOptions = BR.CLASS_SPEC_OPTIONS[classToken]
        if not specOptions then
            return
        end
        specDropdownHolder = Components.Dropdown(sectionsFrame, {
            label = L["CustomBuff.Spec"],
            options = specOptions,
            selected = selectedSpecId,
            width = 130,
            labelWidth = 70,
            onChange = noop,
        })
        specDropdownHolder:SetPoint("TOPLEFT", sectionsFrame, "TOPLEFT", 210, classRowY)
    end

    classDropdownHolder = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.Class"],
        options = classOptions,
        selected = editingBuff and editingBuff.class or nil,
        width = 130,
        labelWidth = 70,
        maxItems = 10,
        onChange = function(value)
            CreateSpecDropdown(value, nil)
        end,
    }, "BuffRemindersCustomClassDropdown")
    secLayout:Add(classDropdownHolder, nil, COMPONENT_GAP)

    -- Initialize spec dropdown for editing existing buff
    if editingBuff and editingBuff.class then
        CreateSpecDropdown(editingBuff.class, editingBuff.requireSpecId)
    end

    -- Require item (item gate)
    local requireItemLabel = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    requireItemLabel:SetText(L["CustomBuff.RequireItem"])
    requireItemLabel:SetWidth(70)
    requireItemLabel:SetJustifyH("LEFT")
    secLayout:AddText(requireItemLabel, 14, COMPONENT_GAP)

    requireItemEditBox = CreateFrame("EditBox", nil, sectionsFrame)
    requireItemEditBox:SetFontObject("GameFontHighlightSmall")
    requireItemEditBox:SetAutoFocus(false)
    local requireItemContainer = StyleEditBox(requireItemEditBox)
    requireItemContainer:SetSize(70, 20)
    requireItemContainer:SetPoint("LEFT", requireItemLabel, "RIGHT", 5, 0)
    if editingBuff and editingBuff.requireItemID then
        requireItemEditBox:SetText(tostring(editingBuff.requireItemID))
    end

    local requireItemModeOptions = {
        { value = "owned", label = L["CustomBuff.RequireItem.EquippedBags"] },
        { value = "equipped", label = L["CustomBuff.RequireItem.Equipped"] },
        { value = "bags", label = L["CustomBuff.RequireItem.InBags"] },
    }
    local currentRequireItemMode = editingBuff and editingBuff.requireItemMode or "owned"
    requireItemModeDropdown = Components.Dropdown(sectionsFrame, {
        label = "",
        labelWidth = 0,
        options = requireItemModeOptions,
        selected = currentRequireItemMode,
        width = 120,
        onChange = noop,
    })
    requireItemModeDropdown:SetPoint("LEFT", requireItemContainer, "RIGHT", 5, 0)

    local requireItemHint = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    requireItemHint:SetPoint("LEFT", requireItemModeDropdown, "RIGHT", 5, 0)
    requireItemHint:SetText(L["CustomBuff.RequireItem.Hint"])

    local glowModeOptions = {
        { value = "whenGlowing", label = L["CustomBuff.BarGlow.WhenGlowing"] },
        { value = "whenNotGlowing", label = L["CustomBuff.BarGlow.WhenNotGlowing"] },
        { value = "disabled", label = L["CustomBuff.BarGlow.Disabled"] },
    }
    local currentGlowMode = editingBuff and editingBuff.glowMode or "disabled"
    glowModeDropdown = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.BarGlow"],
        options = glowModeOptions,
        selected = currentGlowMode,
        width = 175,
        tooltip = {
            title = L["CustomBuff.BarGlow.Title"],
            desc = L["CustomBuff.BarGlow.Desc"],
        },
        onChange = noop,
    })
    secLayout:Add(glowModeDropdown, nil, COMPONENT_GAP)

    -- Load conditions section (per-buff content visibility)
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.ShowIn"])

    -- Local state for load conditions (read on save)
    local loadConditions = {}
    if editingBuff and editingBuff.loadConditions then
        for k, v in pairs(editingBuff.loadConditions) do
            if type(v) == "table" then
                loadConditions[k] = {}
                for dk, dv in pairs(v) do
                    loadConditions[k][dk] = dv
                end
            else
                loadConditions[k] = v
            end
        end
    elseif not editingBuff then
        -- New buff defaults: housing off (matches old category-level default)
        loadConditions.housing = false
    end

    -- Reuse VisibilityToggles with a table-backed store instead of DB-backed
    local visToggles = Components.VisibilityToggles(sectionsFrame, {
        store = {
            getContent = function(key)
                return loadConditions[key] ~= false
            end,
            setContent = function(key)
                if loadConditions[key] ~= false then
                    loadConditions[key] = false
                else
                    loadConditions[key] = nil
                end
            end,
            getDiffTable = function(dbKey)
                return loadConditions[dbKey]
            end,
            ensureDiffTable = function(dbKey)
                if not loadConditions[dbKey] then
                    loadConditions[dbKey] = {}
                end
                return loadConditions[dbKey]
            end,
        },
        noAutoRefresh = true,
        onChange = noop,
    })
    secLayout:Add(visToggles, nil, COMPONENT_GAP)

    -- Ready check toggle
    local lcReadyCheckToggle = Components.Toggle(sectionsFrame, {
        label = L["CustomBuff.ReadyCheckOnly"],
        checked = editingBuff and editingBuff.loadConditions and editingBuff.loadConditions.readyCheckOnly or false,
        onChange = function(isChecked)
            loadConditions.readyCheckOnly = isChecked or nil
        end,
    })
    secLayout:Add(lcReadyCheckToggle, nil, COMPONENT_GAP)

    -- Level filter dropdown
    local levelFilterHolder = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.Level"],
        labelWidth = 70,
        width = 150,
        options = {
            { value = "any", label = L["CustomBuff.Level.Any"] },
            { value = "maxLevel", label = L["CustomBuff.Level.Max"] },
            { value = "belowMaxLevel", label = L["CustomBuff.Level.BelowMax"] },
        },
        get = function()
            local lf = loadConditions.levelFilter
            return lf or "any"
        end,
        onChange = function(val)
            loadConditions.levelFilter = (val ~= "any") and val or nil
        end,
    })
    secLayout:Add(levelFilterHolder, nil, COMPONENT_GAP)

    -- Click action section
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.ClickAction"])

    -- Determine existing action type
    local existingActionType = "none"
    if editingBuff then
        if editingBuff.castMacro and editingBuff.castMacro ~= "" then
            existingActionType = "macro"
        elseif editingBuff.castItemID then
            existingActionType = "item"
        elseif editingBuff.castSpellID then
            existingActionType = "spell"
        end
    end

    -- Container for the conditional input (spell/item Lookup or macro text)
    actionInputHolder = CreateFrame("Frame", nil, sectionsFrame)
    actionInputHolder:SetSize(MODAL_WIDTH - 40, 26)

    -- Spell ID input with Lookup
    castSpellEditBox = CreateFrame("EditBox", nil, actionInputHolder)
    castSpellEditBox:SetFontObject("GameFontHighlightSmall")
    castSpellEditBox:SetAutoFocus(false)
    local castSpellContainer = StyleEditBox(castSpellEditBox)
    castSpellContainer:SetSize(70, 20)
    castSpellContainer:SetPoint("LEFT", 0, 0)
    if editingBuff and editingBuff.castSpellID then
        castSpellEditBox:SetText(tostring(editingBuff.castSpellID))
    end

    local castSpellIcon = CreateBuffIcon(actionInputHolder, 18)
    castSpellIcon:SetPoint("LEFT", castSpellContainer, "RIGHT", 68, 0)
    castSpellIcon:Hide()

    local castSpellName = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castSpellName:SetPoint("LEFT", castSpellIcon, "RIGHT", 5, 0)
    castSpellName:SetPoint("RIGHT", actionInputHolder, "RIGHT", 0, 0)
    castSpellName:SetJustifyH("LEFT")
    castSpellName:SetWordWrap(false)

    local castSpellLookupBtn = CreateButton(actionInputHolder, L["CustomBuff.Lookup"], function()
        local id = tonumber(castSpellEditBox:GetText())
        if not id then
            castSpellIcon:Hide()
            castSpellName:SetText("|cffff4d4d" .. L["CustomBuff.InvalidID"] .. "|r")
            return
        end
        local valid, name, iconID = ValidateSpellID(id)
        if valid then
            castSpellIcon:SetTexture(iconID)
            castSpellIcon:Show()
            castSpellName:SetText(name or "")
        else
            castSpellIcon:Hide()
            castSpellName:SetText("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r")
        end
    end)
    castSpellLookupBtn:SetSize(55, 20)
    castSpellLookupBtn:SetPoint("LEFT", castSpellContainer, "RIGHT", 5, 0)

    -- Item ID input with Lookup
    castItemEditBox = CreateFrame("EditBox", nil, actionInputHolder)
    castItemEditBox:SetFontObject("GameFontHighlightSmall")
    castItemEditBox:SetAutoFocus(false)
    local castItemContainer = StyleEditBox(castItemEditBox)
    castItemContainer:SetSize(70, 20)
    castItemContainer:SetPoint("LEFT", 0, 0)
    if editingBuff and editingBuff.castItemID then
        castItemEditBox:SetText(tostring(editingBuff.castItemID))
    end

    local castItemIcon = CreateBuffIcon(actionInputHolder, 18)
    castItemIcon:SetPoint("LEFT", castItemContainer, "RIGHT", 68, 0)
    castItemIcon:Hide()

    local castItemName = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castItemName:SetPoint("LEFT", castItemIcon, "RIGHT", 5, 0)
    castItemName:SetPoint("RIGHT", actionInputHolder, "RIGHT", 0, 0)
    castItemName:SetJustifyH("LEFT")
    castItemName:SetWordWrap(false)

    local castItemLookupBtn = CreateButton(actionInputHolder, L["CustomBuff.Lookup"], function()
        local id = tonumber(castItemEditBox:GetText())
        if not id then
            castItemIcon:Hide()
            castItemName:SetText("|cffff4d4d" .. L["CustomBuff.InvalidID"] .. "|r")
            return
        end
        local valid, name, iconID = ValidateItemID(id)
        if valid then
            castItemIcon:SetTexture(iconID)
            castItemIcon:Show()
            castItemName:SetText(name or "")
        else
            castItemIcon:Hide()
            castItemName:SetText("|cffff4d4d" .. L["CustomBuff.NotFoundRetry"] .. "|r")
            -- Request item data load for next lookup attempt
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end)
    castItemLookupBtn:SetSize(55, 20)
    castItemLookupBtn:SetPoint("LEFT", castItemContainer, "RIGHT", 5, 0)

    -- Macro text input
    local macroHolder = Components.TextInput(actionInputHolder, {
        label = "",
        value = editingBuff and editingBuff.castMacro or "",
        width = MODAL_WIDTH - 80,
        labelWidth = 0,
    })
    macroHolder:SetPoint("LEFT", 0, 0)
    macroEditBox = macroHolder.editBox

    local macroHint = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    macroHint:SetPoint("TOPLEFT", 0, -24)
    macroHint:SetText(L["CustomBuff.Action.MacroHint"])

    -- Show/hide inputs based on action type
    local function UpdateActionInputVisibility(actionType)
        -- Hide all first
        castSpellContainer:Hide()
        castSpellLookupBtn:Hide()
        castSpellIcon:Hide()
        castSpellName:SetText("")
        castItemContainer:Hide()
        castItemLookupBtn:Hide()
        castItemIcon:Hide()
        castItemName:SetText("")
        macroHolder:Hide()
        macroHint:Hide()

        if actionType == "spell" then
            castSpellContainer:Show()
            castSpellLookupBtn:Show()
            -- Trigger lookup if there's a value
            if castSpellEditBox:GetText() ~= "" then
                local id = tonumber(castSpellEditBox:GetText())
                if id then
                    local valid, name, iconID = ValidateSpellID(id)
                    if valid then
                        castSpellIcon:SetTexture(iconID)
                        castSpellIcon:Show()
                        castSpellName:SetText(name or "")
                    end
                end
            end
        elseif actionType == "item" then
            castItemContainer:Show()
            castItemLookupBtn:Show()
            -- Trigger lookup if there's a value
            if castItemEditBox:GetText() ~= "" then
                local id = tonumber(castItemEditBox:GetText())
                if id then
                    local valid, name, iconID = ValidateItemID(id)
                    if valid then
                        castItemIcon:SetTexture(iconID)
                        castItemIcon:Show()
                        castItemName:SetText(name or "")
                    end
                end
            end
        elseif actionType == "macro" then
            macroHolder:Show()
            macroHint:Show()
        end
    end

    local actionTypeOptions = {
        { value = "none", label = L["CustomBuff.Action.None"] },
        { value = "spell", label = L["CustomBuff.Action.Spell"] },
        { value = "item", label = L["CustomBuff.Action.Item"] },
        { value = "macro", label = L["CustomBuff.Action.Macro"] },
    }
    actionTypeDropdown = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.Action.OnClick"],
        options = actionTypeOptions,
        selected = existingActionType,
        width = 120,
        tooltip = {
            title = L["CustomBuff.Action.Title"],
            desc = L["CustomBuff.Action.Desc"],
        },
        onChange = function(value)
            UpdateActionInputVisibility(value)
        end,
    })
    secLayout:Add(actionTypeDropdown, nil, COMPONENT_GAP)
    secLayout:Add(actionInputHolder, 26)

    -- Initialize visibility for the current action type
    UpdateActionInputVisibility(existingActionType)

    local saveError = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    saveError:SetPoint("BOTTOMLEFT", 20, 42)
    saveError:SetWidth(MODAL_WIDTH - 120)
    saveError:SetJustifyH("LEFT")
    saveError:SetTextColor(1, 0.3, 0.3)

    local cancelBtn = CreateButton(modal, L["Dialog.Cancel"], function()
        modal:Hide()
    end)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 15)

    -- Delete button (only when editing existing buff)
    if existingKey and editingBuff then
        local buffName = editingBuff.name or existingKey
        local deleteBtn = CreateButton(modal, L["Options.Delete"], function()
            modal:Hide()
            StaticPopup_Show("BUFFREMINDERS_DELETE_CUSTOM", buffName, nil, {
                key = existingKey,
                refreshPanel = refreshPanelCallback,
            })
        end)
        deleteBtn:SetPoint("BOTTOMLEFT", 20, 15)
    end

    local saveBtn = CreateButton(modal, L["CustomBuff.Save"], function()
        local validatedIDs = {}
        local firstName = nil
        for _, rowData in ipairs(spellRows) do
            if rowData.validated and rowData.spellID then
                tinsert(validatedIDs, rowData.spellID)
                if not firstName then
                    firstName = rowData.spellName
                end
            end
        end

        if #validatedIDs == 0 then
            saveError:SetText(L["CustomBuff.ValidateError"])
            return
        end
        saveError:SetText("")

        local spellIDValue = #validatedIDs == 1 and validatedIDs[1] or validatedIDs
        local key = existingKey or GenerateCustomBuffKey(spellIDValue)
        local displayName = nameBox:GetText()
        if displayName == "" then
            displayName = firstName or (L["CustomBuff.Action.Spell"] .. " " .. validatedIDs[1])
        end

        local overlayTextValue = strtrim(overlayBox:GetText())
        if overlayTextValue ~= "" then
            overlayTextValue = overlayTextValue:gsub("\\n", "\n")
        else
            overlayTextValue = nil
        end

        -- Resolve click action fields based on selected action type
        local selectedAction = actionTypeDropdown:GetValue()
        local castSpellIDValue = nil
        local castItemIDValue = nil
        local castMacroValue = nil
        if selectedAction == "spell" then
            castSpellIDValue = tonumber(strtrim(castSpellEditBox:GetText())) or nil
        elseif selectedAction == "item" then
            castItemIDValue = tonumber(strtrim(castItemEditBox:GetText())) or nil
        elseif selectedAction == "macro" then
            local macroText = strtrim(macroEditBox:GetText())
            if macroText ~= "" then
                castMacroValue = macroText
            end
        end

        -- Only persist loadConditions if any value differs from default (all-enabled)
        -- Clean up difficulty sub-tables where all entries are enabled (true/nil)
        for _, diffKey in ipairs({ "dungeonDifficulty", "raidDifficulty" }) do
            local dt = loadConditions[diffKey]
            if dt then
                local anyOff = false
                for _, v in pairs(dt) do
                    if v == false then
                        anyOff = true
                        break
                    end
                end
                if not anyOff then
                    loadConditions[diffKey] = nil
                end
            end
        end

        local savedLoadConditions = nil
        local function hasNonDefault(t)
            for _, v in pairs(t) do
                if type(v) == "table" then
                    if hasNonDefault(v) then
                        return true
                    end
                else
                    return true
                end
            end
            return false
        end
        if hasNonDefault(loadConditions) then
            savedLoadConditions = loadConditions
        end

        local customBuff = {
            spellID = spellIDValue,
            key = key,
            name = displayName,
            overlayText = overlayTextValue,
            class = classDropdownHolder:GetValue(),
            requireSpecId = specDropdownHolder and specDropdownHolder:GetValue() or nil,
            showWhenPresent = showIconToggle:GetChecked() or nil,
            requireSpellKnown = requireSpellKnownToggle:GetChecked() or nil,
            glowMode = glowModeDropdown:GetValue() ~= "disabled" and glowModeDropdown:GetValue() or nil,
            castSpellID = castSpellIDValue,
            castItemID = castItemIDValue,
            castMacro = castMacroValue,
            requireItemID = tonumber(strtrim(requireItemEditBox:GetText())) or nil,
            requireItemMode = requireItemModeDropdown:GetValue() ~= "owned" and requireItemModeDropdown:GetValue()
                or nil,
            loadConditions = savedLoadConditions,
        }

        BR.profile.customBuffs[key] = customBuff

        if not existingKey then
            CreateCustomBuffFrameRuntime(customBuff)
        else
            UpdateCustomBuffFrame(key, spellIDValue, displayName)
        end

        modal:Hide()
        -- requireItemMode may have changed; clear cached item ownership so the new mode is evaluated
        BR.BuffState.InvalidateItemCache()
        if refreshPanelCallback then
            refreshPanelCallback()
        end
        UpdateDisplay()
    end)
    saveBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)

    if #existingSpellIDs > 0 then
        for _, spellID in ipairs(existingSpellIDs) do
            CreateSpellRow(spellID)
        end
    else
        CreateSpellRow(nil)
    end

    UpdateLayout()

    customBuffModal = modal
    modal:Show()
end

-- ============================================================================
-- BUFF SETTINGS MODALS (gear icon popups)
-- ============================================================================

-- ---- DK Runeforge ----

local runeforgeModal = nil

-- Resolve rune icon textures once (cached across modal opens)
local cachedRuneIcons = nil
local function GetRuneIcons()
    if cachedRuneIcons then
        return cachedRuneIcons
    end
    cachedRuneIcons = {}
    for _, rune in ipairs(BR.DK_RUNEFORGES) do
        local texture = C_Spell.GetSpellTexture(rune.spellID)
        cachedRuneIcons[rune.enchantID] = texture and { texture } or nil
    end
    return cachedRuneIcons
end

ShowRuneforgeModal = function()
    if runeforgeModal then
        Components.RefreshAll()
        runeforgeModal:Show()
        return
    end

    local MODAL_WIDTH = 560
    local MODAL_HEIGHT = 280
    local MARGIN = 16
    local CHECKBOX_HEIGHT = 22
    local CHECKBOX_GAP = 3
    local RUNE_LABEL_FONT = "GameFontHighlight"

    local modal = CreatePanel("BuffRemindersRuneforgeModal", MODAL_WIDTH, MODAL_HEIGHT, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.RuneforgePreferences"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local runeIcons = GetRuneIcons()

    local function EnsureSpecPrefs(specId)
        local db = BR.profile
        if not db.dkRunePreferences then
            db.dkRunePreferences = {}
        end
        if not db.dkRunePreferences[specId] then
            db.dkRunePreferences[specId] = {}
        end
        return db.dkRunePreferences[specId]
    end

    -- Helper: create rune checkboxes for a slot
    local function CreateRuneCheckboxes(parent, specId, slot, x, startY, maxLabelWidth)
        local y = startY
        for _, rune in ipairs(BR.DK_RUNEFORGES) do
            local enchantID = rune.enchantID
            local runeName = BR.GetSpellName(rune.spellID) or rune.key
            local runeHolder = Components.Checkbox(parent, {
                label = runeName,
                labelFont = RUNE_LABEL_FONT,
                icons = runeIcons[enchantID],
                get = function()
                    local prefs = EnsureSpecPrefs(specId)
                    return prefs[slot] and prefs[slot][enchantID] or false
                end,
                onChange = function(checked)
                    local prefs = EnsureSpecPrefs(specId)
                    if not prefs[slot] then
                        prefs[slot] = {}
                    end
                    prefs[slot][enchantID] = checked or nil
                    BR.BuffState.Refresh()
                    UpdateDisplay()
                end,
            })
            if maxLabelWidth and runeHolder.label then
                runeHolder.label:SetWidth(maxLabelWidth)
                runeHolder.label:SetWordWrap(false)
            end
            runeHolder:SetPoint("TOPLEFT", x, y)
            y = y - (CHECKBOX_HEIGHT + CHECKBOX_GAP)
        end
        return y
    end

    -- 4 top-level tabs: Blood, Frost 2H, Frost DW, Unholy
    local _, bloodName = GetSpecializationInfoByID(250)
    local _, frostName = GetSpecializationInfoByID(251)
    local _, unholyName = GetSpecializationInfoByID(252)

    local DK_TABS = {
        { key = "blood", specId = 250, label = bloodName or "Blood" },
        { key = "frost2h", specId = 251, label = (frostName or "Frost") .. " " .. L["Options.RuneTwoHanded"] },
        { key = "frostdw", specId = 251, label = (frostName or "Frost") .. " " .. L["Options.RuneDualWield"] },
        { key = "unholy", specId = 252, label = unholyName or "Unholy" },
    }

    local tabButtons = {}
    local tabContents = {}

    local function SetActiveTab(activeKey)
        for key, tab in pairs(tabButtons) do
            tab:SetActive(key == activeKey)
        end
        for key, content in pairs(tabContents) do
            if key == activeKey then
                content:Show()
            else
                content:Hide()
            end
        end
    end

    -- Build tab buttons (evenly distributed across modal width)
    local tabGap = 2
    local totalTabWidth = MODAL_WIDTH - MARGIN * 2
    local numTabs = #DK_TABS
    local tabWidth = (totalTabWidth - (numTabs - 1) * tabGap) / numTabs

    local prevTab = nil
    for _, tabDef in ipairs(DK_TABS) do
        local tab = Components.Tab(modal, { label = tabDef.label, width = tabWidth })
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", tabGap, 0)
        else
            tab:SetPoint("TOPLEFT", MARGIN, -36)
        end
        local key = tabDef.key
        tab:SetScript("OnClick", function()
            SetActiveTab(key)
        end)
        tabButtons[key] = tab
        prevTab = tab
    end

    local contentWidth = MODAL_WIDTH - MARGIN * 2

    -- Build tab content
    for _, tabDef in ipairs(DK_TABS) do
        local content = CreateFrame("Frame", nil, modal)
        content:SetPoint("TOPLEFT", MARGIN, -60)
        content:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN)
        content:Hide()
        tabContents[tabDef.key] = content

        local y = -6

        if tabDef.key == "frostdw" then
            -- Frost DW: two columns (MH | OH)
            local colWidth = contentWidth / 2

            local mhLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            mhLabel:SetPoint("TOPLEFT", 0, y)
            mhLabel:SetText("|cffffcc00" .. L["Options.RuneMainHand"] .. "|r")

            local ohLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ohLabel:SetPoint("TOPLEFT", colWidth, y)
            ohLabel:SetText("|cffffcc00" .. L["Options.RuneOffHand"] .. "|r")

            local dwLabelWidth = colWidth - 46
            CreateRuneCheckboxes(content, tabDef.specId, "dw_mainhand", 6, y - 16, dwLabelWidth)
            CreateRuneCheckboxes(content, tabDef.specId, "dw_offhand", colWidth + 6, y - 16, dwLabelWidth)
        else
            -- Blood / Frost 2H / Unholy: single column
            CreateRuneCheckboxes(content, tabDef.specId, "mainhand", 6, y)
        end
    end

    SetActiveTab("blood")

    runeforgeModal = modal
    modal:Show()
end

-- ---- Healthstone ----

local healthstoneModal = nil

ShowHealthstoneModal = function()
    if healthstoneModal then
        Components.RefreshAll()
        healthstoneModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersHealthstoneModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.HealthstoneSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local visHolder = Components.Dropdown(modal, {
        label = L["Options.Visibility"],
        width = 200,
        get = function()
            return BR.Config.Get("defaults.healthstoneVisibility", "readyCheck")
        end,
        options = {
            {
                value = "readyCheck",
                label = L["Options.Healthstone.ReadyCheckOnly"],
                desc = L["Options.Healthstone.ReadyCheckDesc"],
            },
            {
                value = "casterOnly",
                label = L["Options.Healthstone.ReadyCheckWarlock"],
                desc = L["Options.Healthstone.WarlockAlwaysDesc"],
            },
            {
                value = "always",
                label = L["Options.Healthstone.AlwaysShow"],
                desc = L["Options.Healthstone.AlwaysDesc"],
            },
        },
        tooltip = { title = L["Options.Healthstone.Visibility"], desc = L["Options.Healthstone.Visibility.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.healthstoneVisibility", val)
        end,
    })
    layout:Add(visHolder, nil, COMPONENT_GAP)

    local lowStockHolder = Components.Checkbox(modal, {
        label = L["Options.Healthstone.LowStock"],
        get = function()
            return BR.Config.Get("defaults.healthstoneLowStock", false)
        end,
        tooltip = {
            title = L["Options.Healthstone.LowStock"],
            desc = L["Options.Healthstone.LowStock.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.healthstoneLowStock", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(lowStockHolder, nil, COMPONENT_GAP)

    local thresholdHolder = Components.Slider(modal, {
        label = L["Options.Healthstone.Threshold"],
        min = 1,
        max = 2,
        step = 1,
        get = function()
            return BR.Config.Get("defaults.healthstoneThreshold", 1)
        end,
        enabled = function()
            return BR.Config.Get("defaults.healthstoneLowStock", false)
        end,
        tooltip = { title = L["Options.Healthstone.Threshold"], desc = L["Options.Healthstone.Threshold.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.healthstoneThreshold", val)
        end,
    })
    layout:Add(thresholdHolder, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    healthstoneModal = modal
    modal:Show()
end

-- ---- Soulstone ----

local soulstoneModal = nil

ShowSoulstoneModal = function()
    if soulstoneModal then
        Components.RefreshAll()
        soulstoneModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersSoulstoneModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.SoulstoneSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local visHolder = Components.Dropdown(modal, {
        label = L["Options.Visibility"],
        width = 200,
        get = function()
            return BR.Config.Get("defaults.soulstoneVisibility", "readyCheck")
        end,
        options = {
            {
                value = "readyCheck",
                label = L["Options.Soulstone.ReadyCheckOnly"],
                desc = L["Options.Soulstone.ReadyCheckDesc"],
            },
            {
                value = "casterOnly",
                label = L["Options.Soulstone.ReadyCheckWarlock"],
                desc = L["Options.Soulstone.WarlockAlwaysDesc"],
            },
            { value = "always", label = L["Options.Soulstone.AlwaysShow"], desc = L["Options.Soulstone.AlwaysDesc"] },
        },
        tooltip = { title = L["Options.Soulstone.Visibility"], desc = L["Options.Soulstone.Visibility.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.soulstoneVisibility", val)
        end,
    })
    layout:Add(visHolder, nil, COMPONENT_GAP)

    local cdHolder = Components.Checkbox(modal, {
        label = L["Options.Soulstone.HideCooldown"],
        get = function()
            return BR.Config.Get("defaults.soulstoneHideCooldown", false)
        end,
        tooltip = {
            title = L["Options.Soulstone.HideCooldown"],
            desc = L["Options.Soulstone.HideCooldown.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.soulstoneHideCooldown", checked)
        end,
    })
    layout:Add(cdHolder, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    soulstoneModal = modal
    modal:Show()
end

-- ---- Chat Request Messages ----

local chatRequestModal = nil

-- Ordered list of buff keys that support chat requests, with display labels and icon spellIDs.
local chatRequestBuffKeys = {
    { key = "intellect", label = L["Buff.ArcaneIntellect"], spellID = 1459 },
    { key = "attackPower", label = L["Buff.BattleShout"], spellID = 6673 },
    { key = "stamina", label = L["Buff.PowerWordFortitude"], spellID = 21562 },
    { key = "versatility", label = L["Buff.MarkOfTheWild"], spellID = 1126 },
    { key = "skyfury", label = L["Buff.Skyfury"], spellID = 462854 },
    { key = "bronze", label = L["Buff.BlessingOfTheBronze"], spellID = 364342 },
    { key = "devotionAura", label = L["Buff.DevotionAura"], spellID = 465 },
    { key = "atrophicNumbingPoison", label = L["Buff.AtrophicNumbingPoison"], spellID = 381637 },
    { key = "soulstone", label = L["Buff.Soulstone"], spellID = 20707 },
}

ShowChatRequestModal = function()
    if chatRequestModal then
        Components.RefreshAll()
        chatRequestModal:Show()
        return
    end

    local MODAL_WIDTH = 500
    local MARGIN = 16
    local ICON_SIZE = 20
    local ICON_GAP = 6

    local modal = CreatePanel("BuffRemindersChatRequestModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.ChatRequestModal.Title"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local desc = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", MARGIN, -36)
    desc:SetWidth(MODAL_WIDTH - MARGIN * 2)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["Options.ChatRequestModal.Desc"])
    desc:SetTextColor(0.7, 0.7, 0.7)

    local layout = Components.VerticalLayout(modal, { x = MARGIN + ICON_SIZE + ICON_GAP, y = -62 })

    local LABEL_WIDTH = 150
    local INPUT_WIDTH = MODAL_WIDTH - MARGIN * 2 - LABEL_WIDTH - ICON_SIZE - ICON_GAP
    local ROW_GAP = 8

    local inputHolders = {}

    for _, entry in ipairs(chatRequestBuffKeys) do
        local buffKey = entry.key
        local holder = Components.TextInput(modal, {
            label = entry.label,
            labelWidth = LABEL_WIDTH,
            width = INPUT_WIDTH,
            get = function()
                local custom = (BR.profile.chatRequestMessages or {})[buffKey]
                return (custom and custom ~= "") and custom or ""
            end,
            onChange = function(text)
                text = strtrim(text)
                if not BR.profile.chatRequestMessages then
                    BR.profile.chatRequestMessages = {}
                end
                if text == "" then
                    BR.profile.chatRequestMessages[buffKey] = nil
                else
                    BR.profile.chatRequestMessages[buffKey] = text
                end
                -- Refresh overlays so the new message takes effect
                BR.Display.UpdateActionButtons("raid")
                BR.Display.UpdateActionButtons("presence")
            end,
        })
        holder.editBox:SetMaxLetters(120)
        inputHolders[buffKey] = holder
        layout:Add(holder, nil, ROW_GAP)

        local icon = CreateBuffIcon(modal, ICON_SIZE, C_Spell.GetSpellTexture(entry.spellID))
        icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)
    end

    layout:Space(4)

    local resetBtn = CreateButton(modal, L["Options.ChatRequestModal.ResetAll"], function()
        BR.profile.chatRequestMessages = {}
        for _, entry in ipairs(chatRequestBuffKeys) do
            if inputHolders[entry.key] then
                inputHolders[entry.key]:SetValue("")
            end
        end
        BR.Display.UpdateActionButtons("raid")
        BR.Display.UpdateActionButtons("presence")
    end)
    layout:SetX(MARGIN)
    layout:Add(resetBtn, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    chatRequestModal = modal
    modal:Show()
end

-- ---- Delve Food ----

local delveFoodModal = nil

ShowDelveFoodModal = function()
    if delveFoodModal then
        Components.RefreshAll()
        delveFoodModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersDelveFoodModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.DelveFoodSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local timerHolder = Components.Checkbox(modal, {
        label = L["Options.DelveFoodTimer"],
        get = function()
            return BR.Config.Get("defaults.delveFoodTimer", false) == true
        end,
        tooltip = {
            title = L["Options.DelveFoodTimer"],
            desc = L["Options.DelveFoodTimer.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.delveFoodTimer", checked)
        end,
    })
    layout:Add(timerHolder, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    delveFoodModal = modal
    modal:Show()
end

-- ---- Blessing of the Bronze ----

local bronzeModal = nil

ShowBronzeModal = function()
    if bronzeModal then
        Components.RefreshAll()
        bronzeModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersBronzeModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.BronzeSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local hideInCombatHolder = Components.Checkbox(modal, {
        label = L["Options.BronzeHideInCombat"],
        get = function()
            return BR.profile.bronzeHideInCombat == true
        end,
        tooltip = {
            title = L["Options.BronzeHideInCombat"],
            desc = L["Options.BronzeHideInCombat.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("bronzeHideInCombat", checked)
        end,
    })
    layout:Add(hideInCombatHolder, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    bronzeModal = modal
    modal:Show()
end

-- ---- Pet Passive ----

local petPassiveModal = nil

ShowPetPassiveModal = function()
    if petPassiveModal then
        Components.RefreshAll()
        petPassiveModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersPetPassiveModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.PetPassiveSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local passiveCombatHolder = Components.Checkbox(modal, {
        label = L["Options.PetPassiveCombat"],
        get = function()
            return BR.profile.petPassiveOnlyInCombat == true
        end,
        tooltip = {
            title = L["Options.PetPassiveCombat"],
            desc = L["Options.PetPassiveCombat.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("petPassiveOnlyInCombat", checked)
        end,
    })
    layout:Add(passiveCombatHolder, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    petPassiveModal = modal
    modal:Show()
end

-- ---- Pet Summon ----

local petSummonModal = nil

ShowPetSummonModal = function()
    if petSummonModal then
        Components.RefreshAll()
        petSummonModal:Show()
        return
    end

    local MODAL_WIDTH = 340
    local MARGIN = 16

    local modal = CreatePanel("BuffRemindersPetSummonModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.PetSummonSettings"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    local felDomHolder = Components.Checkbox(modal, {
        label = L["Options.FelDomination"],
        get = function()
            return BR.Config.Get("defaults.useFelDomination", false)
        end,
        tooltip = {
            title = L["Options.FelDomination.Title"],
            desc = L["Options.FelDomination.Desc"],
        },
        onChange = function(checked)
            BR.Config.Set("defaults.useFelDomination", checked)
        end,
    })
    layout:Add(felDomHolder, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))
    petSummonModal = modal
    modal:Show()
end

-- ============================================================================
-- SOUND ALERT MODAL
-- ============================================================================

local soundAlertModal = nil
local SOUND_MODAL_BUFF_ARRAYS = { RaidBuffs, PresenceBuffs, TargetedBuffs, SelfBuffs, PetBuffs, Consumables }

-- Build buff options (all buffs that don't already have a sound)
local function BuildBuffOptions()
    local db = BR.profile
    local opts = {}
    local seenGroups = {}
    for _, buffArray in ipairs(SOUND_MODAL_BUFF_ARRAYS) do
        for _, buff in ipairs(buffArray) do
            local key = buff.groupId or buff.key
            if buff.groupId then
                if seenGroups[buff.groupId] then
                    key = nil -- skip duplicate group entries
                else
                    seenGroups[buff.groupId] = true
                end
            end
            if key and not (db.buffSounds and db.buffSounds[key]) then
                local name
                if buff.groupId then
                    local groupInfo = BuffGroups[buff.groupId]
                    name = groupInfo and groupInfo.displayName or buff.name
                else
                    name = buff.name
                end
                tinsert(opts, { label = name, value = key })
            end
        end
    end
    -- Custom buffs
    if db.customBuffs then
        for key, customBuff in pairs(db.customBuffs) do
            if not (db.buffSounds and db.buffSounds[key]) then
                local name = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID))
                tinsert(opts, { label = name, value = key })
            end
        end
    end
    tsort(opts, function(a, b)
        return a.label < b.label
    end)
    return opts
end

-- Build sound options from LSM
local function BuildSoundOptions()
    local soundList = LSM:List("sound")
    local opts = {}
    for _, name in ipairs(soundList) do
        if name ~= "None" then
            tinsert(opts, { label = name, value = name })
        end
    end
    return opts
end

ShowSoundAlertModal = function(refreshCallback, editBuffKey, editSoundName, editBuffName)
    -- Destroy and recreate: dropdown scroll support depends on option count at creation time
    if soundAlertModal then
        soundAlertModal:Hide()
        soundAlertModal:SetParent(nil)
    end

    local isEditing = editBuffKey ~= nil
    local MODAL_WIDTH = 360
    local MARGIN = 16

    local modal = CreatePanel(nil, MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(isEditing and L["Options.Sound.EditTitle"] or L["Options.Sound.Title"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local layout = Components.VerticalLayout(modal, { x = MARGIN, y = -36 })

    -- State for selections
    local selectedBuffKey = editBuffKey
    local selectedSoundName = editSoundName

    local buffOpts
    if isEditing then
        -- When editing, show only the current buff (locked)
        buffOpts = { { label = editBuffName or editBuffKey, value = editBuffKey } }
    else
        buffOpts = BuildBuffOptions()
    end

    local buffDropdown = Components.Dropdown(modal, {
        label = L["Options.Sound.SelectBuff"],
        width = 200,
        maxItems = 15,
        options = buffOpts,
        onChange = function(val)
            selectedBuffKey = val
        end,
    })
    layout:Add(buffDropdown, nil, DROPDOWN_EXTRA)

    if isEditing then
        buffDropdown:SetEnabled(false)
    end

    local soundDropdown = Components.Dropdown(modal, {
        label = L["Options.Sound.SelectSound"],
        width = 200,
        maxItems = 15,
        options = BuildSoundOptions(),
        onChange = function(val)
            selectedSoundName = val
        end,
    })
    layout:Add(soundDropdown, nil, DROPDOWN_EXTRA)

    if editSoundName then
        soundDropdown:SetValue(editSoundName)
    end

    -- Preview + Save row
    local btnRow = CreateFrame("Frame", nil, modal)
    btnRow:SetSize(MODAL_WIDTH - MARGIN * 2, 22)

    local previewBtn = CreateButton(modal, L["Options.Sound.Preview"], function()
        if selectedSoundName then
            local soundFile = LSM:Fetch("sound", selectedSoundName)
            if soundFile then
                PlaySoundFile(soundFile, "Master")
            end
        end
    end)
    previewBtn:SetSize(80, 22)
    previewBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)

    local saveBtn = CreateButton(modal, L["Options.Sound.Save"], function()
        if selectedBuffKey and selectedSoundName then
            SetBuffSound(selectedBuffKey, selectedSoundName)
            modal:Hide()
            if refreshCallback then
                refreshCallback()
            end
        end
    end)
    saveBtn:SetSize(80, 22)
    saveBtn:SetPoint("RIGHT", btnRow, "RIGHT", 0, 0)

    layout:Add(btnRow, nil, COMPONENT_GAP)

    modal:SetHeight(max(-layout:GetY() + MARGIN, 80))

    -- Status text for when no buffs are available (only relevant for add mode)
    if not isEditing and #buffOpts == 0 then
        local noBuffsText = modal:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        noBuffsText:SetPoint("TOP", btnRow, "BOTTOM", 0, -6)
        noBuffsText:SetText(L["Options.Sound.NoBuffs"])
    end

    -- Sync local state from auto-selected first options
    if not isEditing then
        selectedBuffKey = buffDropdown.dropdown:GetValue()
    end
    selectedSoundName = soundDropdown.dropdown:GetValue()

    soundAlertModal = modal
    modal:Show()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

BR.Options = {
    Toggle = ToggleOptions,
    Show = ShowOptions,
    Hide = HideOptions,
}
