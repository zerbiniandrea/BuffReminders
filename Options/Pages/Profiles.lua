local _, BR = ...

-- ============================================================================
-- PROFILES PAGE
-- ============================================================================
-- AceDB profile dropdown, per-spec profile mapping (LibDualSpec), and
-- import/export text areas.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

local abs = math.abs

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })
    local RefreshProfileDropdown

    LayoutSectionHeader(layout, content, L["Options.ActiveProfile"])
    LayoutSectionNote(layout, content, L["Options.ActiveProfile.Desc"])

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

    local profileRow = CreateFrame("Frame", nil, content)
    profileRow:SetSize(contentWidth - COL_PADDING * 2, 26)

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

    layout:Add(profileRow, 26, COMPONENT_GAP)

    local copyDropdown = Components.Dropdown(content, {
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
    layout:Add(copyDropdown, 26, COMPONENT_GAP)

    local deleteDropdown = Components.Dropdown(content, {
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
            RefreshProfileDropdown()
        end,
    })
    layout:Add(deleteDropdown, 26, SECTION_GAP)

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
    LayoutSectionHeader(layout, content, L["Options.PerSpecProfiles"])
    LayoutSectionNote(layout, content, L["Options.PerSpecProfiles.Desc"])

    local specEnabled = Components.Checkbox(content, {
        label = L["Options.PerSpecProfiles.Enable"],
        get = function()
            return BR.Profiles.IsPerSpecEnabled()
        end,
        onChange = function(checked)
            BR.Profiles.SetPerSpecEnabled(checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(specEnabled, 20, COMPONENT_GAP)

    local numSpecs = GetNumSpecializations() or 0
    local specDropdowns = {}
    for i = 1, numSpecs do
        local _, specName = GetSpecializationInfo(i)
        if specName then
            local specDropdown = Components.Dropdown(content, {
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
            layout:Add(specDropdown, 26, COMPONENT_GAP)
            specDropdowns[i] = specDropdown
        end
    end

    local baseRefreshProfileDropdown = RefreshProfileDropdown
    RefreshProfileDropdown = function()
        baseRefreshProfileDropdown()
        local opts = GetProfileOptions()
        for _, sd in pairs(specDropdowns) do
            sd.dropdown:SetOptions(opts)
        end
    end

    BR.Options.RefreshProfileDropdown = function()
        RefreshProfileDropdown()
    end

    -- Export section
    LayoutSectionHeader(layout, content, L["Options.ExportSettings"])
    LayoutSectionNote(layout, content, L["Options.ExportSettings.Desc"])

    local exportTextArea = Components.TextArea(content, {
        width = contentWidth - COL_PADDING * 2,
        height = 50,
    })
    layout:Add(exportTextArea, 50, COMPONENT_GAP)

    local exportButton = CreateButton(content, L["Options.Export"], function()
        local exportString, err = BuffReminders:Export()
        if exportString then
            exportTextArea:SetText(exportString)
            exportTextArea:HighlightText()
            exportTextArea:SetFocus()
        else
            exportTextArea:SetText(L["CustomBuff.Error"] .. " " .. (err or L["Options.FailedExport"]))
        end
    end)
    layout:Add(exportButton, 22, SECTION_GAP)

    -- Import section
    LayoutSectionHeader(layout, content, L["Options.ImportSettings"])
    LayoutSectionNote(
        layout,
        content,
        L["Options.ImportSettings.DescPlain"] .. " |cffff6600" .. L["Options.ImportSettings.Overwrite"] .. "|r"
    )

    local importTextArea = Components.TextArea(content, {
        width = contentWidth - COL_PADDING * 2,
        height = 50,
    })
    layout:Add(importTextArea, 50, COMPONENT_GAP)

    local importStatus = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importStatus:SetWidth(contentWidth - COL_PADDING * 2 - 120)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetText("")

    local importButton = CreateButton(content, L["Options.Import"], function()
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
    layout:Add(importButton, 22)
    importStatus:SetPoint("LEFT", importButton, "RIGHT", 10, 0)

    content:SetHeight(abs(layout:GetY()) + 50)
end

BR.Options.Pages.profiles = {
    title = L["Page.Profiles"],
    Build = Build,
}
