local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- TARGET MEMORY
-- ============================================================================
-- Remembers who the player's cast-on-others buffs are on (buffKey -> name/class)
-- so a click can cast on the same person and tooltips can show them.
-- Runtime-only (not saved): the aura is the source of truth. A live scan
-- rebuilds the memory when the aura API allows the query.

-- Observe() mutates entries in place to avoid per-refresh allocations.
---@type table<string, {name: string, class: string?}>
local memory = {}

---Apply one observation of a buff's state to the memory.
---@param buffKey string
---@param isActive boolean? Whether the buff is currently active anywhere
---@param name string? Character name (with realm) of the non-player target carrying it
---@param class string? English class token of the target (e.g. "PALADIN")
local function Observe(buffKey, isActive, name, class)
    if not isActive then
        return -- keep old memory while the buff is missing
    end
    if name then
        local existing = memory[buffKey]
        if existing then
            existing.name = name
            existing.class = class
        else
            memory[buffKey] = { name = name, class = class }
        end
    else
        memory[buffKey] = nil
    end
end

---Get the remembered target for a buff.
---@param buffKey string
---@return string? name Character name (with realm) of the last known target
---@return string? class English class token (e.g. "PALADIN")
local function Get(buffKey)
    local entry = memory[buffKey]
    if entry then
        return entry.name, entry.class
    end
    return nil, nil
end

---Forget targets that are no longer in the group.
---@param activeNames table<string, true> Set of names currently in the group
local function PruneToRoster(activeNames)
    for buffKey, entry in pairs(memory) do
        if not activeNames[entry.name] then
            memory[buffKey] = nil
        end
    end
end

-- ============================================================================
-- EXPORT
-- ============================================================================

BR.TargetMemory = {
    Observe = Observe,
    Get = Get,
    PruneToRoster = PruneToRoster,
}
