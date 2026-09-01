local _, BR = ...
local L = BR.L

-- ============================================================================
-- SECURE BUTTONS & CLICK-TO-CAST OVERLAYS
-- Consumable action buttons, click-to-cast overlays, and the position sync for
-- both. Kept out of the display layer to isolate the code that combat lockdown
-- restricts.
-- ============================================================================

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local floor, max, min = math.floor, math.max, math.min
local tsort = table.sort
local wipe = wipe

local _, playerClass = UnitClass("player")
local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit

local ChatRequest = BR.ChatRequest

local GetTime = GetTime
local Plain = BR.Secret.Plain

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
        return IsPlayerSpell(spellIDs) and spellIDs or nil
    end
    for _, id in ipairs(spellIDs) do
        if IsPlayerSpell(id) then
            return id
        end
    end
    return nil
end

local FEL_DOMINATION_ID = 333889

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
    if buff.excludeSpellID and IsPlayerSpell(buff.excludeSpellID) then
        return nil
    end
    if buff.requiresSpellID and not IsPlayerSpell(buff.requiresSpellID) then
        return nil
    end
    if buff.requireSpecId then
        local spec = GetSpecialization()
        if spec then
            local specId = GetSpecializationInfo(spec)
            if specId ~= buff.requireSpecId then
                return nil
            end
        end
    end
    -- Prefer the role spell so the cast matches the icon the player sees.
    if not buff.castSpellID and buff.icons and buff.icons.byRole then
        local role = BR.BuffState.GetPlayerRole()
        local roleSpell = role and buff.icons.byRole[role]
        if roleSpell and IsPlayerSpell(roleSpell) then
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
        if IsPlayerSpell(buff.castSpellID) then
            return "spell", buff.castSpellID
        end
        return nil, nil
    end
    local spellID = buff.spellID
    if type(spellID) == "table" then
        spellID = spellID[1]
    end
    if spellID and IsPlayerSpell(spellID) then
        return "spell", spellID
    end
    return nil, nil
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
-- LAST TARGET TOOLTIP
-- ============================================================================
-- Shows the last known target name for targeted buffs.

local lastTargetTooltip

---@param anchor table Frame to anchor to
---@param name string Character name
---@param class? string English class token
---@param hint? string Gray text shown after the name, such as "(not in group)"
local function ShowLastTargetTooltip(anchor, name, class, hint)
    if not lastTargetTooltip then
        local tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tip:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        tip:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        tip.name = tip:CreateFontString(nil, "OVERLAY")
        tip.name:SetPoint("CENTER", 0, 0)
        lastTargetTooltip = tip
    end
    local tip = lastTargetTooltip
    BR.DisplayFonts.Apply(tip.name, 13)
    local r, g, b = 1, 1, 1
    if class then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            r, g, b = c.r, c.g, c.b
        end
    end
    -- A color escape in the hint overrides SetTextColor for that part only.
    tip.name:SetText(hint and (name .. " |cff888888" .. hint .. "|r") or name)
    tip.name:SetTextColor(r, g, b)
    local textWidth, textHeight = BR.DisplayFonts.GetStringSize(tip.name)
    tip:SetSize(textWidth + 24, textHeight + 16)
    tip:ClearAllPoints()
    tip:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    tip:Show()
end

local function HideLastTargetTooltip()
    if lastTargetTooltip then
        lastTargetTooltip:Hide()
    end
end

-- ============================================================================
-- CLICK-TO-CAST OVERLAY
-- ============================================================================

-- The secure resolver reads `type<button>` for the mouse button that was clicked.
-- It does not reliably fall back to the bare `type`, so a click resolves to no
-- action unless every variant carries the type. This overwrites type2, so it
-- clears the snooze tracker and the next SetRightClickSnooze re-applies.
---@param button table Secure button (click overlay or consumable action button)
---@param actionType string "macro" | "item" | "spell"
local function SetActionType(button, actionType)
    button._br_action_type = actionType
    button:SetAttribute("type", actionType)
    for i = 1, 5 do
        button:SetAttribute("type" .. i, actionType)
    end
    button._br_snoozeRightClick = nil
end

