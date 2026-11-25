local _, ns = ...
---@class BR
local BR = ns
local L = BR.L

-- ============================================================================
-- SECURE BUTTONS & CLICK-TO-CAST OVERLAYS
-- Consumable action buttons, click-to-cast overlays, and the position sync for
-- both. Kept out of the display layer to isolate the code that combat lockdown
-- restricts.
-- ============================================================================

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local floor, max = math.floor, math.max
local tsort = table.sort
local wipe = wipe

local _, playerClass = UnitClass("player")
local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit
local GetCategorySetting = BR.Config.GetCategorySetting

local ChatRequest = BR.ChatRequest

local GetTime = GetTime
local IsSpellKnown = C_SpellBook.IsSpellKnown
local Plain = BR.Secret.Plain
local BuffTargets = BR.StateHelpers.BuffTargets
local IsCountdownEntry = BR.StateHelpers.IsCountdownEntry
local SubIcons = BR.SubIcons

---@param category string?
---@return boolean
local function IsCategoryClickable(category)
    return category ~= nil and GetCategorySetting(category, "clickable") == true
end

-- ============================================================================
-- SPELL HELPERS
-- ============================================================================

---Given one or more spell IDs, return the first that the player knows.
---@param spellIDs number|number[]|nil
---@return number?
local function GetCastableSpellID(spellIDs)
    if spellIDs == nil then
        return nil
    end
    if type(spellIDs) ~= "table" then
        return IsSpellKnown(spellIDs) and spellIDs or nil
    end
    for _, id in ipairs(spellIDs) do
        if IsSpellKnown(id) then
            return id
        end
    end
    return nil
end

local FEL_DOMINATION_ID = BR.PET_SPELLS.felDomination

-- Spell names never change once the client resolves them. An unresolved name at
-- login is not cached, so the next display cycle retries it.
local felDomMacroCache = {}

local function GetFelDomPetMacro(petSpellID)
    local cached = felDomMacroCache[petSpellID]
    if cached then
        return cached
    end
    local felDomName = C_Spell.GetSpellName(FEL_DOMINATION_ID)
    local spellName = BR.GetSpellName(petSpellID)
    if not felDomName or not spellName then
        return nil
    end
    local macro = "/cast " .. felDomName .. "\n/cast " .. spellName
    felDomMacroCache[petSpellID] = macro
    return macro
end

---@param buff table The buff definition table
---@return number?
local function GetActionSpellID(buff)
    if buff.excludeSpellID and IsSpellKnown(buff.excludeSpellID) then
        return nil
    end
    if buff.requiresSpellID and not IsSpellKnown(buff.requiresSpellID) then
        return nil
    end
    if buff.requireSpecId then
        local specId, specIndex = BR.Client.GetSpecID()
        if specIndex and specId ~= buff.requireSpecId then
            return nil
        end
    end
    -- Prefer the role spell so the cast matches the icon the player sees.
    if not buff.castSpellID and buff.icons and buff.icons.byRole then
        local role = BR.BuffState.GetPlayerRole()
        local roleSpell = role and buff.icons.byRole[role]
        if roleSpell and IsSpellKnown(roleSpell) then
            return roleSpell
        end
    end
    return GetCastableSpellID(buff.castSpellID or buff.spellID)
end

---Priority: castMacro > castItemID > castSpellID > spellID[1] that the player knows.
---@param buff table The custom buff definition
---@return string? actionType "spell"|"item"|"macro" or nil
---@return any actionValue The spell ID, item string, or macro text
local function ResolveCustomClickAction(buff)
    if not buff then
        return nil, nil
    end
    if buff.castMacro and buff.castMacro ~= "" then
        return "macro", buff.castMacro
    end
    if buff.castItemID then
        return "item", buff.castItemID
    end
    if buff.castSpellID then
        if IsSpellKnown(buff.castSpellID) then
            return "spell", buff.castSpellID
        end
        return nil, nil
    end
    local spellID = buff.spellID
    if type(spellID) == "table" then
        spellID = spellID[1]
    end
    if spellID and IsSpellKnown(spellID) then
        return "spell", spellID
    end
    return nil, nil
end

---The click target of a castOnMissing buff: the player if the player lacks it, else
---the first member in range who lacks it, else the first member who lacks it.
---A secret or unchecked range reads as out of range.
---@param key string
---@return string unit
local function PickCastUnit(key)
    local units = BR.BuffState.GetMissingUnits(key)
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

---@param def table? Buff definition from the custom buff table
---@return boolean
local function HasCustomClickAction(def)
    if not def then
        return false
    end
    return def.castSpellID ~= nil or def.castItemID ~= nil or (def.castMacro ~= nil and def.castMacro ~= "")
end

-- ============================================================================
-- INFO TOOLTIPS
-- ============================================================================
-- Addon info about a cast: the last target of a targeted buff and the next pick.
-- The description tooltip setting never gates them. A theme with a native tooltip
-- uses GameTooltip, which that client skins.

local TARGET_TIP = BR.Theme.targetTooltip
local CHOICE_SPELL_FMT = L["Tooltip.ChoiceSpell"]

