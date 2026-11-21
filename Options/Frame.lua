local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- OPTIONS PANEL SHELL
-- ============================================================================
-- Builds the panel chrome and a sidebar nav that lazily builds and swaps page
-- content.
--
-- Each page is registered as BR.Options.Pages.<id> = { title, Build = fn(content), showMasqueBanner = bool }.

local max, min = math.max, math.min

local L = BR.L
local Components = BR.Components
local CreatePanel = BR.CreatePanel

local PANEL_ZOOM = BR.PANEL_ZOOM

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
-- Top of the content: the header divider, and the bottom of the header band.
local HEADER_HEIGHT = CONTENT_TOP_OFFSET - 4

local Theme = BR.Theme
local SetTextColor = BR.SetThemeTextColor
local SetColorTexture = BR.SetThemeColorTexture
local PaintGradient = BR.PaintGradient

local optionsPanel = nil

-- ============================================================================
-- POPUP DIALOGS
-- ============================================================================

StaticPopupDialogs["BUFFREMINDERS_DELETE_PROFILE"] = {
    text = L["Dialog.DeleteProfile"],
    button1 = L["Options.Delete"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function(_, data)
        BR.Profiles.DeleteProfile(data.name)
        data.onDeleted()
    end,
    showAlert = true,
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
    -- AceDB rejects a profile name longer than 50 characters.
    maxLetters = 50,
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
    local colors = Theme.sidebarGroup
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(SIDEBAR_WIDTH, 22)

    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text:upper())
    SetTextColor(fs, colors.text)
    header.label = fs

    local sep = header:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 4, 1)
    sep:SetPoint("BOTTOMRIGHT", -4, 1)
    PaintGradient(sep, "HORIZONTAL", colors.left, colors.right)

    return header
end

-- A small red notification dot pinned to the right of a sidebar label (page
-- button or group header). It stays hidden until unacknowledged new features
-- exist.
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

-- A toggle for the sidebar footer (Lock / Test).
-- opts: { accent = {r,g,b}, tooltip = {title, desc}, onClick = fn(self) }.
local function CreateFooterToggle(parent, opts)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(24)
    local surface = BR.CreateSurface(btn)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    btn.label = label

    local styles = Theme.footer
    local normalStyle = BR.ResolveStyle(styles.normal, opts.accent)
    local hoverStyle = BR.ResolveStyle(styles.hover, opts.accent)
    local activeStyle = BR.ResolveStyle(styles.active, opts.accent)
    local isHovered, isActive = false, false
    local function Update()
        local style = normalStyle
        if isActive then
            style = activeStyle
        elseif isHovered then
            style = hoverStyle
        end
        BR.PaintStyled(surface, label, style)
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

---@param btn table
---@param hovered boolean
local function PaintSidebarButton(btn, hovered)
    local nav = Theme.nav
    local style = nav.idle
    if btn.isActive then
        style = nav.active
    elseif hovered then
        style = nav.hover
    end
    PaintGradient(btn.bg, "HORIZONTAL", style.left, style.right)
    SetTextColor(btn.label, style.text)
    btn.accent:SetShown(btn.isActive)
end

local function CreateSidebarButton(parent, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SIDEBAR_WIDTH, 24)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    btn.bg = bg

    local accent = btn:CreateTexture(nil, "ARTWORK")
    accent:SetSize(2, Theme.nav.barHeight)
    accent:SetPoint("LEFT", 0, 0)
    SetColorTexture(accent, Theme.nav.bar)
    accent:Hide()
    btn.accent = accent

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", 14, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    btn.label = fs

    btn:SetScript("OnEnter", function(self)
        PaintSidebarButton(self, true)
    end)
    btn:SetScript("OnLeave", function(self)
        PaintSidebarButton(self, false)
    end)
    function btn:SetActive(active)
        self.isActive = active
        PaintSidebarButton(self, self:IsVisible() and self:IsMouseOver())
    end
    btn:SetActive(false)
    return btn
end