-- Neutralise the right button with an empty type2, which resolves to no handler.
-- PostClick reads the flag and snoozes instead. `on == false` gives the button's
-- own action back to the right click. Call it after SetActionType, which
-- overwrites type2. Self-gated, so callers can re-apply on every display cycle.
-- Must run out of combat.
local function SetRightClickSnooze(button, on)
    if not button then
        return
    end
    on = on == true and BR.profile.defaults.rightClickSnooze ~= false
    if button._br_snoozeRightClick == on then
        return
    end
    button._br_snoozeRightClick = on
    button:SetAttribute("type2", on and "" or button._br_action_type)
end

-- ============================================================================
-- SECURE ACTIONS
-- ============================================================================
-- ResolveAction turns a buff frame into a plain action table. ApplyAction is the
-- only place that writes secure attributes. A new attribute concern belongs in
-- ApplyAction, never at a call site.

---@class BRSecureAction
---@field kind "macro"|"item"|"spell" Secure action type
---@field tag string Namespace for the dirty gate. Two actions of one kind from
---different sources must not compare equal.
---@field id any Identity within the tag
---@field macrotext string? Macro text, when it does not depend on live state
---@field itemID number? Item behind the action, also for tooltips and click memory
---@field slot number? Weapon slot the macro applies the item to
---@field spellID number? kind == "spell"
---@field unit string? Cast target (nil = default targeting)
---@field snooze boolean? Right-click snoozes reminders instead of running the action
---@field macroFn function? Builds the macro text, also re-run by PreClick
---@field macroSpellID number? Argument for macroFn
---@field prefix string? Chat channel command in front of chatMsg
---@field chatKey string? Buff key when the action is a chat request
---@field chatMsg string? Request text without the channel prefix

-- Every resolver fills this one table, and ApplyAction copies what it needs before
-- the next fill. A resolve runs for every frame on every display cycle, so it must
-- not allocate.
local scratchAction = {}

---@param kind "macro"|"item"|"spell"
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

---Wire an action onto a secure button. UpdateActionButtons resolves every frame on
---every display cycle, but the action rarely changes, so SameAction gates the
---attribute writes. The snooze write stays outside that gate, because the option
---can change while the action does not.
---@param button table Secure button (click overlay or consumable action button)
---@param action BRSecureAction
local function ApplyAction(button, action)
    button._br_has_action = true
    button.itemID = action.itemID
    button._br_clickMacroFn = action.macroFn
    button._br_clickMacroSpellID = action.macroSpellID
    button._br_chatRequestKey = action.chatKey
    button._br_chatRequestMsg = action.chatMsg
    if not action.chatKey then
        button._br_chatRequestCooldownUntil = nil
    end
    if not SameAction(button._br_action, action) then
        SetActionType(button, action.kind)
        if action.kind == "macro" then
            button:SetAttribute("macrotext", MacroText(action))
        elseif action.kind == "item" then
            button:SetAttribute("item", "item:" .. action.itemID)
        else
            button:SetAttribute("spell", action.spellID)
            -- Always write unit, because nil clears it. A stale "player" from a
            -- previous action retargets the cast onto the player.
            button:SetAttribute("unit", action.unit)
        end
        StoreAction(button, action)
    end
    SetRightClickSnooze(button, action.snooze)
end

---@param itemID number
---@param slot number? 16 or 17 for a weapon buff, nil otherwise
---@param snooze boolean Right-click snoozes instead of using the item
---@param tag string? Overrides the dirty-gate namespace
---@return BRSecureAction
local function ItemAction(itemID, slot, snooze, tag)
    local action = NewAction(slot and "macro" or "item", tag or (slot and "weaponitem" or "item"), itemID)
    action.itemID = itemID
    action.slot = slot
    action.snooze = snooze
    return action
end

