local _, BR = ...

-- ============================================================================
-- OPTIONS PANEL SHELL
-- ============================================================================
-- Builds the panel chrome (title, version, Discord link, scale stepper, close
-- button, lock + test bar, banners) and a sidebar nav that lazily builds and
-- swaps page content.
--
-- Each page is registered as BR.Options.Pages.<id> = { title, Build = fn(content), showMasqueBanner = bool }.
-- BR.Options.Groups (in Context.lua) declares sidebar order.

local floor, max, min = math.floor, math.max, math.min
local tinsert = table.insert

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local OPTIONS_BASE_SCALE = BR.OPTIONS_BASE_SCALE

local ToggleTestMode = BR.Display.ToggleTestMode

local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

local C = BR.Options.Constants
local PANEL_WIDTH = C.PANEL_WIDTH
local PANEL_HEIGHT = C.PANEL_HEIGHT
local SIDEBAR_WIDTH = C.SIDEBAR_WIDTH
local SIDEBAR_X = C.SIDEBAR_X
local CONTENT_TOP_OFFSET = C.CONTENT_TOP_OFFSET
local PANEL_BOTTOM_MARGIN = C.PANEL_BOTTOM_MARGIN
local SCROLLBAR_WIDTH = C.SCROLLBAR_WIDTH
local COL_PADDING = C.COL_PADDING

local BORDER_R, BORDER_G, BORDER_B = unpack(BR.Colors.Border)
local ACCENT_R, ACCENT_G, ACCENT_B = unpack(BR.Colors.Accent)

local optionsPanel = nil

-- ============================================================================
-- POPUP DIALOGS
-- ============================================================================

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
    -- New profiles start blank: SetProfile on a fresh name creates an empty
    -- profile and fires OnProfileChanged -> RefreshAfterProfileChange, which
    -- fills in defaults. No CopyProfile, so it does not clone the current one.
    BR.aceDB:SetProfile(name)
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

StaticPopupDialogs["BUFFREMINDERS_KOFI_URL"] = {
    text = L["Dialog.KofiPrompt"],
    button1 = L["Dialog.Close"],
    hasEditBox = true,
    editBoxWidth = 250,
    OnShow = function(self)
        self.EditBox:SetText("https://ko-fi.com/zerbyy")
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

-- ============================================================================
-- SIDEBAR BUTTON FACTORY
-- ============================================================================

local function CreateSidebarGroupHeader(parent, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(SIDEBAR_WIDTH, 22)

    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetText("|cffffcc00" .. text:upper() .. "|r")
    fs:SetJustifyH("LEFT")
    header.label = fs

    local sep = header:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 4, 1)
    sep:SetPoint("BOTTOMRIGHT", -4, 1)
    sep:SetColorTexture(0.4, 0.32, 0.05, 0.6)

    return header
end

-- A small red notification dot pinned just to the right of a sidebar label
-- (page button or group header), hidden until there are unacknowledged new
-- features. Mirrors the mobile "there's something new here" affordance. Flat
-- bundled circle tinted red, so it reads as a clean badge against the thin-edge
-- chrome (the stock Indicator textures are glossy/beveled and look dated here).
local NOTIFY_DOT_TEXTURE = "Interface\\AddOns\\BuffReminders\\Media\\dot.tga"
local NOTIFY_DOT_COLOR = { 0.88, 0.42, 0.40 }
local function AttachNotificationDot(anchorLabel)
    local dot = anchorLabel:GetParent():CreateTexture(nil, "OVERLAY")
    dot:SetTexture(NOTIFY_DOT_TEXTURE)
    dot:SetVertexColor(NOTIFY_DOT_COLOR[1], NOTIFY_DOT_COLOR[2], NOTIFY_DOT_COLOR[3])
    dot:SetSize(10, 10)
    dot:SetPoint("LEFT", anchorLabel, "RIGHT", 6, 0)
    dot:Hide()
    return dot
end

-- A state-expressive toggle for the sidebar footer (Lock / Test). Bordered so it
-- reads as a tool, not a nav row; when ACTIVE its fill + border + text take the
-- given accent, so the current mode (unlocked / testing) is glanceable from any
-- page. opts: { accent = {r,g,b}, tooltip = {title, desc}, onClick = fn(self) }.
local function CreateFooterToggle(parent, opts)
    local accent = opts.accent
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(24)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    btn.label = label

    local isHovered, isActive = false, false
    local function Update()
        if isActive then
            btn:SetBackdropColor(accent[1], accent[2], accent[3], 0.22)
            btn:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
            label:SetTextColor(1, 1, 1)
        elseif isHovered then
            btn:SetBackdropColor(1, 1, 1, 0.06)
            btn:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.8)
            label:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0, 0, 0, 0)
            btn:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, 1)
            label:SetTextColor(0.85, 0.85, 0.85)
        end
    end

    btn:SetScript("OnEnter", function()
        isHovered = true
        Update()
        if opts.tooltip then
            BR.ShowTooltip(btn, opts.tooltip.title, opts.tooltip.desc, "ANCHOR_RIGHT")
        end
    end)
    btn:SetScript("OnLeave", function()
        isHovered = false
        Update()
        if opts.tooltip then
            BR.HideTooltip()
        end
    end)
    btn:SetScript("OnClick", function()
        opts.onClick(btn)
    end)

    function btn:SetActive(active)
        isActive = active
        Update()
    end
    function btn:SetLabel(text)
        label:SetText(text)
    end
    Update()
    return btn
