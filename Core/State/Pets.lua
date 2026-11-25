local _, ns = ...
---@class BR
local BR = ns

-- Pet state: the creature family of the current pet and its happiness.

---@class BuffState
local BuffState = BR.BuffState

local Plain = BR.Secret.Plain

-- Creature family of the current pet (false = no pet, nil = unresolved).
---@type number|false|nil
local cachedPetFamily = nil

-- Happiness of the current pet (false = no pet or no value, nil = unresolved).
-- C_PetInfo.GetPetHappiness exists only on a client with pet happiness.
---@type number|false|nil
local cachedPetHappiness = nil
local GetPetHappiness = C_PetInfo and C_PetInfo.GetPetHappiness

---Creature family of the current pet (cached).
---@return number|false|nil familyID false = no pet, nil = unresolved or secret, not cached so later refreshes retry
function BuffState.GetPetFamily()
    if cachedPetFamily == nil then
        if not UnitExists("pet") then
            cachedPetFamily = false
        else
            local _, familyID = UnitCreatureFamily("pet")
            familyID = Plain(familyID)
            if type(familyID) ~= "number" then
                return nil
            end
            cachedPetFamily = familyID
        end
    end
    return cachedPetFamily
end

---Check whether the player's current pet is not an allowed demon. Returns false
---when there is no pet, no desired demon, or an unresolved family.
---@return boolean
function BuffState.IsWrongDemonPet()
    if not BR.PetHelpers.GetDesiredWarlockDemon() then
        return false
    end
    local familyID = BuffState.GetPetFamily()
    return familyID ~= nil and familyID ~= false and not BR.PetHelpers.IsAllowedWarlockFamily(familyID)
end

---Invalidate wrong-pet cache
function BuffState.InvalidatePetCache()
    cachedPetFamily = nil
end

---Happiness of the current pet (cached): 1 unhappy, 2 content, 3 happy.
---@return number? happiness nil without a pet or on a client without pet happiness
function BuffState.GetPetHappiness()
    if not GetPetHappiness then
        return nil
    end
    if cachedPetHappiness == nil then
        if not UnitExists("pet") then
            cachedPetHappiness = false
        else
            local happiness = Plain(GetPetHappiness())
            if type(happiness) ~= "number" then
                -- Pet data is not resolved yet. Do not cache, so the next Refresh retries.
                return nil
            end
            cachedPetHappiness = happiness
        end
    end
    return cachedPetHappiness or nil
end

function BuffState.InvalidatePetHappinessCache()
    cachedPetHappiness = nil
end

BR.GameContext.RegisterCache("pet", BuffState.InvalidatePetCache)
BR.GameContext.RegisterCache("petHappiness", BuffState.InvalidatePetHappinessCache)