---@param c number[]
---@return string
local function ColorEscape(c)
    return string.format("|cff%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end
local SPELL_ESCAPE = ColorEscape(TARGET_TIP.spell)

local lastTargetTooltip
local nativeOwner

---@param anchor table Frame to anchor to
---@param name string Character name
---@param class? string English class token
---@param hint? string Gray text shown after the name, such as "(not in group)"
---@param lead? string Gray text shown before the name
---@param above? boolean Place the tooltip above the anchor
---@param spellID? number Spell shown after the name
local function ShowLastTargetTooltip(anchor, name, class, hint, lead, above, spellID)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local spellName = spellID and BR.GetSpellName(spellID)
    if TARGET_TIP.native then
        local line = (lead and (lead .. " ") or "") .. (c and ("|c" .. c.colorStr) or "|cffffffff") .. name .. "|r"
        if spellName then
            local icon = BR.Icons.GetBuffTexture(spellID)
            local spell = (icon and ("|T" .. icon .. ":0|t ") or "") .. SPELL_ESCAPE .. spellName .. "|r"
            line = line .. " " .. CHOICE_SPELL_FMT:format(spell)
        end
        if hint then
            line = line .. " " .. hint
        end
        GameTooltip:SetOwner(anchor, above and "ANCHOR_TOP" or "ANCHOR_BOTTOM")
        -- The line color paints the lead, the separator and the hint.
        local n = TARGET_TIP.note
        GameTooltip:AddLine(line, n[1], n[2], n[3])
        GameTooltip:Show()
        nativeOwner = anchor
        return
    end
    if spellName then
        hint = CHOICE_SPELL_FMT:format(spellName)
    end
    if not lastTargetTooltip then
        local tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local bg, edge = TARGET_TIP.bg, TARGET_TIP.edge
        tip:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        tip:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
        tip.name = tip:CreateFontString(nil, "OVERLAY")
        tip.name:SetPoint("CENTER", 0, 0)
        lastTargetTooltip = tip
    end
    local tip = lastTargetTooltip
    BR.DisplayFonts.Apply(tip.name, 13)
    local r, g, b = 1, 1, 1
    if c then
        r, g, b = c.r, c.g, c.b
    end
    -- A color escape in the hint overrides SetTextColor for that part only.
    local text = hint and (name .. " |cff888888" .. hint .. "|r") or name
    tip.name:SetText(lead and ("|cff888888" .. lead .. "|r " .. text) or text)
    tip.name:SetTextColor(r, g, b)
    local textWidth, textHeight = BR.DisplayFonts.GetStringSize(tip.name)
    tip:SetSize(textWidth + 24, textHeight + 16)
    tip:ClearAllPoints()
    if above then
        tip:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
    else
        tip:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    end
    tip:Show()
end

local function HideLastTargetTooltip()
    if lastTargetTooltip then
        lastTargetTooltip:Hide()
    end
    if nativeOwner and GameTooltip:IsOwned(nativeOwner) then
        GameTooltip:Hide()
    end
    nativeOwner = nil
end

-- ============================================================================
-- CLICK-TO-CAST OVERLAY
-- ============================================================================

-- The secure resolver reads `type<button>` for the mouse button that was clicked.
-- It does not reliably fall back to the bare `type`, so a click resolves to no
-- action unless every variant carries the type. This overwrites type2, so it
-- clears the right-click mode and the next SetRightClickMode re-applies.
---@param button table Secure button (click overlay or consumable action button)
---@param actionType string "macro" | "item" | "spell", or "" for no action
local function SetActionType(button, actionType)
    button._br_action_type = actionType
    button:SetAttribute("type", actionType)
    for i = 1, 5 do
        button:SetAttribute("type" .. i, actionType)
    end
    button._br_rightClick = nil
end

-- "menu" neutralises the right button with an empty type2, which resolves to no
-- handler, and PostClick opens the reminder menu. "own" gives the button's own
-- action to the right click.
-- Call it after SetActionType, which overwrites type2. Self-gated, so callers can
-- re-apply on every display cycle. Must run out of combat.
---@param button table
local function SetRightClickMode(button)
    local mode = BR.profile.defaults.rightClickMenu == false and "own" or "menu"
    if button._br_rightClick == mode then
        return
    end
    button._br_rightClick = mode
    button:SetAttribute("type2", mode == "own" and button._br_action_type or "")
end

---Open the reminder menu on a right-click up event of a button in "menu" mode.
---@param button table The secure button
---@param mouseButton string
---@param down boolean
---@param frame table? The buff frame of the button
---@return boolean handled true when the click belongs to the menu
local function HandleMenuClick(button, mouseButton, down, frame)
    if mouseButton ~= "RightButton" or button._br_rightClick ~= "menu" then
        return false
    end
    if not down and frame then
        BR.Display.OpenReminderMenu(button, frame)
    end
    return true
end

-- ============================================================================
-- SECURE ACTIONS
-- ============================================================================
-- ResolveAction turns a buff frame into a plain action table. ApplyAction is the
-- only place that writes secure attributes. A new attribute concern belongs in
-- ApplyAction, never at a call site.

---@class BRSecureAction
---@field kind "macro"|"item"|"spell"|"none" Secure action type. "none": the left click does nothing
---@field tag string Namespace for the dirty gate. Two actions of one kind from
---different sources must not compare equal.
---@field id any Identity within the tag
---@field macrotext string? Macro text, when it does not depend on live state
---@field itemID number? Item behind the action, also for tooltips and click memory
---@field slot number? Weapon slot the macro applies the item to
---@field atPlayer boolean? The macro uses the item at the player location
---@field spellID number? kind == "spell"
---@field unit string? Cast target (nil = default targeting)
---@field macroFn function? Builds the macro text, also re-run by PreClick
---@field macroSpellID number? Argument for macroFn
---@field prefix string? Chat channel command in front of chatMsg
---@field chatKey string? Buff key when the action is a chat request
---@field chatMsg string? Request text without the channel prefix
---@field pickDef RaidBuff? PreClick picks the spell and the unit for this buff
---@field spellFn (fun(): number?)? PreClick writes the spell that this function returns
---@field tipSpellID number? Spell that the hover tooltip names, for a macro
---@field tipItemID number? Item that the hover tooltip names, for a macro. With tipSpellID: the item indoors

-- Every resolver fills this one table, and ApplyAction copies what it needs before
-- the next fill. A resolve runs for every frame on every display cycle, so it must
-- not allocate.
local scratchAction = {}

---@param kind "macro"|"item"|"spell"|"none"
---@param tag string
---@param id any
---@return BRSecureAction
local function NewAction(kind, tag, id)
    wipe(scratchAction)
    scratchAction.kind = kind
    scratchAction.tag = tag
    scratchAction.id = id
    return scratchAction
end

---@param a BRSecureAction?
---@param b BRSecureAction?
---@return boolean
local function SameAction(a, b)
    return a ~= nil
        and b ~= nil
        and a.kind == b.kind
        and a.tag == b.tag
        and a.id == b.id
        and a.unit == b.unit
        and a.slot == b.slot
        and a.prefix == b.prefix
end

---A macro action that depends on live state carries its inputs, not its text, so a
---resolve never pays the concat. The write path builds the text.
---@param action BRSecureAction
---@return string?
local function MacroText(action)
    if action.macroFn then
        return action.macroFn(action.macroSpellID)
    end
    if action.prefix then
        return action.prefix .. action.chatMsg
    end
    if action.slot then
        return "/use item:" .. action.itemID .. "\n/use " .. action.slot
    end
    if action.atPlayer then
        return "/use [@player] item:" .. action.itemID
    end
    return action.macrotext
end

---Copy the scratch action into the button's own table, which SameAction reads on
---the next cycle. The table is created once per button and reused.
---@param button table
---@param action BRSecureAction
local function StoreAction(button, action)
    local stored = button._br_action
    if stored then
        wipe(stored)
    else
        stored = {}
        button._br_action = stored
    end
    for key, value in pairs(action) do
        stored[key] = value
    end
end

---@return "hover"|"always"
local function RowRevealMode()
    local defaults = BR.profile.defaults
    return defaults and defaults.subIconReveal == "always" and "always" or "hover"
end

-- The single-target ranks of each group-cast buff, highest first. The buff data is static.
---@type table<string, number[]>
local singleRanksByKey = {}
local variantChoices = {}
-- One reused table per buff, so a sync pass does not allocate.
---@type table<string, SubChoiceSpell>
local groupRankByKey = {}

---@param def RaidBuff
---@return number[]
local function SingleRanks(def)
    local ranks = singleRanksByKey[def.key]
    if ranks then
        return ranks
    end
    local isGroup = {}
    for _, rank in ipairs(def.groupCast) do
        isGroup[rank.spellID] = true
    end
    ranks = {}
    local ids = def.spellID
    if type(ids) ~= "table" then
        ids = { ids }
    end
    ---@cast ids number[]
    for _, id in ipairs(ids) do
        if not isGroup[id] then
            ranks[#ranks + 1] = id
        end
    end
    singleRanksByKey[def.key] = ranks
    return ranks
end

-- A raid buff with a group version offers the variant that the main click does not
-- cast, on a member who lacks the buff. A group version needs its reagent in the bags.
---@type SubChoiceRow
local GROUP_VARIANT_ROW = {
    choiceUnit = function(def)
        return PickCastUnit(def.key)
    end,
    pick = function(def)
        local groupID, groupUnit = BR.BuffState.GetGroupCastSpellID(def)
        if groupID then
            return groupID, groupUnit or "player"
        end
        local spellID = GetActionSpellID(def)
        return spellID, spellID and PickCastUnit(def.key)
    end,
    others = function(def, _, spellID)
        wipe(variantChoices)
        local isGroup = false
        for _, rank in ipairs(def.groupCast) do
            isGroup = isGroup or rank.spellID == spellID
        end
        if isGroup then
            variantChoices[1] = SingleRanks(def)
        else
            local groupID = BR.BuffState.GetGroupRank(def.groupCast)
            if groupID then
                local choice = groupRankByKey[def.key]
                if choice then
                    choice.spellID = groupID
                else
                    choice = { spellID = groupID }
                    groupRankByKey[def.key] = choice
                end
                variantChoices[1] = choice
            end
        end
        return variantChoices
    end,
}

---The choice row of a buff: its own row, or the group variant of a group-cast raid buff.
---@param def table?
---@return SubChoiceRow?
local function RowOf(def)
    if not def then
        return nil
    end
    if def.subChoices then
        return def.subChoices
    end
    if def.groupCast and def.castOnMissing then
        return GROUP_VARIANT_ROW
    end
    return nil
end

---A choice only casts, so a choice row needs click-to-cast.
---@param frame table The buff frame
---@return boolean
local function HasRow(frame)
    return frame._br_rowItems ~= nil or (RowOf(frame.buffDef) ~= nil and IsCategoryClickable(frame.buffCategory))
end

---Wire an action onto a secure button. UpdateActionButtons resolves every frame on
---every display cycle, but the action rarely changes, so SameAction gates the
---attribute writes. The right-click write stays outside that gate, because the
---right-click option can change while the action does not.
---@param button table Secure button (click overlay or consumable action button)
---@param action BRSecureAction
local function ApplyAction(button, action)
    button._br_has_action = true
    button.itemID = action.itemID
    button._br_clickMacroFn = action.macroFn
    button._br_clickMacroSpellID = action.macroSpellID
    button._br_pickDef = action.pickDef
    button._br_clickSpellFn = action.spellFn
    button._br_chatRequestKey = action.chatKey
    button._br_chatRequestMsg = action.chatMsg
    if not action.chatKey then
        button._br_chatRequestCooldownUntil = nil
    end
    if not SameAction(button._br_action, action) then
        SetActionType(button, action.kind == "none" and "" or action.kind)
        if action.kind == "macro" then
            button:SetAttribute("macrotext", MacroText(action))
        elseif action.kind == "item" then
            button:SetAttribute("item", "item:" .. action.itemID)
        elseif action.kind == "spell" then
            button:SetAttribute("spell", action.spellID)
            -- Always write unit, because nil clears it. A stale "player" from a
            -- previous action retargets the cast onto the player.
            button:SetAttribute("unit", action.unit)
        end
        StoreAction(button, action)
    end
    SetRightClickMode(button)
end

---@param itemID number
---@param slot number? 16 or 17 for a weapon buff, nil otherwise
---@param tag string? Overrides the dirty-gate namespace
---@return BRSecureAction
local function ItemAction(itemID, slot, tag)
    local action = NewAction(slot and "macro" or "item", tag or (slot and "weaponitem" or "item"), itemID)
    action.itemID = itemID
    action.slot = slot
    return action
end

---@param spellID number
---@param unit string? Cast target (nil = default targeting)
---@return BRSecureAction
local function SpellAction(spellID, unit)
    local action = NewAction("spell", "spell", spellID)
    action.spellID = spellID
    action.unit = unit
    return action
end

---A macro the resolver can spell out in full. The text is then also the identity,
---unless a smaller `id` describes it.
---@param tag string
---@param macrotext string
---@param id any?
---@return BRSecureAction
local function MacroAction(tag, macrotext, id)
    local action = NewAction("macro", tag, id or macrotext)
    action.macrotext = macrotext
    return action
end

---@param frame table The buff frame
---@return number? slot 16 (main hand) or 17 (off hand), or nil
local function GetWeaponSlot(frame)
    if frame.key == "weaponBuff" then
        return 16
    end
    if frame.key == "weaponBuffOH" then
        return 17
    end
    return nil
end

---A bag item from the consumable scan. A feast or cauldron drops at the player location when
---the placeAtPlayer setting is on, because a ground target needs a second click.
---@param item table Scan entry with itemID and placed
---@param frame table The buff frame
---@return BRSecureAction
local function ConsumableItemAction(item, frame)
    if item.placed and BR.profile.defaults.placeAtPlayer ~= false then
        local action = NewAction("macro", "placeditem", item.itemID)
        action.itemID = item.itemID
        action.atPlayer = true
        return action
    end
    return ItemAction(item.itemID, GetWeaponSlot(frame))
end

-- Buff frames that own a secure child. Most frames never get one, so the sync
-- and hide-all paths iterate this set instead of every frame.
-- Weak keys are only a backstop: an overlay's script closures pin its frame, so
-- removal paths call UnregisterSecureHost. A custom buff deleted in combat stays
-- registered on purpose, so the next sync hides its orphaned overlay.
local secureHostFrames = setmetatable({}, { __mode = "k" })

---An extra frame registers its main frame, which is what SyncSecureButtons iterates.
---@param frame table The frame a secure child was created for
local function RegisterSecureHost(frame)
    secureHostFrames[frame.isExtraFrame and frame.mainFrame or frame] = true
end

---@param frame table
local function UnregisterSecureHost(frame)
    secureHostFrames[frame] = nil
end

local ICON_HOVER_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover"

---Match the hover highlight of a click overlay to the icon style. The Blizzard
---style gets the action-button hover art over its frame art; the flat style, or
---a missing atlas, keeps the square highlight.
local function StyleOverlayHighlight(overlay)
    local highlight = overlay.highlight
    local IconStyle = BR.IconStyle
    if IconStyle.UsesBlizzardArt() and BR.HasThemeAtlas(ICON_HOVER_ATLAS) then
        if not highlight._br_actionArt then
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT", 0, 0)
            -- SetAtlas keeps an earlier SetTexCoord crop.
            highlight:SetTexCoord(0, 1, 0, 1)
            highlight:SetAtlas(ICON_HOVER_ATLAS)
            highlight:SetBlendMode("BLEND")
            highlight._br_actionArt = true
        end
        local width, height = overlay:GetSize()
        highlight:SetSize(width * IconStyle.FRAME_WIDTH_RATIO, height)
    elseif highlight._br_actionArt then
        highlight:ClearAllPoints()
        highlight:SetAllPoints()
        highlight:SetBlendMode("BLEND")
        highlight:SetColorTexture(1, 1, 1, 0.2)
        highlight:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)
        highlight._br_actionArt = false
    end
end

-- ============================================================================
-- CHOICE PICK AND CHOICE ROW
-- ============================================================================
-- A subChoices reminder names its next cast and its person on hover. The click and
-- the choice row act on that person while the pick stays valid.

local NEXT_LEAD = L["Tooltip.Next"]

-- Frames whose row is open in "hover" mode.
local openRows = setmetatable({}, { __mode = "k" })

---The rank that the level of the unit accepts, else the highest known rank.
---@param ranks number[] Highest rank first
---@param unit string
---@return number?
local function FitRank(ranks, unit)
    local pickRank = BR.DriveBy and BR.DriveBy.PickRank
    local rank = pickRank and pickRank(ranks, Plain(UnitLevel(unit)) or -1)
    if rank then
        return rank
    end
    local isKnown = BR.StateHelpers.IsPlayerSpellCached
    for _, id in ipairs(ranks) do
        if isKnown(id) then
            return id
        end
    end
    return nil
end

---@param units string[]?
---@param unit string
---@return boolean
local function IsListed(units, unit)
    if not units then
        return false
    end
    for i = 1, #units do
        if units[i] == unit then
            return true
        end
    end
    return false
end

---The pick of the hover, while its unit is the same player and still lacks or
---renews the buff, is in range and is not phased. Only a classChoices buff keeps
---a pick, because its pick can change with range.
---@param frame table The buff frame
---@return number? spellID
---@return string? unit
local function RememberedPick(frame)
    local def = frame.buffDef
    local unit = frame._br_pickUnit
    local guid = frame._br_pickGUID
    if not def.classChoices or not unit or not guid or Plain(UnitGUID(unit)) ~= guid then
        return nil
    end
    local key = def.key
    if
        not IsListed(BR.BuffState.GetMissingUnits(key), unit)
        and not IsListed(BR.BuffState.GetChoiceRenewUnits(key), unit)
    then
        return nil
    end
    if unit ~= "player" and (Plain(UnitInRange(unit)) ~= true or Plain(UnitPhaseReason(unit)) ~= nil) then
        return nil
    end
    return frame._br_pickSpell, unit
end

---The cast of the main icon: the remembered pick, else a new pick.
---@param frame table The buff frame
---@return number? spellID
---@return string? unit
local function CurrentPick(frame)
    local spellID, unit = RememberedPick(frame)
    if spellID then
        return spellID, unit
    end
    local def = frame.buffDef
    return RowOf(def).pick(def)
end

---The cast of a click on a castOnMissing buff, read at click time. The stored action
---of a classChoices buff holds any known spell: the member that the click picks names
---the spell.
---@param pickDef RaidBuff
---@param frame table The buff frame
---@param spellID number? The spell of the stored action
---@return number? spellID nil casts nothing
---@return string? unit
local function PickDefCast(pickDef, frame, spellID)
    if pickDef.subChoices then
        return CurrentPick(frame)
    end
    local groupSpellID, groupUnit = BR.BuffState.GetGroupCastSpellID(pickDef)
    if groupSpellID then
        return groupSpellID, groupUnit
    end
    if pickDef.classChoices then
        return BR.BuffState.GetChoiceCast(pickDef)
    end
    return spellID, PickCastUnit(pickDef.key)
end

---Shown above the anchor, because the choice row can open below it.
---@param anchor table
---@param unit string
---@param spellID number
---@param lead? string
local function ShowPickTooltip(anchor, unit, spellID, lead)
    local _, class = UnitClass(unit)
    local name = Plain(UnitName(unit)) or unit
    ShowLastTargetTooltip(anchor, name, Plain(class), nil, lead, true, spellID)
end

---@param frame table The buff frame
---@param spellID number
---@param unit string
local function RememberPick(frame, spellID, unit)
    frame._br_pickSpell = spellID
    frame._br_pickUnit = unit
    frame._br_pickGUID = Plain(UnitGUID(unit))
end

---Remember a new pick and show it. Out of combat only.
---@param overlay table
---@param frame table The buff frame
---@return boolean shown false when the click casts nothing
local function ShowNextPick(overlay, frame)
    frame._br_pickUnit = nil
    local entry = BR.BuffState.entries[frame.key]
    if InCombatLockdown() or (entry and entry.noClick) then
        return false
    end
    local def = frame.buffDef
    local spellID, unit = def.subChoices.pick(def)
    if not spellID or not unit then
        return false
    end
    RememberPick(frame, spellID, unit)
    BR.SecureButtons.ScheduleSecureSync()
    if unit ~= "player" then
        ShowPickTooltip(overlay, unit, spellID, NEXT_LEAD)
        return true
    end
    -- A self pick names no person, so only the description tooltip shows it.
    BR.SecureButtons.ShowDescriptionTooltip(overlay, frame, { spellID = spellID })
    return true
end

---@param frame table The buff frame
local function FinishCloseRow(frame)
    if frame.buffText then
        frame.buffText:SetAlpha(1)
    end
    BR.SecureButtons.ScheduleSecureSync()
end

---Close the row. The secure sync does not run in combat, so the "BUFF!" text
---comes back here.
---@param frame table The buff frame
---@param instant? boolean Skip the fade-out
local function CloseRow(frame, instant)
    openRows[frame] = nil
    local fading = false
    if not instant and not InCombatLockdown() and RowRevealMode() == "hover" then
        for _, btn in ipairs(frame.actionButtons or {}) do
            if btn:IsVisible() then
                btn._br_fadeIn:Stop()
                -- A fading button must not cast.
                btn:EnableMouse(false)
                btn._br_fadeOut:Play()
                fading = true
            end
        end
    end
    if not fading then
        FinishCloseRow(frame)
        return
    end
    C_Timer.After(SubIcons.FADE_OUT_DURATION, function()
        if not openRows[frame] then
            FinishCloseRow(frame)
        end
    end)
end

local HOVER_GRACE = 0.3

---Forget the pick and close the row when the cursor leaves both the icon and its
---row. The delay covers the gap between them.
---@param frame table The buff frame
local function EndHoverSoon(frame)
    C_Timer.After(HOVER_GRACE, function()
        -- IsMouseOver ignores the mouse state, so it also covers an icon with no overlay.
        if frame:IsVisible() and frame:IsMouseOver() then
            return
        end
        local overlay = frame.clickOverlay
        if overlay and overlay:IsVisible() and overlay:IsMouseOver() then
            return
        end
        for _, btn in ipairs(frame.actionButtons or {}) do
            if btn:IsVisible() and btn:IsMouseOver() then
                -- A button with the mouse off gets no OnLeave to end the hover.
                if not btn:IsMouseEnabled() then
                    EndHoverSoon(frame)
                end
                return
            end
        end
        frame._br_pickUnit = nil
        -- An "always" row never closes, and a close shows the "BUFF!" text for one frame.
        if RowRevealMode() == "hover" then
            CloseRow(frame)
        end
    end)
end

---In "hover" mode, show the row while the cursor is on the icon or the row.
---@param frame table The buff frame
local function OpenRow(frame)
    if InCombatLockdown() or RowRevealMode() ~= "hover" or openRows[frame] then
        return
    end
    openRows[frame] = true
    -- The fill gives the mouse back to the buttons that a fade-out took it from.
    if frame._br_rowItems then
        frame._br_rowDirty = true
    end
    -- A faded button can stay on its driver until the sync parks it: undo the fade.
    -- The sync takes the mouse back.
    for _, btn in ipairs(frame.actionButtons or {}) do
        btn._br_fadeOut:Stop()
        btn:SetAlpha(btn._br_alpha)
    end
    BR.SecureButtons.ScheduleSecureSync()
end

---Draw the 5 s swipe of the chat-request lockout over a click overlay.
---@param overlay table
---@param frame table The buff frame of the overlay
local function ShowRequestLockout(overlay, frame)
    if not overlay._br_chatRequestCooldown then
        local cd = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
        cd:SetDrawBling(false)
        cd:SetHideCountdownNumbers(true)
        cd.noCooldownCount = true
        overlay._br_chatRequestCooldown = cd
    end
    BR.IconStyle.AnchorCooldown(overlay._br_chatRequestCooldown, overlay, frame)
    overlay._br_chatRequestCooldown:SetCooldown(GetTime(), 5)
end

-- The overlay is parented to UIParent with NO anchor to the buff frame hierarchy:
-- a layout dependency on that hierarchy makes the hierarchy protected.
-- SyncSecureButtons positions it after each layout pass.
---@param frame table The parent buff frame
local function CreateClickOverlay(frame)
    RegisterSecureHost(frame)
    local overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    overlay:RegisterForClicks("AnyDown", "AnyUp")
    overlay:EnableMouse(false)
    overlay:Hide()
    RegisterStateDriver(overlay, "visibility", "[combat] hide; show")
    overlay._br_hostFrame = frame
    -- IsVisible(), not IsShown(): the frame's own shown state can be true while
    -- its parent container is hidden.
    overlay:SetScript("OnShow", function(self)
        if not frame:IsVisible() then
            self:Hide()
        end
    end)
    -- Never write macrotext for a chat-request overlay here. The secure dispatcher
    -- can read the attribute snapshot before the write propagates, which sends a
    -- stale channel prefix. RefreshChatRequestMacros rewires those overlays instead.
    overlay:SetScript("PreClick", function(self, button)
        if button == "RightButton" and self._br_rightClick == "menu" then
            return
        end
        -- A spell action with no spell casts nothing. PostClick writes the spell back.
        local entry = BR.BuffState.entries[frame.key]
        if entry and entry.noClick and self._br_action_type == "spell" and not InCombatLockdown() then
            self:SetAttribute("spell", nil)
            self._br_spellCleared = true
            return
        end
        if self._br_clickMacroFn and not self._br_chatRequestKey then
            local noClick = entry and entry.noClick
            self:SetAttribute("macrotext", noClick and "" or self._br_clickMacroFn(self._br_clickMacroSpellID))
        end
        local pickDef = self._br_pickDef
        if pickDef and not InCombatLockdown() then
            -- With no pick, the click casts nothing, and PostClick writes the spell back.
            local castID, castUnit = PickDefCast(pickDef, frame, self._br_action.spellID)
            self:SetAttribute("spell", castID)
            self._br_spellCleared = castID == nil or nil
            self:SetAttribute("unit", castUnit or "player")
        end
        local spellFn = self._br_clickSpellFn
        if spellFn and not InCombatLockdown() then
            self:SetAttribute("spell", spellFn())
        end
    end)
    overlay:SetScript("PostClick", function(self, button, down)
        if self._br_spellCleared then
            self._br_spellCleared = nil
            if not InCombatLockdown() then
                self:SetAttribute("spell", self._br_action.spellID)
            end
        end
        if HandleMenuClick(self, button, down, frame) then
            return
        end
        -- The down event can carry the cast, so the up event drops the pick. The
        -- refresh after the cast fills the row for the next pick.
        if not down then
            frame._br_pickUnit = nil
        end
        if self._br_action_type == "" then
            return
        end
        if self._br_chatRequestKey then
            -- Anti-spam gate. Some players report that it stops the chat dispatch
            -- in restricted contexts. The cause is not known, so the Chat Requests
            -- page can turn it off.
            if BR.profile.chatRequestCooldown ~= false then
                self._br_chatRequestCooldownUntil = GetTime() + 5
                self:EnableMouse(false)
                ShowRequestLockout(self, frame)
                C_Timer.After(5, function()
                    -- ApplyAction and DisableOverlay clear the flag, so a stale
                    -- fire after a role change does nothing.
                    -- If combat started inside the window, skip EnableMouse: it is
                    -- protected during lockdown. UpdateActionButtons re-enables the
                    -- mouse after combat.
                    if self._br_chatRequestKey then
                        self._br_chatRequestCooldownUntil = nil
                        if not InCombatLockdown() then
                            self:EnableMouse(true)
                        end
                    end
                end)
            end
            return
        end
        BR.ConsumableMemory.RememberChoice(self.itemID, frame)
        C_Timer.After(0.3, function()
            if not InCombatLockdown() then
                BR.BuffState.InvalidateItemCache()
                BR.SecureButtons.InvalidateConsumableCache()
                BR.Display.Update()
                -- The tooltip must not name the target of the last cast.
                if frame.buffDef and frame.buffDef.subChoices and self:IsVisible() and self:IsMouseOver() then
                    if not ShowNextPick(self, frame) then
                        HideLastTargetTooltip()
                    end
                end
            end
        end)
        -- Second refresh for spells with a cast time, such as rogue poisons.
        if self._br_clickMacroFn then
            C_Timer.After(2, function()
                if not InCombatLockdown() then
                    BR.BuffState.InvalidateItemCache()
                    BR.SecureButtons.InvalidateConsumableCache()
                    BR.Display.Update()
                end
            end)
        end
    end)
    overlay.highlight = overlay:CreateTexture(nil, "HIGHLIGHT")
    overlay.highlight:SetAllPoints()
    overlay.highlight:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)
    overlay.highlight:SetColorTexture(1, 1, 1, 0.2)
    overlay:HookScript("OnEnter", StyleOverlayHighlight)
    overlay:HookScript("OnEnter", function()
        if HasRow(frame) then
            OpenRow(frame)
        end
        if
            frame.buffDef
            and frame.buffDef.subChoices
            and IsCategoryClickable(frame.buffCategory)
            and ShowNextPick(overlay, frame)
        then
            return
        end
        -- An overlay with no left action exists only for the right-click menu, so no
        -- cast target applies. The anchor is the overlay: the cursor is over the
        -- overlay, not over the buff frame below it.
        if overlay._br_action_type == "" then
            BR.SecureButtons.ShowDescriptionTooltip(overlay, frame)
            return
        end
        -- Only the caster class has a meaningful last target.
        local def = frame.buffDef
        if
            def
            and BuffTargets.DEFAULT_TARGET[frame.buffCategory]
            and BuffTargets.PicksUnit(BuffTargets.Resolve(def, frame.buffCategory))
            and not (def.class and def.class ~= playerClass)
        then
            local name, class = BR.TargetMemory.Get(def.key)
            -- A pinned target overrides the automatic memory. The class color is
            -- known only when the pin matches the remembered player. If the pinned
            -- player is not in the group, the click macro does nothing.
            local hint
            local pinned = frame.buffDef.pinnedTarget and frame.buffDef.pinnedTarget()
            if pinned then
                if pinned ~= name then
                    class = nil
                end
                name = pinned
                local ok, inGroup = pcall(UnitExists, pinned)
                if not (ok and inGroup) then
                    hint = L["Tooltip.PinNotInGroup"]
                end
            end
            hint = hint or def.targetHint
            if not name then
                BR.SecureButtons.ShowDescriptionTooltip(overlay, frame)
                return
            end
            local function showTargetInfo()
                ShowLastTargetTooltip(overlay, name, class, hint)
            end
            -- The target joins the description as a line. While the tooltip key is
            -- up, and where the description is off, the target info shows alone.
            local shown = BR.SecureButtons.ShowDescriptionTooltip(overlay, frame, {
                addLines = function(tooltip)
                    -- The description owns GameTooltip by now, so only the own frame hides.
                    if lastTargetTooltip then
                        lastTargetTooltip:Hide()
                    end
                    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                    local text = hint and (name .. " |cff888888" .. hint .. "|r") or name
                    tooltip:AddLine(" ")
                    tooltip:AddLine(
                        L["Tooltip.TargetLine"]:format(text),
                        c and c.r or 1,
                        c and c.g or 1,
                        c and c.b or 1
                    )
                end,
                fallback = showTargetInfo,
            })
            if not shown then
                showTargetInfo()
            end
            return
        end
        BR.SecureButtons.ShowDescriptionTooltip(overlay, frame)
    end)
    overlay:HookScript("OnLeave", function()
        if HasRow(frame) then
            EndHoverSoon(frame)
        end
        HideLastTargetTooltip()
        BR.Display.EndHoverTooltip(overlay)
        if GameTooltip:IsOwned(overlay) then
            GameTooltip:Hide()
        end
    end)
    frame.clickOverlay = overlay
