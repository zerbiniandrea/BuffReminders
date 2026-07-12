local _, BR = ...

-- ============================================================================
-- LOADOUT DETECTION (talents / talent loadouts / equipment sets)
-- ============================================================================
-- Pure detection helpers for the "loadout" reminder category. None of these
-- touch the aura API, so they stay accurate in combat / encounters / M+ (the
-- exact contexts the rest of the addon fights the aura whitelist over).
--
-- A loadout *rule* (stored in BR.profile.loadoutReminders) has the shape:
--   {
--     key, name, require = "gear" | "talent" | "loadout",
--     overlayText,                       -- shown when the rule is unmet
--     icon,                              -- fileID fallback (live icon via GetRuleIcon)
--     -- require == "gear":    gear = { setID, name }
--     -- require == "talent":  spellID = <talent spell>
--     -- require == "loadout": specID, loadout = { name, configID }              (WoW named loadout)
--     --                       specID, loadout = { name, source = "tlex" }       (Talent Loadout Ex loadout)
--     when = { <content gates, same shape as CustomBuff.loadConditions>,
--              instances = { { id, mapID, name }, ... } },  -- empty = any
--     clickToFix = boolean,
--   }
-- "Satisfied" == the player is already set up correctly (no reminder shown).
--
-- BINDING (who a rule applies to). The detection IDs are scoped, so each rule
-- type binds to the character/spec it was created on and stays hidden elsewhere
-- (otherwise a shared profile leaks one toon's rules onto another as false
-- reminders you can't satisfy). Stamped at save time, enforced by
-- AppliesToCurrentCharacter, surfaced in the list by GetBindingLabel:
--   * require "talent"  -> spec-bound (talents live in a spec tree)       -> specID
--   * require "loadout" (WoW)  -> character + spec bound (configID per-toon) -> character + specID
--   * require "loadout" (tlex) -> spec-bound (TLEx data is account-wide by class+spec) -> specID
--   * require "gear"    -> character-bound (setID is per-character)        -> character
-- Rules saved before binding existed (no specID / character) apply everywhere.

local Loadouts = {}

-- Cache WoW API (file-scope locals; these never change at runtime).
local IsSpellKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown
local IsPlayerSpell = IsPlayerSpell
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecializationInfoByID = GetSpecializationInfoByID
local UnitName = UnitName
local UnitClass = UnitClass
local GetRealmName = GetRealmName
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local C_ClassTalents = C_ClassTalents
local C_Traits = C_Traits
local C_EquipmentSet = C_EquipmentSet
local C_ChallengeMode = C_ChallengeMode
local C_Spell = C_Spell
local C_Timer = C_Timer
local Enum = Enum

local DEFAULT_TALENT_ICON = 133741 -- inv_misc_book_09: generic talent/loadout book icon, last resort
local DEFAULT_GEAR_ICON = 7539422 -- ui-transmog-showequippedgear: nicer fallback for icon-less sets
-- INV_Misc_QuestionMark: the "?" both WoW's Equipment Manager and TLEx store as a
-- set/loadout's icon when the user never picked one. Treated as "no real icon" so
-- we can swap in a meaningful default instead of showing the "?" on the reminder.
local QUESTION_MARK_ICON = 134400

-- Bodies are hoisted to file scope (not inline `pcall(function() ... end)`) so the
-- refresh-path callers below don't allocate a closure per rule per refresh.
local function ResolveCurrentSpecID()
    local idx = GetSpecialization()
    if not idx then
        return 0
    end
    return (GetSpecializationInfo(idx)) or 0
end

---Resolve the player's current spec ID (0 if none / not yet available).
---Prefers State's cached spec (`BR.StateHelpers.GetPlayerSpecId`, invalidated on
---PLAYER_SPECIALIZATION_CHANGED) so the per-rule refresh gating reuses one cached
---value instead of re-querying the spec API per rule. Falls back to a live query
---when StateHelpers isn't available yet (Loadouts loads before State).
---@return number
local function GetCurrentSpecID()
    local helpers = BR.StateHelpers
    if helpers and helpers.GetPlayerSpecId then
        return helpers.GetPlayerSpecId() or 0
    end
    local ok, specID = pcall(ResolveCurrentSpecID)
    return (ok and specID) or 0
