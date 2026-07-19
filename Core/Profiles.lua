local _, BR = ...

-- ============================================================================
-- PROFILE SYSTEM (AceDB-3.0 + LibDualSpec-1.0)
-- ============================================================================
-- Thin wrapper around AceDB-3.0 for profile management.
-- BR.profile is a proxy table that always routes reads/writes to the active
-- AceDB profile, so closures capturing `local db = BR.profile` stay valid
-- across profile switches.

BR.Profiles = {}

-- Queue for combat-deferred profile switch
local pendingSwitch = nil

-- When true, OnProfileEvent skips RefreshAfterProfileChange (used to batch
-- SetProfile + CopyProfile into a single refresh).
local suppressRefresh = false

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

---Initialize AceDB and the profile proxy
---@param aceDefaults table AceDB defaults table with profile/global keys
function BR.Profiles.Initialize(aceDefaults)
    BR.aceDB = LibStub("AceDB-3.0"):New("BuffRemindersDB", aceDefaults, true)

    -- Profile proxy: closure-safe access to active profile.
    -- All code uses `local db = BR.profile` and reads/writes go through here
    -- to the current AceDB profile, even after profile switches.
    BR.profile = setmetatable({}, {
        __index = function(_, key)
            return BR.aceDB.profile[key]
        end,
        __newindex = function(_, key, value)
            BR.aceDB.profile[key] = value
        end,
    })

    -- LibDualSpec enhancement (per-spec profile switching)
    local LibDualSpec = LibStub("LibDualSpec-1.0", true)
    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(BR.aceDB, "BuffReminders")
    end

    -- Register AceDB callbacks for profile changes
    BR.aceDB.RegisterCallback(BR.Profiles, "OnProfileChanged", "OnProfileEvent")
    BR.aceDB.RegisterCallback(BR.Profiles, "OnProfileCopied", "OnProfileEvent")
    BR.aceDB.RegisterCallback(BR.Profiles, "OnProfileReset", "OnProfileEvent")
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

---Suppress refresh callbacks for the duration of fn(), then fire one refresh.
---Used to batch several profile mutations (e.g. SetProfile + import writes)
---into a single refresh cycle.
---@param fn function
function BR.Profiles.BatchOperation(fn)
    suppressRefresh = true
    local ok, err = pcall(fn)
    suppressRefresh = false
    if ok then
        BR.Profiles.RefreshAfterProfileChange()
    else
        -- Still refresh to ensure consistent state, then propagate the error
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
        print("|cffffcc00BuffReminders:|r " .. BR.L["Profile.SwitchQueued"])
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

---Fill missing keys in `target` from code `source`, recursively. Skips `minimap`
---(lives in AceDB global, not per-profile) and the `defaults` sub-table (served by
---the metatable __index - only ensures the table exists). Used by the bootstrap on
---login and on every profile switch/copy/reset.
---@param source table code defaults (BR.defaults)
---@param target table profile table to fill
local function DeepCopyDefault(source, target)
    for k, v in pairs(source) do
        if k == "minimap" then -- luacheck: ignore 542
            -- Skip: lives in AceDB global, not per-profile
        elseif k == "defaults" then
            -- Skip value copy (served by metatable __index), but ensure the table exists
            if target[k] == nil then
                target[k] = {}
            end
        elseif target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                DeepCopyDefault(v, target[k])
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            -- Recursively fill in missing nested keys
            DeepCopyDefault(v, target[k])
        end
    end
end
BR.Profiles.DeepCopyDefault = DeepCopyDefault

---Re-apply the defaults metatable on the active profile's defaults table
function BR.Profiles.ReapplyDefaultsMetatable()
    local codeDefaults = BR.defaults
    if not codeDefaults then
        return
    end
    local db = BR.profile
    if not db.defaults then
        db.defaults = {}
    end
    setmetatable(db.defaults, { __index = codeDefaults.defaults })
end

---Full display refresh after profile data changes (switch, copy, reset).
---Re-applies defaults metatable, rebuilds custom buffs, fires all refresh
---callbacks, recomputes state, and repositions frames.
function BR.Profiles.RefreshAfterProfileChange()
    -- Re-apply defaults metatable for the active profile's defaults table
    BR.Profiles.ReapplyDefaultsMetatable()

    -- Deep copy defaults into the new profile (materializes keys for pairs() iteration)
    if BR.defaults then
        DeepCopyDefault(BR.defaults, BR.profile)
    end

    -- Rebuild custom buffs if present
    if BR.Display and BR.Display.BuildCustomBuffArray then
        BR.Display.BuildCustomBuffArray()
    end

    -- Rebuild loadout reminders if present
    if BR.Display and BR.Display.BuildLoadoutRulesArray then
        BR.Display.BuildLoadoutRulesArray()
    end

    -- The category-settings memo may still hold the PREVIOUS profile's values
    -- (nothing has fired a refresh event yet); wipe it before SyncDirectionCache
    -- reads grow directions through it, or the LayoutRefresh below would see a
    -- spurious direction change and convert (corrupt) the new profile's positions.
    if BR.Display and BR.Display.InvalidateCategorySettingsCache then
        BR.Display.InvalidateCategorySettingsCache()
    end

    -- Sync direction cache before firing LayoutRefresh to prevent spurious position conversions
    if BR.Movers and BR.Movers.SyncDirectionCache then
        BR.Movers.SyncDirectionCache()
    end

    -- Fire all refresh callbacks in the correct order
    local registry = BR.CallbackRegistry
    registry:TriggerEvent("FramesReparent")
    registry:TriggerEvent("VisualsRefresh")
    registry:TriggerEvent("LayoutRefresh")
    registry:TriggerEvent("DisplayRefresh")

    -- Re-sort consumable cache (remembered items and legacy filter may differ between profiles)
    if BR.SecureButtons and BR.SecureButtons.InvalidateConsumableCache then
        BR.SecureButtons.InvalidateConsumableCache()
    end

    -- Refresh chat-request macrotext: per-profile chatRequestMessages may differ.
    if BR.SecureButtons and BR.SecureButtons.RefreshChatRequestMacros then
        BR.SecureButtons.RefreshChatRequestMacros()
    end

    -- Recompute buff state
    if BR.BuffState then
        BR.BuffState.Refresh()
    end

    -- Reposition container frames from profile's saved positions
    if BR.Movers then
        if BR.Movers.RepositionAllFrames then
            BR.Movers.RepositionAllFrames()
        end
        if BR.Movers.UpdateAnchor then
            BR.Movers.UpdateAnchor()
        end
    end

    -- Refresh UI components (dropdowns, checkboxes, etc.)
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
        print("|cffffcc00BuffReminders:|r " .. string.format(BR.L["Profile.Switched"], name))
    end
end)