end

-- ============================================================================
-- PET SPEC ICON HOVER
-- ============================================================================
-- On hover, a pet frame shows its spec ability icon. Each overlay is hooked once.
-- The event handler reads the spec icon from the buff frame, so it stays current
-- across display updates.

---@param overlay table SecureActionButton overlay
---@param frame table The buff frame whose icon to swap
local function HookPetSpecIconHover(overlay, frame)
    if overlay._br_pet_hover_hooked then
        return
    end
    overlay._br_pet_hover_hooked = true
    overlay:HookScript("OnEnter", function()
        if not (BR.profile.defaults or {}).petSpecIconOnHover then
            return
        end
        local specIcon = frame._br_pet_spec_icon
        if specIcon then
            overlay._br_pet_hovering = true
            overlay._br_pet_real_icon = frame.icon:GetTexture()
            frame.icon:SetTexture(specIcon)
        end
    end)
    overlay:HookScript("OnLeave", function()
        overlay._br_pet_hovering = nil
        local realIcon = overlay._br_pet_real_icon
        if realIcon then
            frame.icon:SetTexture(realIcon)
            overlay._br_pet_real_icon = nil
        end
    end)
end

--- Call after a display update: it saves the icon the update applied, then puts the
--- spec icon back if the cursor is still on the overlay.
---@param frame table The buff frame to check
local function ReapplyPetSpecIconIfHovered(frame)
    local overlay = frame.clickOverlay
    if not overlay or not overlay._br_pet_hovering then
        return
    end
    local specIcon = frame._br_pet_spec_icon
    if specIcon and (BR.profile.defaults or {}).petSpecIconOnHover then
        overlay._br_pet_real_icon = frame.icon:GetTexture()
        frame.icon:SetTexture(specIcon)
    end
