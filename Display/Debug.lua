local _, ns = ...
---@class BR
local BR = ns

-- On-demand diagnostics for bug reports. Each command prints the raw values that
-- feed one check, so a user can paste the output into an issue. The commands are
-- intentionally not localized. Loads after Display.lua and reads BR.Display at
-- call time.

-- Diagnostic for the DK "Wrong Rune" false-positive reports: every value that
-- feeds the dkRuneMH / dkRuneOH checks.
local function PrintRuneDebug()
    local PREFIX = "|cff00ccffBuffReminders rune debug:|r "
    local function line(...)
        print(PREFIX .. table.concat({ ... }, " "))
    end

    local _, class = UnitClass("player")
    line("class =", tostring(class))

    local specId = BR.StateHelpers.GetPlayerSpecId()
    local specName
    if specId then
        specName = select(2, GetSpecializationInfoByID(specId))
    end
    line("specId =", tostring(specId), "(" .. tostring(specName) .. ")")

    local hasOH = BR.BuffState.HasOffHandWeapon()
    line("HasOffHandWeapon =", tostring(hasOH), "| HasShield =", tostring(BR.BuffState.HasShield()))
    line("IsRestricted =", tostring(BR.BuffState.IsRestricted()), "(checks are suppressed when true)")

    -- Refresh so the permanent-enchant accessors reflect the current item links.
    BR.BuffState.Refresh("full")

    -- Enchant name lookup by enchantID from the runeforge table.
    local runeByEnchant = {}
    for _, rune in ipairs(BR.DK_RUNEFORGES) do
        runeByEnchant[rune.enchantID] = BR.GetSpellName(rune.spellID) or rune.key
    end
    local function enchantLabel(id)
        if not id then
            return "none"
        end
        return tostring(id) .. " (" .. (runeByEnchant[id] or "UNKNOWN - not in DK_RUNEFORGES") .. ")"
    end

    -- Raw item links + the value the addon actually parses/uses. Escape the pipe
    -- codes (| -> ||) so the link prints as copyable literal text instead of
    -- rendering as a clickable [Item Name], which drops the enchant payload
    -- when the user pastes the output.
    local function escapeLink(link)
        if not link then
            return "nil"
        end
        return (link:gsub("|", "||"))
    end
    line("MH link =", escapeLink(GetInventoryItemLink("player", 16)))
    line("OH link =", escapeLink(GetInventoryItemLink("player", 17)))
    line("MH permanent enchant =", enchantLabel(BR.BuffState.GetPermanentWeaponEnchantID(16)))
    line("OH permanent enchant =", enchantLabel(BR.BuffState.GetPermanentWeaponEnchantID(17)))

    -- Temporary weapon enchants (oils/imbues) for completeness - not used by rune check.
    local hasMain, _, _, mainID, hasOff, _, _, offID = GetWeaponEnchantInfo()
    line("temp enchant MH =", tostring(hasMain), tostring(mainID), "| OH =", tostring(hasOff), tostring(offID))

    -- Configured preference buckets for this spec.
    local prefs = BR.profile.dkRunePreferences
    local specPrefs = prefs and specId and prefs[specId]
    local function dumpBucket(name, bucket)
        if not bucket or not next(bucket) then
            line("prefs." .. name, "= (empty)")
            return
        end
        local parts = {}
        for id in pairs(bucket) do
            parts[#parts + 1] = enchantLabel(id)
        end
        line("prefs." .. name, "=", table.concat(parts, ", "))
    end
    if not specPrefs then
        line("dkRunePreferences[specId] = nil (nothing configured for this spec)")
    else
        dumpBucket("mainhand (2H)", specPrefs.mainhand)
        dumpBucket("dw_mainhand", specPrefs.dw_mainhand)
        dumpBucket("dw_offhand", specPrefs.dw_offhand)
    end

    -- Which bucket the MH check resolves to, and the verdict of each check.
    line("MH check uses bucket:", hasOH and "dw_mainhand" or "mainhand (2H)")
    local mhEntry = BR.BuffState.entries and BR.BuffState.entries.dkRuneMH
    local ohEntry = BR.BuffState.entries and BR.BuffState.entries.dkRuneOH
    line("dkRuneMH visible =", tostring(mhEntry and mhEntry.visible))
    line("dkRuneOH visible =", tostring(ohEntry and ohEntry.visible))
end

-- Diagnostic for restriction detection: the C_Secrets answers, plus the
-- classification-vs-live-read cross-check for one spell. Paste target for
-- false-"missing" reports; the cross-check is the API-lie detector that
-- justifies an OVERRIDE_NOT_TRACKABLE entry.

local SECRECY_LEVEL_NAMES = { [0] = "NeverSecret", [1] = "AlwaysSecret", [2] = "ContextuallySecret" }

local function PrintSecretDebug(arg)
    local PREFIX = "|cff00ccffBuffReminders secret debug:|r "
    local function line(...)
        print(PREFIX .. table.concat({ ... }, " "))
    end
    local function str(v)
        if v == nil then
            return "nil"
        end
        if issecretvalue(v) then
            return "SECRET"
        end
        return tostring(v)
    end
    -- Every C_Secrets call is wrapped: a client without the namespace or a
    -- member must not stop the dump.
    local function ask(fn, ...)
        if type(fn) ~= "function" then
            return "unavailable"
        end
        local ok, v = pcall(fn, ...)
        if not ok then
            return "ERROR(" .. tostring(v) .. ")"
        end
        return str(v)
    end
    local S = C_Secrets
    local AuraField = BR.Secret.AuraField

    line("addon =", C_AddOns.GetAddOnMetadata("BuffReminders", "Version") or "?", "| client =", (GetBuildInfo()))
    local _, instanceType, difficultyID = GetInstanceInfo()
    line(
        "zone =",
        str(instanceType),
        "| difficultyID =",
        str(difficultyID),
        "| InCombatLockdown =",
        tostring(InCombatLockdown())
    )
    line("IsRestricted() =", tostring(BR.BuffState.IsRestricted()))

    line("HasSecretRestrictions =", ask(S.HasSecretRestrictions))
    line("ShouldAurasBeSecret =", ask(S.ShouldAurasBeSecret))
    line("ShouldCooldownsBeSecret =", ask(S.ShouldCooldownsBeSecret))
    line("ShouldUnitIdentityBeSecret(player) =", ask(S.ShouldUnitIdentityBeSecret, "player"))

    -- Group-unit identity sample: the ally class/role caches in State.lua exist
    -- because these reads can degrade to secrets.
    if IsInGroup() then
        local unit = UnitExists("party1") and "party1" or "raid1"
        line(
            "ShouldUnitIdentityBeSecret(" .. unit .. ") =",
            ask(S.ShouldUnitIdentityBeSecret, unit),
            "| UnitClass =",
            str(select(2, UnitClass(unit))),
            "| UnitGroupRolesAssigned =",
            str(UnitGroupRolesAssigned(unit)),
            "| UnitIsPlayer =",
            str(UnitIsPlayer(unit)),
            "| UnitLevel =",
            str(UnitLevel(unit))
        )
    end

    local okEnum, firstAura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL")
    line("enumerate player =", okEnum and ("OK spellId=" .. str(AuraField(firstAura, "spellId"))) or "THREW")

    if not arg then
        return
    end
    local id = tonumber(arg)
    if not id then
        line("unknown spell '" .. tostring(arg) .. "'. Usage: /br secretdebug [spellID]")
        return
    end

    -- Cross-check: classification against a real read. A non-nil aura table
    -- proves presence - table identity is never secret.
    local level
    local okLevel, rawLevel = pcall(S.GetSpellAuraSecrecy, id)
    if okLevel and not issecretvalue(rawLevel) then
        level = rawLevel
    end
    local okRead, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, "player", id)
    local readResult
    if not okRead then
        readResult = "THREW"
    elseif aura == nil then
        readResult = "nil"
    elseif issecretvalue(aura) then
        readResult = "SECRET"
    else
        readResult = "FOUND"
    end
    line(
        "live check",
        tostring(id),
        str(C_Spell.GetSpellName(id)),
        "| classification =",
        SECRECY_LEVEL_NAMES[level] or str(level),
        "| ShouldSpellAuraBeSecret =",
        ask(S.ShouldSpellAuraBeSecret, id),
        "| IsAuraSpellTrackable =",
        tostring(BR.Restrictions.IsAuraSpellTrackable(id)),
        "| GetUnitAuraBySpellID(player) =",
        readResult
    )
