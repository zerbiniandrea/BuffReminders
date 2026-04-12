local _, BR = ...
local L = BR.L

-- ============================================================================
-- SECURE BUTTONS & CLICK-TO-CAST OVERLAYS
-- Consumable action buttons (sub-icons, expanded), click-to-cast spell overlays,
-- and all secure frame positioning logic. Separated from the display layer to
-- keep combat-lockdown-sensitive code isolated.
-- ============================================================================

-- Lua stdlib locals (avoid repeated global lookups in hot paths)
local floor, max, min = math.floor, math.max, math.min
local tsort = table.sort

local _, playerClass = UnitClass("player")
local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit

-- Chat request: categories that support "request buff in chat" on click
local chatRequestableCategories = { raid = true, presence = true }
local requestOnCooldown = {}
local REQUEST_COOLDOWN = 5

--- Returns the macro slash command prefix for the current group type.
local function GetChatRequestPrefix()
    if IsInGroup(2) then -- instance group
        return "/instance "
    elseif IsInRaid() then
        return "/raid "
    elseif IsInGroup() then
        return "/party "
    end
    return "/say "
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

local function GetFelDomPetMacro(petSpellID)
    local felDomName = C_Spell.GetSpellName(FEL_DOMINATION_ID)
    local spellName = BR.GetSpellName(petSpellID)
    if not felDomName or not spellName then
        return nil
    end
    return "/cast " .. felDomName .. "\n/cast " .. spellName
end

-- Pre-filter a buff's spell by talent/spec requirements, then find a castable spell ID.
-- Checks excludeSpellID, requiresSpellID, and requireSpecId before delegating
-- to GetCastableSpellID. Returns nil if the buff is filtered out or no spell is castable.
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
    -- When iconByRole is present, prefer the role-appropriate spell so the cast
    -- matches the displayed icon (e.g., Water Shield for healers, not Lightning Shield).
    if not buff.castSpellID and buff.iconByRole then
        local role = BR.BuffState.GetPlayerRole()
        local roleSpell = role and buff.iconByRole[role]
        if roleSpell and IsPlayerSpell(roleSpell) then
            return roleSpell
        end
    end
    return GetCastableSpellID(buff.castSpellID or buff.spellID)
end

---Resolve the click action for a custom buff.
---Priority: castMacro > castItemID > castSpellID > spellID[1] (if player knows it).
---Kept separate from GetActionSpellID to avoid leaking category awareness into shared code.
---@param buff table The custom buff definition
---@return string? actionType "spell"|"item"|"macro" or nil
---@return any actionValue The spell ID, item string, or macro text
local function ResolveCustomClickAction(buff)
    if not buff then
        return nil, nil
    end
    -- Priority 1: Raw macro text
    if buff.castMacro and buff.castMacro ~= "" then
        return "macro", buff.castMacro
    end
    -- Priority 2: Item
    if buff.castItemID then
        return "item", buff.castItemID
    end
    -- Priority 3: Explicit cast spell (separate from tracked aura)
    if buff.castSpellID then
        if IsPlayerSpell(buff.castSpellID) then
            return "spell", buff.castSpellID
        end
        return nil, nil
    end
    -- Priority 4: Fallback to tracked spell (only if player can cast it)
    local spellID = buff.spellID
    if type(spellID) == "table" then
        spellID = spellID[1]
    end
    if spellID and IsPlayerSpell(spellID) then
        return "spell", spellID
    end
    return nil, nil
end

---Check whether a custom buff definition has a per-buff click action configured
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
-- Custom styled tooltip for targeted buffs showing the last known target name.

local lastTargetTooltip

---Show the last target tooltip anchored below the given frame
---@param anchor table Frame to anchor to
---@param name string Character name
---@param class? string English class token
local function ShowLastTargetTooltip(anchor, name, class)
    if not lastTargetTooltip then
        local fontPath = BR.Display.GetFontPath()
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
        tip.name:SetFont(fontPath, 13, "OUTLINE")
        tip.name:SetPoint("CENTER", 0, 0)
        lastTargetTooltip = tip
    end
    local tip = lastTargetTooltip
    -- Set class-colored name
    local r, g, b = 1, 1, 1
    if class then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            r, g, b = c.r, c.g, c.b
        end
    end
    tip.name:SetText(name)
    tip.name:SetTextColor(r, g, b)
    -- Size to fit text
    local textWidth = tip.name:GetStringWidth()
    local textHeight = tip.name:GetStringHeight()
    tip:SetSize(textWidth + 24, textHeight + 16)
    -- Anchor below the frame
    tip:ClearAllPoints()
    tip:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    tip:Show()
