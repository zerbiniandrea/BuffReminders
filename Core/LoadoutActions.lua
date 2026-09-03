local _, BR = ...

-- ============================================================================
-- LOADOUT ACTIONS (click-to-fix)
-- ============================================================================
-- The write half of the loadout category: equip a gear set, load a talent
-- loadout, or open the talent UI. Core/Loadouts.lua stays read-only detection.
--
-- The client blocks gear swaps and talent edits in combat, so ApplyFix guards on
-- lockdown and tells the user instead of failing in silence.

local LoadoutActions = {}

local InCombatLockdown = InCombatLockdown
local C_ClassTalents = C_ClassTalents
local C_EquipmentSet = C_EquipmentSet
local C_Timer = C_Timer
local Enum = Enum

local Loadouts = BR.Loadouts

-- The talent UI's loadout dropdown reflects the spec's "last selected saved config".
-- That stamp only sticks after the config commits. A swap that changes points returns
-- LoadInProgress and runs the "Changing Talents" cast. A stamp before that commit is
-- lost: the talent frame re-derives the dropdown on commit and shows the OLD loadout.
-- So the in-progress case defers the stamp to the next TRAIT_CONFIG_UPDATED. A
-- generation token and a timeout stop a pending stamp from landing on an unrelated
-- later commit when the cast never completes.
local dropdownSyncFrame = CreateFrame("Frame")
local pendingSync
local syncGen = 0

local function StampLastSelected(specID, configID)
    if C_ClassTalents.UpdateLastSelectedSavedConfigID then
        pcall(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, configID)
    end
    -- Blizzard bug: an ALREADY-OPEN talent frame does not re-read the last-selected
    -- config after an API change, so its loadout dropdown keeps the previous set until
    -- /reload. If the frame is loaded, nudge its dropdown with the same SetSelectionID
    -- the UI uses internally. PlayerSpellsFrame is load-on-demand and nil until the
    -- first open; an unloaded dropdown reads fresh on the next open.
    local tab = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    local dropdown = tab and tab.LoadSystem
    if dropdown and dropdown.SetSelectionID then
        pcall(dropdown.SetSelectionID, dropdown, configID)
    end
end

dropdownSyncFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    local sync = pendingSync
    pendingSync = nil
    if sync then
        StampLastSelected(sync.specID, sync.configID)
    end
end)

local function QueueDropdownSync(specID, configID)
    syncGen = syncGen + 1
    local myGen = syncGen
    pendingSync = { specID = specID, configID = configID }
    dropdownSyncFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    C_Timer.After(8, function()
        -- A newer queue bumps syncGen, so clear only a stamp from this generation.
        if myGen == syncGen and pendingSync then
            pendingSync = nil
            dropdownSyncFrame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
        end
    end)
end

-- Load a WoW named talent loadout in place. Re-resolve the configID by name for
-- the current spec first: configIDs are per-character, so the id snapshotted on the
-- rule can be stale on an alt that shares the loadout name. Falls back to the stored
-- id, and returns false when no configID resolves.
---@param rule LoadoutRule
---@return boolean
local function LoadWoWLoadout(rule)
    if not (C_ClassTalents and C_ClassTalents.LoadConfig) then
        return false
    end
    local specID = rule.specID or Loadouts.GetCurrentSpecID()
    local name = rule.loadout and rule.loadout.name
    local configID
    if name then
        for _, entry in ipairs(Loadouts.ListLoadouts(specID)) do
            if entry.name == name then
                configID = entry.configID
                break
            end
        end
    end
    configID = configID or (rule.loadout and rule.loadout.configID)
    if not configID then
        return false
    end
    local result = C_ClassTalents.LoadConfig(configID, true)
    if result == nil or result == Enum.LoadConfigResult.Error then
        return false
    end
    if result == Enum.LoadConfigResult.LoadInProgress then
        QueueDropdownSync(specID, configID)
    else
        StampLastSelected(specID, configID) -- Ready / NoChangesNecessary: applied synchronously
    end
    return true
end

---Act on a clicked reminder: equip the gear set, load the talent loadout, or open
---the talent UI.
---@param rule LoadoutRule
function LoadoutActions.ApplyFix(rule)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(BR.L["Loadout.CombatBlocked"], 1, 0.3, 0.3)
        return
    end
    if rule.require == "gear" and rule.gear and rule.gear.setID then
        pcall(C_EquipmentSet.UseEquipmentSet, rule.gear.setID)
        return
    end
    -- Talent Loadout Ex loadouts are not WoW configs, so they fall through to
    -- opening the UI.
    if rule.require == "loadout" and rule.loadout and not Loadouts.IsTLXRule(rule) then
        local ok, loaded = pcall(LoadWoWLoadout, rule)
        if ok and loaded then
            return
        end
    end
    -- talent / external loadout / unresolved: open the talent UI so the user
    -- finishes by hand.
    pcall(function()
        if PlayerSpellsUtil and PlayerSpellsUtil.OpenToClassTalentsTab then
            PlayerSpellsUtil.OpenToClassTalentsTab()
        elseif ToggleTalentFrame then
            ToggleTalentFrame()
        end
    end)
end

BR.LoadoutActions = LoadoutActions
