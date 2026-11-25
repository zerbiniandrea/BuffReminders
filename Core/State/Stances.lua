local _, ns = ...
---@class BR
local BR = ns

-- Stance and shapeshift state: the active stance, the stance bar, and the wrong-stance and
-- wrong-form checks.

---@class BuffState
local BuffState = BR.BuffState

local _, playerClass = UnitClass("player")

-- Warrior stance and druid form rules of the client: the allowed stances and the
-- stance that the click casts.
local STANCE_RULES = BR.BuffData.stanceRules
local NO_STANCE = BR.NO_STANCE

-- Priest shadow forms. Shadowform is the only stance shadow priests can take;
-- Voidform is a temporary aura that visually replaces it. The stance bar API
-- works in restricted contexts (combat/encounter/M+) where aura queries fail
-- for non-whitelisted spells, so the stance bar is read directly.
local SHADOWFORM = BR.SHADOWFORM_SPELL_ID
local VOIDFORM = 194249

-- Travel-family shapeshift form IDs (GetShapeshiftFormID): ground Travel and
-- Mount Form both report 3, Aquatic reports 4, Flight reports 27. Every variant
-- shares spell 783 except Mount Form (210053), so this table keys off the engine
-- form category instead of the spell. That covers any Mount Form appearance
-- variant. None of these collide with combat forms (Cat 1, Bear 5, Dire Bear 8, Moonkin 31).
-- Used to suppress the wrong-form reminder during travel.
local DRUID_TRAVEL_FORM_IDS = {
    [3] = true, -- ground Travel Form + Mount Form
    [4] = true, -- Aquatic Form
    [27] = true, -- Flight Form
}

-- Shapeshift/stance cache: the active stance and the derived priest shadowform
-- and stance icon values, all invalidated together by InvalidateStanceCache.
-- `false` on a field = computed and absent; nil = not yet computed.
---@class StanceCache
---@field currentStanceIcon number|false|nil  -- false = unstanced
---@field shadowFormActive boolean|nil
---@field activeSpellID number|false|nil        -- false = unstanced; nil = not computed / transient
---@field barSpells table<number, true>|nil      -- spell IDs of the stance bar slots
---@type StanceCache
local stanceCache = {}

---Resolve the active stance's spell ID, or nil if unstanced/unresolved (cached).
---Unstanced (form 0) is a stable result and cached as `false`; a form set but
---with unresolved spell data is a transient load state left uncached to retry.
---@return number?
local function GetActiveStanceSpellID()
    if stanceCache.activeSpellID ~= nil then
        return stanceCache.activeSpellID or nil
    end
    local active = GetShapeshiftForm()
    if not active or active == 0 then
        stanceCache.activeSpellID = false
        return nil
    end
    local _, _, _, spellID = GetShapeshiftFormInfo(active)
    if type(spellID) == "number" then
        stanceCache.activeSpellID = spellID
        return spellID
    end
    return nil
end

---Active stance spell ID, and true as second value when the stance bar has no active
---form. Both values are nil while the spell data of an active form is unresolved.
---@return number? spellID
---@return boolean? unstanced
function BuffState.GetActiveStance()
    local spellID = GetActiveStanceSpellID()
    return spellID, stanceCache.activeSpellID == false or nil
end

---Set of the spell IDs on the stance bar. Cached. A slot with unresolved spell data is
---a transient load state, so that set stays uncached to retry.
---@return table<number, true>
function BuffState.GetStanceBarSpells()
    local spells = stanceCache.barSpells
    if spells then
        return spells
    end
    spells = {}
    local resolved = true
    for i = 1, GetNumShapeshiftForms() do
        local _, _, _, spellID = GetShapeshiftFormInfo(i)
        if type(spellID) == "number" then
            spells[spellID] = true
        else
            resolved = false
        end
    end
    if resolved then
        stanceCache.barSpells = spells
    end
    return spells
end

---Whether the active stance is outside the allowed stances of the rule. A form
---set with unresolved spell data is a transient load state and reads as allowed.
---The verdict reads live, because the allowed set can follow the content type.
---@param rule StanceRule
---@return boolean
local function IsOutsideAllowedStances(rule)
    local allowed = rule.allowed()
    if not allowed then
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if activeSpellID then
        return not allowed[activeSpellID]
    end
    if stanceCache.activeSpellID == false then
        return not allowed[NO_STANCE]
    end
    return false
end

---Whether a warrior is unstanced or in a stance that the rule does not allow.
---@return boolean
function BuffState.IsWrongWarriorStance()
    return playerClass == "WARRIOR" and IsOutsideAllowedStances(STANCE_RULES.WARRIOR)
end

---Stance spell ID that the warrior click casts, or nil for non-warriors.
---@return number?
function BuffState.GetExpectedWarriorStanceID()
    if playerClass ~= "WARRIOR" then
        return nil
    end
    return STANCE_RULES.WARRIOR.castID()
end

---Texture of the active stance or form, or nil if unstanced. Cached.
---@return number?
function BuffState.GetCurrentStanceIcon()
    if stanceCache.currentStanceIcon ~= nil then
        return stanceCache.currentStanceIcon or nil
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        stanceCache.currentStanceIcon = false
        return nil
    end
    stanceCache.currentStanceIcon = C_Spell.GetSpellTexture(activeSpellID) or false
    return stanceCache.currentStanceIcon or nil
end

---Whether the priest is currently in Shadowform (or Voidform, which lives in
---the same stance bar slot). Cached. Reliable in restricted contexts because
---the stance API is unaffected by combat/encounter/M+ aura restrictions.
---@return boolean
function BuffState.IsShadowFormActive()
    if stanceCache.shadowFormActive ~= nil then
        return stanceCache.shadowFormActive
    end
    if playerClass ~= "PRIEST" then
        stanceCache.shadowFormActive = false
        return false
    end
    local activeSpellID = GetActiveStanceSpellID()
    if not activeSpellID then
        -- Form 0 = no shadowform (cache). A non-zero form with unresolved spell
        -- data is a transient load state: return the safe default and retry.
        if GetShapeshiftForm() == 0 then
            stanceCache.shadowFormActive = false
            return false
        end
        return true
    end
    stanceCache.shadowFormActive = activeSpellID == SHADOWFORM or activeSpellID == VOIDFORM
    return stanceCache.shadowFormActive
end

---Whether a druid is in a form that the rule does not allow. With
---druidIgnoreTravelForm, any travel-family form or a mount reads as allowed.
---@return boolean
function BuffState.IsWrongDruidForm()
    if playerClass ~= "DRUID" then
        return false
    end
    if BR.profile.druidIgnoreTravelForm ~= false and (DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()] or IsMounted()) then
        return false
    end
    return IsOutsideAllowedStances(STANCE_RULES.DRUID)
end

---Form spell ID that the druid click casts (0 = cancel the form), or nil.
---@return number?
function BuffState.GetExpectedDruidFormID()
    if playerClass ~= "DRUID" then
        return nil
    end
    return STANCE_RULES.DRUID.castID()
end

---Invalidate all stance caches (active stance, stance icon, priest shadowform).
function BuffState.InvalidateStanceCache()
    wipe(stanceCache)
end

BR.GameContext.RegisterCache("stance", BuffState.InvalidateStanceCache)