end
Loadouts.GetCurrentSpecID = GetCurrentSpecID

-- Character identity never changes during a session, so memoize it once. Only
-- cached after name AND realm resolve, so an early call can't poison it with "?".
local cachedCharacterKey

---Stable identity for the current character ("Name - Realm"). Equipment / loadout
---rules bind to this because their IDs (setID, configID) are per-character.
---@return string
function Loadouts.GetCurrentCharacterKey()
    if cachedCharacterKey then
        return cachedCharacterKey
    end
    local name, realm = UnitName("player"), GetRealmName()
    local key = (name or "?") .. " - " .. (realm or "?")
    if name and realm then
        cachedCharacterKey = key
    end
    return key
end

---Localized spec name for a spec ID, or nil if unavailable.
---@param specID number?
---@return string?
local function ResolveSpecName(specID)
    if not specID then
        return nil
    end
    -- GetSpecializationInfoByID -> id, name, ...
    local ok, _, name = pcall(GetSpecializationInfoByID, specID)
    return (ok and name) or nil
end

---Display-only character name with the realm stripped off. Matching still uses
---the full "Name - Realm" stored on the rule; the realm just bloats the list
---label and is redundant for the common single-realm case.
---@param character string?
---@return string?
local function CharacterDisplayName(character)
    if not character then
        return nil
    end
    return character:match("^(.-) %- ") or character
end

---Whether a rule's saved binding (spec / character) matches the current toon.
---See the BINDING note at the top of the file. Rules without a stored binding
---(saved before this existed) apply everywhere.
---@param rule LoadoutRule
---@return boolean
function Loadouts.AppliesToCurrentCharacter(rule)
    if rule.require == "talent" then
        if rule.specID and rule.specID ~= GetCurrentSpecID() then
            return false
        end
    elseif rule.require == "loadout" then
        if rule.character and rule.character ~= Loadouts.GetCurrentCharacterKey() then
            return false
        end
        if rule.specID and rule.specID ~= GetCurrentSpecID() then
            return false
        end
    elseif rule.require == "gear" then
        if rule.character and rule.character ~= Loadouts.GetCurrentCharacterKey() then
            return false
        end
    end
    return true
end

---Human-readable "what this rule was saved on" for the list page, plus the class
---token so the caller can class-color it:
---  * talent  -> "<Spec> <Class>" (no character anchor, so name the class)
---  * gear    -> "<Name>"
---  * loadout -> "<Spec> · <Name>"  (spec-first, matching the talent ordering)
---Realm is stripped for display (see CharacterDisplayName); it lives on the rule
---for matching only. Returns nil text if the rule predates binding capture.
---@param rule LoadoutRule
---@return string? text, string? classToken
function Loadouts.GetBindingLabel(rule)
    if rule.require == "talent" then
        local specName = ResolveSpecName(rule.specID)
        if not specName then
            return nil, rule.class
        end
        local className = rule.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[rule.class]
        if className then
            return BR.L["Loadout.SpecClass"]:format(specName, className), rule.class
        end
        return specName, rule.class
    elseif rule.require == "gear" then
        return CharacterDisplayName(rule.character), rule.class
    elseif rule.require == "loadout" then
        local specName = ResolveSpecName(rule.specID)
        local charName = CharacterDisplayName(rule.character)
        if charName and specName then
            return specName .. " · " .. charName, rule.class
        end
        return charName or specName, rule.class
    end
    return nil, rule.class
end

-- ----------------------------------------------------------------------------
-- Requirement checks (return true == player is already correctly set up)
-- ----------------------------------------------------------------------------

local function ResolveTalentKnown(spellID)
    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end
    return IsPlayerSpell and IsPlayerSpell(spellID) or false
end

---@param spellID number?
---@return boolean
function Loadouts.IsTalentKnown(spellID)
    if not spellID then
        return true
    end
    local ok, known = pcall(ResolveTalentKnown, spellID)
    return ok and known or false
end

