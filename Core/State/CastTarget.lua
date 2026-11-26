local _, ns = ...
---@class BR
local BR = ns

-- The unit that a click casts a buff on, from the target rule of the buff. The click,
-- the hover highlight and the target tooltip read this one answer. Out of combat only:
-- the name compares read unit identity.

---@class BuffState
local BuffState = BR.BuffState
local StateHelpers = BR.StateHelpers
local BuffTargets = StateHelpers.BuffTargets
local TargetMemory = BR.TargetMemory
local Plain = BR.Secret.Plain

---The group unit of a character name: a roster name, else a name that the game
---resolves, such as a pin typed without its realm.
---@param name string
---@return string?
local function ValidUnitOfName(name)
    local units = StateHelpers.GetValidUnits()
    for _, data in ipairs(units) do
        if data.name == name then
            return data.unit
        end
    end
    if Plain(UnitExists(name)) ~= true then
        return nil
    end
    for _, data in ipairs(units) do
        if Plain(UnitIsUnit(data.unit, name)) == true then
            return data.unit
        end
    end
    return nil
end

---The first player in the group with the role, who can receive a cast.
---@param role RoleType
---@return string?
local function ValidUnitOfRole(role)
    for _, data in ipairs(StateHelpers.GetValidUnits()) do
        if data.isPlayer and not data.isPhased and StateHelpers.GetUnitRole(data) == role then
            return data.unit
        end
    end
    return nil
end

---The player if listed, else the first member in range, else the first member.
---A secret or unchecked range reads as out of range.
---@param key string
---@return string
local function MissingUnit(key)
    local units = BuffState.GetMissingUnits(key)
    if not units or not units[1] then
        return "player"
    end
    for i = 1, #units do
        if units[i] == "player" then
            return "player"
        end
    end
    for i = 1, #units do
        if Plain(UnitInRange(units[i])) == true then
            return units[i]
        end
    end
    return units[1]
end

---@param buff table
---@param category "raid"|"presence"|"targeted"
---@return string? unit nil: default targeting
---@return boolean? blocked The pinned target is not in the group, so the click casts nothing
function BuffState.GetCastUnit(buff, category)
    local target = BuffTargets.Resolve(buff, category)
    if target == "group" then
        return buff.castOnMissing and MissingUnit(buff.key) or "player"
    end
    if target == "self" then
        return "player"
    end
    if target == "anyone" then
        return nil
    end
    local pinned = buff.pinnedTarget and buff.pinnedTarget()
    if pinned then
        local unit = ValidUnitOfName(pinned)
        if unit then
            return unit
        end
        -- A dead or offline member is still in the group. The cast fails, but on the pin only.
        if Plain(UnitExists(pinned)) == true then
            return pinned
        end
        return nil, true
    end
    local name = TargetMemory.Get(buff.key)
    local unit = name and ValidUnitOfName(name)
    if unit then
        return unit
    end
    -- The memory of a tankOrSelf buff holds the tank that lacks it. With none, the player.
    if target == "tankOrSelf" then
        return "player"
    end
    unit = buff.fallbackRole and ValidUnitOfRole(buff.fallbackRole)
    if unit then
        return unit
    end
    if target == "allyOrSelf" and BuffState.IsAlone() then
        return "player"
    end
    return nil
end