end

-- ============================================================================
-- CONSUMABLE ACTION BUTTONS
-- ============================================================================

local BADGE_COLORS = {
    [L["Badge.Hearty"]] = { r = 0.4, g = 0.7, b = 1 },
    [L["Badge.Fleeting"]] = { r = 0.4, g = 0.7, b = 1 },
    [L["Badge.Cauldron"]] = { r = 0.4, g = 0.7, b = 1 },
}

---@param mainIconSize number The consumable category's main icon size
---@param item string? A BR.TextPositions.SizedItems key; nil uses the shared base
---@return number fontSize
local function ComputeConsumableFontSize(mainIconSize, item)
    return max(6, floor(mainIconSize * BR.TextPositions.GetSizePercent(item) / 100))
end

---@param owner table An item row button
local function ShowItemRowTooltip(owner)
    if owner.itemID and owner._br_buff_frame then
        BR.SecureButtons.ShowDescriptionTooltip(owner, owner._br_buff_frame, { itemID = owner.itemID })
    end
end

---@return table btn The created button
local function CreateActionButton()
    local btn = SubIcons.CreateButton()
    -- The refresh runs shortly after the click so the consumed buff disappears fast.
    btn:SetScript("PostClick", function(self, button, down)
        if HandleMenuClick(self, button, down, self._br_buff_frame) then
            return
        end
        BR.ConsumableMemory.RememberChoice(self.itemID, self._br_buff_frame)
        C_Timer.After(0.3, function()
            if not InCombatLockdown() then
                BR.BuffState.InvalidateItemCache()
                BR.SecureButtons.InvalidateConsumableCache()
                BR.Display.Update()
            end
        end)
    end)
    btn:SetScript("OnEnter", ShowItemRowTooltip)
    btn:SetScript("OnLeave", function(self)
        BR.Display.EndHoverTooltip(self)
        GameTooltip:Hide()
        EndHoverSoon(self._br_buff_frame)
    end)

    return btn
end

-- The bags are rescanned only when BAG_UPDATE_DELAYED fires.
local consumableCache = {}
local consumableCacheDirty = true

local function InvalidateConsumableCache()
    consumableCacheDirty = true
end

-- The item filters change the cached arrays, not the bag scan. Invalidate them so
-- the next render rebuilds them with the new filter.
BR.CallbackRegistry:RegisterCallback("SettingChanged", function(_, path)
    if path == "defaults.hideLegacyConsumables" or path == "defaults.preferReusableRunes" then
        consumableCacheDirty = true
    end
end)

-- The sort reads the running aura, and a world-entry resolve can build the arrays
-- before the first state refresh reports it.
BR.CallbackRegistry:RegisterCallback("ActiveConsumableChanged", function()
    consumableCacheDirty = true
end)

---Stack count text for a bag item. A permanent item shows none.
---@param item table?
---@return string
local function FormatStackCount(item)
    if not item or item.permanent then
        return ""
    end
    return tostring(item.count)
end

---Cooldown of a bag item, or nil when it has none. C_Item.GetItemCooldown throws
---in a restricted context, and its returns can be secret values, so a failed or
---secret read yields nil.
---@param itemID number?
---@return number? start
---@return number? duration
local function GetItemCooldown(itemID)
    if not itemID then
        return nil
    end
    if BR.Restrictions.CooldownsRestricted() then
        return nil
    end
    local ok, start, duration = pcall(C_Item.GetItemCooldown, itemID)
    if not ok then
        return nil
    end
    start, duration = Plain(start), Plain(duration)
    if not start or not duration or duration <= 0 then
        return nil
    end
    return start, duration
end