local function ResolveLoadoutActive(specID, name)
    local cfgID = C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    if not cfgID then
        return false -- on a starter / unsaved build: no named loadout active
    end
    local info = C_Traits and C_Traits.GetConfigInfo(cfgID)
    return info ~= nil and info.name == name
end

---@param specID number?
---@param name string?
---@return boolean
function Loadouts.IsLoadoutActive(specID, name)
    if not name then
        return true
    end
    local ok, active = pcall(ResolveLoadoutActive, specID, name)
    return ok and active or false
end

-- Whether Talent Loadout Ex is installed and exposes its API. Memoized once
-- positive (an addon can't unload mid-session), re-probed while absent because
-- TLEx's load order relative to BuffReminders isn't guaranteed - so an early probe
-- can't poison it into skipping forever. A single global lookup is cheap and only
-- runs on cache-cold refreshes / when the picker opens, so there's no per-frame cost.
local tlxAvailable = false
local function IsTLXAvailable()
    if tlxAvailable then
        return true
    end
    ---@diagnostic disable-next-line: undefined-field
    local TLX = _G.TLX
    tlxAvailable = TLX ~= nil and TLX.GetLoadedData ~= nil
    return tlxAvailable
end
Loadouts.IsTLXAvailable = IsTLXAvailable

-- Resolve TLEx's stored loadout list for the current class + spec. TLEx keys its DB
-- account-wide by class token + spec INDEX (not spec ID). Returns nil when TLEx isn't
-- installed or has nothing saved for this spec. Callers wrap this in pcall.
local function GetTLXSpecTable()
    ---@diagnostic disable-next-line: undefined-field
    local db = _G.TalentLoadoutEx
    if not db then
        return nil
    end
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    if not class or not specIndex then
        return nil
    end
    return db[class] and db[class][specIndex]
end

-- Hoisted body (see the file-scope note above): a refresh-path caller (GetRuleIcon)
-- pcalls this, so keep it a named function rather than an inline closure per call.
local function ResolveTLXLoadoutIconBody(name)
    local specTable = GetTLXSpecTable()
    if not specTable then
        return nil
    end
    for _, data in ipairs(specTable) do
        if data.text and data.name == name then
            return data.icon
        end
    end
    return nil
end

-- Live-resolve a TLEx loadout's icon by name (icon may be a fileID number or an
-- atlas/path string). Returns nil when TLEx isn't installed or the name isn't found,
-- so callers fall back to the rule's snapshotted icon / the spec icon.
local function ResolveTLXLoadoutIcon(name)
    if not name or not IsTLXAvailable() then
        return nil
    end
    local ok, icon = pcall(ResolveTLXLoadoutIconBody, name)
    return ok and icon or nil
end

local function ResolveTLXLoadoutActive(name)
    if not IsTLXAvailable() then
        return false
    end
    -- GetLoadedData() varargs the loadout(s) TLEx considers currently loaded (it
    -- diffs each stored talent string against the active config). Pack into a table
    -- so we can scan; returns {} when none / not yet computed.
    ---@diagnostic disable-next-line: undefined-field
    local loaded = { _G.TLX.GetLoadedData() }
    for _, data in ipairs(loaded) do
        if data and data.name == name then
            return true
        end
    end
    return false
end

---Whether a Talent Loadout Ex loadout (matched by name within the current spec)
---is the one currently loaded. Talent Loadout Ex loadouts are NOT WoW named
---loadouts, so `C_ClassTalents` can't see them - detection goes through TLEx's own
---public API (`_G.TLX.GetLoadedData`). Returns false when TLEx isn't installed or
---hasn't computed its loaded state yet.
---@param name string?
---@return boolean
function Loadouts.IsTLXLoadoutActive(name)
    if not name then
        return true
    end
    local ok, active = pcall(ResolveTLXLoadoutActive, name)
    return ok and active or false
end

local function ResolveSetEquipped(setID)
    -- GetEquipmentSetInfo -> name, iconFileID, setID, isEquipped, ...
    local _, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(setID)
    return isEquipped == true
end

