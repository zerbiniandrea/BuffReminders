local addonName, ns = ...
---@class BR
local BR = ns

local L = BR.L

-- ============================================================================
-- ADDON BOOTSTRAP
-- ============================================================================
-- Runs once on ADDON_LOADED: SavedVariables/AceDB setup, versioned migrations,
-- default seeding, and options/minimap registration. Owns its own event frame,
-- because each module owns the events it consumes. Loads after Display.lua, so
-- the BR.Display.* builder and registration helpers exist.

local defaults = BR.defaults
local CATEGORIES = BR.CATEGORY_ORDER

local bootstrapFrame = CreateFrame("Frame")
BR.Client.RegisterEvent(bootstrapFrame, "ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= addonName then
        return
    end
    bootstrapFrame:UnregisterEvent("ADDON_LOADED")

    BR.Display.SetPlayerClass((select(2, UnitClass("player"))))
    -- A database without profiles and global predates AceDB and starts fresh.
    local isFirstInstall = not BuffRemindersDB or (not BuffRemindersDB.profiles and not BuffRemindersDB.global)
    if not BuffRemindersDB then
        BuffRemindersDB = {}
    elseif isFirstInstall then
        wipe(BuffRemindersDB)
    end

    BR.Migrations.StampUnversionedProfiles(BuffRemindersDB.profiles)
    BR.Migrations.RunAllProfiles(BuffRemindersDB.profiles)

    local aceDefaults = {
        profile = {},
        global = { minimap = defaults.minimap },
    }
    for k, v in pairs(defaults) do
        if k ~= "minimap" then
            aceDefaults.profile[k] = v
        end
    end

    BR.Profiles.Initialize(aceDefaults)

    local db = BR.profile

    if not db.customBuffs then
        db.customBuffs = {}
    end
    BR.Display.BuildCustomBuffArray()

    if not db.loadoutReminders then
        db.loadoutReminders = {}
    end
    BR.Display.BuildLoadoutRulesArray()

    -- A fresh install acknowledges every current what's-new cohort, because
    -- nothing is new to a new user. An upgrade starts with an empty set, so the
    -- additions of this release light up.
    if isFirstInstall then
        BR.Options.WhatsNew.MarkSeen()
    end

    -- The glow registry reads the profile and the custom-buff array, so it must build after both.
    BR.GameContext.RebuildGlowRegistry()

    if not db.categoryVisibility then
        db.categoryVisibility = {}
    end
    for _, category in ipairs(CATEGORIES) do
        if not db.categoryVisibility[category] then
            local defaultVis = defaults.categoryVisibility[category]
            db.categoryVisibility[category] = {
                openWorld = defaultVis and defaultVis.openWorld ~= false,
                housing = defaultVis and defaultVis.housing == true,
                dungeon = defaultVis and defaultVis.dungeon ~= false,
                scenario = defaultVis and defaultVis.scenario ~= false,
                raid = defaultVis and defaultVis.raid ~= false,
                pvp = defaultVis and defaultVis.pvp ~= false,
                hideInPvPMatch = defaultVis and defaultVis.hideInPvPMatch == true,
            }
        end
    end

    local settingsPanel = CreateFrame("Frame")
    settingsPanel.name = "BuffReminders"

    local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BuffReminders")
    BR.ApplyTitleColor(title)

    local desc = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(L["Display.Description"])

    local openBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    openBtn:SetSize(150, 24)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText(L["Display.OpenOptions"])
    openBtn:SetScript("OnClick", function()
        BR.Options.Toggle()
        -- HideUIPanel also cleans up the keyboard focus of the settings panel.
        if SettingsPanel then
            HideUIPanel(SettingsPanel)
        end
    end)

    local slashInfo = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    slashInfo:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -12)
    slashInfo:SetText(L["Display.SlashCommands"])

    local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
    Settings.RegisterAddOnCategory(category)

    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)
    if LDB and LDBIcon then
        local dataObj = LDB:NewDataObject("BuffReminders", {
            type = "launcher",
            label = "BuffReminders",
            icon = "Interface\\AddOns\\BuffReminders\\icon",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    BR.Options.Toggle()
                elseif button == "RightButton" then
                    BR.Display.ToggleTestMode()
                    BR.Components.RefreshAll()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("BuffReminders")
                tooltip:AddLine(L["Display.MinimapLeftClick"])
                tooltip:AddLine(L["Display.MinimapRightClick"])
                local owner = tooltip:GetOwner()
                if owner and owner:GetParent() == Minimap then
                    tooltip:AddLine("|cFF808080/br minimap|r |cFF808080to toggle this icon|r")
                end
            end,
        })
        LDBIcon:Register("BuffReminders", dataObj, BR.aceDB.global.minimap)
        LDBIcon:AddButtonToCompartment("BuffReminders")
        BR.MinimapButton = { Icon = LDBIcon, DataObj = dataObj }
    end

    C_Timer.After(5, function()
        local glob = BR.aceDB.global
        if isFirstInstall then
            -- A fresh install never had the dismiss button. Skip the transition notice.
            glob.snoozeNoticeShown = true
            glob.casterNameNoticeShown = true
            print("|cff00ccffBuffReminders:|r " .. L["Display.LoginFirstInstall"])
            return
        end
        if BR.profile.showLoginMessages ~= false and not glob.casterNameNoticeShown then
            glob.casterNameNoticeShown = true
            print("|cff00ccffBuffReminders:|r " .. L["Display.LoginCasterName"])
        end
        -- Right-click and /br snooze replace the consumable dismiss button.
        -- An existing user gets this notice one time only.
        if BR.profile.showLoginMessages ~= false and not glob.snoozeNoticeShown then
            glob.snoozeNoticeShown = true
            print("|cff00ccffBuffReminders:|r " .. L["Display.LoginSnooze"])
        end
    end)
end)
