local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- PROFILE SYSTEM (AceDB-3.0 + LibDualSpec-1.0)
-- ============================================================================

BR.Profiles = {}

-- Queue for combat-deferred profile switch
local pendingSwitch = nil

-- When true, OnProfileEvent skips RefreshAfterProfileChange.
local suppressRefresh = false

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

---Initialize AceDB and the profile proxy
---@param aceDefaults table AceDB defaults table with profile/global keys
function BR.Profiles.Initialize(aceDefaults)
    BR.aceDB = LibStub("AceDB-3.0"):New("BuffRemindersDB", aceDefaults, true)
    -- LibDualSpec can switch profiles inside EnhanceDatabase, so this callback must register first.
    BR.aceDB.RegisterCallback(BR.Profiles, "OnNewProfile", "StampCurrentVersion")

    -- The proxy routes each read and write to the active AceDB profile. A closure
    -- that captures `local db = BR.profile` stays valid across profile switches.
    ---@type BRProfile
    BR.profile = setmetatable({}, {
        __index = function(_, key)
            return BR.aceDB.profile[key]
        end,
        __newindex = function(_, key, value)
            BR.aceDB.profile[key] = value
        end,
    })

    local LibDualSpec = LibStub("LibDualSpec-1.0", true)
    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(BR.aceDB, "BuffReminders")
    end

    BR.aceDB.RegisterCallback(BR.Profiles, "OnProfileChanged", "OnProfileEvent")
    BR.aceDB.RegisterCallback(BR.Profiles, "OnProfileCopied", "OnProfileEvent")
    BR.aceDB.RegisterCallback(BR.Profiles, "OnProfileReset", "OnProfileReset")
end

-- ============================================================================
-- PROFILE EVENT HANDLER
-- ============================================================================

---Called by AceDB when the active profile changes (switch, copy, reset)
function BR.Profiles.OnProfileEvent()
    if suppressRefresh then
        return
    end
    BR.Profiles.RefreshAfterProfileChange()
end

---A new or reset profile holds current-format data, so it carries the current dbVersion.
---@param database table AceDB database object
function BR.Profiles.StampCurrentVersion(_, _, database)
    database.profile.dbVersion = BR.Migrations.DB_VERSION
end

function BR.Profiles.OnProfileReset(_, _, database)
    BR.Profiles.StampCurrentVersion(nil, nil, database)
    BR.Profiles.OnProfileEvent()
end

---Suppress refresh callbacks for the duration of fn(), then fire one refresh.
---@param fn function
function BR.Profiles.BatchOperation(fn)
    suppressRefresh = true
    local ok, err = pcall(fn)
    suppressRefresh = false
    if ok then
        BR.Profiles.RefreshAfterProfileChange()
    else
        -- Refresh also on failure to keep the state consistent, then propagate the error
        BR.Profiles.RefreshAfterProfileChange()
        error(err, 2)
    end
end

-- ============================================================================
-- PROFILE CRUD (delegates to AceDB)
-- ============================================================================

---Get the active profile name
---@return string
function BR.Profiles.GetActiveProfileName()
    if not BR.aceDB then
        return "Default"
    end
    return BR.aceDB:GetCurrentProfile()
end

---List all profile names (sorted)
---@return string[]
function BR.Profiles.ListProfiles()
    if not BR.aceDB then
        return { "Default" }
    end
    local profiles = {}
    BR.aceDB:GetProfiles(profiles)
    table.sort(profiles)
    return profiles
end

---Switch to a different profile (queues if in combat)
---@param name string Profile name
---@return boolean success
function BR.Profiles.SwitchProfile(name)
    if name == BR.Profiles.GetActiveProfileName() then
        return true
    end
    if InCombatLockdown() then
        pendingSwitch = name
        print("|cff00ccffBuffReminders:|r " .. BR.L["Profile.SwitchQueued"])
        return true
    end
    BR.aceDB:SetProfile(name) -- fires OnProfileChanged -> RefreshAfterProfileChange
    return true
end

---Copy another profile's settings into the active profile
---@param sourceName string Source profile name
---@return boolean success
function BR.Profiles.CopyProfile(sourceName)
    BR.aceDB:CopyProfile(sourceName) -- fires OnProfileCopied -> RefreshAfterProfileChange
    return true
end

---Delete a profile
---@param name string Profile name to delete
---@return boolean success
function BR.Profiles.DeleteProfile(name)
    BR.aceDB:DeleteProfile(name)
    return true
end

---Reset the active profile to defaults
---@return boolean success
function BR.Profiles.ResetProfile()
    BR.aceDB:ResetProfile() -- fires OnProfileReset -> RefreshAfterProfileChange
    return true
end

-- ============================================================================
-- PER-SPEC PROFILES (LibDualSpec)
-- ============================================================================

