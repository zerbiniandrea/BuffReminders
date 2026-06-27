local addonName, BR = ...

local L = BR.L

-- ============================================================================
-- ADDON BOOTSTRAP
-- ============================================================================
-- Runs once on ADDON_LOADED: SavedVariables/AceDB setup, versioned migrations,
-- default seeding, and options/minimap registration. Owns its own event frame -
-- each module owns the events it consumes (cf. Display.lua, State.lua). Loads
-- after Display.lua so the BR.Display.* builder/registration helpers exist.

local defaults = BR.defaults
local CATEGORIES = BR.CATEGORY_ORDER

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= addonName then
        return
    end
    bootstrapFrame:UnregisterEvent("ADDON_LOADED")

    BR.Display.SetPlayerClass((select(2, UnitClass("player"))))
    local isFirstInstall = not BuffRemindersDB
    if not BuffRemindersDB then
        BuffRemindersDB = {}
    end

    -- ====================================================================
    -- Pre-AceDB migration: wrap the old flat SavedVariables layout (root-level
    -- iconSize/categorySettings/etc., no profiles) into the AceDB structure so
    -- AceDB:New() adopts the existing data instead of seeing a fresh install.
    -- Also runs on first install (empty table), seeding an empty profile.
    -- ====================================================================
    if not rawget(BuffRemindersDB, "profiles") then
        -- Old flat format -> AceDB format
        local profileData, globalData = {}, {}
        for k, v in pairs(BuffRemindersDB) do
            if k == "minimap" then
                globalData[k] = v
            else
                profileData[k] = v
            end
        end
        wipe(BuffRemindersDB)
        rawset(BuffRemindersDB, "profiles", { ["Default"] = profileData })
        rawset(BuffRemindersDB, "profileKeys", {})
        rawset(BuffRemindersDB, "global", globalData)
    end

    -- Build AceDB defaults (minimap is global, everything else is per-profile)
    local aceDefaults = {
        profile = {},
        global = { minimap = defaults.minimap },
    }
    for k, v in pairs(defaults) do
        if k ~= "minimap" then
            aceDefaults.profile[k] = v
        end
    end

    -- Initialize AceDB + profile proxy
    BR.Profiles.Initialize(aceDefaults)

    local db = BR.profile

    -- ====================================================================
    -- Versioned migrations - each runs exactly once, tracked by dbVersion.
    -- Migration functions live in Core/Migrations.lua (append-only; never
    -- delete or renumber - old profiles can return from any version).
    -- ====================================================================
    BR.Migrations.Run(db, defaults, { CATEGORIES = CATEGORIES })

    -- Deep copy defaults for non-defaults tables
    BR.Profiles.DeepCopyDefault(defaults, db)

    -- Initialize custom buffs storage and populate BUFF_TABLES.custom
    if not db.customBuffs then
        db.customBuffs = {}
    end
    BR.Display.BuildCustomBuffArray()

    -- Initialize loadout reminders storage and populate BUFF_TABLES.loadout
    if not db.loadoutReminders then
        db.loadoutReminders = {}
    end
    BR.Display.BuildLoadoutRulesArray()

    -- Register custom buffs in glow fallback lookup (so they work in M+/combat)
    for _, customBuff in ipairs(BR.BUFF_TABLES.custom) do
        if customBuff.glowMode ~= "disabled" then
            BR.Display.RegisterGlowBuff(customBuff, "custom")
        end
    end

    -- Set up metatable so db.defaults inherits from code defaults
    if not db.defaults then
        db.defaults = {}
    end
    setmetatable(db.defaults, { __index = defaults.defaults })

    -- Initialize categoryVisibility with defaults for each category
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

    -- Register with WoW's Interface Options
    local settingsPanel = CreateFrame("Frame")
    settingsPanel.name = "BuffReminders"

    local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BuffReminders")

    local desc = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(L["Display.Description"])

    local openBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
    openBtn:SetSize(150, 24)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText(L["Display.OpenOptions"])
    openBtn:SetScript("OnClick", function()
        BR.Options.Toggle()
        -- Close the WoW settings panel properly (HideUIPanel handles keyboard focus cleanup)
        if SettingsPanel then
            HideUIPanel(SettingsPanel)
        end
    end)

    local slashInfo = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    slashInfo:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -12)
    slashInfo:SetText(L["Display.SlashCommands"])

    local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
    Settings.RegisterAddOnCategory(category)

    -- Minimap button (LibDBIcon)
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

    -- Login messages
    local GLOW_NOTICE_MAX = 5 -- show the glow-default change notice for this many logins
    C_Timer.After(5, function()
        local glob = BR.aceDB.global
        if isFirstInstall then
            -- Fresh installs already default to no glow; suppress the change notice.
            glob.glowDefaultNoticeCount = GLOW_NOTICE_MAX
            print("|cff00ccffBuffReminders:|r " .. L["Display.LoginFirstInstall"])
            return
        end
        -- Glow default flipped to off for existing users who never explicitly
        -- enabled it. Shown for the first few logins (one-time messages are
        -- easily missed), regardless of showLoginMessages, then stops. Does not
        -- replace the regular login message - both can print the same login.
        if (glob.glowDefaultNoticeCount or 0) < GLOW_NOTICE_MAX then
            glob.glowDefaultNoticeCount = (glob.glowDefaultNoticeCount or 0) + 1
            print("|cff00ccffBuffReminders:|r " .. L["Display.LoginGlowDefaultChanged"])
        end
        if BR.profile.showLoginMessages ~= false then
            print("|cff00ccffBuffReminders:|r " .. L["Display.LoginLoadout"])
        end
    end)
end)