---@param setID number?
---@return boolean
function Loadouts.IsSetEquipped(setID)
    if not setID or not C_EquipmentSet then
        return setID == nil
    end
    local ok, equipped = pcall(ResolveSetEquipped, setID)
    return ok and equipped or false
end

---Whether the rule's expectation is currently met (no reminder needed).
---@param rule LoadoutRule
---@return boolean
function Loadouts.IsSatisfied(rule)
    if rule.require == "gear" then
        return Loadouts.IsSetEquipped(rule.gear and rule.gear.setID)
    elseif rule.require == "talent" then
        return Loadouts.IsTalentKnown(rule.spellID)
    elseif rule.require == "loadout" then
        -- Loadouts are per-spec: a rule for another spec doesn't apply right now.
        if rule.specID and rule.specID ~= GetCurrentSpecID() then
            return true
        end
        if rule.loadout and rule.loadout.source == "tlex" then
            return Loadouts.IsTLXLoadoutActive(rule.loadout.name)
        end
        return Loadouts.IsLoadoutActive(rule.specID, rule.loadout and rule.loadout.name)
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Instance context match (Phase 3 narrowing; empty list == any)
-- ----------------------------------------------------------------------------

---@param instances table[]?
---@return boolean
function Loadouts.CurrentInstanceMatches(instances)
    if not instances or #instances == 0 then
        return true
    end
    -- Name is the one identifier that lines up across dungeons (GetMapUIInfo) and
    -- raids (Encounter Journal) with GetInstanceInfo, so it's the primary key. The
    -- challenge-map id is an exact match inside a keystone; mapID is a last resort.
    -- Identity comes from State's content-type cache (one GetInstanceInfo per zone
    -- instead of per rule per refresh). Runtime access is safe despite State
    -- loading after this file: the only caller is State.Refresh itself.
    local name, instanceID, activeChallenge = BR.BuffState.GetInstanceContext()
    for _, inst in ipairs(instances) do
        if inst.name and inst.name == name then
            return true
        end
        if activeChallenge and inst.id == activeChallenge then
            return true
        end
        if inst.mapID and inst.mapID == instanceID then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Picker population (used by the rule editor dialog)
-- ----------------------------------------------------------------------------