end

---Hide the last target tooltip
local function HideLastTargetTooltip()
    if lastTargetTooltip then
        lastTargetTooltip:Hide()
    end
end

-- ============================================================================
-- CLICK-TO-CAST OVERLAY
-- ============================================================================

-- Create a SecureActionButton overlay for click-to-cast on a buff frame.
-- Parented to UIParent with NO anchors to the buff frame hierarchy, avoiding any
-- layout dependency that would make the frame hierarchy protected/secure.
-- Position is synced manually by SyncSecureButtons() after each layout pass.
---@param frame table The parent buff frame
local function CreateClickOverlay(frame)
    local overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    overlay:RegisterForClicks("AnyDown")
    overlay:EnableMouse(false)
    overlay:Hide()
    -- Auto-hide in combat (secure state driver), auto-show after
    RegisterStateDriver(overlay, "visibility", "[combat] hide; show")
    -- When state driver re-shows after combat, hide if buff frame isn't visible
    -- Uses IsVisible() (not IsShown()) to check entire parent chain — the frame's own
    -- shown state can be true while its parent container is hidden.
    overlay:SetScript("OnShow", function(self)
        if not frame:IsVisible() then
            self:Hide()
        end
    end)
    -- Re-evaluate dynamic macros before each click, refresh display after
    overlay:SetScript("PreClick", function(self)
        if self._br_chatRequestKey and not requestOnCooldown[self._br_chatRequestKey] then
            -- Rebuild macro each click to pick up current group type (party→raid).
            -- Safe outside combat (overlay hidden via state driver in combat).
            self:SetAttribute("macrotext", GetChatRequestPrefix() .. self._br_chatRequestMsg)
        elseif self._br_clickMacroFn then
            self:SetAttribute("macrotext", self._br_clickMacroFn(self._br_clickMacroSpellID))
        end
    end)
    overlay:SetScript("PostClick", function(self)
        if self._br_chatRequestKey then
            local key = self._br_chatRequestKey
            if not requestOnCooldown[key] and IsInGroup() then
                requestOnCooldown[key] = true
                -- Blank the macro to prevent spamming; restore after cooldown.
                -- SetAttribute is safe here: overlays are hidden during combat via
                -- state driver, so PostClick only fires outside combat lockdown.
                local msg = self._br_chatRequestMsg
                self:SetAttribute("macrotext", "")
                C_Timer.After(REQUEST_COOLDOWN, function()
                    requestOnCooldown[key] = nil
                    -- Restore macro if overlay is still a chat-request button.
                    -- If in combat lockdown, skip — SetupChatRequestOverlay will
                    -- re-set the macro when SyncSecureButtons runs after combat.
                    if self._br_chatRequestKey and not InCombatLockdown() then
                        self:SetAttribute("macrotext", GetChatRequestPrefix() .. msg)
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
        -- Delayed refresh for cast-time spells (e.g. rogue poisons ~1.5s)
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
    -- Tooltip: show last target name for targeted buffs, or item tooltip for consumables
    overlay:HookScript("OnEnter", function()
        if frame.buffDef and (frame.buffCategory == "targeted" or frame.buffDef.castOnOthers) then
            local name, class = BR.StateHelpers.GetLastTarget(frame.buffDef.key)
            if name then
                ShowLastTargetTooltip(overlay, name, class)
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
        end
    end)
    overlay:HookScript("OnLeave", function()
        HideLastTargetTooltip()
        if frame.buffCategory == "consumable" then
            GameTooltip:Hide()
        end
    end)
    frame.clickOverlay = overlay
end

-- ============================================================================
-- PET SPEC ICON HOVER
-- ============================================================================
-- On hover, swaps a pet frame's icon to the spec ability icon (Cunning/Ferocity/Tenacity).
-- Hooks are installed once per overlay; the spec icon reference is read from the
-- buff frame at event time so it stays in sync with display updates.

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

--- Re-apply pet spec icon if the overlay is currently hovered (called after display updates).
--- The display code just set the real icon, so we save it before re-swapping.
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

-- Badge text → color for buff frame middle-left overlay (quality uses atlas icons separately)
local BADGE_COLORS = {
    [L["Badge.Hearty"]] = { r = 0.4, g = 0.7, b = 1 }, -- Hearty (cyan)
    [L["Badge.Fleeting"]] = { r = 0.4, g = 0.7, b = 1 }, -- Fleeting (cyan)
}

---Compute consumable text font size from scale percentage.
---@param mainIconSize number The consumable category's main icon size
---@return number fontSize
local function ComputeConsumableFontSize(mainIconSize)
    local d = BR.profile and BR.profile.defaults
    local scale = d and d.consumableTextScale or 25
    return max(6, floor(mainIconSize * scale / 100))
end

---Create a small SecureActionButton for the consumable item row.
---Parented to UIParent with NO anchors to buff frames (avoids taint).
---Position synced by SyncSecureButtons().
---@return table btn The created button
local function CreateActionButton()
    local btn = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyDown")
    btn:Hide()
    -- Start hidden — state driver activated by SyncSecureButtons() after positioning
    RegisterStateDriver(btn, "visibility", "hide")
    -- When state driver re-shows after combat, hide if buff frame isn't visible
    -- Uses IsVisible() to check entire parent chain (see CreateClickOverlay comment)
    btn:SetScript("OnShow", function(self)
        local bf = self._br_buff_frame
        if not bf or not bf:IsVisible() then
            self:Hide()
        end
    end)
    -- Refresh display shortly after click so the consumed buff disappears quickly
    btn:SetScript("PostClick", function(self)
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

-- Consumable item cache: only rescan bags when BAG_UPDATE_DELAYED fires
local consumableCache = {} -- key → items array (or nil)
local consumableCacheDirty = true

local function InvalidateConsumableCache()
    consumableCacheDirty = true
end

---Scan bags for all consumable categories and populate the cache.
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
    -- Scan all bags once, bucket items by consumable category
    local buckets = {} -- category → { [itemID] = { count, icon } }
    local maxBags = NUM_BAG_SLOTS or 4
    for bag = 0, maxBags do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
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
                            -- Read stat label and badge from item table
                            if type(allowedEntry) == "table" then
                                bucket.statLabel = allowedEntry.label
                                bucket.badge = allowedEntry.badge
                            end
                            -- Parse crafted quality atlas from item link (e.g. Quality-Tier3, Quality-12-Tier2)
                            local hyperlink = info and info.hyperlink
                            if hyperlink then
                                local suffix = hyperlink:match("Quality%-[%w%-]*Tier%d")
                                if suffix then
                                    bucket.qualityAtlas = "Professions-Icon-" .. suffix
                                end
                            end
                            -- Store the spell this item casts (for auto-remember reverse lookup)
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

    -- Auto-remember food/weapon consumed outside addon (count-delta tracking)
    BR.ConsumableMemory.DetectConsumedItems(buckets, specId)

    -- Convert buckets to sorted arrays
    wipe(consumableCache)
    for category, entries in pairs(buckets) do
        local items = {}
        for _, item in pairs(entries) do
            items[#items + 1] = item
        end
        local allowedSet = itemSets[category]
        local rememberedSpell = BR.ConsumableMemory.GetRemembered(specId, category)
        tsort(items, function(a, b)
            -- If items have priority values, sort by priority first (lower = better)
            -- Priority entries (e.g., fleeting flasks) come before non-priority (regular)
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
            -- Remembered consumable spell for this spec sorts above non-remembered
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

    -- Snapshot current counts for next delta comparison
    BR.ConsumableMemory.SnapshotCounts(buckets)
end

-- Map buff key → CONSUMABLE_ITEMS category key (derived from buff definitions in Data/Buffs.lua)
local BUFF_KEY_TO_CATEGORY = BR.BUFF_KEY_TO_CATEGORY

---Get cached consumable items for a buff definition.
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

---Create/update the item icons for a consumable buff frame.
---Sets attributes, textures, and marks buttons visible. Positioning is handled
---separately by SyncSecureButtons() (no anchors to avoid taint).
---@param frame table The buff frame
---@param actionItems table[]? Array of { itemID, count, icon }
---@param clickable boolean? Whether buttons should accept mouse input
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

        btn.itemID = item.itemID
        btn.icon:SetTexture(item.icon or 134400)
        -- Dirty tracking: skip redundant SetAttribute calls
        if btn._br_action_item ~= item.itemID then
            if frame.key == "weaponBuff" or frame.key == "weaponBuffOH" then
                local slot = frame.key == "weaponBuffOH" and 17 or 16
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/use item:" .. tostring(item.itemID) .. "\n/use " .. slot)
            else
                btn:SetAttribute("type", "item")
                btn:SetAttribute("item", "item:" .. tostring(item.itemID))
            end
            btn._br_action_item = item.itemID
        end

        btn:EnableMouse(clickable == true)
        btn._br_visible = true
        btn._br_count = item.count
        btn._br_qualityAtlas = item.qualityAtlas
        btn._br_needs_sync = true
    end

    -- Mark unused buttons hidden
    for i = btnIndex + 1, #frame.actionButtons do
        frame.actionButtons[i]._br_visible = false
        frame.actionButtons[i]:Hide()
    end
end

-- ============================================================================
-- SECURE FRAME SYNC
-- ============================================================================

---Get the effective category for a buff frame (split or "main")
local function GetEffectiveCategory(frame)
    if frame.buffCategory and IsCategorySplit(frame.buffCategory) then
        return frame.buffCategory
    end
    return "main"
end

-- Hide secure frames (action buttons + overlays) for frames belonging to a specific catKey.
-- Used during mover drag to prevent sub-icons from lingering at old positions.
local function HideSecureFramesForCatKey(catKey)
    if InCombatLockdown() then
        return
    end
    for _, frame in pairs(BR.Display.frames) do
        -- Match by effective category OR by individual buff key (for detached icons)
        local effectiveCat = GetEffectiveCategory(frame)
        if effectiveCat == catKey or frame.key == catKey then
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

-- Sync all secure button positions/sizes/visibility with their buff frames.
-- Uses screen coordinates (no anchors) so secure frames never taint the buff hierarchy.
-- Safe to call at any time; skips if in combat lockdown.
local function HideAllSecureFrames()
    if InCombatLockdown() then
        return
    end
    for _, frame in pairs(BR.Display.frames) do
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

local function SyncSecureButtons()
    if InCombatLockdown() then
        return
    end
    -- Hide all clickable overlays during test mode to prevent desync
    if BR.Display.IsTestMode() then
        HideAllSecureFrames()
        return
    end
    local fontPath = BR.Display.GetFontPath()
    for _, frame in pairs(BR.Display.frames) do
        -- Sync click overlay
        local overlay = frame.clickOverlay
        if overlay then
            local cs = frame.buffCategory
                and BR.profile.categorySettings
                and BR.profile.categorySettings[frame.buffCategory]
            local clickable = cs and cs.clickable == true
            -- Custom buffs with per-buff click actions are individually clickable
            if not clickable and frame.buffCategory == "custom" then
                clickable = HasCustomClickAction(frame.buffDef)
            end
            if frame:IsVisible() then
                if not clickable or not overlay._br_has_action then
                    overlay:EnableMouse(false)
                    overlay:Hide()
                    overlay._br_left = nil
                else
                    local left, bottom, width, height = frame:GetRect()
                    if left then
                        -- Skip if position unchanged (avoids redundant ClearAllPoints/SetPoint)
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
                        overlay:EnableMouse(true)
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
                    local consumableSettings = GetCategorySettings("consumable")
                    local size = max(ACTION_ICON_MIN, floor((catSettings.iconSize or 64) * ACTION_ICON_SCALE))
                    local btnSpacing = max(2, floor(size * 0.2))
                    local subIconSide = consumableSettings.subIconSide or "BOTTOM"
                    -- Count visible buttons
                    local visibleCount = 0
                    for _, btn in ipairs(frame.actionButtons) do
                        if btn._br_visible then
                            visibleCount = visibleCount + 1
                        end
                    end
                    if visibleCount > 0 then
                        local cFontSize = ComputeConsumableFontSize(catSettings.iconSize or 64)
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
                                local needsUpdate = btn._br_needs_sync
                                    or btn._br_x ~= btnX
                                    or btn._br_y ~= btnY
                                    or btn._br_size ~= size
                                if needsUpdate then
                                    -- Reposition
                                    btn:ClearAllPoints()
                                    btn:SetSize(size, size)
                                    btn:SetFrameStrata(frame:GetFrameStrata())
                                    btn:SetFrameLevel(frame:GetFrameLevel() + 4)
                                    btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", btnX, btnY)
                                    btn._br_x = btnX
                                    btn._br_y = btnY
                                    btn._br_size = size
                                    -- Update text/font (only when data or size changed)
                                    btn.count:SetText(
                                        btn._br_count and btn._br_count > 1 and tostring(btn._br_count) or ""
                                    )
                                    btn.count:SetFont(fontPath, cFontSize, "OUTLINE")
                                    -- Quality atlas icon (holder frame at +10 to draw above borders/glows)
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
                                    btn._br_needs_sync = false
                                end
                                -- Activate combat state driver on first show (buttons start with "hide" driver)
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
                    -- Hide buttons that are no longer visible
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

-- Schedule secure button sync for the next frame (after layout has been calculated)
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

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

---Get the weapon equipment slot for a buff frame, if applicable.
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

---Set up a click overlay as a chat-request button for buffs the player can't cast.
---@param frame table The buff frame
---@param showHighlight boolean Whether to show the hover highlight
local function SetupChatRequestOverlay(frame, showHighlight)
    if not frame.clickOverlay then
        CreateClickOverlay(frame)
    end
    local overlay = frame.clickOverlay
    overlay._br_has_action = true
    overlay._br_clickMacroFn = nil
    overlay._br_clickMacroSpellID = nil
    overlay.itemID = nil
    overlay._br_chatRequestKey = frame.key
    local customMsg = (BR.profile.chatRequestMessages or {})[frame.key]
    overlay._br_chatRequestMsg = (customMsg and customMsg ~= "") and customMsg
        or L["ChatRequest." .. frame.key]
        or frame.displayName
    requestOnCooldown[frame.key] = nil -- Clear stale cooldown from prior setup
    overlay:SetAttribute("type", "macro")
    overlay:SetAttribute("macrotext", GetChatRequestPrefix() .. overlay._br_chatRequestMsg)
    overlay:EnableMouse(true)
    if overlay.highlight then
        overlay.highlight:SetShown(showHighlight)
    end
end

---Disable a click overlay: mark inactive, disable mouse, hide, clear position cache.
---@param overlay table SecureActionButton overlay
local function DisableOverlay(overlay)
    overlay._br_has_action = false
    overlay._br_clickMacroFn = nil
    overlay._br_clickMacroSpellID = nil
    overlay._br_chatRequestKey = nil
    overlay._br_chatRequestMsg = nil
    overlay.itemID = nil
    overlay:EnableMouse(false)
    overlay:Hide()
    overlay._br_left = nil
end

---Set pet summon spell or Fel Domination macro attributes on an overlay.
---Handles Fel Domination wrapping when the setting is enabled and the player knows it.
---@param overlay table SecureActionButton overlay
---@param spellID number The pet summon spell ID
---@param db table The profile database
local function SetPetSpellAttributes(overlay, spellID, db)
    local felMacro = (db.defaults or {}).useFelDomination
        and IsPlayerSpell(FEL_DOMINATION_ID)
        and GetFelDomPetMacro(spellID)
    if felMacro then
        overlay:SetAttribute("type", "macro")
        overlay:SetAttribute("macrotext", felMacro)
    else
        overlay:SetAttribute("type", "spell")
        overlay:SetAttribute("spell", spellID)
    end
end

---Set item-use or weapon-buff macro attributes on an overlay.
---@param overlay table SecureActionButton overlay
---@param itemID number The consumable item ID
---@param weaponSlot number? 16 or 17, or nil for non-weapon consumables
local function SetItemAttributes(overlay, itemID, weaponSlot)
    overlay.itemID = itemID
    if weaponSlot then
        overlay:SetAttribute("type", "macro")
        overlay:SetAttribute("macrotext", "/use item:" .. itemID .. "\n/use " .. weaponSlot)
    else
        overlay:SetAttribute("type", "item")
        overlay:SetAttribute("item", "item:" .. itemID)
    end
end

-- ============================================================================
-- SUB-ELEMENT HANDLERS
-- ============================================================================

---Update consumable sub-elements: sub-icon button clickability and expanded mode extra frame overlays.
---@param frame table The buff frame
---@param actionItems table[]? Cached consumable items
---@param showHighlight boolean Category-level highlight setting
---@param frameHighlight boolean Per-frame highlight (same as showHighlight for consumables)
---@param db table The profile database
local function UpdateConsumableSubElements(frame, actionItems, showHighlight, frameHighlight, db)
    local displayMode = (db.defaults or {}).consumableDisplayMode or "sub_icons"

    -- Sub-icon buttons: enable mouse input and set highlight
    if displayMode == "sub_icons" and frame.actionButtons then
        for _, btn in ipairs(frame.actionButtons) do
            btn:EnableMouse(true)
            if btn.highlight then
                btn.highlight:SetShown(showHighlight)
            end
        end
    end

    -- Expanded mode: set up click overlays on extra frames
    if displayMode == "expanded" and frame.extraFrames and actionItems then
        local weaponSlot = GetWeaponSlot(frame)
        for idx, extra in ipairs(frame.extraFrames) do
            local itemIdx = idx + 1 -- extra[1] = items[2], etc.
            if extra:IsShown() and actionItems[itemIdx] then
                if not extra.clickOverlay then
                    CreateClickOverlay(extra)
                end
                local eOverlay = extra.clickOverlay
                eOverlay._br_has_action = true
                eOverlay._br_clickMacroFn = nil
                eOverlay._br_clickMacroSpellID = nil
                SetItemAttributes(eOverlay, actionItems[itemIdx].itemID, weaponSlot)
                eOverlay:EnableMouse(true)
                if eOverlay.highlight then
                    eOverlay.highlight:SetShown(frameHighlight)
                end
            elseif extra.clickOverlay then
                DisableOverlay(extra.clickOverlay)
            end
        end
    elseif frame.extraFrames then
        -- Not expanded: disable extra overlays
        for _, extra in ipairs(frame.extraFrames) do
            if extra.clickOverlay then
                DisableOverlay(extra.clickOverlay)
            end
        end
    end
end

---Update click overlays on pet extra frames (each has its own summon spell).
---No-ops for frames without extraFrames (non-pet, non-consumable categories).
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
            eOverlay._br_has_action = true
            eOverlay._br_clickMacroFn = nil
            eOverlay._br_clickMacroSpellID = nil
            eOverlay.itemID = nil
            SetPetSpellAttributes(eOverlay, extra._br_pet_spell, db)
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

---Disable the main overlay, sub-icon buttons, and extra frame overlays for a frame.
---@param frame table The buff frame
---@param db table The profile database
local function DisableFrameAndChildren(frame, db)
    if frame.clickOverlay then
        DisableOverlay(frame.clickOverlay)
    end
    -- Sub-icon buttons: disable mouse but keep visible if mode is sub_icons
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
    -- Extra frame overlays
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

---Wire up click-to-cast overlays for all buff frames in a category.
---For consumables, also sets up consumable action items and expanded mode.
---For spells, checks talent/spec requirements and castability.
---@param category string
local function UpdateActionButtons(category)
    if InCombatLockdown() or BR.Display.IsTestMode() then
        return
    end

    local db = BR.profile
    local cs = db.categorySettings and db.categorySettings[category]
    local enabled = cs and cs.clickable == true
    local showHighlight = enabled and (cs.clickableHighlight ~= false)

    for _, frame in pairs(BR.Display.frames) do
        if frame.buffCategory == category then
            -- Custom buffs define click actions per-buff; treat as enabled when an action is set
            local frameEnabled = enabled
            local frameHighlight = showHighlight
            if not frameEnabled and category == "custom" and HasCustomClickAction(frame.buffDef) then
                frameEnabled = true
                frameHighlight = true
            end

            if frameEnabled then
                if category == "consumable" then
                    local actionItems = GetConsumableActionItems(frame.buffDef)
                    local def = frame.buffDef

                    if actionItems and #actionItems > 0 then
                        if not frame.clickOverlay then
                            CreateClickOverlay(frame)
                        end
                        local overlay = frame.clickOverlay
                        overlay._br_has_action = true
                        overlay._br_clickMacroFn = nil
                        overlay._br_clickMacroSpellID = nil
                        SetItemAttributes(overlay, actionItems[1].itemID, GetWeaponSlot(frame))
                        overlay:EnableMouse(true)
                        if overlay.highlight then
                            overlay.highlight:SetShown(showHighlight)
                        end
                    elseif def and def.clickMacro and (not def.casterClass or def.casterClass == playerClass) then
                        -- No consumable in bags but has clickMacro — cast the creation spell
                        if not frame.clickOverlay then
                            CreateClickOverlay(frame)
                        end
                        local overlay = frame.clickOverlay
                        local castableID = def.castSpellID or def.spellID
                        overlay._br_has_action = true
                        overlay.itemID = nil
                        overlay._br_clickMacroFn = def.clickMacro
                        overlay._br_clickMacroSpellID = castableID
                        overlay:SetAttribute("type", "macro")
                        overlay:SetAttribute("macrotext", def.clickMacro(castableID))
                        overlay:EnableMouse(true)
                        if overlay.highlight then
                            overlay.highlight:SetShown(showHighlight)
                        end
                    elseif def and def.castSpellID and (not def.casterClass or def.casterClass == playerClass) then
                        -- No consumable in bags but has castSpellID — cast the creation spell
                        if not frame.clickOverlay then
                            CreateClickOverlay(frame)
                        end
                        local overlay = frame.clickOverlay
                        overlay._br_has_action = true
                        overlay.itemID = nil
                        overlay._br_clickMacroFn = nil
                        overlay._br_clickMacroSpellID = nil
                        overlay:SetAttribute("type", "spell")
                        overlay:SetAttribute("spell", def.castSpellID)
                        overlay:EnableMouse(true)
                        if overlay.highlight then
                            overlay.highlight:SetShown(showHighlight)
                        end
                    elseif frame.clickOverlay then
                        -- No action resolved; clear fields but don't Hide() — let
                        -- SyncSecureButtons handle visibility via _br_has_action check.
                        frame.clickOverlay._br_has_action = false
                        frame.clickOverlay._br_clickMacroFn = nil
                        frame.clickOverlay._br_clickMacroSpellID = nil
                        frame.clickOverlay.itemID = nil
                        frame.clickOverlay:EnableMouse(false)
                    end
                    UpdateConsumableSubElements(frame, actionItems, showHighlight, frameHighlight, db)
                elseif frame.key == "petPassive" then
                    -- Pet passive: click to switch pet to Assist stance
                    if not frame.clickOverlay then
                        CreateClickOverlay(frame)
                    end
                    local overlay = frame.clickOverlay
                    overlay._br_has_action = true
                    overlay.itemID = nil
                    overlay._br_clickMacroFn = nil
                    overlay._br_clickMacroSpellID = nil
                    overlay:SetAttribute("type", "macro")
                    overlay:SetAttribute("macrotext", "/petassist")
                    overlay:EnableMouse(true)
                    if overlay.highlight then
                        overlay.highlight:SetShown(frameHighlight)
                    end
                else
                    -- Spells / Custom: check castability before creating overlay
                    local castableID
                    local customActionType, customActionValue
                    if frame._br_pet_spell then
                        castableID = frame._br_pet_spell
                    elseif category == "custom" then
                        customActionType, customActionValue = ResolveCustomClickAction(frame.buffDef)
                        if customActionType == "spell" then
                            castableID = customActionValue
                            customActionType = nil -- handled by spell path below
                        end
                    else
                        castableID = GetActionSpellID(frame.buffDef)
                    end

                    if customActionType then
                        -- Custom buff with item/macro action
                        if not frame.clickOverlay then
                            CreateClickOverlay(frame)
                        end
                        local overlay = frame.clickOverlay
                        overlay._br_has_action = true
                        overlay.itemID = nil
                        overlay._br_clickMacroFn = nil
                        overlay._br_clickMacroSpellID = nil
                        if customActionType == "macro" then
                            overlay:SetAttribute("type", "macro")
                            overlay:SetAttribute("macrotext", customActionValue:gsub("\\n", "\n"))
                        elseif customActionType == "item" then
                            overlay:SetAttribute("type", "item")
                            overlay:SetAttribute("item", "item:" .. customActionValue)
                            overlay.itemID = customActionValue
                        end
                        overlay:EnableMouse(true)
                        if overlay.highlight then
                            overlay.highlight:SetShown(frameHighlight)
                        end
                    elseif castableID and not (frame.buffDef and frame.buffDef.noClickToCast) then
                        if not frame.clickOverlay then
                            CreateClickOverlay(frame)
                        end
                        local overlay = frame.clickOverlay
                        overlay._br_has_action = true
                        overlay.itemID = nil
                        if frame.buffDef and frame.buffDef.clickMacro then
                            overlay._br_clickMacroFn = frame.buffDef.clickMacro
                            overlay._br_clickMacroSpellID = castableID
                            overlay:SetAttribute("type", "macro")
                            overlay:SetAttribute("macrotext", frame.buffDef.clickMacro(castableID))
                        elseif frame._br_pet_spell then
                            overlay._br_clickMacroFn = nil
                            overlay._br_clickMacroSpellID = nil
                            SetPetSpellAttributes(overlay, castableID, db)
                        else
                            overlay._br_clickMacroFn = nil
                            overlay._br_clickMacroSpellID = nil
                            overlay:SetAttribute("type", "spell")
                            overlay:SetAttribute("spell", castableID)
                            overlay:SetAttribute("unit", category == "raid" and "player" or nil)
                        end
                        overlay:EnableMouse(true)
                        if overlay.highlight then
                            overlay.highlight:SetShown(frameHighlight)
                        end
                        if frame._br_pet_spec_icon then
                            HookPetSpecIconHover(overlay, frame)
                        end
                    elseif db.requestBuffInChat and chatRequestableCategories[category] and not frame.isPlayerBuff then
                        SetupChatRequestOverlay(frame, frameHighlight)
                    elseif frame.clickOverlay then
                        DisableOverlay(frame.clickOverlay)
                    end

                    -- Pet extra frames: each has its own summon spell
                    UpdateExtraFrameOverlays(frame, frameHighlight, db)
                end
            else
                DisableFrameAndChildren(frame, db)
            end
        end
    end
    ScheduleSecureSync()
end

-- Refresh overlay spell attributes for all frames (e.g., after spec change).
-- Re-checks talent/spec pre-filters and IsPlayerSpell, updates EnableMouse + spell attribute.
-- Also refreshes consumable action buttons.
local function RefreshOverlaySpells()
    if InCombatLockdown() or BR.Display.IsTestMode() then
        return
    end

    local db = BR.profile
    local seen = {}
    for _, frame in pairs(BR.Display.frames) do
        local cat = frame.buffCategory
        if cat and not seen[cat] then
            seen[cat] = true
            local cs = db.categorySettings and db.categorySettings[cat]
            if (cs and cs.clickable == true) or cat == "custom" then
                UpdateActionButtons(cat)
            end
        end
    end
end

-- Export module
BR.SecureButtons = {
    UpdateActionButtons = UpdateActionButtons,
    RefreshOverlaySpells = RefreshOverlaySpells,
    GetConsumableActionItems = GetConsumableActionItems,
    UpdateConsumableButtons = UpdateConsumableButtons,
    InvalidateConsumableCache = InvalidateConsumableCache,
    HideAllSecureFrames = HideAllSecureFrames,
    HideSecureFramesForCatKey = HideSecureFramesForCatKey,
    ScheduleSecureSync = ScheduleSecureSync,
    ComputeConsumableFontSize = ComputeConsumableFontSize,
    BADGE_COLORS = BADGE_COLORS,
    ReapplyPetSpecIconIfHovered = ReapplyPetSpecIconIfHovered,
}
