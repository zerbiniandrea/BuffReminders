local _, ns = ...
---@class BR
local BR = ns

-- Content visibility: whether the settings allow a category, a custom buff, a loadout rule or a
-- free consumable in the current content, and which row of a per-content grid applies.

local GameContext = BR.GameContext
local GetCurrentContentType = GameContext.GetContentType
local GetCurrentDifficultyKey = GameContext.GetDifficultyKey

-- Maps content type to the DB key holding its difficulty sub-filter. A content type
-- without a sub-row on this client ignores a saved filter, because no control can clear it.
local CONTENT_DIFF_DB_KEYS = {}
for contentType, diffDbKey in pairs({
    scenario = "scenarioDifficulty",
    dungeon = "dungeonDifficulty",
    raid = "raidDifficulty",
    pvp = "pvpType",
}) do
    if BR.BuffData.instanceContent.difficulties[contentType] then
        CONTENT_DIFF_DB_KEYS[contentType] = diffDbKey
    end
end

-- Content type -> row of a per-content grid setting. Other content uses the world row.
local CONTENT_GRID_ROWS = { dungeon = "dungeon", scenario = "dungeon", raid = "raid", pvp = "pvp" }

---Row of the per-content grid settings for the current content.
---@return string
local function GetContentRow()
    return CONTENT_GRID_ROWS[GetCurrentContentType()] or "world"
end

---Whether a per-content grid allows a choice. A saved row holds only the keys
---that the user toggled, and an unchecked choice is stored as false. A missing
---key follows the code default.
---@param setting string Key of the grid in profile.defaults
---@param row string
---@param key string
---@return boolean
local function IsContentChoiceAllowed(setting, row, key)
    local defaults = BR.profile.defaults
    local prefs = defaults and defaults[setting]
    local saved = type(prefs) == "table" and prefs[row]
    local allowed
    if type(saved) == "table" then
        allowed = saved[key]
    end
    if allowed == nil then
        local defaultGrid = BR.defaults.defaults[setting]
        local defaultRow = defaultGrid and defaultGrid[row]
        allowed = defaultRow and defaultRow[key]
    end
    return allowed == true
end

---Whether a category is visible for the current content type
---@param category CategoryName
---@return boolean
local function IsCategoryVisibleForContent(category, skipReadyCheck)
    if GameContext.IsInVehicle() and category ~= "raid" and category ~= "presence" then
        return false
    end
    local db = BR.profile
    if not db.categoryVisibility then
        return true
    end
    local visibility = db.categoryVisibility[category]
    if not visibility then
        return true
    end
    local contentType = GetCurrentContentType()
    if visibility[contentType] == false then
        return false
    end
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and visibility[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end
    -- Hide category when PvP match is active (past prep phase)
    if contentType == "pvp" and not GameContext.IsPvPPrepPhase() and visibility.hideInPvPMatch then
        return false
    end
    -- Per-category ready check filter (skipped when caller handles ready check independently)
    if not skipReadyCheck then
        local catSettings = db.categorySettings and db.categorySettings[category]
        if catSettings and catSettings.showOnlyOnReadyCheck and not GameContext.IsInReadyCheck() then
            return false
        end
    end
    return true
end

---Whether a custom buff is visible under its per-buff loadConditions
---@param buff CustomBuff
---@return boolean
local function IsCustomBuffVisibleForContent(buff)
    if GameContext.IsInVehicle() then
        return false
    end
    local lc = buff.loadConditions
    if not lc then
        return true
    end -- nil = show everywhere

    local contentType = GetCurrentContentType()
    if lc[contentType] == false then
        return false
    end

    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and lc[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end

    if lc.readyCheckOnly and not GameContext.IsInReadyCheck() then
        return false
    end

    if lc.levelFilter then
        if lc.levelFilter == "maxLevel" and GameContext.GetPlayerLevel() < GameContext.GetMaxExpansionLevel() then
            return false
        elseif
            lc.levelFilter == "belowMaxLevel" and GameContext.GetPlayerLevel() >= GameContext.GetMaxExpansionLevel()
        then
            return false
        end
    end

    return true
end

-- Loadout rule "scope" -> the content type its content must equal. Gear/talents
-- lock once a key or match starts, so scope is just the content bucket (no
-- per-difficulty granularity). "dungeon" covers every dungeon difficulty incl.
-- Mythic+; arena/battleground both live under "pvp" and split on instance type;
-- "delve" lives under "scenario" and splits on difficulty key.
local LOADOUT_SCOPE_CONTENT = {
    openWorld = "openWorld",
    raid = "raid",
    dungeon = "dungeon",
    delve = "scenario",
    arena = "pvp",
    battleground = "pvp",
}

---Whether a loadout rule is visible for the current content. Rules store a
---player-facing `scope` (openWorld / dungeon / delve / raid / arena / battleground) plus an optional
---instance allow-list and a `readyCheckOnly` gate. Scope captures intent directly,
---so there is no deny-list to infer.
---@param rule LoadoutRule
---@return boolean
local function IsLoadoutRuleVisibleForContent(rule)
    if GameContext.IsInVehicle() then
        return false
    end
    local when = rule.when
    if not when then
        return true
    end

    local scope = when.scope
    if scope then
        local needContent = LOADOUT_SCOPE_CONTENT[scope]
        if not needContent then
            -- Unknown or retired scope: hide rather than show in the wrong content.
            return false
        end
        if GetCurrentContentType() ~= needContent then
            return false
        end
        -- Arena and battleground share the "pvp" content type; split on diff key.
        -- Delves share the "scenario" content type with Torghast etc.; split too.
        if scope == "arena" then
            if GetCurrentDifficultyKey() ~= "arena" then
                return false
            end
        elseif scope == "battleground" then
            if GetCurrentDifficultyKey() ~= "bg" then
                return false
            end
        elseif scope == "delve" then
            if GetCurrentDifficultyKey() ~= "delves" then
                return false
            end
        end
    end

    if when.readyCheckOnly and not GameContext.IsInReadyCheck() then
        return false
    end

    return true
end

---Whether a free consumable is visible under its override visibility settings
---@param db table Database settings
---@return boolean
local function IsFreeConsumableVisible(db)
    if GameContext.IsInVehicle() then
        return false
    end
    local vis = db.defaults and db.defaults.freeConsumableVisibility
    if not vis then
        return true
    end
    local contentType = GetCurrentContentType()
    if vis[contentType] == false then
        return false
    end
    local diffKey = GetCurrentDifficultyKey()
    if diffKey then
        local diffDbKey = CONTENT_DIFF_DB_KEYS[contentType]
        local diffTable = diffDbKey and vis[diffDbKey]
        if diffTable and diffTable[diffKey] == false then
            return false
        end
    end
    -- PvP match hiding follows the consumable category's setting
    if contentType == "pvp" and not GameContext.IsPvPPrepPhase() then
        local catVis = db.categoryVisibility and db.categoryVisibility.consumable
        if catVis and catVis.hideInPvPMatch then
            return false
        end
    end
    return true
end

BR.Visibility = {
    GetContentRow = GetContentRow,
    IsContentChoiceAllowed = IsContentChoiceAllowed,
    IsCategoryVisibleForContent = IsCategoryVisibleForContent,
    IsCustomBuffVisibleForContent = IsCustomBuffVisibleForContent,
    IsLoadoutRuleVisibleForContent = IsLoadoutRuleVisibleForContent,
    IsFreeConsumableVisible = IsFreeConsumableVisible,
}