---@param spellID number
---@param unit string? Cast target (nil = default targeting)
---@param snooze boolean? Right-click snoozes instead of casting
---@return BRSecureAction
local function SpellAction(spellID, unit, snooze)
    local action = NewAction("spell", "spell", spellID)
    action.spellID = spellID
    action.unit = unit
    action.snooze = snooze
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
    overlay:SetScript("PreClick", function(self)
        if self._br_clickMacroFn and not self._br_chatRequestKey then
            self:SetAttribute("macrotext", self._br_clickMacroFn(self._br_clickMacroSpellID))
        end
    end)
    overlay:SetScript("PostClick", function(self, button, down)
        -- Fire the snooze once, on the up event, and skip the refresh below.
        if button == "RightButton" and not down and self._br_snoozeRightClick then
            BR.SnoozeConsumables()
            return
        end
        if self._br_chatRequestKey then
            -- Anti-spam gate. Some players report that it stops the chat dispatch
            -- in restricted contexts. The cause is not known, so the Chat Requests
            -- page can turn it off.
            if BR.profile.chatRequestCooldown ~= false then
                self._br_chatRequestCooldownUntil = GetTime() + 5
                self:EnableMouse(false)
                if not self._br_chatRequestCooldown then
                    local cd = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
                    cd:SetAllPoints(self)
                    cd:SetDrawBling(false)
                    cd:SetHideCountdownNumbers(true)
                    cd.noCooldownCount = true
                    self._br_chatRequestCooldown = cd
                end
                self._br_chatRequestCooldown:SetCooldown(GetTime(), 5)
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
    overlay:HookScript("OnEnter", function()
        if frame.buffDef and (frame.buffCategory == "targeted" or frame.buffDef.castOnOthers) then
            -- Only the caster class has a meaningful last target.
            if frame.buffDef.class and frame.buffDef.class ~= playerClass then
                return
            end
            local name, class = BR.TargetMemory.Get(frame.buffDef.key)
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
            if name then
                ShowLastTargetTooltip(overlay, name, class, hint)
            end
            return
        end
        if frame.buffCategory == "consumable" then
            local db = BR.profile
            if not db or not db.defaults or db.defaults.showConsumableTooltips ~= true then
                return
            end
            local itemID = overlay.itemID
            if itemID then
                GameTooltip:SetOwner(overlay, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(itemID)
                GameTooltip:Show()
            end
            return
        end
        -- The anchor is the overlay: the cursor is over the overlay, not over the
        -- buff frame below it.
        if frame.buffCategory == "raid" or frame.buffCategory == "presence" then
            if BR.Display.ShowBuffSpellTooltip then
                BR.Display.ShowBuffSpellTooltip(frame, overlay)
            end
        end
    end)
    overlay:HookScript("OnLeave", function()
        HideLastTargetTooltip()
        if frame.buffCategory == "consumable" or frame.buffCategory == "raid" or frame.buffCategory == "presence" then
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

local ACTION_ICON_SCALE = 0.45
local ACTION_ICON_MIN = 18
local ACTION_ICON_OFFSET = -6

local BADGE_COLORS = {
    [L["Badge.Hearty"]] = { r = 0.4, g = 0.7, b = 1 },
    [L["Badge.Fleeting"]] = { r = 0.4, g = 0.7, b = 1 },
}

---@param mainIconSize number The consumable category's main icon size
---@param item string? A BR.TextPositions.SizedItems key; nil uses the shared base
---@return number fontSize
local function ComputeConsumableFontSize(mainIconSize, item)
    return max(6, floor(mainIconSize * BR.TextPositions.GetSizePercent(item) / 100))
end

---Parented to UIParent with NO anchor to a buff frame: an anchor taints it.
---SyncSecureButtons positions it.
---@return table btn The created button
local function CreateActionButton()
    local btn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:Hide()
    -- Starts hidden. SyncSecureButtons swaps in the combat driver after it positions
    -- the button.
    RegisterStateDriver(btn, "visibility", "hide")
    btn:SetScript("OnShow", function(self)
        local bf = self._br_buff_frame
        if not bf or not bf:IsVisible() then
            self:Hide()
        end
    end)
    -- The refresh runs shortly after the click so the consumed buff disappears fast.
    btn:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down and self._br_snoozeRightClick then
            BR.SnoozeConsumables()
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

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", -1, 1)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetTexCoord(BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET, BR.TEXCOORD_INSET, 1 - BR.TEXCOORD_INSET)
    btn.highlight:SetColorTexture(1, 1, 1, 0.2)

    btn:SetScript("OnEnter", function(self)
        if not BR.profile or not BR.profile.defaults then
            return
        end
        if BR.profile.defaults.showConsumableTooltips ~= true then
            return
        end
        if not self.itemID then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
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
                            local okSpell, _, useSpellID = pcall(GetItemSpell, itemID)
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
            tsort(items, function(a, b)
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
    return items and #items > 0 and items or nil
end

---Create or update the item icons for a consumable buff frame. SyncSecureButtons
---positions them.
---@param frame table The buff frame
---@param actionItems table[]? Array of { itemID, count, icon }
---@param clickable boolean? True when the buttons accept mouse input
---@param startIndex? number First index in actionItems to show (default 1)
local function UpdateConsumableButtons(frame, actionItems, clickable, startIndex)
    if InCombatLockdown() then
        return
    end
    startIndex = startIndex or 1
    if not actionItems or #actionItems < startIndex then
        if frame.actionButtons then
            for _, btn in ipairs(frame.actionButtons) do
                btn._br_visible = false
                btn:Hide()
            end
        end
        return
    end

    if not frame.actionButtons then
        frame.actionButtons = {}
        RegisterSecureHost(frame)
    end

    local btnIndex = 0
    for i = startIndex, #actionItems do
        btnIndex = btnIndex + 1
        local item = actionItems[i]
        local btn = frame.actionButtons[btnIndex]
        if not btn then
            btn = CreateActionButton()
            btn._br_buff_frame = frame
            frame.actionButtons[btnIndex] = btn
        end

        btn.icon:SetTexture(item.icon or 134400)
        ApplyAction(btn, ItemAction(item.itemID, GetWeaponSlot(frame), true))

        btn:EnableMouse(clickable == true)
        btn._br_visible = true
        btn._br_count = item.count
        btn._br_permanent = item.permanent
        btn._br_qualityAtlas = item.qualityAtlas
        btn._br_badge = item.badge
        btn._br_needs_sync = true
    end

    for i = btnIndex + 1, #frame.actionButtons do
        frame.actionButtons[i]._br_visible = false
        frame.actionButtons[i]:Hide()
    end
end

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
            if frame.actionButtons then
                for _, btn in ipairs(frame.actionButtons) do
                    if btn._br_driver_active then
                        RegisterStateDriver(btn, "visibility", "hide")
                        btn._br_driver_active = false
                        btn._br_x = nil
                    else
                        btn:Hide()
                    end
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
        if frame.actionButtons then
            for _, btn in ipairs(frame.actionButtons) do
                if btn._br_driver_active then
                    RegisterStateDriver(btn, "visibility", "hide")
                    btn._br_driver_active = false
                    btn._br_x = nil
                else
                    btn:Hide()
                end
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
            local cs = frame.buffCategory
                and BR.profile.categorySettings
                and BR.profile.categorySettings[frame.buffCategory]
            local clickable = cs and cs.clickable == true
            -- Click to cast governs casting. A chat request answers its own toggle
            -- on the Chat Requests page, and a custom buff its own click action, so
            -- both stay clickable where the category turned click-to-cast off.
            if not clickable then
                clickable = overlay._br_chatRequestKey ~= nil
                    or (frame.buffCategory == "custom" and HasCustomClickAction(frame.buffDef))
            end
            if frame:IsVisible() then
                if not clickable or not overlay._br_has_action then
                    overlay:EnableMouse(false)
                    overlay:Hide()
                    overlay._br_left = nil
                else
                    local left, bottom, width, height = frame:GetRect()
                    if left then
                        if
                            overlay._br_left ~= left
                            or overlay._br_bottom ~= bottom
                            or overlay._br_width ~= width
                            or overlay._br_height ~= height
                        then
                            overlay:ClearAllPoints()
                            overlay:SetSize(width, height)
                            overlay:SetFrameStrata(frame:GetFrameStrata())
                            overlay:SetFrameLevel(frame:GetFrameLevel() + 5)
                            overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
                            overlay._br_left = left
                            overlay._br_bottom = bottom
                            overlay._br_width = width
                            overlay._br_height = height
                        end
                        -- The cooldown timer clears the timestamp when it expires.
                        -- The next sync run then re-enables the mouse.
                        local cdEnabled = BR.profile.chatRequestCooldown ~= false
                        local cdUntil = cdEnabled and overlay._br_chatRequestCooldownUntil
                        if cdUntil and cdUntil > GetTime() then
                            overlay:EnableMouse(false)
                        else
                            overlay:EnableMouse(true)
                        end
                        if not overlay:IsShown() then
                            overlay:Show()
                        end
                    end
                end
            else
                overlay:Hide()
                overlay:EnableMouse(false)
                overlay._br_left = nil
            end
        end
        -- Sync action buttons (consumable item row)
        if frame.actionButtons then
            if frame:IsVisible() then
                local left, bottom, width, height = frame:GetRect()
                if left then
                    local effectiveCat = GetEffectiveCategory(frame)
                    local catSettings = GetCategorySettings(effectiveCat)
                    local size = max(ACTION_ICON_MIN, floor((catSettings.iconSize or 64) * ACTION_ICON_SCALE))
                    local btnSpacing = max(2, floor(size * 0.2))
                    local subIconSide = GetCategorySettings("consumable").subIconSide or "BOTTOM"
                    local visibleCount = 0
                    for _, btn in ipairs(frame.actionButtons) do
                        if btn._br_visible then
                            visibleCount = visibleCount + 1
                        end
                    end
                    if visibleCount > 0 then
                        local baseIconSize = catSettings.iconSize or 64
                        local stackFontSize = ComputeConsumableFontSize(baseIconSize, "stackCount")
                        local badgeFontSize = ComputeConsumableFontSize(baseIconSize, "badge")
                        local showSubIconBadge = BR.Config.Get("defaults.consumableBadgeOnSubIcons") == true
                        local idx = 0
                        for _, btn in ipairs(frame.actionButtons) do
                            if btn._br_visible then
                                local btnX, btnY
                                local isSideways = subIconSide == "LEFT" or subIconSide == "RIGHT"
                                if isSideways then
                                    local maxPerCol = max(1, floor((height + btnSpacing) / (size + btnSpacing)))
                                    local row = idx % maxPerCol
                                    local col = floor(idx / maxPerCol)
                                    local thisColCount = min(maxPerCol, visibleCount - col * maxPerCol)
                                    local thisColHeight = thisColCount * size + (thisColCount - 1) * btnSpacing
                                    local thisColStartY = bottom + (height - thisColHeight) / 2
                                    if subIconSide == "LEFT" then
                                        btnX = left + ACTION_ICON_OFFSET - size - col * (size + btnSpacing)
                                    else
                                        btnX = left + width - ACTION_ICON_OFFSET + col * (size + btnSpacing)
                                    end
                                    btnY = thisColStartY + row * (size + btnSpacing)
                                else
                                    local maxPerRow = max(1, floor((width + btnSpacing) / (size + btnSpacing)))
                                    local col = idx % maxPerRow
                                    local row = floor(idx / maxPerRow)
                                    local thisRowCount = min(maxPerRow, visibleCount - row * maxPerRow)
                                    local thisRowWidth = thisRowCount * size + (thisRowCount - 1) * btnSpacing
                                    local thisRowStartX = left + (width - thisRowWidth) / 2
                                    btnX = thisRowStartX + col * (size + btnSpacing)
                                    if subIconSide == "TOP" then
                                        btnY = bottom + height - ACTION_ICON_OFFSET + row * (size + btnSpacing)
                                    else
                                        btnY = bottom + ACTION_ICON_OFFSET - size - row * (size + btnSpacing)
                                    end
                                end
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
                                if needsUpdate then
                                    btn:ClearAllPoints()
                                    btn:SetSize(size, size)
                                    btn:SetFrameStrata(frame:GetFrameStrata())
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
                                        btn._br_badgeLabel:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
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
                                            cd:SetAllPoints()
                                            cd:SetDrawEdge(true)
                                            cd:EnableMouse(false)
                                            btn._br_cooldown = cd
                                        end
                                        btn._br_cooldown:SetCooldown(cdStart, cdDuration)
                                    elseif btn._br_cooldown then
                                        btn._br_cooldown:Clear()
                                    end
                                end
                                -- A new button starts on the "hide" driver.
                                if not btn._br_driver_active then
                                    RegisterStateDriver(btn, "visibility", "[combat] hide; show")
                                    btn._br_driver_active = true
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
                            RegisterStateDriver(btn, "visibility", "hide")
                            btn._br_driver_active = false
                            btn._br_x = nil
                        end
                    end
                end
            else
                for _, btn in ipairs(frame.actionButtons) do
                    if btn._br_driver_active then
                        RegisterStateDriver(btn, "visibility", "hide")
                        btn._br_driver_active = false
                        btn._br_x = nil
                    else
                        btn:Hide()
                    end
                end
            end
        end
        -- Sync extra frame click overlays (expanded consumable display mode)
        if frame.extraFrames then
            for _, extra in ipairs(frame.extraFrames) do
                local extraOverlay = extra.clickOverlay
                if extraOverlay then
                    if extra:IsVisible() then
                        local extraCs = frame.buffCategory
                            and BR.profile.categorySettings
                            and BR.profile.categorySettings[frame.buffCategory]
                        local extraClickable = extraCs and extraCs.clickable == true
                        if not extraClickable then
                            extraOverlay:EnableMouse(false)
                            extraOverlay:Hide()
                            extraOverlay._br_left = nil
                        else
                            local eLeft, eBottom, eWidth, eHeight = extra:GetRect()
                            if eLeft then
                                if
                                    extraOverlay._br_left ~= eLeft
                                    or extraOverlay._br_bottom ~= eBottom
                                    or extraOverlay._br_width ~= eWidth
                                    or extraOverlay._br_height ~= eHeight
                                then
                                    extraOverlay:ClearAllPoints()
                                    extraOverlay:SetSize(eWidth, eHeight)
                                    extraOverlay:SetFrameStrata(extra:GetFrameStrata())
                                    extraOverlay:SetFrameLevel(extra:GetFrameLevel() + 5)
                                    extraOverlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", eLeft, eBottom)
                                    extraOverlay._br_left = eLeft
                                    extraOverlay._br_bottom = eBottom
                                    extraOverlay._br_width = eWidth
                                    extraOverlay._br_height = eHeight
                                end
                                extraOverlay:EnableMouse(true)
                                if not extraOverlay:IsShown() then
                                    extraOverlay:Show()
                                end
                            end
                        end
                    else
                        extraOverlay:Hide()
                        extraOverlay:EnableMouse(false)
                        extraOverlay._br_left = nil
                    end
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
        and IsPlayerSpell(FEL_DOMINATION_ID)
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
---@param snooze boolean Right-click snoozes instead of running the macro
---@return BRSecureAction
local function ClickMacroAction(macroFn, spellID, snooze)
    local action = NewAction("macro", "clickmacro", spellID)
    action.macroFn = macroFn
    action.macroSpellID = spellID
    action.snooze = snooze
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
---@param showHighlight boolean Category-level highlight setting
---@param frameHighlight boolean Per-frame highlight (same as showHighlight for consumables)
---@param db table The profile database
local function UpdateConsumableSubElements(frame, actionItems, showHighlight, frameHighlight, db)
    local displayMode = (db.defaults or {}).consumableDisplayMode or "sub_icons"

    if displayMode == "sub_icons" and frame.actionButtons then
        for _, btn in ipairs(frame.actionButtons) do
            btn:EnableMouse(true)
            if btn.highlight then
                btn.highlight:SetShown(showHighlight)
            end
        end
    end

    if displayMode == "expanded" and frame.extraFrames and actionItems then
        local weaponSlot = GetWeaponSlot(frame)
        for idx, extra in ipairs(frame.extraFrames) do
            local itemIdx = idx + 1 -- The main frame owns items[1].
            if extra:IsShown() and actionItems[itemIdx] then
                if not extra.clickOverlay then
                    CreateClickOverlay(extra)
                end
                local eOverlay = extra.clickOverlay
                ApplyAction(eOverlay, ItemAction(actionItems[itemIdx].itemID, weaponSlot, true))
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
---@param db table The profile database
local function DisableFrameAndChildren(frame, db)
    if frame.clickOverlay then
        DisableOverlay(frame.clickOverlay)
    end
    -- Sub-icons stay on screen in sub_icons mode. Only the mouse goes off.
    if frame.actionButtons then
        local displayMode = (db.defaults or {}).consumableDisplayMode or "sub_icons"
        for _, btn in ipairs(frame.actionButtons) do
            btn:EnableMouse(false)
            if displayMode ~= "sub_icons" then
                if btn._br_driver_active then
                    RegisterStateDriver(btn, "visibility", "hide")
                    btn._br_driver_active = false
                    btn._br_x = nil
                else
                    btn:Hide()
                end
            end
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

    if category == "consumable" then
        local actionItems = GetConsumableActionItems(def)
        if actionItems then
            return ItemAction(actionItems[1].itemID, GetWeaponSlot(frame), true), actionItems
        end
        -- Nothing in the bags. Cast the creation spell if the player knows one.
        if def and (not def.casterClass or def.casterClass == playerClass) then
            local castableID = def.castSpellID or def.spellID
            if def.clickMacro then
                return ClickMacroAction(def.clickMacro, castableID, true), actionItems
            end
            if def.castSpellID then
                return SpellAction(def.castSpellID, nil, true), actionItems
            end
        end
        -- The player cannot create the consumable and carries none. Ask the
        -- provider class in chat, as raid and presence buffs do. The right click
        -- sends the request here instead of a snooze.
        if def and def.chatRequestable and db.requestBuffInChat then
            return ChatAction(frame), actionItems
        end
        return nil, actionItems
    end

    if frame.key == "petPassive" then
        return MacroAction("petassist", "/petassist")
    end

    if frame.key == "repairGear" then
        -- Outdoors, the macro summons the vendor mount. Indoors, it uses the repair
        -- item. The two conditions exclude each other, so one click never spends
        -- both. A player who owns neither gets an inert icon.
        local sources = BR.BuffState.GetRepairSources()
        local mountName = sources.mountSpellID and BR.GetSpellName(sources.mountSpellID)
        local itemID = sources.itemID
        local macro
        if mountName and itemID then
            macro = "/use [indoors] item:" .. itemID .. "\n/cast [outdoors] " .. mountName
        elseif mountName then
            macro = "/cast " .. mountName
        elseif itemID then
            macro = "/use item:" .. itemID
        else
            return nil
        end
        return MacroAction("repair", macro)
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
            return ItemAction(customValue, nil, false, "customitem")
        end
    else
        castableID = GetActionSpellID(def)
    end

    if castableID and not (def and def.noClickToCast) then
        if def and def.clickMacro then
            return ClickMacroAction(def.clickMacro, castableID, false)
        end
        if frame._br_pet_spell then
            return PetAction(castableID, db)
        end
        return SpellAction(castableID, category == "raid" and "player" or nil)
    end

    if db.requestBuffInChat and def and def.chatRequestable and not frame.isPlayerBuff then
        return ChatAction(frame)
    end
    return nil
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
    local cs = db.categorySettings and db.categorySettings[category]
    local enabled = cs and cs.clickable == true
    local showHighlight = enabled and (cs.clickableHighlight ~= false)

    -- A category with click-to-cast off still resolves its frames when it can host
    -- a chat request: only the resolver knows whether a given frame lands on one.
    local mayOverride = enabled or category == "custom" or ChatRequest.WantsCategory(category)

    for _, frame in pairs(frames) do
        if frame.buffCategory == category then
            local action, actionItems
            if mayOverride then
                action, actionItems = ResolveAction(frame, category, db)
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
                DisableFrameAndChildren(frame, db)
            else
                if action then
                    if not frame.clickOverlay then
                        CreateClickOverlay(frame)
                    end
                    local overlay = frame.clickOverlay
                    ApplyAction(overlay, action)
                    overlay:EnableMouse(true)
                    if overlay.highlight then
                        overlay.highlight:SetShown(frameHighlight)
                    end
                    if frame._br_pet_spec_icon then
                        HookPetSpecIconHover(overlay, frame)
                    end
                elseif frame.clickOverlay then
                    DisableOverlay(frame.clickOverlay)
                end

                if category == "consumable" then
                    UpdateConsumableSubElements(frame, actionItems, showHighlight, frameHighlight, db)
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

local function RefreshOverlaySpells()
    if InCombatLockdown() or BR.Display.IsTestMode() then
        return
    end

    -- An event can fire before the first PLAYER_ENTERING_WORLD builds the frames.
    local framesByCategory = BR.Display.framesByCategory
    if not framesByCategory then
        return
    end
    local db = BR.profile
    for cat in pairs(framesByCategory) do
        local cs = db.categorySettings and db.categorySettings[cat]
        if (cs and cs.clickable == true) or cat == "custom" or ChatRequest.WantsCategory(cat) then
            UpdateActionButtons(cat)
        end
    end
end

BR.SecureButtons = {
    UpdateActionButtons = UpdateActionButtons,
    UnregisterSecureHost = UnregisterSecureHost,
    RefreshOverlaySpells = RefreshOverlaySpells,
    RefreshChatRequestMacros = RefreshChatRequestMacros,
    GetConsumableActionItems = GetConsumableActionItems,
    UpdateConsumableButtons = UpdateConsumableButtons,
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
