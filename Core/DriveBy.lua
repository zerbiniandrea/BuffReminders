local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Drive-by buffs: a reminder to buff the targeted player when that player is outside
-- the group and lacks a buff of the player's class, and an optional greeting after
-- the cast. The target reads are memoized and the target events clear them.

local L = BR.L
local GameContext = BR.GameContext
local StateHelpers = BR.StateHelpers
local IsBuffEnabled = StateHelpers.IsBuffEnabled
local IsPlayerSpellCached = StateHelpers.IsPlayerSpellCached
local Plain = BR.Secret.Plain
local BuffBeneficiaries = BR.BuffBeneficiaries
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID

local RANK_LEVELS = BR.DRIVE_BY.rankLevels
local LEVEL_SPAN = BR.DRIVE_BY.levelSpan
local FEATURE_KEY = "driveByBuffs"

local _, playerClass = UnitClass("player")

---@param spellIDs SpellID?
---@return boolean
local function HasRankLevels(spellIDs)
    for _, id in ipairs(StateHelpers.AsSpellList(spellIDs)) do
        if RANK_LEVELS[id] then
            return true
        end
    end
    return false
end

-- Table order decides which missing buff the reminder offers.
local candidates = {}
for _, category in ipairs({ "raid", "self" }) do
    for _, buff in ipairs(BR.BUFF_TABLES[category]) do
        if buff.class == playerClass and HasRankLevels(buff.spellID) then
            candidates[#candidates + 1] = buff
        end
    end
end

---@class DriveByTarget
---@field name string Name with realm, for the whisper
---@field shortName string
---@field class string
---@field level number -1 when the target level is unknown
---@field pvp boolean The target is PvP-flagged and the player is not

---@type DriveByTarget
local target = { name = "", shortName = "", class = "", level = -1, pvp = false }
local targetState = nil ---@type boolean? nil = not read, false = no target that qualifies
---@type table<table, boolean> Aura ID list -> the target has one of the auras
local targetHasAura = {}

local function InvalidateCache()
    targetState = nil
    wipe(targetHasAura)
end

---@return DriveByTarget?
local function GetTarget()
    if targetState == nil then
        targetState = Plain(UnitExists("target")) == true
            and Plain(UnitIsPlayer("target")) == true
            and Plain(UnitIsUnit("target", "player")) == false
            and Plain(UnitCanAssist("player", "target")) == true
            and Plain(UnitIsDeadOrGhost("target")) == false
            and Plain(UnitIsConnected("target")) == true
            and not Plain(UnitInParty("target"))
            and not Plain(UnitInRaid("target"))
        if targetState then
            local name = Plain(GetUnitName("target", true))
            local shortName = Plain(UnitName("target"))
            local _, class = UnitClass("target")
            class = Plain(class)
            if name and shortName and class then
                target.name = name
                target.shortName = shortName
                target.class = class
                target.level = Plain(UnitLevel("target")) or -1
                target.pvp = Plain(UnitIsPVP("target")) == true and Plain(UnitIsPVP("player")) ~= true
            else
                targetState = false
            end
        end
    end
    return targetState and target or nil
end

-- Any rank from any caster counts as the buff.
---@param auraIDs number[]
---@return boolean
local function TargetHasAura(auraIDs)
    local has = targetHasAura[auraIDs]
    if has == nil then
        has = false
        for _, id in ipairs(auraIDs) do
            if GetUnitAuraBySpellID("target", id) then
                has = true
                break
            end
        end
        targetHasAura[auraIDs] = has
    end
    return has
end

---@param beneficiaryKey string
---@param class string
---@return boolean
local function TargetBenefits(beneficiaryKey, class)
    local classes = BuffBeneficiaries[beneficiaryKey]
    return not classes or classes[class] == true
end

-- IsSpellKnown answers true only for the highest learned rank, so every rank
-- below it counts as known too.
---@param ranks number[] Highest rank first
---@param level number Target level, -1 when unknown
---@return number?
local function PickRank(ranks, level)
    local known = false
    for _, id in ipairs(ranks) do
        local rankLevel = RANK_LEVELS[id]
        if rankLevel then
            known = known or IsPlayerSpellCached(id)
            if known and (level < 0 or level >= rankLevel - LEVEL_SPAN) then
                return id
            end
        end
    end
    return nil
end

---The rank to cast on the target, or nil when no reminder shows. Safe to call every render.
---@return number? spellID
local function Pick()
    if not IsBuffEnabled(FEATURE_KEY) or GameContext.IsInCombat() or BR.BuffState.IsRestricted() then
        return nil
    end
    local current = GetTarget()
    if not current then
        return nil
    end
    local defaults = BR.profile.defaults
    if current.pvp and not (defaults and defaults.driveByAllowPvP) then
        return nil
    end
    for _, buff in ipairs(candidates) do
        local auraIDs, ranks, beneficiaryKey = buff.spellID, buff.spellID, buff.key
        if buff.activeChoice then
            local choice = buff.activeChoice()
            auraIDs = choice and choice.auraIDs
            ranks = choice and choice.spellIDs
            beneficiaryKey = choice and choice.beneficiaries or buff.key
        end
        if
            ranks
            and TargetBenefits(beneficiaryKey, current.class)
            and not TargetHasAura(StateHelpers.AsSpellList(auraIDs))
        then
            local spellID = PickRank(StateHelpers.AsSpellList(ranks), current.level)
            if spellID then
                return spellID
            end
        end
    end
    return nil
end

-- ============================================================================
-- GREETING
-- ============================================================================

-- A player gets one greeting per session.
local greeted = {}
local pendingCastGUID, pendingName

---Replace every literal token. A user text can hold % signs, so the search is plain.
---@param text string
---@param token string
---@param value string
---@return string
local function ReplaceToken(text, token, value)
    local first, last = text:find(token, 1, true)
    while first do
        text = text:sub(1, first - 1) .. value .. text:sub(last + 1)
        first, last = text:find(token, first + #value, true)
    end
    return text
end

---@param text string
---@param name string
---@param spellID number
---@return string
local function FillGreeting(text, name, spellID)
    text = ReplaceToken(text, "{name}", (name:match("^[^-]+")) or name)
    return ReplaceToken(text, "{spell}", BR.GetSpellName(spellID) or "")
end

---@param name string
---@param spellID number
local function SendGreeting(name, spellID)
    local defaults = BR.profile.defaults
    local mode = defaults and defaults.driveByGreeting or "none"
    if mode == "none" or greeted[name] or GameContext.IsInCombat() then
        return
    end
    greeted[name] = true
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if mode == "whisper" then
        local text = defaults.driveByWhisper or L["DriveBy.WhisperDefault"]
        send(FillGreeting(text, name, spellID), "WHISPER", nil, name)
    elseif mode == "emote" then
        local emote = defaults.driveByEmote or "WAVE"
        if emote == "CUSTOM" then
            local text = defaults.driveByEmoteText or L["DriveBy.EmoteDefault"]
            send(FillGreeting(text, name, spellID), "EMOTE")
        else
            DoEmote(emote, name)
        end
    end
end

-- UNIT_SPELLCAST_SENT names the cast target, so a cast on the player while the
-- stranger is targeted never greets the stranger.
local function OnSpellcastSent(castTarget, castGUID, spellID)
    pendingCastGUID = nil
    if not Pick() or not RANK_LEVELS[spellID] then
        return
    end
    local current = GetTarget()
    if current and not greeted[current.name] and (castTarget == current.shortName or castTarget == current.name) then
        pendingCastGUID = castGUID
        pendingName = current.name
    end
end

local function OnSpellcastSucceeded(castGUID, spellID)
    if pendingCastGUID ~= nil and not GameContext.IsInCombat() and castGUID == pendingCastGUID then
        pendingCastGUID = nil
        SendGreeting(pendingName, spellID)
    end
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local eventFrame = CreateFrame("Frame")
BR.Client.RegisterEvent(eventFrame, "PLAYER_TARGET_CHANGED")
BR.Client.RegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
BR.Client.RegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
BR.Client.RegisterEvent(eventFrame, "GROUP_ROSTER_UPDATE")
BR.Client.RegisterEvent(eventFrame, "UNIT_AURA", "target")
BR.Client.RegisterEvent(eventFrame, "UNIT_FLAGS", "target")
BR.Client.RegisterEvent(eventFrame, "UNIT_LEVEL", "target")
BR.Client.RegisterEvent(eventFrame, "UNIT_CONNECTION", "target")
BR.Client.RegisterEvent(eventFrame, "UNIT_FACTION", "target", "player")
BR.Client.RegisterEvent(eventFrame, "UNIT_SPELLCAST_SENT", "player")
BR.Client.RegisterEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")

-- The reminder hides in combat, so a combat event only clears the cache.
-- PLAYER_REGEN_ENABLED renders through the display handler.
eventFrame:SetScript("OnEvent", function(_, event, _, arg2, arg3, arg4)
    if event == "UNIT_SPELLCAST_SENT" then
        OnSpellcastSent(arg2, arg3, arg4)
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellcastSucceeded(arg2, arg3)
        return
    end
    InvalidateCache()
    if event ~= "PLAYER_REGEN_ENABLED" and IsBuffEnabled(FEATURE_KEY) and not GameContext.IsInCombat() then
        BR.CallbackRegistry:TriggerEvent("RenderRequested", event == "PLAYER_TARGET_CHANGED")
    end
end)

BR.DriveBy = {
    Pick = Pick,
}