local function RefreshConsumableCache()
    if not consumableCacheDirty then
        return
    end
    consumableCacheDirty = false

    if not C_Container or not C_Container.GetContainerNumSlots then
        wipe(consumableCache)
        return
    end

    local specId = BR.StateHelpers and BR.StateHelpers.GetPlayerSpecId()
    local itemSets = BR.CONSUMABLE_ITEMS or {}
    local defs = BR.profile and BR.profile.defaults or {}
    local hideLegacy = defs.hideLegacyConsumables ~= false
    local preferReusableRunes = defs.preferReusableRunes == true
    local buckets = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                for category, allowedSet in pairs(itemSets) do
                    local allowedEntry = allowedSet[itemID]
                    if allowedEntry and not (buckets[category] and buckets[category][itemID]) then
                        if not buckets[category] then
                            buckets[category] = {}
                        end
                        -- A failed count skips the item until the next bag scan.
                        local ok, count = pcall(C_Item.GetItemCount, itemID, false, true)
                        count = (ok and count) or 0
                        if count > 0 then
                            local info = C_Container.GetContainerItemInfo(bag, slot)
                            local icon = info and info.iconFileID or nil
                            local bucket = {
                                itemID = itemID,
                                count = count,
                                icon = icon,
                            }
                            if type(allowedEntry) == "table" then
                                bucket.statLabel = allowedEntry.label
                                bucket.badge = allowedEntry.badge
                                bucket.weaponClass = allowedEntry.weaponClass
                            end
                            -- The item link carries the crafted quality tier.
                            local hyperlink = info and info.hyperlink
                            if hyperlink then
                                local suffix = hyperlink:match("Quality%-[%w%-]*Tier%d")
                                if suffix then
                                    bucket.qualityAtlas = "Professions-Icon-" .. suffix
                                end
                            end
                            -- ConsumableMemory looks the item up by the spell it casts.
                            local okSpell, _, useSpellID = pcall(C_Item.GetItemSpell, itemID)
                            if okSpell and useSpellID then
                                bucket.useSpellID = useSpellID
                            end
                            buckets[category][itemID] = bucket
                        end
                    end
                end
            end
        end
    end

    BR.ConsumableMemory.DetectConsumedItems(buckets, specId)

    -- The legacy filter runs here, not during the bag scan: ConsumableMemory must
    -- see unfiltered data or its consumption counts go wrong.
    wipe(consumableCache)
    for category, entries in pairs(buckets) do
        local items = {}
        local allowedSet = itemSets[category]
        local runeFallback = preferReusableRunes and category == "rune" and {} or nil
        for itemID, item in pairs(entries) do
            local entry = allowedSet and allowedSet[itemID]
            item.permanent = type(entry) == "table" and entry.permanent or nil
            item.placed = type(entry) == "table" and entry.placed or nil
            if not (hideLegacy and type(entry) == "table" and entry.legacy) then
                if runeFallback and not item.permanent then
                    runeFallback[#runeFallback + 1] = item
                else
                    items[#items + 1] = item
                end
            end
        end
        -- The preference must never leave the player with nothing to click. With no
        -- reusable rune in the bags, the consumed runes come back.
        if runeFallback and #items == 0 then
            items = runeFallback
        end
        if #items > 0 then
            local rememberedSpell = BR.ConsumableMemory.GetRemembered(specId, category)
            -- A drink fires BAG_UPDATE_DELAYED after its aura lands, so a scan-time read is current.
            local activeSpell = BR.BuffState.GetActiveConsumableSpell(category)
            -- The stat label spans the regular and fleeting forms of one consumable. An
            -- unlabeled category, such as runes, keeps its priority order: every rune
            -- grants the same effect, so no item is "the same" one to refresh.
            local activeLabel
            if activeSpell then
                for _, item in ipairs(items) do
                    if item.useSpellID == activeSpell then
                        activeLabel = item.statLabel
                        break
                    end
                end
            end
            tsort(items, function(a, b)
                -- The stat of the running aura sorts first, so a refresh keeps the stat
                -- and the main icon shows the aura it extends.
                if activeLabel then
                    local aAct = a.statLabel == activeLabel
                    local bAct = b.statLabel == activeLabel
                    if aAct ~= bAct then
                        return aAct
                    end
                end
                -- A lower priority value sorts first.
                local aPri = allowedSet and allowedSet[a.itemID]
                local bPri = allowedSet and allowedSet[b.itemID]
                local aNum = type(aPri) == "number" and aPri or (type(aPri) == "table" and aPri.priority) or nil
                local bNum = type(bPri) == "number" and bPri or (type(bPri) == "table" and bPri.priority) or nil
                if (aNum ~= nil) ~= (bNum ~= nil) then
                    return aNum ~= nil
                end
                if aNum and bNum and aNum ~= bNum then
                    return aNum < bNum
                end
                if rememberedSpell then
                    local aRem = a.useSpellID == rememberedSpell
                    local bRem = b.useSpellID == rememberedSpell
                    if aRem ~= bRem then
                        return aRem
                    end
                end
                if a.count == b.count then
                    return a.itemID < b.itemID
                end
                return a.count > b.count
            end)
            consumableCache[category] = items
        end
    end
    BR.ConsumableMemory.SnapshotCounts(buckets)
end

local BUFF_KEY_TO_CATEGORY = BR.BUFF_KEY_TO_CATEGORY

-- Weapon subclasses (Enum.ItemWeaponSubclass) that each weaponClass accepts.
local WEAPON_CLASS_SUBCLASSES = {
    edged = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true },
    blunt = { [4] = true, [5] = true, [10] = true, [13] = true },
}

-- Filtered weapon item list per hand slot. It is rebuilt when the bag scan makes a
-- new list or the weapon in the hand changes.
---@type table<number, { source: table, subclass: number|false, list: table[] }>
local weaponFitCache = {}

---Drop the items that do not fit the weapon in the hand. The order of the sorted list stays.
---@param items table[] Sorted bag scan items of the weapon category
---@param slot number 16 (main hand) or 17 (off hand)
---@return table[]
local function FilterForWeapon(items, slot)
    local subclass = BR.BuffState.GetWeaponSubclass(slot) or false
    local cached = weaponFitCache[slot]
    if cached and cached.source == items and cached.subclass == subclass then
        return cached.list
    end
    local list = {}
    for _, item in ipairs(items) do
        local accepted = item.weaponClass and WEAPON_CLASS_SUBCLASSES[item.weaponClass]
        if not accepted or (subclass and accepted[subclass]) then
            list[#list + 1] = item
        end
    end
    weaponFitCache[slot] = { source = items, subclass = subclass, list = list }
    return list
end

---@param buff table The buff definition table
---@return table[]? items Array of { itemID, count, icon } sorted by count desc, or nil
local function GetConsumableActionItems(buff)
    if not buff then
        return nil
    end
    local category = BUFF_KEY_TO_CATEGORY[buff.key]
    if not category then
        return nil
    end
    RefreshConsumableCache()
    local items = consumableCache[category]
    local slot = buff.checkWeaponEnchant and 16 or buff.checkWeaponEnchantOH and 17 or nil
    if items and slot then
        items = FilterForWeapon(items, slot)
    end
    return items and #items > 0 and items or nil
end

---Set the item row of a consumable buff frame to actionItems[startIndex..]. If no
---item is at or after startIndex, the row clears. SyncSecureButtons builds and
---positions the buttons.
---@param frame table The buff frame
---@param actionItems table[]|false|nil Array of { itemID, count, icon }
---@param startIndex? number First index in actionItems to show (default 1)
local function SetItemRow(frame, actionItems, startIndex)
    startIndex = startIndex or 1
    if actionItems and #actionItems >= startIndex then
        frame._br_rowItems = actionItems
        frame._br_rowStart = startIndex
        frame._br_rowDirty = true
        RegisterSecureHost(frame)
        return
    end
    frame._br_rowItems = nil
    openRows[frame] = nil
    if not frame.actionButtons then
        return
    end
    local inCombat = InCombatLockdown()
    for _, btn in ipairs(frame.actionButtons) do
        -- A plain field: the next sync parks the button.
        btn._br_visible = false
        if not inCombat then
            btn:Hide()
        end
    end
end

---Fill the item row buttons from the items that SetItemRow stored. Out of combat only.
---@param frame table The buff frame
local function FillItemRow(frame)
    local items = frame._br_rowItems
    local buttons = frame.actionButtons
    if not buttons then
        buttons = {}
        frame.actionButtons = buttons
    end
    local clickable = IsCategoryClickable(frame.buffCategory)
    local showHighlight = clickable and GetCategorySetting(frame.buffCategory, "clickableHighlight") ~= false
    frame._br_rowDirty = nil
    local count = 0
    for i = frame._br_rowStart, #items do
        count = count + 1
        local item = items[i]
        local btn = buttons[count]
        if not btn then
            btn = CreateActionButton()
            btn._br_buff_frame = frame
            buttons[count] = btn
        end

        btn.icon:SetTexture(item.icon or 134400)
        ApplyAction(btn, ConsumableItemAction(item, frame))

        btn:EnableMouse(clickable)
        btn.highlight:SetShown(showHighlight)
        btn._br_count = item.count
        btn._br_permanent = item.permanent
        btn._br_qualityAtlas = item.qualityAtlas
        btn._br_badge = item.badge
        btn._br_needs_sync = true
    end
    frame._br_rowCount = count
    for i = count + 1, #buttons do
        buttons[i]._br_visible = false
        buttons[i]:Hide()
    end
end

---Fill the item row if its items or settings changed, then show or hide it. Out of combat only.
---@param frame table The buff frame
---@param shown boolean The row is open
local function ShowItemRow(frame, shown)
    if frame._br_rowDirty then
        FillItemRow(frame)
    end
    local count = shown and frame._br_rowCount or 0
    for i, btn in ipairs(frame.actionButtons) do
        btn._br_visible = i <= count
    end
end

---A click-through hover area over an icon whose item row has no overlay to open it.
---@param frame table The buff frame
---@param on boolean
local function SetHoverCatcher(frame, on)
    local catcher = frame._br_hoverCatcher
    if not on then
        if catcher then
            catcher:Hide()
        end
        return
    end
    if not catcher then
        catcher = CreateFrame("Frame", nil, frame)
        catcher:SetAllPoints()
        -- The catcher covers the icon, so it passes the hover on to the icon scripts.
        catcher:SetScript("OnEnter", function()
            OpenRow(frame)
            local onEnter = frame:GetScript("OnEnter")
            if onEnter then
                onEnter(frame)
            end
        end)
        catcher:SetScript("OnLeave", function()
            EndHoverSoon(frame)
            local onLeave = frame:GetScript("OnLeave")
            if onLeave then
                onLeave(frame)
            end
        end)
        -- After the scripts, because an OnEnter script turns the whole mouse on.
        -- Motion only, so a click reaches the world.
        catcher:SetMouseClickEnabled(false)
        catcher:SetMouseMotionEnabled(true)
        frame._br_hoverCatcher = catcher
    end
    catcher:Show()
end

---The target of the choice buttons of a frame.
---@param frame table The buff frame
---@return string? unit
local function ChoiceUnit(frame)
    local def = frame.buffDef
    local row = RowOf(def)
    if row and row.choiceUnit then
        return row.choiceUnit(def)
    end
    local _, unit = CurrentPick(frame)
    return unit
end

---@param btn table A choice button
---@param unit string
---@return number? spellID
local function ChoiceCast(btn, unit)
    return btn._br_spell or (btn._br_ranks and FitRank(btn._br_ranks, unit))
end

---A consumable action button that casts one choice of a choice row, or uses the
---item of an item choice.
---@param frame table The buff frame
---@return table btn
local function CreateChoiceButton(frame)
    local btn = CreateActionButton()
    btn._br_buff_frame = frame
    btn._br_choice = true
    btn:SetScript("PreClick", function(self, button)
        if
            InCombatLockdown()
            or not (self._br_ranks or self._br_spell)
            or (button == "RightButton" and self._br_rightClick == "menu")
        then
            return
        end
        local unit = ChoiceUnit(frame) or "player"
        self:SetAttribute("spell", ChoiceCast(self, unit))
        self:SetAttribute("unit", unit)
    end)
    btn:SetScript("PostClick", function(self, button, down)
        HandleMenuClick(self, button, down, frame)
    end)
    btn:SetScript("OnEnter", function(self)
        if InCombatLockdown() then
            return
        end
        local itemID = self.itemID
        if itemID then
            BR.SecureButtons.ShowDescriptionTooltip(self, frame, { itemID = itemID })
            return
        end
        if not (self._br_ranks or self._br_spell) then
            return
        end
        local pickSpellID, pickUnit = CurrentPick(frame)
        if not pickSpellID or not pickUnit then
            return
        end
        -- A row click casts on the person that this tooltip names.
        RememberPick(frame, pickSpellID, pickUnit)
        local unit = ChoiceUnit(frame)
        local castID = unit and ChoiceCast(self, unit)
        if unit and castID then
            ShowPickTooltip(self, unit, castID)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        HideLastTargetTooltip()
        BR.Display.EndHoverTooltip(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
        EndHoverSoon(frame)
    end)
    return btn
end

---Fill the choice row of a buff frame with the other choices for the
---person of the main icon. SyncSecureButtons positions the row. Out of combat only.
---@param frame table The buff frame
---@param active boolean The click overlay shows
---@param shown boolean The row is open
local function UpdateChoiceRow(frame, active, shown)
    local buttons = frame.actionButtons
    local others, unit
    if active then
        local def = frame.buffDef
        local spellID, pickUnit = CurrentPick(frame)
        others = spellID and pickUnit and RowOf(def).others(def, pickUnit, spellID)
        unit = others and ChoiceUnit(frame)
    end
    local valid, count = 0, 0
    if others and unit then
        local showHighlight = GetCategorySetting(frame.buffCategory, "clickableHighlight") ~= false
        for _, choice in ipairs(others) do
            local itemID = choice.itemID
            local fixedID = choice.spellID
            local ranks = not itemID and not fixedID and choice or nil
            local castID = fixedID or (ranks and FitRank(ranks, unit))
            local usable = itemID ~= nil or castID ~= nil
            if usable then
                valid = valid + 1
            end
            if shown and usable then
                if not buttons then
                    buttons = {}
                    frame.actionButtons = buttons
                end
                count = count + 1
                local btn = buttons[count]
                if not btn then
                    btn = CreateChoiceButton(frame)
                    buttons[count] = btn
                end
                btn._br_ranks = ranks
                btn._br_spell = fixedID
                local action = btn._br_action
                if itemID then
                    if not action or action.itemID ~= itemID then
                        btn.icon:SetTexture(C_Item.GetItemIconByID(itemID) or 134400)
                        ApplyAction(btn, ItemAction(itemID))
                    end
                elseif castID and (not action or action.spellID ~= castID or action.unit ~= unit) then
                    btn.icon:SetTexture(BR.Icons.GetBuffTexture(castID))
                    ApplyAction(btn, SpellAction(castID, unit))
                end
                -- ApplyAction runs only when the choice changes, and the setting can change alone.
                SetRightClickMode(btn)
                btn.highlight:SetShown(showHighlight)
                btn:EnableMouse(true)
                btn._br_visible = true
            end
        end
    end
    frame._br_rowHasChoices = valid > 0
    for i = count + 1, buttons and #buttons or 0 do
        buttons[i]._br_visible = false
    end
    -- The row covers the "BUFF!" text below the icon.
    if frame.buffText then
        frame.buffText:SetAlpha(count > 0 and 0 or 1)
    end
end

-- An open row closes on combat start.
local rowEvents = CreateFrame("Frame")
BR.Client.RegisterEvent(rowEvents, "PLAYER_REGEN_DISABLED")
rowEvents:SetScript("OnEvent", function()
    for frame in pairs(openRows) do
        CloseRow(frame, true)
    end
end)

-- ============================================================================
-- SECURE FRAME SYNC
-- ============================================================================

---@return string category The frame's own category when it is split, else "main"
local function GetEffectiveCategory(frame)
    if frame.buffCategory and IsCategorySplit(frame.buffCategory) then
        return frame.buffCategory
    end
    return "main"
end

-- A mover drag calls this. Without it, sub-icons stay at the old position.
local function HideSecureFramesForCatKey(catKey)
    if InCombatLockdown() then
        return
    end
    for frame in pairs(secureHostFrames) do
        -- A detached icon matches on its own buff key - or its groupId, since
        -- grouped buffs store detach state under the group key.
        local effectiveCat = GetEffectiveCategory(frame)
        local groupId = frame.buffDef and frame.buffDef.groupId
        if effectiveCat == catKey or frame.key == catKey or groupId == catKey then
            openRows[frame] = nil
            if frame._br_hoverCatcher then
                frame._br_hoverCatcher:Hide()
            end
            if frame.actionButtons then
                for _, btn in ipairs(frame.actionButtons) do
                    SubIcons.Park(btn)
                end
            end
            if frame.clickOverlay then
                frame.clickOverlay:EnableMouse(false)
                frame.clickOverlay:Hide()
                frame.clickOverlay._br_left = nil
            end
            if frame.extraFrames then
                for _, extra in ipairs(frame.extraFrames) do
                    if extra.clickOverlay then
                        extra.clickOverlay:EnableMouse(false)
                        extra.clickOverlay:Hide()
                        extra.clickOverlay._br_left = nil
                    end
                end
            end
        end
    end
end

-- Safe to call at any time. It does nothing during combat lockdown.
local function HideAllSecureFrames()
    if InCombatLockdown() then
        return
    end
    for frame in pairs(secureHostFrames) do
        if frame.clickOverlay then
            frame.clickOverlay:EnableMouse(false)
            frame.clickOverlay:Hide()
            frame.clickOverlay._br_left = nil
        end
        openRows[frame] = nil
        if frame._br_hoverCatcher then
            frame._br_hoverCatcher:Hide()
        end
        if frame.actionButtons then
            for _, btn in ipairs(frame.actionButtons) do
                SubIcons.Park(btn)
            end
        end
        if frame.extraFrames then
            for _, extra in ipairs(frame.extraFrames) do
                if extra.clickOverlay then
                    extra.clickOverlay:EnableMouse(false)
                    extra.clickOverlay:Hide()
                    extra.clickOverlay._br_left = nil
                end
            end
        end
    end
end

---Place a click overlay over its host and show it, or hide it. On a shown overlay,
---the caller sets the mouse.
---@param overlay table SecureActionButton overlay
---@param host table The frame that the overlay covers
---@param active boolean The overlay takes clicks
---@return boolean placed The overlay shows over the host
local function SyncOverlay(overlay, host, active)
    if not active or not host:IsVisible() then
        overlay:EnableMouse(false)
        overlay:Hide()
        overlay._br_left = nil
        return false
    end
    local left, bottom, width, height = host:GetRect()
    if not left then
        return false
    end
    if
        overlay._br_left ~= left
        or overlay._br_bottom ~= bottom
        or overlay._br_width ~= width
        or overlay._br_height ~= height
    then
        overlay:ClearAllPoints()
        overlay:SetSize(width, height)
        overlay:SetFrameStrata(host:GetFrameStrata())
        overlay:SetFrameLevel(host:GetFrameLevel() + 5)
        overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        overlay._br_left = left
        overlay._br_bottom = bottom
        overlay._br_width = width
        overlay._br_height = height
    end
    if not overlay:IsShown() then
        overlay:Show()
    end
    return true
end

-- Secure buttons are placed in screen coordinates, never anchored, so they cannot
-- taint the buff frame hierarchy. Safe to call at any time. It does nothing during
-- combat lockdown.
local function SyncSecureButtons()
    if InCombatLockdown() then
        return
    end
    -- Test mode shows frames that no real buff state backs.
    if BR.Display.IsTestMode() then
        HideAllSecureFrames()
        return
    end
    local outlineFlag = BR.DisplayFonts.GetOutline()
    local ApplyFont = BR.DisplayFonts.Apply
    for frame in pairs(secureHostFrames) do
        -- Sync click overlay
        local overlay = frame.clickOverlay
        if overlay then
            local clickable = IsCategoryClickable(frame.buffCategory)
            -- Click to cast governs casting. A chat request answers its own toggle
            -- on the Chat Requests page, and a custom buff its own click action, so
            -- both stay clickable where the category turned click-to-cast off.
            if not clickable then
                clickable = overlay._br_chatRequestKey ~= nil
                    or (frame.buffCategory == "custom" and HasCustomClickAction(frame.buffDef))
            end
            if SyncOverlay(overlay, frame, clickable and overlay._br_has_action == true) then
                -- The cooldown timer clears the timestamp when it expires.
                -- The next sync run then re-enables the mouse.
                local cdEnabled = BR.profile.chatRequestCooldown ~= false
                local cdUntil = cdEnabled and overlay._br_chatRequestCooldownUntil
                overlay:EnableMouse(not (cdUntil and cdUntil > GetTime()))
            end
        end
        local itemRow = frame._br_rowItems ~= nil
        local overlayShown = overlay ~= nil and overlay:IsShown()
        if itemRow or (overlay and RowOf(frame.buffDef)) then
            if not frame:IsVisible() then
                openRows[frame] = nil
            end
            local revealed = openRows[frame] or RowRevealMode() == "always"
            if itemRow then
                ShowItemRow(frame, revealed)
            else
                -- A choice only casts, so a row opens only with click-to-cast on.
                local active = overlayShown and IsCategoryClickable(frame.buffCategory)
                UpdateChoiceRow(frame, active, active and revealed)
                if not frame._br_rowHasChoices then
                    openRows[frame] = nil
                end
            end
        end
        SetHoverCatcher(frame, itemRow and not overlayShown and RowRevealMode() == "hover")
        -- Sync action buttons (consumable item row or choice row)
        if frame.actionButtons then
            if frame:IsVisible() then
                local left, bottom, width, height = frame:GetRect()
                if left then
                    -- The row and its metrics follow the icon art, inside the border.
                    local hostInset = frame._br_borderInset or 0
                    left, bottom = left + hostInset, bottom + hostInset
                    width, height = width - 2 * hostInset, height - 2 * hostInset
                    local effectiveCat = GetEffectiveCategory(frame)
                    local catSettings = GetCategorySettings(effectiveCat)
                    local baseIconSize = (catSettings.iconSize or 64) - 2 * hostInset
                    local size, btnSpacing = SubIcons.Metrics(baseIconSize)
                    local subIconSide = (BR.profile.defaults or {}).subIconSide or "BOTTOM"
                    local visibleCount = 0
                    for _, btn in ipairs(frame.actionButtons) do
                        if btn._br_visible then
                            visibleCount = visibleCount + 1
                        end
                    end
                    if visibleCount > 0 then
                        local stackFontSize = ComputeConsumableFontSize(baseIconSize, "stackCount")
                        local badgeFontSize = ComputeConsumableFontSize(baseIconSize, "badge")
                        local showSubIconBadge = BR.Config.Get("defaults.consumableBadgeOnSubIcons") == true
                        local blizzardArt = BR.IconStyle.UsesBlizzardArt()
                        -- The buttons already inherit the UIParent alpha.
                        local uiAlpha = UIParent:GetEffectiveAlpha()
                        local hostAlpha = uiAlpha > 0 and frame:GetEffectiveAlpha() / uiAlpha or 1
                        local idx = 0
                        for _, btn in ipairs(frame.actionButtons) do
                            if btn._br_visible then
                                local btnX, btnY = SubIcons.Position(
                                    idx,
                                    visibleCount,
                                    subIconSide,
                                    left,
                                    bottom,
                                    width,
                                    height,
                                    size,
                                    btnSpacing
                                )
                                -- The size and outline stamps let the dirty check see
                                -- a font setting change. A face change needs no stamp:
                                -- linked fontstrings follow the shared font object.
                                local needsUpdate = btn._br_needs_sync
                                    or btn._br_x ~= btnX
                                    or btn._br_y ~= btnY
                                    or btn._br_size ~= size
                                    or btn._br_font_size ~= stackFontSize
                                    or btn._br_badge_font_size ~= badgeFontSize
                                    or btn._br_font_outline ~= outlineFlag
                                    or btn._br_blizzardArt ~= blizzardArt
                                if needsUpdate then
                                    btn:ClearAllPoints()
                                    btn:SetSize(size, size)
                                    SubIcons.ApplyStyle(btn, blizzardArt)
                                    StyleOverlayHighlight(btn)
                                    local strata = frame:GetFrameStrata()
                                    btn:SetFrameStrata(btn._br_choice and SubIcons.STRATA_ABOVE[strata] or strata)
                                    btn:SetFrameLevel(frame:GetFrameLevel() + 4)
                                    btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", btnX, btnY)
                                    btn._br_x = btnX
                                    btn._br_y = btnY
                                    btn._br_size = size
                                    btn.count:SetText(
                                        (btn._br_count and not btn._br_permanent) and tostring(btn._br_count) or ""
                                    )
                                    ApplyFont(btn.count, stackFontSize)
                                    -- The holder sits at +10 to draw above borders and glows.
                                    if btn._br_qualityAtlas then
                                        if not btn._br_qualityIcon then
                                            local qHolder = CreateFrame("Frame", nil, btn)
                                            qHolder:SetAllPoints()
                                            qHolder:SetFrameLevel(btn:GetFrameLevel() + 10)
                                            btn._br_qualityIcon = qHolder:CreateTexture(nil, "OVERLAY", nil, 7)
                                        end
                                        local qOffset = -floor(size * 0.125)
                                        local qSize = max(10, floor(size * 0.45))
                                        btn._br_qualityIcon:ClearAllPoints()
                                        btn._br_qualityIcon:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", qOffset, qOffset)
                                        btn._br_qualityIcon:SetSize(qSize, qSize)
                                        btn._br_qualityIcon:SetAtlas(btn._br_qualityAtlas)
                                        btn._br_qualityIcon:Show()
                                    elseif btn._br_qualityIcon then
                                        btn._br_qualityIcon:Hide()
                                    end
                                    local bc = showSubIconBadge and btn._br_badge and BADGE_COLORS[btn._br_badge]
                                    if bc then
                                        if not btn._br_badgeLabel then
                                            btn._br_badgeLabel = btn:CreateFontString(nil, "OVERLAY", nil, 7)
                                        end
                                        btn._br_badgeLabel:ClearAllPoints()
                                        btn._br_badgeLabel:SetPoint(
                                            "TOPLEFT",
                                            btn,
                                            "TOPLEFT",
                                            btn._br_textInset,
                                            -btn._br_textInset
                                        )
                                        ApplyFont(btn._br_badgeLabel, badgeFontSize)
                                        btn._br_badgeLabel:SetTextColor(bc.r, bc.g, bc.b, 1)
                                        btn._br_badgeLabel:SetText(btn._br_badge)
                                        btn._br_badgeLabel:Show()
                                    elseif btn._br_badgeLabel then
                                        btn._br_badgeLabel:Hide()
                                    end
                                    btn._br_font_size = stackFontSize
                                    btn._br_badge_font_size = badgeFontSize
                                    btn._br_font_outline = outlineFlag
                                    btn._br_needs_sync = false
                                end
                                do
                                    local cdStart, cdDuration
                                    if btn._br_permanent then
                                        cdStart, cdDuration = GetItemCooldown(btn.itemID)
                                    end
                                    if cdStart then
                                        if not btn._br_cooldown then
                                            local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                                            cd:EnableMouse(false)
                                            btn._br_cooldown = cd
                                        end
                                        BR.IconStyle.AnchorCooldown(btn._br_cooldown, btn, btn)
                                        BR.IconStyle.StyleItemCooldown(btn._br_cooldown, btn)
                                        btn._br_cooldown:SetCooldown(cdStart, cdDuration)
                                    elseif btn._br_cooldown then
                                        btn._br_cooldown:Clear()
                                    end
                                end
                                SubIcons.SetAlpha(btn, hostAlpha)
                                -- A new button starts on the "hide" driver.
                                if SubIcons.Activate(btn) and RowRevealMode() == "hover" then
                                    btn._br_fadeIn:Play()
                                end
                                if not btn:IsShown() then
                                    btn:Show()
                                end
                                idx = idx + 1
                            end
                        end
                    end
                    for _, btn in ipairs(frame.actionButtons) do
                        if not btn._br_visible and btn._br_driver_active then
                            SubIcons.Park(btn)
                        end
                    end
                end
            else
                for _, btn in ipairs(frame.actionButtons) do
                    SubIcons.Park(btn)
                end
            end
        end
        -- Extra frame click overlays (expanded consumables, pet actions)
        if frame.extraFrames then
            local clickable = IsCategoryClickable(frame.buffCategory)
            for _, extra in ipairs(frame.extraFrames) do
                local extraOverlay = extra.clickOverlay
                if
                    extraOverlay and SyncOverlay(extraOverlay, extra, clickable and extraOverlay._br_has_action == true)
                then
                    extraOverlay:EnableMouse(true)
                end
            end
        end
    end
end

-- The sync runs on the next frame, after the layout pass calculates the rects.
local syncPending = false
local function ScheduleSecureSync()
    if syncPending then
        return
    end
    syncPending = true
    C_Timer.After(0, function()
        syncPending = false
        SyncSecureButtons()
    end)
end

---@param overlay table SecureActionButton overlay
local function DisableOverlay(overlay)
    overlay._br_has_action = false
    overlay._br_clickMacroFn = nil
    overlay._br_clickMacroSpellID = nil
    overlay._br_pickDef = nil
    overlay._br_clickSpellFn = nil
    overlay._br_chatRequestKey = nil
    overlay._br_chatRequestMsg = nil
    overlay._br_chatRequestCooldownUntil = nil
    overlay.itemID = nil
    overlay:EnableMouse(false)
    overlay:Hide()
    overlay._br_left = nil
end

---Summon a pet, wrapped in Fel Domination when the warlock has the option on.
---@param spellID number Pet summon spell ID
---@param db table The profile database
---@return BRSecureAction
local function PetAction(spellID, db)
    local felMacro = (db.defaults or {}).useFelDomination
        and IsSpellKnown(FEL_DOMINATION_ID)
        and GetFelDomPetMacro(spellID)
    if felMacro then
        return MacroAction("petmacro", felMacro)
    end
    return SpellAction(spellID)
end

---Run a macro whose text depends on state that PreClick reads at click time, such
---as the weapon slot a poison applies to. The identity is the spell, because
---PreClick rebuilds the text on every click.
---@param macroFn function Builds the macro text from a spell ID
---@param spellID number
---@return BRSecureAction
local function ClickMacroAction(macroFn, spellID)
    local action = NewAction("macro", "clickmacro", spellID)
    action.macroFn = macroFn
    action.macroSpellID = spellID
    return action
end

---Ask the group for a buff the player cannot cast.
---@param frame table The buff frame
---@return BRSecureAction? action nil when the buff resolves no request text
local function ChatAction(frame)
    local msg = ChatRequest.ResolveMessage(frame.key, frame.displayName)
    if not msg then
        return nil
    end
    -- The prefix is compared, not folded into the identity: a group change must
    -- rewrite the macro, and the concat belongs on the write path.
    local action = NewAction("macro", "chat", msg)
    action.prefix = ChatRequest.GetPrefix()
    action.chatKey = frame.key
    action.chatMsg = msg
    return action
end

-- A custom macro body stores its line breaks as a literal backslash-n. The
-- resolver runs on every display cycle, but the bodies do not change. The cache
-- holds every body the profile has used this session: weak keys release nothing,
-- because Lua 5.1 never removes strings from a weak table.
local expandedCustomMacros = {}
local function ExpandCustomMacro(raw)
    local text = expandedCustomMacros[raw]
    if not text then
        text = (raw:gsub("\\n", "\n"))
        expandedCustomMacros[raw] = text
    end
    return text
end

-- ============================================================================
-- SUB-ELEMENT HANDLERS
-- ============================================================================

---@param frame table The buff frame
---@param actionItems table[]? Cached consumable items
---@param frameHighlight boolean Per-frame highlight
---@param db table The profile database
local function UpdateConsumableSubElements(frame, actionItems, frameHighlight, db)
    local displayMode = (db.defaults or {}).consumableDisplayMode or "sub_icons"

    -- The sync applies the click settings to the item row.
    if frame._br_rowItems then
        frame._br_rowDirty = true
    end

    if displayMode == "expanded" and frame.extraFrames and actionItems then
        for _, extra in ipairs(frame.extraFrames) do
            -- Display sets _br_item: an expiring buff shows a subset of actionItems.
            if extra:IsShown() and extra._br_item then
                if not extra.clickOverlay then
                    CreateClickOverlay(extra)
                end
                local eOverlay = extra.clickOverlay
                ApplyAction(eOverlay, ConsumableItemAction(extra._br_item, frame))
                eOverlay:EnableMouse(true)
                if eOverlay.highlight then
                    eOverlay.highlight:SetShown(frameHighlight)
                end
            elseif extra.clickOverlay then
                DisableOverlay(extra.clickOverlay)
            end
        end
    elseif frame.extraFrames then
        for _, extra in ipairs(frame.extraFrames) do
            if extra.clickOverlay then
                DisableOverlay(extra.clickOverlay)
            end
        end
    end
end

---Each pet extra frame has its own summon spell. A frame with no extra frames is
---safe to pass: the function does nothing.
---@param frame table The main buff frame
---@param frameHighlight boolean Whether to show the highlight texture
---@param db table The profile database
local function UpdateExtraFrameOverlays(frame, frameHighlight, db)
    if not frame.extraFrames then
        return
    end
    for _, extra in ipairs(frame.extraFrames) do
        if extra:IsShown() and extra._br_pet_spell then
            if not extra.clickOverlay then
                CreateClickOverlay(extra)
            end
            local eOverlay = extra.clickOverlay
            ApplyAction(eOverlay, PetAction(extra._br_pet_spell, db))
            eOverlay:EnableMouse(true)
            if eOverlay.highlight then
                eOverlay.highlight:SetShown(frameHighlight)
            end
            if extra._br_pet_spec_icon then
                HookPetSpecIconHover(eOverlay, extra)
            end
        elseif extra.clickOverlay then
            DisableOverlay(extra.clickOverlay)
        end
    end
end

---@param frame table The buff frame
local function DisableFrameAndChildren(frame)
    if frame.clickOverlay then
        DisableOverlay(frame.clickOverlay)
    end
    -- An item row stays on screen with the mouse off. A choice row closes with its overlay.
    if frame.actionButtons then
        for _, btn in ipairs(frame.actionButtons) do
            btn:EnableMouse(false)
        end
    end
    if frame.extraFrames then
        for _, extra in ipairs(frame.extraFrames) do
            if extra.clickOverlay then
                DisableOverlay(extra.clickOverlay)
            end
        end
    end
end

-- ============================================================================
-- UPDATE ACTION BUTTONS (CLICK-TO-CAST WIRING)
-- ============================================================================

---Resolve the click action for a buff frame. Reads buff data and config only:
---no frame writes, no secure API. The branch order is the action priority.
---@param frame table The buff frame
---@param category string
---@param db table The profile database
---@return BRSecureAction? action nil when the frame has no click action
---@return table[]? actionItems Consumable items behind the action (consumable category only)
local function ResolveAction(frame, category, db)
    local def = frame.buffDef

    -- A click must not spend again the item that started the countdown.
    local entry = BR.BuffState.entries[frame.key]
    if entry and IsCountdownEntry(entry) then
        return nil
    end

    if category == "consumable" then
        local actionItems = GetConsumableActionItems(def)
        if actionItems then
            return ConsumableItemAction(actionItems[1], frame), actionItems
        end
        -- Nothing in the bags. Cast the creation spell if the player knows one.
        if def and (not def.casterClass or def.casterClass == playerClass) then
            local castableID = def.castSpellID or def.spellID
            if def.clickMacro then
                return ClickMacroAction(def.clickMacro, castableID), actionItems
            end
            if def.castSpellID then
                return SpellAction(def.castSpellID), actionItems
            end
        end
        -- The player cannot create the consumable and carries none. Ask the
        -- provider class in chat, as raid and presence buffs do.
        if def and def.chatRequestable and db.requestBuffInChat then
            return ChatAction(frame), actionItems
        end
        return nil, actionItems
    end

    if frame.key == "petPassive" then
        return MacroAction("petassist", "/petassist")
    end

    if frame.key == "repairGear" then
        -- The macro summons the vendor mount where it can be summoned, and uses the
        -- repair item everywhere else. The conditions exclude each other, so one
        -- click never spends both. A player who owns neither gets an inert icon.
        local sources = BR.BuffState.GetRepairSources()
        local mountName = sources.mountSpellID and BR.GetSpellName(sources.mountSpellID)
        local itemID = sources.itemID
        local macro, tipSpellID, tipItemID
        if mountName and itemID then
            -- Where the mount is blocked, the item takes the whole macro: an area
            -- can block mounts and still read as outdoors, and the conditional
            -- would send the click to a cast that fails.
            tipItemID = itemID
            if BR.BuffState.IsRepairMountUsable() then
                macro = "/use [indoors] item:" .. itemID .. "\n/cast [outdoors] " .. mountName
                tipSpellID = sources.mountSpellID
            else
                macro = "/use item:" .. itemID
            end
        elseif mountName then
            macro = "/cast " .. mountName
            tipSpellID = sources.mountSpellID
        elseif itemID then
            macro = "/use item:" .. itemID
            tipItemID = itemID
        else
            return nil
        end
        local action = MacroAction("repair", macro)
        action.tipSpellID = tipSpellID
        action.tipItemID = tipItemID
        return action
    end

    if def and def.clickMacroText then
        local macrotext = def.clickMacroText()
        return macrotext and MacroAction("clickmacrotext", macrotext) or nil
    end

    if def and def.clickItem then
        return ItemAction(def.clickItem)
    end

    local castableID
    if frame._br_pet_spell then
        castableID = frame._br_pet_spell
    elseif category == "custom" then
        local customType, customValue = ResolveCustomClickAction(def)
        if customType == "spell" then
            castableID = customValue
        elseif customType == "macro" then
            return MacroAction("custommacro", ExpandCustomMacro(customValue), customValue)
        elseif customType == "item" then
            return ItemAction(customValue, nil, "customitem")
        end
    else
        castableID = GetActionSpellID(def)
    end

    if castableID and not (def and def.noClickToCast) then
        if def and def.clickMacro then
            return ClickMacroAction(def.clickMacro, castableID)
        end
        if frame._br_pet_spell then
            return PetAction(castableID, db)
        end
        -- The unit stays "player" in the stored action. PreClick writes the
        -- real spell and unit, so the refresh never overwrites a picked target.
        if category == "raid" and def and def.castOnMissing then
            local action = SpellAction(castableID, "player")
            action.pickDef = def
            return action
        end
        if def and def.clickSpell then
            local action = SpellAction(castableID, def.castUnit)
            action.spellFn = def.clickSpell
            return action
        end
        return SpellAction(castableID, (category == "raid" or category == "self") and "player" or nil)
    end

    if db.requestBuffInChat and def and def.chatRequestable and not frame.isPlayerBuff then
        return ChatAction(frame)
    end
    return nil
end

-- ============================================================================
-- DESCRIPTION TOOLTIPS
-- ============================================================================
-- The game tooltip of the spell or item that an icon uses. The tooltip setting of
-- the category gates it, and it never shows in combat. Info tooltips (the last
-- target and the next pick) are separate: the setting never gates them.

---@class DescriptionTooltipOpts
---@field spellID? number Spell to show in place of the resolved subject
---@field itemID? number Item to show in place of the resolved subject
---@field addLines? fun(tooltip: table) Adds lines at the end, before the tooltip shows
---@field fallback? fun() Draws a short tooltip while the tooltip key is up

---The spell or item that a click on the frame uses, read at hover time. Where no
---click resolves, the spell that the icon shows. Out of combat only: the click
---resolvers read unit state, which combat can make secret.
---@param frame table The hovered buff frame or extra frame
---@return "spell"|"item"|nil kind
---@return number? id
local function ResolveDescriptionSubject(frame)
    if frame._br_item then
        return "item", frame._br_item.itemID
    end
    if frame._br_pet_spellID then
        return "spell", frame._br_pet_spellID
    end
    local def = frame.buffDef
    if not def then
        return nil
    end
    -- ResolveAction fills the shared scratch action. A hover never runs inside a resolve.
    local action = ResolveAction(frame, frame.buffCategory, BR.profile)
    -- A chat request asks for the buff, so the buff spell describes it.
    if action and not action.chatKey then
        -- The repair macro uses the item indoors and the mount outdoors.
        if action.tipSpellID and not (action.tipItemID and IsIndoors()) then
            return "spell", action.tipSpellID
        end
        local itemID = action.tipItemID or action.itemID
        if itemID then
            return "item", itemID
        end
        local spellID = action.macroSpellID or action.spellID
        if action.pickDef then
            spellID = PickDefCast(action.pickDef, frame, spellID)
        elseif action.spellFn then
            spellID = action.spellFn()
        end
        if spellID then
            return "spell", spellID
        end
    end
    local spellID = GetActionSpellID(def) or (type(def.spellID) == "table" and def.spellID[1] or def.spellID)
    if spellID then
        return "spell", spellID
    end
    return nil
end

---@param owner table
---@param def table? The buff definition, for the provider line
---@param kind "spell"|"item"|nil nil shows only the name
---@param id number?
---@param name string?
---@param addLines (fun(tooltip: table))?
local function DrawDescriptionTooltip(owner, def, kind, id, name, addLines)
    -- The tooltip key can redraw after combat starts.
    if InCombatLockdown() then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if kind == "item" then
        GameTooltip:SetItemByID(id)
    elseif kind == "spell" then
        GameTooltip:SetSpellByID(id)
        -- The provider line helps only when another class gives the buff.
        if def and def.class and def.class ~= playerClass then
            local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[def.class]) or def.class
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[def.class]
            GameTooltip:AddLine(
                L["BuffTooltip.ProvidedBy"]:format(className),
                c and c.r or 1,
                c and c.g or 1,
                c and c.b or 1
            )
        end
    else
        GameTooltip:SetText(name)
    end
    if addLines then
        addLines(GameTooltip)
    end
    GameTooltip:Show()
end

---Show the description tooltip of a frame. The single gate for description tooltips:
---callers do not check the setting. The subject resolves once, when the hover starts.
---@param owner table The hovered frame, which anchors the tooltip
---@param frame table The buff frame or extra frame that the tooltip describes
---@param opts DescriptionTooltipOpts?
---@return boolean shown false when the setting or combat blocks the tooltip, or when nothing describes the frame
local function ShowDescriptionTooltip(owner, frame, opts)
    if InCombatLockdown() or not BR.Display.IsDescriptionTooltipOn(frame.buffCategory) then
        return false
    end
    ---@type "spell"|"item"|nil, number?
    local kind, id
    if opts and opts.itemID then
        kind, id = "item", opts.itemID
    elseif opts and opts.spellID then
        kind, id = "spell", opts.spellID
    else
        kind, id = ResolveDescriptionSubject(frame)
    end
    local host = frame.isExtraFrame and frame.mainFrame or frame
    local def = host.buffDef
    local name = host.displayName or (def and def.name)
    if not kind and not name then
        return false
    end
    local addLines = opts and opts.addLines
    BR.Display.ShowHoverTooltip(owner, function()
        DrawDescriptionTooltip(owner, def, kind, id, name, addLines)
    end, opts and opts.fallback)
    return true
end

---@param category string
local function UpdateActionButtons(category)
    if InCombatLockdown() or BR.Display.IsTestMode() then
        return
    end

    -- A category with no frames skips the whole pass, the sync included.
    local frames = BR.Display.framesByCategory and BR.Display.framesByCategory[category]
    if not frames or not next(frames) then
        return
    end

    local db = BR.profile
    local enabled = IsCategoryClickable(category)
    local showHighlight = enabled and GetCategorySetting(category, "clickableHighlight") ~= false

    -- A category with click-to-cast off still resolves its frames when it can host
    -- a chat request: only the resolver knows whether a given frame lands on one.
    local mayOverride = enabled or category == "custom" or ChatRequest.WantsCategory(category)

    for _, frame in pairs(frames) do
        if frame.buffCategory == category then
            local entry = BR.BuffState.entries[frame.key]
            -- Set also where nothing resolves, so the display never asks again for the same state.
            frame._br_resolvedCountdown = entry ~= nil and IsCountdownEntry(entry)
            local action, actionItems
            if mayOverride then
                action, actionItems = ResolveAction(frame, category, db)
            end
            -- The right-click menu needs an overlay also where the left click does
            -- nothing. A loadout frame takes its own clicks, so no overlay covers it.
            if not action and enabled and category ~= "loadout" and db.defaults.rightClickMenu ~= false then
                action = NewAction("none", "none", true)
            end

            local frameEnabled = enabled
            local frameHighlight = showHighlight
            -- Click to cast governs casting. A chat request answers its own toggle
            -- on the Chat Requests page, and a custom buff its own click action, so
            -- both stay clickable where the category turned click-to-cast off.
            if not frameEnabled and action and (action.chatKey or category == "custom") then
                frameEnabled = true
                frameHighlight = true
            end

            if not frameEnabled then
                DisableFrameAndChildren(frame)
            else
                if action then
                    if not frame.clickOverlay then
                        CreateClickOverlay(frame)
                    end
                    local overlay = frame.clickOverlay
                    ApplyAction(overlay, action)
                    overlay:EnableMouse(true)
                    if overlay.highlight then
                        overlay.highlight:SetShown(frameHighlight and action.kind ~= "none")
                    end
                    if frame._br_pet_spec_icon then
                        HookPetSpecIconHover(overlay, frame)
                    end
                elseif frame.clickOverlay then
                    DisableOverlay(frame.clickOverlay)
                end

                if category == "consumable" then
                    UpdateConsumableSubElements(frame, actionItems, frameHighlight, db)
                else
                    UpdateExtraFrameOverlays(frame, frameHighlight, db)
                end
            end
        end
    end
    ScheduleSecureSync()
end

-- ChatAction puts the channel prefix inside the macrotext, and PreClick cannot
-- rewrite it in time. Only a new resolve makes the prefix current after the
-- player changes group or profile.
local function RefreshChatRequestMacros()
    for _, cat in ipairs(ChatRequest.Categories()) do
        UpdateActionButtons(cat)
    end
end

---Rewire every category, also the ones whose click to cast just turned off.
local function UpdateAllActionButtons()
    for _, cat in ipairs(BR.CATEGORY_ORDER) do
        UpdateActionButtons(cat)
    end
end

local function RefreshOverlaySpells()
    if InCombatLockdown() or BR.Display.IsTestMode() then
        return
    end

    -- An event can fire before the first PLAYER_ENTERING_WORLD builds the frames.
    local framesByCategory = BR.Display.framesByCategory
    if not framesByCategory then
        return
    end
    for cat in pairs(framesByCategory) do
        if IsCategoryClickable(cat) or cat == "custom" or ChatRequest.WantsCategory(cat) then
            UpdateActionButtons(cat)
        end
    end
end

BR.SecureButtons = {
    UpdateActionButtons = UpdateActionButtons,
    UpdateAllActionButtons = UpdateAllActionButtons,
    ShowDescriptionTooltip = ShowDescriptionTooltip,
    UnregisterSecureHost = UnregisterSecureHost,
    RefreshOverlaySpells = RefreshOverlaySpells,
    RefreshChatRequestMacros = RefreshChatRequestMacros,
    GetConsumableActionItems = GetConsumableActionItems,
    SetItemRow = SetItemRow,
    InvalidateConsumableCache = InvalidateConsumableCache,
    HideAllSecureFrames = HideAllSecureFrames,
    HideSecureFramesForCatKey = HideSecureFramesForCatKey,
    ScheduleSecureSync = ScheduleSecureSync,
    ComputeConsumableFontSize = ComputeConsumableFontSize,
    FormatStackCount = FormatStackCount,
    GetItemCooldown = GetItemCooldown,
    BADGE_COLORS = BADGE_COLORS,
    ReapplyPetSpecIconIfHovered = ReapplyPetSpecIconIfHovered,
}

BR.GameContext.RegisterCache("consumables", InvalidateConsumableCache)
