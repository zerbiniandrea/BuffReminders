local _, BR = ...

-- ============================================================================
-- EXTERNALS: SOUND ALERTS
-- ============================================================================
-- Plays a sound when a tracked external lands on the player. These auras are
-- secret, so no Lua code can see one arrive: the trigger must live in the
-- engine. AddAuraSound registers a spell ID plus a file, and the client plays it.
--
-- AddAuraSound is refused while an addon restriction is active, so a denied
-- registration waits for the lift. RemoveAuraSound carries no such restriction,
-- so removals always run and only additions defer.
--
-- A resolved sound is a file path OR a file ID, and the two go in different struct
-- fields. The wrong field is rejected silently, with no sound and no error.
--
-- Two entries can list the same spell ID, because the player's own entries are free
-- to repeat a curated one. Two handles on one ID play the sound twice, so each ID is
-- claimed once per pass and the earlier entry wins.

local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

local Resolve = BR.Sounds.Resolve

local AddAuraSound = C_UnitAuras.AddAuraSound
local RemoveAuraSound = C_UnitAuras.RemoveAuraSound
local IsAddOnRestrictionActive = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive

local RESTRICTION = Enum.AddOnRestrictionType
local TRIGGER_ADDED = Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added or 0
-- Same channel the addon plays its reminder sounds on (Display.lua).
local CHANNEL = "Master"

local Settings = BR.GetExternalSettings
local Entries = BR.GetExternalEntries
local EntrySound = BR.GetExternalEntrySound

---@class AuraSoundRegistration
---@field sound string|number  -- file path or file ID
---@field spellIDs number[]    -- the IDs this entry claimed
---@field ids number[]         -- AddAuraSound handles, one per claimed ID
---@type table<string, AuraSoundRegistration>
local active = {}
-- Set when a registration was refused, so the lift watcher retries.
local pending = false

---True while a registration is refused. An encounter blocks it outright; a
---keystone run blocks it once combat starts.
---@return boolean
local function IsRestricted()
    if not (IsAddOnRestrictionActive and RESTRICTION) then
        return false
    end
    if IsAddOnRestrictionActive(RESTRICTION.Encounter) then
        return true
    end
    return IsAddOnRestrictionActive(RESTRICTION.ChallengeMode) and IsAddOnRestrictionActive(RESTRICTION.Combat) == true
end

---@param key string
local function Remove(key)
    local registration = active[key]
    if not registration then
        return
    end
    local ids = registration.ids
    for i = #ids, 1, -1 do
        RemoveAuraSound(ids[i])
    end
    active[key] = nil
end

---One handle per spell ID. A partial registration reads as complete on the next
---reconcile. If one call fails, Register drops the new handles and the entry waits.
---@param key string
---@param spellIDs number[]
---@param sound string|number A file path or a file ID
---@param throttle number? Seconds before the same handle may play again
local function Register(key, spellIDs, sound, throttle)
    local ids = {}
    -- One table for the whole loop: AddAuraSound reads it synchronously.
    local info = {
        unitToken = "player",
        soundFileName = type(sound) == "string" and sound or nil,
        soundFileID = type(sound) == "number" and sound or nil,
        outputChannel = CHANNEL,
        throttleSeconds = throttle,
    }

    for _, spellID in ipairs(spellIDs) do
        info.spellID = spellID
        local ok, handle = pcall(AddAuraSound, TRIGGER_ADDED, info)
        if not ok or not handle then
            for i = #ids, 1, -1 do
                RemoveAuraSound(ids[i])
            end
            pending = true
            return
        end
        ids[#ids + 1] = handle
    end

    active[key] = { sound = sound, spellIDs = spellIDs, ids = ids }
end

---True when two ID lists hold the same IDs in the same order.
---@param a number[]
---@param b number[]
---@return boolean
local function SameIDs(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

---Sound and owned spell IDs per entry key, for the entries that must play one.
---An entry whose every ID belongs to an earlier entry drops out here.
---@return table<string, table>
local function BuildDesired()
    local desired = {}
    local enabled = Settings().entries
    -- A sound belongs to an external the player tracks, so the entry's own
    -- checkbox is the gate.
    if not enabled then
        return desired
    end

    local claimed = {}
    for _, entry in ipairs(Entries()) do
        if enabled[entry.key] then
            local sound = Resolve(EntrySound(entry))
            if sound then
                local owned = {}
                for _, spellID in ipairs(entry.spellIDs) do
                    if not claimed[spellID] then
                        claimed[spellID] = true
                        owned[#owned + 1] = spellID
                    end
                end
                if owned[1] then
                    desired[entry.key] = { sound = sound, spellIDs = owned, throttle = entry.soundThrottle }
                end
            end
        end
    end

    return desired
end

---Bring the engine registrations in line with the settings.
local function Reconcile()
    if not AddAuraSound then
        return
    end

    local desired = BuildDesired()

    -- Clearing the current key during traversal is legal in Lua 5.1.
    for key, registration in pairs(active) do
        local want = desired[key]
        if not want or want.sound ~= registration.sound or not SameIDs(want.spellIDs, registration.spellIDs) then
            Remove(key)
        end
    end

    pending = false
    local restricted = IsRestricted()

    for _, entry in ipairs(Entries()) do
        local want = desired[entry.key]
        if want and not active[entry.key] then
            if restricted then
                pending = true
            else
                Register(entry.key, want.spellIDs, want.sound, want.throttle)
            end
        end
    end
end

local watcher = CreateFrame("Frame")
-- Registrations do not survive a reload, so login rebuilds them all.
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
watcher:SetScript("OnEvent", function(_, event, _, state)
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        -- state 0 = Enum.AddOnRestrictionState.Inactive. Only a lift lets a
        -- refused registration through.
        if state ~= 0 or not pending then
            return
        end
    end
    Reconcile()
end)

BR.CallbackRegistry:RegisterCallback("ExternalsRefresh", Reconcile)

BR.AuraSounds = {
    Reconcile = Reconcile,
}
