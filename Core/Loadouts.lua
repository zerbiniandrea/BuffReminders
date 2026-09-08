local _, BR = ...

-- ============================================================================
-- LOADOUT DETECTION (talents / talent loadouts / equipment sets)
-- ============================================================================
-- Pure detection helpers for the "loadout" reminder category. None of them touch
-- the aura API, so they stay accurate in combat, encounters and M+.
--
-- BINDING. A rule stores the character and spec whose IDs its detection reads, so
-- a shared profile cannot leak one character's rules onto another as false
-- reminders. The save path stamps the binding; this module only reads it.
-- A rule with no stored specID or character applies everywhere.

local Loadouts = {}

local TalentLoadoutEx = BR.TalentLoadoutEx

local IsSpellKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown
local IsPlayerSpell = IsPlayerSpell
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecializationInfoByID = GetSpecializationInfoByID
local UnitName = UnitName
local GetRealmName = GetRealmName
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local C_ClassTalents = C_ClassTalents
local C_Traits = C_Traits
local C_EquipmentSet = C_EquipmentSet
local C_ChallengeMode = C_ChallengeMode
local C_Spell = C_Spell

local DEFAULT_TALENT_ICON = 133741 -- inv_misc_book_09: generic talent/loadout book icon, last resort
local DEFAULT_GEAR_ICON = 7539422 -- ui-transmog-showequippedgear: fallback for sets with no icon
local QUESTION_MARK_ICON = 134400

-- Bodies stay at file scope, not inline `pcall(function() ... end)`, so the
-- refresh-path callers below do not allocate a closure per rule per refresh.
local function ResolveCurrentSpecID()
    local idx = GetSpecialization()
    if not idx then
        return 0
    end
    return (GetSpecializationInfo(idx)) or 0
end

---Resolve the player's current spec ID (0 if none / not yet available).
---Prefers State's cached spec, so the per-rule refresh gating reuses one value
---instead of one spec API query per rule. Falls back to a live query while
---BR.StateHelpers is absent: Loadouts loads before State.
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
-- cached after name AND realm resolve, so an early call cannot poison it with "?".
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

---Display-only character name with the realm stripped off. Matching uses the
---full "Name - Realm" stored on the rule.
---@param character string?
---@return string?
local function CharacterDisplayName(character)
    if not character then
        return nil
    end
    return character:match("^(.-) %- ") or character
end

---Whether a rule's saved binding (spec / character) matches the current character.
---See the BINDING note at the top of the file.
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
---for matching only. Returns nil text when the rule stores no binding.
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

-- Marks a rule whose loadout is stored by Talent Loadout Ex rather than by WoW.
-- A WoW loadout carries a configID instead and stores no source.
local TLX_SOURCE = "tlex"
Loadouts.TLX_SOURCE = TLX_SOURCE

---Whether a rule points at a Talent Loadout Ex loadout.
---@param rule LoadoutRule
---@return boolean
local function IsTLXRule(rule)
    return rule.require == "loadout" and rule.loadout ~= nil and rule.loadout.source == TLX_SOURCE
end
Loadouts.IsTLXRule = IsTLXRule

---Prepare the external addons the given rules depend on. Runs one time for each
---session, and only for a rule set that asks an external addon a question: the
---load it needs is a client-wide one, so an unrelated profile must not pay for it.
---@param rules LoadoutRule[]
function Loadouts.EnsureAddonsReady(rules)
    for _, rule in ipairs(rules) do
        if IsTLXRule(rule) then
            TalentLoadoutEx.EnsureReady()
            return
        end
    end
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
---The second return value reports whether the answer is settled. Callers must not
---cache an unsettled answer, because no event announces the moment it settles.
---@param rule LoadoutRule
---@return boolean satisfied
---@return boolean known
function Loadouts.IsSatisfied(rule)
    if rule.require == "gear" then
        return Loadouts.IsSetEquipped(rule.gear and rule.gear.setID), true
    elseif rule.require == "talent" then
        return Loadouts.IsTalentKnown(rule.spellID), true
    elseif rule.require == "loadout" then
        -- Loadouts are per-spec: a rule for another spec does not apply now.
        if rule.specID and rule.specID ~= GetCurrentSpecID() then
            return true, true
        end
        if IsTLXRule(rule) then
            return TalentLoadoutEx.IsLoadoutActive(rule.loadout.name)
        end
        return Loadouts.IsLoadoutActive(rule.specID, rule.loadout and rule.loadout.name), true
    end
    return true, true
end

-- ----------------------------------------------------------------------------
-- Instance context match (empty list == any)
-- ----------------------------------------------------------------------------

---@param instances table[]?
---@return boolean
function Loadouts.CurrentInstanceMatches(instances)
    if not instances or #instances == 0 then
        return true
    end
    -- Name is the one identifier that lines up across dungeons (GetMapUIInfo) and
    -- raids (Encounter Journal) with GetInstanceInfo, so it is the primary key. The
    -- challenge-map id is an exact match inside a keystone; mapID is a last resort.
    -- Identity comes from State's content-type cache: one GetInstanceInfo per zone
    -- instead of one per rule per refresh. State loads after this file, but only
    -- State.Refresh calls this function, so the runtime access is safe.
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
    -- The Encounter Journal can be unloaded, so the raid list stays optional.
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

---Resolve the icon for a rule. The set or spec icon changes after the rule is
---saved, so this resolves live on each refresh. Falls back to the rule's cached
---icon, then to a per-type default.
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
        if ok and icon and icon ~= QUESTION_MARK_ICON then
            return icon
        end
        return DEFAULT_GEAR_ICON
    elseif rule.require == "loadout" then
        -- A Talent Loadout Ex loadout carries its own icon. Resolve it live by name,
        -- so a re-icon inside that addon shows up. Falls back to the rule's snapshot
        -- when the addon is absent or the loadout is deleted.
        if IsTLXRule(rule) then
            local live = TalentLoadoutEx.GetLoadoutIcon(rule.loadout.name)
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
    if rule.icon and rule.icon ~= QUESTION_MARK_ICON then
        return rule.icon
    end
    return DEFAULT_TALENT_ICON
end

BR.Loadouts = Loadouts