-- ============================================================================
-- PANEL BUILDER
-- ============================================================================

local function CreateOptionsPanel()
    local panel = CreatePanel("BuffRemindersOptions", PANEL_WIDTH, PANEL_HEIGHT, {
        escClose = true,
        header = HEADER_HEIGHT,
        brackets = true,
    })
    panel:Hide()

    -- EditBox tracker so panel-wide hide clears focus. Components owns the
    -- pruning; every edit box a factory builds lands here, dialogs included.
    local panelEditBoxes = {}
    Components.SetEditBoxesRef(panelEditBoxes)
    panel:SetScript("OnHide", function()
        Components.ClearEditBoxFocus()
        BR.HideOptionsTooltip()
        -- A panel close acknowledges this release's additions. Persist first,
        -- then recompute the snapshot, so the next open shows no dots.
        BR.Options.WhatsNew.MarkSeen()
        BR.Options.WhatsNew.Refresh()
    end)

    -- ====================================================================
    -- TOP BAR: title + version + Discord + Ko-fi
    -- ====================================================================
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", COL_PADDING, -14)
    local brand = Theme.headerBrand
    title:SetText(BR.ColorCode(brand[1]) .. "Buff|r" .. BR.ColorCode(brand[2]) .. "Reminders|r")
    local headerDot = BR.ColorCode(Theme.headerDot) .. "\194\183|r"

    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local addonVersion = C_AddOns.GetAddOnMetadata("BuffReminders", "Version") or ""
    version:SetText(addonVersion)
    SetTextColor(version, Theme.version)

    local discordSep = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    discordSep:SetPoint("LEFT", version, "RIGHT", 6, 0)
    discordSep:SetText(headerDot)

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
    kofiSep:SetText(headerDot)

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
    local MIN_PCT, MAX_PCT = PANEL_ZOOM.MIN, PANEL_ZOOM.MAX

    local closeBtn = BR.Options.Helpers.AddCloseButton(panel)

    local scaleHolder = CreateFrame("Frame", nil, panel)
    scaleHolder:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    scaleHolder:SetSize(60, 16)

    local scaleDown = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDown:SetPoint("LEFT", 0, 0)
    scaleDown:SetText("<")

    local scaleValue = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleValue:SetPoint("LEFT", scaleDown, "RIGHT", 4, 0)
    scaleValue:SetText(BR.GetPanelZoom() .. "%")

    local scaleUp = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleUp:SetPoint("LEFT", scaleValue, "RIGHT", 4, 0)
    scaleUp:SetText(">")

    local zoomIdle, zoomLimit, zoomHover = Theme.zoom.idle, Theme.zoom.limit, Theme.zoom.hover

    local function UpdateScaleText()
        local pct = BR.GetPanelZoom()
        scaleValue:SetText(pct .. "%")
        SetTextColor(scaleDown, pct > MIN_PCT and zoomIdle or zoomLimit)
        SetTextColor(scaleUp, pct < MAX_PCT and zoomIdle or zoomLimit)
    end

    local function UpdateScale(delta)
        BR.profile.optionsPanelZoom = max(MIN_PCT, min(MAX_PCT, BR.GetPanelZoom() + delta))
        panel:SetScale(BR.PanelScale())
        BR.RefreshDialogScales()
        UpdateScaleText()
    end

    local downBtn = CreateFrame("Button", nil, scaleHolder)
    downBtn:SetAllPoints(scaleDown)
    downBtn:SetScript("OnClick", function()
        UpdateScale(-PANEL_ZOOM.STEP)
    end)
    downBtn:SetScript("OnEnter", function()
        if BR.GetPanelZoom() > MIN_PCT then
            SetTextColor(scaleDown, zoomHover)
        end
    end)
    downBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    local upBtn = CreateFrame("Button", nil, scaleHolder)
    upBtn:SetAllPoints(scaleUp)
    upBtn:SetScript("OnClick", function()
        UpdateScale(PANEL_ZOOM.STEP)
    end)
    upBtn:SetScript("OnEnter", function()
        if BR.GetPanelZoom() < MAX_PCT then
            SetTextColor(scaleUp, zoomHover)
        end
    end)
    upBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    UpdateScaleText()

    panel:SetScale(BR.PanelScale())

    -- The header divider is the top layout primitive: the sidebar and the
    -- content area hang from it and run to the panel's bottom margin.
    local headerSep = panel:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT", SIDEBAR_X, -HEADER_HEIGHT)
    headerSep:SetPoint("TOPRIGHT", -COL_PADDING, -HEADER_HEIGHT)
    BR.AddGroove(headerSep, Theme.groove.header)

    -- ====================================================================
    -- SIDEBAR
    -- ====================================================================
    local sidebar = CreateFrame("Frame", nil, panel)
    sidebar:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", SIDEBAR_X, PANEL_BOTTOM_MARGIN)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    -- The inset keeps the recess clear of the shade line under the header groove.
    local sidebarColors = Theme.sidebar
    local sidebarTop = -sidebarColors.inset

    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetPoint("TOPLEFT", 0, sidebarTop)
    sidebarBg:SetPoint("BOTTOMRIGHT", 0, 0)

    local sidebarBorder = sidebar:CreateTexture(nil, "BORDER")
    sidebarBorder:SetWidth(1)
    sidebarBorder:SetPoint("TOPRIGHT", 0, sidebarTop)
    sidebarBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    PaintGradient(sidebarBg, "VERTICAL", sidebarColors.bottom, sidebarColors.top)
    SetColorTexture(sidebarBorder, sidebarColors.edge)

    -- ====================================================================
    -- CONTENT AREA
    -- ====================================================================
    -- Each page gets its own ScrollableContainer. The page content is built
    -- lazily, on the first navigation to that page.
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
    -- Both are global mode toggles, so they stay reachable from every page.
    local FOOTER_WIDTH = SIDEBAR_WIDTH - 24
    local FOOTER_PAD = 10 -- symmetric gap above the cluster (below the divider) and below it (to the sidebar edge)
    local UNLOCK_ACCENT = { 0.95, 0.55, 0.2 } -- orange = "edit mode", matching the anchor hint banner

    local testToggle = CreateFooterToggle(sidebar, {
        accent = BR.Colors.Accent,
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
    table.insert(BR.RefreshableComponents, testToggle)
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
        local locked = BR.Display.IsFrameLocked()
        self:SetLabel(locked and L["Options.Unlock"] or L["Options.Lock"])
        self:SetActive(not locked)
    end
    lockToggle:Refresh()
    table.insert(BR.RefreshableComponents, lockToggle)

    local footerSepLeft, footerSepRight = BR.CreateRule(sidebar, "ARTWORK", Theme.footerRule)
    footerSepLeft:SetPoint("BOTTOMLEFT", lockToggle, "TOPLEFT", 0, FOOTER_PAD)
    footerSepLeft:SetPoint("BOTTOMRIGHT", lockToggle, "TOP", 0, FOOTER_PAD)
    footerSepRight:SetPoint("BOTTOMLEFT", lockToggle, "TOP", 0, FOOTER_PAD)
    footerSepRight:SetPoint("BOTTOMRIGHT", lockToggle, "TOPRIGHT", 0, FOOTER_PAD)

    local unlockBanner = Components.Banner(panel, {
        text = L["Options.AnchorHint"],
        color = "orange",
        icon = "services-icon-warning",
        bgAlpha = 0.95,
        visible = function()
            return not BR.Display.IsFrameLocked()
        end,
    })
    unlockBanner:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, 0)
    unlockBanner:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- Snapshot the unacknowledged what's-new entries before the first page
    -- builds. The row dots and the sidebar bubble-up read that snapshot.
    BR.Options.WhatsNew.Refresh()

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
        -- The panel's OnShow calls Components.RefreshAll(), which re-syncs the
        -- Lock and Test footer toggles. No explicit refresh is needed here.
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