---List the saved talent loadouts for a spec.
---@param specID number
---@return { name: string, configID: number }[]
function Loadouts.ListLoadouts(specID)
    local out = {}
    pcall(function()
        if not (C_ClassTalents and C_Traits) then
            return
        end
        local ids = C_ClassTalents.GetConfigIDsBySpecID(specID)
        if not ids then
            return
        end
        for _, cfgID in ipairs(ids) do
            local info = C_Traits.GetConfigInfo(cfgID)
            if info and info.name then
                out[#out + 1] = { name = info.name, configID = cfgID }
            end
        end
    end)
    return out
end

---List the Talent Loadout Ex loadouts saved for the current class + spec. TLEx
---stores account-wide keyed by class token + spec INDEX (not spec ID); group
---headers (entries without a `.text` talent string) are skipped. Returns an empty
---list when TLEx isn't installed, so the picker self-gates on its presence.
---@return { name: string, icon: number|string? }[]
function Loadouts.ListTLXLoadouts()
    local out = {}
    if not IsTLXAvailable() then
        return out
    end
    pcall(function()
        local specTable = GetTLXSpecTable()
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

---List the player's saved equipment sets.
---@return { setID: number, name: string, icon: number }[]
function Loadouts.ListEquipmentSets()
    local out = {}
    pcall(function()
        if not C_EquipmentSet then
            return
        end
        local ids = C_EquipmentSet.GetEquipmentSetIDs()
        if not ids then
            return
        end
        for _, setID in ipairs(ids) do
            local name, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
            out[#out + 1] = { setID = setID, name = name, icon = icon }
        end
    end)
    return out
end

---List the current season's instances (M+ dungeons + current raid tier).
---@return { id: number, mapID: number?, name: string, icon: number?, kind: string }[]
function Loadouts.ListCurrentInstances()
    local out = {}
    -- Mythic+ dungeons for the current season.
    pcall(function()
        if C_ChallengeMode and C_ChallengeMode.GetMapTable then
            local maps = C_ChallengeMode.GetMapTable()
            if maps then
                for _, id in ipairs(maps) do
                    local name, _, _, texture, _, mapID = C_ChallengeMode.GetMapUIInfo(id)
                    if name then
                        out[#out + 1] = { id = id, mapID = mapID, name = name, icon = texture, kind = "dungeon" }
                    end
                end
            end
        end
    end)
    -- Raids in the current Encounter Journal tier (best-effort: EJ may be unloaded).
    pcall(function()
        if not (EJ_GetCurrentTier and EJ_SelectTier and EJ_GetInstanceByIndex) then
            return
        end
        EJ_SelectTier(EJ_GetCurrentTier())
        local i = 1
        while true do
            -- 10th return = shouldDisplayDifficulty: false for world-boss groupings
            -- (e.g. the "Midnight" world-boss zone), true for real raid instances.
            -- (Slot 9 is the instance link string; mapID sits at 8, shifting this.)
            local instanceID, name, _, _, buttonImage, _, _, _, _, shouldDisplayDifficulty =
                EJ_GetInstanceByIndex(i, true)
            if not instanceID then
                break
            end
            if shouldDisplayDifficulty ~= false then
                out[#out + 1] = { id = instanceID, name = name, icon = buttonImage, kind = "raid" }
            end
            i = i + 1
        end
    end)
    return out
end

-- ----------------------------------------------------------------------------
-- Display + fix helpers
-- ----------------------------------------------------------------------------

---Resolve the icon a rule should display. Derived live each refresh (the set
---or spec may have been re-iconed since the rule was saved), falling back to the
---rule's cached icon and finally a per-type default.
---@param rule LoadoutRule
---@return number|string
function Loadouts.GetRuleIcon(rule)
    if rule.require == "talent" and rule.spellID then
        local ok, tex = pcall(C_Spell.GetSpellTexture, rule.spellID)
        if ok and tex then
            return tex
        end
    elseif rule.require == "gear" and rule.gear and rule.gear.setID then
        -- GetEquipmentSetInfo -> name, iconFileID, ...
        local ok, _, icon = pcall(C_EquipmentSet.GetEquipmentSetInfo, rule.gear.setID)
        -- Use the set's own icon, but skip the "?" placeholder the Equipment Manager
        -- stores when no icon was picked - fall back to a nicer generic gear icon.
        if ok and icon and icon ~= QUESTION_MARK_ICON then
            return icon
        end
        return DEFAULT_GEAR_ICON
    elseif rule.require == "loadout" then
        -- TLEx loadouts carry their own icon (fileID or atlas/path string). Resolve it
        -- live by name so an external re-icon in TalentLoadoutEx is picked up; fall back
        -- to the rule's snapshot (TLEx uninstalled / loadout deleted). Skip TLEx's "?"
        -- placeholder (INV_Misc_QuestionMark) and fall through to the spec icon instead.
        if rule.loadout and rule.loadout.source == "tlex" then
            local live = ResolveTLXLoadoutIcon(rule.loadout.name)
            if live and live ~= QUESTION_MARK_ICON then
                return live
            end
            if rule.icon and rule.icon ~= QUESTION_MARK_ICON then
                return rule.icon
            end
            -- fall through to the spec icon below
        end
        if rule.specID then
            -- GetSpecializationInfoByID -> id, name, description, icon, ...
            local ok, _, _, _, icon = pcall(GetSpecializationInfoByID, rule.specID)
            if ok and icon then
                return icon
            end
        end
    end
    -- Last resort: the rule's cached icon (skip the "?" placeholder a TLEx rule may
    -- have stored there), else the generic talent book.
    if rule.icon and rule.icon ~= QUESTION_MARK_ICON then
        return rule.icon
    end
    return DEFAULT_TALENT_ICON
end

-- The talent UI's loadout dropdown reflects the spec's "last selected saved config",
-- but that stamp only sticks if applied AFTER the config actually commits. A swap that
-- changes points returns LoadInProgress and runs the "Changing Talents" cast; stamp the
-- selection before that commit and the talent frame re-derives the dropdown on commit,
-- showing the OLD loadout (points change, dropdown lies - the reported bug). So for the
-- in-progress case we defer the stamp to the next TRAIT_CONFIG_UPDATED. A generation
-- token + timeout keeps a pending stamp from leaking onto an unrelated later commit if
-- the cast never lands (e.g. the player is pulled into combat before it finishes).
local dropdownSyncFrame = CreateFrame("Frame")
local pendingSync
local syncGen = 0

local function StampLastSelected(specID, configID)
    if C_ClassTalents.UpdateLastSelectedSavedConfigID then
        pcall(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, configID)
    end
    -- Blizzard bug: an ALREADY-OPEN talent frame doesn't re-read the last-selected
    -- config when it changes via the API, so its loadout dropdown keeps showing the
    -- previous set until /reload. If the frame is loaded, nudge its dropdown with the
    -- same SetSelectionID the UI uses internally (referenced live - PlayerSpellsFrame
    -- is load-on-demand and nil until first opened; when unloaded the dropdown reads
    -- fresh on next open, so there's nothing to fix).
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

-- Defer the dropdown stamp until the talent-change cast commits.
local function QueueDropdownSync(specID, configID)
    syncGen = syncGen + 1
    local myGen = syncGen
    pendingSync = { specID = specID, configID = configID }
    dropdownSyncFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    C_Timer.After(8, function()
        -- Only clear if still ours and unfired (a newer queue bumps syncGen).
        if myGen == syncGen and pendingSync then
            pendingSync = nil
            dropdownSyncFrame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
        end
    end)
end

-- Load a WoW named talent loadout in place. Re-resolve the configID by name for
-- the current spec first: configIDs are per-character, so the one snapshotted on the
-- rule can be stale on an alt sharing the loadout name. Fall back to the stored id.
-- Returns false when nothing loadable resolves, so ApplyFix drops to opening the UI.
---@param rule LoadoutRule
---@return boolean
local function LoadWoWLoadout(rule)
    if not (C_ClassTalents and C_ClassTalents.LoadConfig) then
        return false
    end
    local specID = rule.specID or GetCurrentSpecID()
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
    -- Load-and-apply (autoApply = true), THEN stamp the dropdown selection - order and
    -- timing matter for the loadout dropdown to reflect the swap (see the note above).
    local result = C_ClassTalents.LoadConfig(configID, true)
    if result == nil or result == Enum.LoadConfigResult.Error then
        return false -- load didn't take; let ApplyFix open the talent UI instead
    end
    if result == Enum.LoadConfigResult.LoadInProgress then
        QueueDropdownSync(specID, configID) -- stamp once the "Changing Talents" cast commits
    else
        StampLastSelected(specID, configID) -- Ready / NoChangesNecessary: applied synchronously
    end
    return true
end

---Act on a clicked reminder: equip the gear set, load the talent loadout, or open
---the talent UI. Gear swaps and talent edits are blocked in combat by the client;
---guard early so the user gets a clear message instead of a silent no-op.
---@param rule LoadoutRule
function Loadouts.ApplyFix(rule)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(BR.L["Loadout.CombatBlocked"], 1, 0.3, 0.3)
        return
    end
    if rule.require == "gear" and rule.gear and rule.gear.setID then
        pcall(C_EquipmentSet.UseEquipmentSet, rule.gear.setID)
        return
    end
    -- WoW named loadout: load it in place. TLEx loadouts aren't WoW configs
    -- (C_ClassTalents can't see them), so those fall through to opening the UI.
    if rule.require == "loadout" and rule.loadout and rule.loadout.source ~= "tlex" then
        local ok, loaded = pcall(LoadWoWLoadout, rule)
        if ok and loaded then
            return
        end
    end
    -- talent / TLEx loadout / unresolved: open the talent UI so the user finishes by hand.
    pcall(function()
        if PlayerSpellsUtil and PlayerSpellsUtil.OpenToClassTalentsTab then
            PlayerSpellsUtil.OpenToClassTalentsTab()
        elseif ToggleTalentFrame then
            ToggleTalentFrame()
        end
    end)
end

BR.Loadouts = Loadouts