---Check if per-spec profiles are enabled
---@return boolean
function BR.Profiles.IsPerSpecEnabled()
    if not BR.aceDB or not BR.aceDB.IsDualSpecEnabled then
        return false
    end
    return BR.aceDB:IsDualSpecEnabled()
end

---Enable or disable per-spec profiles
---@param enabled boolean
function BR.Profiles.SetPerSpecEnabled(enabled)
    if not BR.aceDB or not BR.aceDB.SetDualSpecEnabled then
        return
    end
    BR.aceDB:SetDualSpecEnabled(enabled)
end

---Get the profile assigned to a specific spec
---@param specIndex number
---@return string
function BR.Profiles.GetSpecProfile(specIndex)
    if not BR.aceDB or not BR.aceDB.GetDualSpecProfile then
        return BR.Profiles.GetActiveProfileName()
    end
    return BR.aceDB:GetDualSpecProfile(specIndex) or BR.Profiles.GetActiveProfileName()
end

---Set the profile for a specific spec
---@param specIndex number
---@param profileName string
function BR.Profiles.SetSpecProfile(specIndex, profileName)
    if not BR.aceDB or not BR.aceDB.SetDualSpecProfile then
        return
    end
    BR.aceDB:SetDualSpecProfile(profileName, specIndex)
end

-- ============================================================================
-- REFRESH AFTER PROFILE CHANGE
-- ============================================================================

---Fill missing keys in `target` from code `source`, recursively. Skips `minimap`.
---@param source table code defaults (BR.defaults)
---@param target table profile table to fill
local function DeepCopyDefault(source, target)
    for k, v in pairs(source) do
        if k == "minimap" then -- luacheck: ignore 542
            -- minimap lives in the AceDB global, not in the profile
        elseif target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                DeepCopyDefault(v, target[k])
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            DeepCopyDefault(v, target[k])
        end
    end
end

---Full display refresh after profile data changes (switch, copy, reset, import).
function BR.Profiles.RefreshAfterProfileChange()
    -- An import replaces whole profile keys outside AceDB, so the defaults that the
    -- string leaves out must be filled here.
    if BR.defaults then
        DeepCopyDefault(BR.defaults, BR.profile)
    end

    if BR.Display and BR.Display.BuildCustomBuffArray then
        BR.Display.BuildCustomBuffArray()
    end
    BR.GameContext.RebuildGlowRegistry()

    if BR.Display and BR.Display.BuildLoadoutRulesArray then
        BR.Display.BuildLoadoutRulesArray()
    end

    -- No refresh event fired yet, so the category-settings memo can still hold the
    -- PREVIOUS profile's values. Wipe it before SyncDirectionCache reads the grow
    -- directions through it. If not, the LayoutRefresh below sees a spurious
    -- direction change and corrupts the new profile's positions.
    if BR.Display and BR.Display.InvalidateCategorySettingsCache then
        BR.Display.InvalidateCategorySettingsCache()
    end

    -- SyncDirectionCache must run before LayoutRefresh.
    if BR.Movers and BR.Movers.SyncDirectionCache then
        BR.Movers.SyncDirectionCache()
    end

    local registry = BR.CallbackRegistry
    registry:TriggerEvent("FramesReparent")
    registry:TriggerEvent("VisualsRefresh")
    registry:TriggerEvent("LayoutRefresh")
    registry:TriggerEvent("DisplayRefresh")
    -- ExternalsRefresh is explicit here. The externals VisualsRefresh subscription
    -- only propagates font changes, but the enabled flag, entry set, position and
    -- sizing are all per-profile.
    registry:TriggerEvent("ExternalsRefresh")

    -- The remembered items and the legacy filter can differ between profiles.
    if BR.SecureButtons and BR.SecureButtons.InvalidateConsumableCache then
        BR.SecureButtons.InvalidateConsumableCache()
    end

    -- chatRequestMessages can differ between profiles.
    if BR.SecureButtons and BR.SecureButtons.RefreshChatRequestMacros then
        BR.SecureButtons.RefreshChatRequestMacros()
    end

    if BR.Movers then
        if BR.Movers.RepositionAllFrames then
            BR.Movers.RepositionAllFrames()
        end
        if BR.Movers.UpdateAnchor then
            BR.Movers.UpdateAnchor()
        end
    end

    if BR.Components and BR.Components.RefreshAll then
        BR.Components.RefreshAll()
    end
end

-- ============================================================================
-- COMBAT DEFERRAL
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and pendingSwitch then
        local name = pendingSwitch
        pendingSwitch = nil
        BR.aceDB:SetProfile(name) -- fires OnProfileChanged -> RefreshAfterProfileChange
        print("|cff00ccffBuffReminders:|r " .. string.format(BR.L["Profile.Switched"], name))
    end
end)
