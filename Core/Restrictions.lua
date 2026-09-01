local _, BR = ...

-- Restriction predicates measured through C_Secrets. This module predicts
-- whether a read yields secrets; the BR.Secret helpers in Core.lua verify the
-- values a read returns.

local issecretvalue = issecretvalue

local ShouldAurasBeSecret = C_Secrets.ShouldAurasBeSecret
local ShouldCooldownsBeSecret = C_Secrets.ShouldCooldownsBeSecret
local GetSpellAuraSecrecy = C_Secrets.GetSpellAuraSecrecy

local NEVER_SECRET = Enum.SecrecyLevel.NeverSecret

-- Spells whose classification reads NeverSecret while the live query returns
-- nothing in restricted contexts. Add an ID only after an in-game
-- /br secretdebug run proves the mismatch.
---@type table<number, boolean>
local OVERRIDE_NOT_TRACKABLE = {}

local Restrictions = {}

---Whether aura queries produce secret values in the current context.
---A secret answer counts as restricted.
---@return boolean
function Restrictions.AurasRestricted()
    local v = ShouldAurasBeSecret()
    if issecretvalue(v) then
        return true
    end
    return v == true
end

---Whether cooldown queries produce secret values in the current context.
---A secret answer counts as restricted.
---@return boolean
function Restrictions.CooldownsRestricted()
    local v = ShouldCooldownsBeSecret()
    if issecretvalue(v) then
        return true
    end
    return v == true
end

local spellSecrecyCache = {}

---Whether the spell's aura stays readable in restricted contexts.
---The classification is context-free, so the answer is memoized per spell.
---@param spellID number
---@return boolean
function Restrictions.IsAuraSpellTrackable(spellID)
    local cached = spellSecrecyCache[spellID]
    if cached ~= nil then
        return cached
    end
    local result = false
    if not OVERRIDE_NOT_TRACKABLE[spellID] then
        -- pcall: custom buffs carry user-entered spell IDs, and an invalid
        -- ID must not error out of the refresh path.
        local ok, level = pcall(GetSpellAuraSecrecy, spellID)
        result = ok and not issecretvalue(level) and level == NEVER_SECRET
    end
    spellSecrecyCache[spellID] = result
    return result
end

---Clear the per-spell classification cache. Blizzard can reclassify a spell
---in a mid-session hotfix, so the cache resets on PLAYER_ENTERING_WORLD.
function Restrictions.InvalidateSpellSecrecyCache()
    spellSecrecyCache = {}
end

BR.Restrictions = Restrictions