end

local SPELL_DEBUG_CATEGORIES = { "raid", "presence", "targeted", "self", "pet", "consumable", "utility" }

---@param buff table
---@return number[]
local function BuffSpellIDs(buff)
    local ids = {}
    local spellID = buff.spellID
    if type(spellID) == "table" then
        for _, id in ipairs(spellID) do
            ids[#ids + 1] = id
        end
    elseif type(spellID) == "number" then
        ids[1] = spellID
    end
    if type(buff.castSpellID) == "number" then
        ids[#ids + 1] = buff.castSpellID
    end
    return ids
end

local spellDebugWindow

---@param text string
local function ShowCopyWindow(text)
    if not spellDebugWindow then
        local panel = BR.CreatePanel("BuffRemindersSpellDebug", 720, 460, { escClose = true })
        panel:SetPoint("CENTER")
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetText("BuffReminders spell debug: Ctrl+A, Ctrl+C, then Esc")
        local area = BR.Components.TextArea(panel, { width = 696, height = 416, readOnly = true })
        area:SetPoint("TOPLEFT", 12, -32)
        panel.area = area
        spellDebugWindow = panel
    end
    spellDebugWindow.area:SetText(text)
    spellDebugWindow:Show()
    spellDebugWindow.area:SetFocus()
    spellDebugWindow.area:HighlightText()
end

-- One row per spell ID of every buff of the active client: whether the client knows the
-- spell, whether the player knows it, its aura secrecy, and whether the player has the aura.
local function ShowSpellDebug()
    local S = C_Secrets
    local _, class = UnitClass("player")
    local version, build = GetBuildInfo()
    local lines = {
        string.format(
            "client=%s project=%s build=%s.%s class=%s level=%s",
            BR.CLIENT,
            tostring(WOW_PROJECT_ID),
            tostring(version),
            tostring(build),
            tostring(class),
            tostring(UnitLevel("player"))
        ),
        "category | key | id | name | rank | known | secrecy | on player",
    }
    for _, category in ipairs(SPELL_DEBUG_CATEGORIES) do
        for _, buff in ipairs(BR.BUFF_TABLES[category] or {}) do
            for _, id in ipairs(BuffSpellIDs(buff)) do
                local okLevel, level = pcall(S.GetSpellAuraSecrecy, id)
                local okAura, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
                local onPlayer = not okAura and "THREW" or issecretvalue(aura) and "SECRET" or tostring(aura ~= nil)
                local levelName = okLevel and not issecretvalue(level) and SECRECY_LEVEL_NAMES[level] or "?"
                lines[#lines + 1] = string.format(
                    "%s | %s | %d | %s | %s | %s | %s | %s",
                    category,
                    tostring(buff.key),
                    id,
                    tostring(C_Spell.GetSpellName(id)),
                    tostring(C_Spell.GetSpellSubtext(id)),
                    tostring(C_SpellBook.IsSpellKnown(id)),
                    levelName,
                    onPlayer
                )
            end
        end
    end
    ShowCopyWindow(table.concat(lines, "\n"))
end

BR.Display.PrintRuneDebug = PrintRuneDebug
BR.Display.PrintSecretDebug = PrintSecretDebug
BR.Display.ShowSpellDebug = ShowSpellDebug
