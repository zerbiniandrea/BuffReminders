local _, BR = ...

-- ============================================================================
-- TALENT LOADOUT EX INTEGRATION
-- ============================================================================
-- Reads the loadouts of the Talent Loadout Ex addon. Its loadouts are not WoW
-- named loadouts, so `C_ClassTalents` cannot see them at all.
--
-- READINESS. The addon answers from a list it builds in a frame initializer that
-- runs only after Blizzard_PlayerSpells loads. Until then it reports an empty
-- list, which reads the same as "no loadout matches". Every negative answer
-- passes the readiness gate first, so an addon that cannot answer yet says so.

local TalentLoadoutEx = {}

local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitClass = UnitClass
local GetSpecialization = GetSpecialization
local C_AddOns = C_AddOns
local C_ClassTalents = C_ClassTalents
local C_Traits = C_Traits

-- Whether the addon is installed and exposes its API. Memoized once positive: an
-- addon cannot unload mid-session. Re-probed while absent, because its load order
-- relative to BuffReminders is not guaranteed. An early probe must not poison the
-- result into skipping forever.
local available = false
local function IsAvailable()
    if available then
        return true
    end
    ---@diagnostic disable-next-line: undefined-field
    local api = _G.TLX
    available = api ~= nil and api.GetLoadedData ~= nil
    return available
end
TalentLoadoutEx.IsAvailable = IsAvailable

-- The addon rebuilds its loaded list 0.1s after the event that changed the
-- talents. An answer read inside that window can hold the previous build, so the
-- readiness check waits for the window to end.
local SETTLE_SECONDS = 0.5
local readySince = nil

local function ResolveTalentTreeReady()
    ---@diagnostic disable-next-line: undefined-field
    local playerSpells = _G.PlayerSpellsFrame
    local talents = playerSpells and playerSpells.TalentsFrame
    if not talents or not talents.GetTreeInfo then
        return false
    end
    local treeInfo = talents:GetTreeInfo()
    return treeInfo ~= nil and treeInfo.ID ~= nil
end

---Whether the addon holds a loaded-loadout list that can be trusted. It builds
---that list from the talent frame's export string, so a frame that reports no
---tree yields an empty list. See the READINESS note at the top of the file.
---@return boolean
local function IsReady()
    ---@diagnostic disable-next-line: undefined-field
    if not IsAvailable() or not _G.TalentLoadoutExMainFrame then
        readySince = nil
        return false
    end
    local ok, ready = pcall(ResolveTalentTreeReady)
    if not ok or not ready then
        readySince = nil
        return false
    end
    readySince = readySince or GetTime()
    return (GetTime() - readySince) >= SETTLE_SECONDS
end

local loadRequested = false

---Ask the client to load Blizzard_PlayerSpells, so the addon runs its frame
---initializer without player action. It registers that initializer on the addon's
---load event and never requests the load itself. The load alone can leave the
---talent frame without a tree, so `IsReady` still decides whether answers count.
---Runs one time for each session.
function TalentLoadoutEx.EnsureReady()
    if loadRequested or InCombatLockdown() or not IsAvailable() or IsReady() then
        return
    end
    loadRequested = true
    pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
end

-- Resolve the stored loadout list for the current class + spec. The addon keys its
-- saved variables account-wide by class token + spec INDEX (not spec ID). Returns
-- nil when the addon is absent or has nothing saved for this spec. Callers wrap
-- this in pcall.
local function GetSpecTable()
    -- The addon's saved variables carry the same name as this module's namespace.
    ---@diagnostic disable-next-line: undefined-field
    local savedVariables = _G.TalentLoadoutEx
    if not savedVariables then
        return nil
    end
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    if not class or not specIndex then
        return nil
    end
    return savedVariables[class] and savedVariables[class][specIndex]
end

local function FindData(name)
    local specTable = GetSpecTable()
    if not specTable then
        return nil
    end
    for _, data in ipairs(specTable) do
        if data.text and data.name == name then
            return data
        end
    end
    return nil
end

local function ResolveLoadoutIcon(name)
    local data = FindData(name)
    return data and data.icon or nil
end

---Live-resolve a loadout's icon by name. The icon is a fileID number or an
---atlas/path string. Returns nil when the addon is absent or the name is not
---found, so callers fall back to their own icon.
---@param name string?
---@return number|string?
function TalentLoadoutEx.GetLoadoutIcon(name)
    if not name or not IsAvailable() then
        return nil
    end
    local ok, icon = pcall(ResolveLoadoutIcon, name)
    return ok and icon or nil
end

local function ResolveLoadoutActive(name)
    -- GetLoadedData() varargs the loadouts the addon holds as loaded. It diffs each
    -- stored talent string against the active config. The pack makes the result
    -- scannable, and stays empty when the addon computes none.
    ---@diagnostic disable-next-line: undefined-field
    local loaded = { _G.TLX.GetLoadedData() }
    for _, data in ipairs(loaded) do
        if data and data.name == name then
            return true
        end
    end
    return false
end

-- Second opinion for a negative answer: the active config serialized to an import
-- string. An exact match with the stored string proves the loadout is active while
-- the addon's list still holds the previous build. The reverse does not hold - an
-- imported build keeps the string it came with, so a mismatch decides nothing and
-- the addon's answer stands.
local function ResolveLoadoutActiveByString(name)
    local data = FindData(name)
    if not data or not data.text then
        return false
    end
    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID()
    if not configID or not C_Traits then
        return false
    end
    return C_Traits.GenerateImportString(configID) == data.text
end

---Whether the named loadout (matched within the current spec) is the one now
---loaded.
---The second return value reports whether the answer is settled. An unsettled
---answer reads as active, so an addon that cannot answer yet raises no reminder,
---and callers must not cache it.
---@param name string?
---@return boolean active
---@return boolean known
function TalentLoadoutEx.IsLoadoutActive(name)
    if not name then
        return true, true
    end
    if not IsReady() then
        return true, false
    end
    local ok, active = pcall(ResolveLoadoutActive, name)
    if not ok then
        return true, false
    end
    if active then
        return true, true
    end
    local matched
    ok, matched = pcall(ResolveLoadoutActiveByString, name)
    return (ok and matched) or false, true
end

---List the loadouts saved for the current class + spec. Group headers (entries
---without a `.text` talent string) are skipped. Returns an empty list when the
---addon is absent, so a picker self-gates on its presence.
---@return { name: string, icon: number|string? }[]
function TalentLoadoutEx.ListLoadouts()
    local out = {}
    if not IsAvailable() then
        return out
    end
    pcall(function()
        local specTable = GetSpecTable()
        if not specTable then
            return
        end
        for _, data in ipairs(specTable) do
            if data.text and data.name then
                out[#out + 1] = { name = data.name, icon = data.icon }
            end
        end
    end)
    return out
end

BR.TalentLoadoutEx = TalentLoadoutEx
