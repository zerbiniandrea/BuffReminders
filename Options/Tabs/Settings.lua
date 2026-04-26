local _, BR = ...

-- ============================================================================
-- SETTINGS TAB
-- ============================================================================
-- Visibility rules, chat request toggle, buff tracking mode, custom anchors.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader

local UpdateDisplay = BR.Display.Update

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local tinsert = table.insert
local tremove = table.remove
local mmax = math.max

local function Build(ctx)
    local C = ctx.constants
    local PANEL_WIDTH = C.PANEL_WIDTH
    local COL_PADDING = C.COL_PADDING

    local settingsContent = ctx:CreateSimpleContent("settings", 500)
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
        BR.Options.Modals.ChatRequest.Show()
    end)
    customizeMsgsBtn:SetPoint("LEFT", requestBuffHolder.label, "RIGHT", 8, 0)
    customizeMsgsBtn:SetFrameLevel(requestBuffHolder:GetFrameLevel() + 5)

    setLayout:Add(requestBuffHolder, nil, COMPONENT_GAP)

    -- Visibility section
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
                value = "self_only",
                label = L["Options.BuffTracking.SelfOnly"],
                desc = L["Options.BuffTracking.SelfOnly.Desc"],
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
            Components.RefreshAll()
        end,
    })
    setLayout:Add(trackingModeHolder, nil, COMPONENT_GAP)

    local selfOnlyOutsideHolder = Components.Checkbox(settingsContent, {
        label = L["Options.BuffTracking.SelfOnlyOutsideInstances"],
        tooltip = {
            title = L["Options.BuffTracking.SelfOnlyOutsideInstances"],
            desc = L["Options.BuffTracking.SelfOnlyOutsideInstances.Desc"],
        },
        get = function()
            return BR.profile.selfOnlyOutsideInstances == true
        end,
        enabled = function()
            return BR.Config.Get("buffTrackingMode", "all") ~= "self_only"
        end,
        onChange = function(checked)
            BR.Config.Set("selfOnlyOutsideInstances", checked)
        end,
    })
    setLayout:Add(selfOnlyOutsideHolder, nil, COMPONENT_GAP)

    -- Custom Anchor Frames section
    LayoutSectionHeader(setLayout, settingsContent, L["Options.CustomAnchorFrames"])

    local customAnchorDesc = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customAnchorDesc:SetWidth(PANEL_WIDTH - COL_PADDING * 2)
    customAnchorDesc:SetJustifyH("LEFT")
    customAnchorDesc:SetText(L["Options.CustomAnchorFrames.Desc"])
    setLayout:AddText(customAnchorDesc, 22, COMPONENT_GAP)

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

    local addAnchorBtn

    local customAnchorList = CreateFrame("Frame", nil, settingsContent)
    customAnchorList:SetSize(PANEL_WIDTH - COL_PADDING * 2, 1)

    local customAnchorEntries = {}

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

        customAnchorList:SetHeight(mmax(1, entryY))
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
end

BR.Options.Tabs.Settings = { Build = Build }