end

local function CreateSidebarButton(parent, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SIDEBAR_WIDTH, 24)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0)
    btn.bg = bg

    local accent = btn:CreateTexture(nil, "ARTWORK")
    accent:SetSize(2, 18)
    accent:SetPoint("LEFT", 0, 0)
    accent:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    accent:Hide()
    btn.accent = accent

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", 14, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    btn.label = fs

    btn:SetScript("OnEnter", function(self)
        if not self.isActive then
            self.bg:SetColorTexture(1, 1, 1, 0.06)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isActive then
            self.bg:SetColorTexture(1, 1, 1, 0)
        end
    end)

    function btn:SetActive(active)
        self.isActive = active
        if active then
            self.bg:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.12)
            self.accent:Show()
            self.label:SetTextColor(1, 1, 1)
        else
            self.bg:SetColorTexture(1, 1, 1, 0)
            self.accent:Hide()
            self.label:SetTextColor(0.85, 0.85, 0.85)
        end
    end

    btn:SetActive(false)
    return btn
end

-- ============================================================================
-- PANEL BUILDER
-- ============================================================================

local function CreateOptionsPanel()
    local panel = CreatePanel("BuffRemindersOptions", PANEL_WIDTH, PANEL_HEIGHT, { escClose = true })
    panel:Hide()

    -- EditBox tracker so panel-wide hide clears focus.
    local panelEditBoxes = {}
    Components.SetEditBoxesRef(panelEditBoxes)
    panel:SetScript("OnHide", function()
        for _, editBox in ipairs(panelEditBoxes) do
            editBox:ClearFocus()
        end
        -- Closing the panel acknowledges this release's additions: the user had
        -- the cascade (sidebar + rows) in front of them this session. Persist,
        -- then recompute the snapshot so the next open opens clean.
        BR.Options.WhatsNew.MarkSeen()
        BR.Options.WhatsNew.Refresh()
    end)

    -- ====================================================================
    -- TOP BAR: title + version + Discord + Ko-fi
    -- ====================================================================
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", COL_PADDING, -14)
    title:SetText("|cffffffffBuff|r|cffffcc00Reminders|r")

    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local addonVersion = C_AddOns.GetAddOnMetadata("BuffReminders", "Version") or ""
    version:SetText(addonVersion)

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

    local kofiSep = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    kofiSep:SetPoint("LEFT", discordLink, "RIGHT", 6, 0)
    kofiSep:SetText("|cff555555·|r")

    local kofiLink = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    kofiLink:SetPoint("LEFT", kofiSep, "RIGHT", 6, 0)
    kofiLink:SetText("|cffff5e5b" .. L["Options.SupportKofi"] .. "|r")

    local kofiHit = CreateFrame("Button", nil, panel)
    kofiHit:SetAllPoints(kofiLink)
    kofiHit:SetScript("OnClick", function()
        StaticPopup_Show("BUFFREMINDERS_KOFI_URL")
    end)
    kofiHit:SetScript("OnEnter", function()
        kofiLink:SetText("|cffff8a88" .. L["Options.SupportKofi"] .. "|r")
        BR.ShowTooltip(kofiHit, L["Options.SupportKofi.Title"], L["Options.SupportKofi.Desc"], "ANCHOR_BOTTOM")
    end)
    kofiHit:SetScript("OnLeave", function()
        kofiLink:SetText("|cffff5e5b" .. L["Options.SupportKofi"] .. "|r")
        BR.HideTooltip()
    end)

    -- ====================================================================
    -- TOP BAR: scale stepper + close button
    -- ====================================================================
    local BASE_SCALE = OPTIONS_BASE_SCALE
    local MIN_PCT, MAX_PCT = 80, 150

    local function GetScalePct()
        return floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
    end

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
    scaleValue:SetText(GetScalePct() .. "%")

    local scaleUp = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleUp:SetPoint("LEFT", scaleValue, "RIGHT", 4, 0)
    scaleUp:SetText(">")

    local function UpdateScaleText()
        local pct = GetScalePct()
        scaleValue:SetText(pct .. "%")
        scaleDown:SetTextColor(pct > MIN_PCT and 1 or 0.4, pct > MIN_PCT and 1 or 0.4, pct > MIN_PCT and 1 or 0.4)
        scaleUp:SetTextColor(pct < MAX_PCT and 1 or 0.4, pct < MAX_PCT and 1 or 0.4, pct < MAX_PCT and 1 or 0.4)
    end

    local function UpdateScale(delta)
        local newPct = max(MIN_PCT, min(MAX_PCT, GetScalePct() + delta))
        local newScale = newPct / 100 * BASE_SCALE
        BR.profile.optionsPanelScale = newScale
        panel:SetScale(newScale)
        UpdateScaleText()
    end

    local downBtn = CreateFrame("Button", nil, scaleHolder)
    downBtn:SetAllPoints(scaleDown)
    downBtn:SetScript("OnClick", function()
        UpdateScale(-10)
    end)
    downBtn:SetScript("OnEnter", function()
        if GetScalePct() > MIN_PCT then
            scaleDown:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)
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
        if GetScalePct() < MAX_PCT then
            scaleUp:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)
        end
    end)
    upBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    UpdateScaleText()

    if BR.profile.optionsPanelScale then
        panel:SetScale(BR.profile.optionsPanelScale)
    end

    -- The header divider is the top layout primitive: the sidebar and content
    -- area hang from it and run to the panel's bottom margin. Global tools
    -- (Lock / Test) live in the sidebar footer rather than a bottom bar, so no
    -- horizontal strip steals height from every page.
    local headerSep = panel:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT", SIDEBAR_X, -CONTENT_TOP_OFFSET + 4)
    headerSep:SetPoint("TOPRIGHT", -COL_PADDING, -CONTENT_TOP_OFFSET + 4)
    headerSep:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 1)

    -- ====================================================================
    -- SIDEBAR
    -- ====================================================================
    local sidebar = CreateFrame("Frame", nil, panel)
    sidebar:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", SIDEBAR_X, PANEL_BOTTOM_MARGIN)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(0, 0, 0.04, 0.35)

    local sidebarBorder = sidebar:CreateTexture(nil, "BORDER")
    sidebarBorder:SetWidth(1)
    sidebarBorder:SetPoint("TOPRIGHT", 0, 0)
    sidebarBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    sidebarBorder:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 1)

    -- ====================================================================
    -- CONTENT AREA
    -- ====================================================================
    -- Each page registers via BR.Options.Pages.<id>. We create a parent frame
    -- per page (a ScrollableContainer), build its content lazily on first nav.
    local contentArea = CreateFrame("Frame", nil, panel)
    contentArea:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", SIDEBAR_WIDTH + 6, 0)
    contentArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -COL_PADDING + 4, PANEL_BOTTOM_MARGIN)

    local pageContainers = {} -- pageId -> scrollFrame
    local pageBuilt = {} -- pageId -> bool
    local activePageId = nil

    -- Banner (Masque) - only visible on pages that flag showMasqueBanner.
    local masqueBanner
    local UpdateBannerLayout

    local function CreatePageContainer(pageId)
        local scrollFrame, content = Components.ScrollableContainer(contentArea, {
            contentHeight = 600,
            scrollbarWidth = SCROLLBAR_WIDTH,
        })
        scrollFrame:SetPoint("TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
        scrollFrame:Hide()
        pageContainers[pageId] = scrollFrame
        scrollFrame.content = content
        return scrollFrame, content
    end

    local function GetPage(pageId)
        return BR.Options.Pages[pageId]
    end

    local function BuildPageIfNeeded(pageId)
        if pageBuilt[pageId] then
            return
        end
        local page = GetPage(pageId)
        local scrollFrame = pageContainers[pageId]
        if not page or not scrollFrame then
            return
        end
        if page.Build then
            page.Build(scrollFrame.content, scrollFrame)
        end
        pageBuilt[pageId] = true
    end

    local sidebarButtons = {} -- pageId -> button
    local pageDots = {} -- pageId -> what's-new dot on that sidebar button
    local groupDots = {} -- { dot, group } per sidebar group header (bubble-up)

    local function UpdateWhatsNewDots()
        local WhatsNew = BR.Options.WhatsNew
        for pageId, dot in pairs(pageDots) do
            dot:SetShown(WhatsNew.IsPageNew(pageId))
        end
        for _, gd in ipairs(groupDots) do
            gd.dot:SetShown(WhatsNew.IsGroupNew(gd.group))
        end
    end

    local function ActivatePage(pageId)
        if activePageId == pageId then
            return
        end
        activePageId = pageId
        for id, scrollFrame in pairs(pageContainers) do
            if id == pageId then
                BuildPageIfNeeded(id)
                scrollFrame:Show()
            else
                scrollFrame:Hide()
            end
        end
        for id, btn in pairs(sidebarButtons) do
            btn:SetActive(id == pageId)
        end
        if masqueBanner then
            masqueBanner:Refresh()
            UpdateBannerLayout()
        end
        Components.RefreshAll()
    end

    -- ====================================================================
    -- BUILD SIDEBAR FROM GROUPS REGISTRY
    -- ====================================================================
    local sidebarY = -8
    local firstPageId = nil
    for _, group in ipairs(BR.Options.Groups) do
        local hasAnyPage = false
        for _, pageId in ipairs(group.pages) do
            if BR.Options.Pages[pageId] then
                hasAnyPage = true
                break
            end
        end
        if hasAnyPage then
            local header = CreateSidebarGroupHeader(sidebar, L[group.titleKey] or group.titleKey)
            header:SetPoint("TOPLEFT", 0, sidebarY)
            sidebarY = sidebarY - 22
            groupDots[#groupDots + 1] = { dot = AttachNotificationDot(header.label), group = group }

            for _, pageId in ipairs(group.pages) do
                local page = BR.Options.Pages[pageId]
                if page then
                    local btn = CreateSidebarButton(sidebar, page.title or pageId)
                    btn:SetPoint("TOPLEFT", 0, sidebarY)
                    btn:SetScript("OnClick", function()
                        ActivatePage(pageId)
                    end)
                    sidebarButtons[pageId] = btn
                    pageDots[pageId] = AttachNotificationDot(btn.label)
                    sidebarY = sidebarY - 24
                    -- Pre-create the page container so masque banner refresh / page-show events work.
                    CreatePageContainer(pageId)
                    if not firstPageId then
                        firstPageId = pageId
                    end
                end
            end
            sidebarY = sidebarY - 6 -- group gap
        end
    end

    -- ====================================================================
    -- BANNERS (Masque, Anchor unlock)
    -- ====================================================================
    masqueBanner = Components.Banner(panel, {
        text = L["Options.MasqueNote"],
        icon = "QuestNormal",
        color = "orange",
        visible = function()
            if not IsMasqueActive() then
                return false
            end
            local page = activePageId and BR.Options.Pages[activePageId]
            return page and page.showMasqueBanner == true
        end,
    })

    local BANNER_GAP = 6

    UpdateBannerLayout = function()
        contentArea:ClearAllPoints()
        contentArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -COL_PADDING + 4, PANEL_BOTTOM_MARGIN)
        if masqueBanner:IsShown() then
            masqueBanner:ClearAllPoints()
            masqueBanner:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", SIDEBAR_WIDTH + 6, -BANNER_GAP)
            masqueBanner:SetPoint("RIGHT", panel, "RIGHT", -COL_PADDING + 4, 0)
            masqueBanner:FitHeight()
            contentArea:SetPoint("TOPLEFT", masqueBanner, "BOTTOMLEFT", 0, -BANNER_GAP)
        else
            contentArea:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", SIDEBAR_WIDTH + 6, 0)
        end
    end

    panel:SetScript("OnShow", function()
        Components.RefreshAll()
        if masqueBanner then
            masqueBanner:Refresh()
        end
        UpdateBannerLayout()
        UpdateWhatsNewDots()
    end)

    -- ====================================================================
    -- SIDEBAR FOOTER (global tools: Lock + Test)
    -- ====================================================================
    -- Pinned to the bottom of the nav rail behind a divider. Both are global
    -- mode toggles whose effect is on-screen, so they stay always at hand from
    -- every page and surface their active state via the accent fill - no bottom
    -- bar stealing height from the content.
    local FOOTER_WIDTH = SIDEBAR_WIDTH - 24
    local FOOTER_PAD = 10 -- symmetric gap above the cluster (below the divider) and below it (to the sidebar edge)
    local UNLOCK_ACCENT = { 0.95, 0.55, 0.2 } -- orange = "edit mode", matching the anchor hint banner

    local testToggle = CreateFooterToggle(sidebar, {
        accent = { ACCENT_R, ACCENT_G, ACCENT_B },
        tooltip = { title = L["Options.TestAppearance"], desc = L["Options.TestAppearance.Desc"] },
        onClick = function(self)
            ToggleTestMode()
            self:Refresh()
        end,
    })
    testToggle:SetWidth(FOOTER_WIDTH)
    testToggle:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, FOOTER_PAD)
    function testToggle:Refresh()
        local on = BR.Display.IsTestMode()
        self:SetLabel(on and L["Options.StopTest"] or L["Options.Test"])
        self:SetActive(on)
    end
    testToggle:Refresh()
    tinsert(BR.RefreshableComponents, testToggle)
    panel.testToggle = testToggle

    local lockToggle = CreateFooterToggle(sidebar, {
        accent = UNLOCK_ACCENT,
        tooltip = { title = L["Options.LockUnlock"], desc = L["Options.LockUnlock.Desc"] },
        onClick = function()
            BR.Display.ToggleLock()
            Components.RefreshAll()
        end,
    })
    lockToggle:SetWidth(FOOTER_WIDTH)
    lockToggle:SetPoint("BOTTOM", testToggle, "TOP", 0, 6)
    function lockToggle:Refresh()
        local locked = BR.profile.locked
        self:SetLabel(locked and L["Options.Unlock"] or L["Options.Lock"])
        self:SetActive(not locked)
    end
    lockToggle:Refresh()
    tinsert(BR.RefreshableComponents, lockToggle)

    local footerSep = sidebar:CreateTexture(nil, "ARTWORK")
    footerSep:SetHeight(1)
    footerSep:SetPoint("BOTTOMLEFT", lockToggle, "TOPLEFT", 0, FOOTER_PAD)
    footerSep:SetPoint("BOTTOMRIGHT", lockToggle, "TOPRIGHT", 0, FOOTER_PAD)
    footerSep:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 0.7)

    -- Anchor-unlock hint: hangs just below the panel while frames are unlocked.
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

    -- Snapshot unacknowledged what's-new entries before the first page builds,
    -- so rows light their dots and the sidebar bubble-up reflects them.
    BR.Options.WhatsNew.Refresh()

    -- Activate first available page.
    if firstPageId then
        ActivatePage(firstPageId)
    end

    panel.ActivatePage = ActivatePage
    BR.Options.ActivatePage = ActivatePage

    return panel
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local function ShowOptions()
    if not optionsPanel then
        optionsPanel = CreateOptionsPanel()
    end
    if not optionsPanel:IsShown() then
        -- The Lock/Test footer toggles re-sync via Components.RefreshAll() on the
        -- panel's OnShow, so their labels/active state are always current.
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

BR.Options.Toggle = ToggleOptions
BR.Options.Show = ShowOptions
BR.Options.Hide = HideOptions
