local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Spell ranks: the highest known rank that a target of a given level accepts.

local LEVELS = BR.SPELL_RANKS.levels
local LEVEL_SPAN = BR.SPELL_RANKS.levelSpan
local IsPlayerSpellCached = BR.StateHelpers.IsPlayerSpellCached

-- IsSpellKnown answers true only for the highest learned rank, so every rank
-- below it counts as known too.
---@param ranks number[] Highest rank first. An ID with no level is skipped
---@param level number Target level, -1 when unknown
---@return number?
local function Fit(ranks, level)
    local known = false
    for _, id in ipairs(ranks) do
        local rankLevel = LEVELS[id]
        if rankLevel then
            known = known or IsPlayerSpellCached(id)
            if known and (level < 0 or level >= rankLevel - LEVEL_SPAN) then
                return id
            end
        end
    end
    return nil
end

BR.Ranks = {
    Fit = Fit,
}
