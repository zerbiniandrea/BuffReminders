local _, BR = ...

-- On-demand diagnostics for bug reports. Each command prints the raw values that
-- feed one check, so a user can paste the output into an issue. The commands are
-- intentionally not localized. Loads after Display.lua and reads BR.Display at
-- call time.

local format = string.format

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

-- Session log of talent-loadout changes. The "ghost spell" report (a spell stays
-- in the spell book after a loadout swap removes it, but the cast fails with
-- "spell not learned") needs the swap sequence to reproduce it. Bounded length.
local LOADOUT_LOG_MAX = 12
local loadoutLog = {}
local lastLoggedLoadout

local function ResolveActiveLoadout()
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return nil, nil
    end
    local info = C_Traits.GetConfigInfo(configID)
    return info and info.name, configID
end

local function LogLoadoutChange()
    local ok, name, configID = pcall(ResolveActiveLoadout)
    if not ok then
        return
    end
    local label = name or ("configID " .. tostring(configID))
    if label == lastLoggedLoadout then
        return
    end
    lastLoggedLoadout = label
    if #loadoutLog >= LOADOUT_LOG_MAX then
        table.remove(loadoutLog, 1)
    end
    loadoutLog[#loadoutLog + 1] = { time = GetTime(), label = label, spec = GetSpecialization() }
end

-- Diagnostic for the "ghost spell" report. Dumps every learned-state API for one
-- spell, the talent nodes that grant it, and the loadout changes of this session,
-- then names the APIs that disagree. Defaults to Lay on Hands.
local GHOST_SPELL_DEFAULT = 633 -- Lay on Hands
local GHOST_SPELL_ALIASES = { lay = 633, layonhands = 633, loh = 633 }

local function PrintSpellDebug(arg)
    local PREFIX = "|cff00ccffBuffReminders spell debug:|r "
    local function line(...)
        print(PREFIX .. table.concat({ ... }, " "))
    end
    local function str(v)
        if v == nil then
            return "nil"
        end
        return tostring(v)
    end
    -- Every API call is wrapped: a function that an older client does not have
    -- must not stop the dump.
    local function try(fn, ...)
        if type(fn) ~= "function" then
            return "unavailable"
        end
        local results = { pcall(fn, ...) }
        if not results[1] then
            return "ERROR(" .. str(results[2]) .. ")"
        end
        local parts = {}
        for i = 2, #results do
            parts[#parts + 1] = str(results[i])
        end
        return #parts > 0 and table.concat(parts, ", ") or "nil"
    end

    local spellID = arg and (GHOST_SPELL_ALIASES[arg] or tonumber(arg)) or GHOST_SPELL_DEFAULT
    if not spellID then
        line("unknown spell '" .. str(arg) .. "'. Usage: /br spelldebug [spellID|lay]")
        return
    end

    local _, class = UnitClass("player")
    local specId = BR.StateHelpers.GetPlayerSpecId()
    local specName = specId and select(2, GetSpecializationInfoByID(specId))
    line("addon =", C_AddOns.GetAddOnMetadata("BuffReminders", "Version") or "?", "| client =", (GetBuildInfo()))
    line("class =", str(class), "| specId =", str(specId), "(" .. str(specName) .. ")")
    line("spellID =", str(spellID), "| name =", str(C_Spell.GetSpellName(spellID)))

    -- Learned-state APIs. The report is a disagreement between them, so print
    -- each result raw instead of one resolved verdict.
    local isPlayerSpell = IsPlayerSpell(spellID) and true or false
    line("IsPlayerSpell =", try(IsPlayerSpell, spellID))
    line("IsSpellKnown =", try(IsSpellKnown, spellID))
    line("IsSpellKnownOrOverridesKnown =", try(IsSpellKnownOrOverridesKnown, spellID))

    local inBook = false
    if C_SpellBook then
        local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        line("C_SpellBook.IsSpellKnown =", try(C_SpellBook.IsSpellKnown, spellID, false))
        line("C_SpellBook.IsSpellInSpellBook =", try(C_SpellBook.IsSpellInSpellBook, spellID, bank))
        line("C_SpellBook.IsSpellKnownOrInSpellBook =", try(C_SpellBook.IsSpellKnownOrInSpellBook, spellID, bank))
        local okSlot, slot, slotBank = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID)
        line("FindSpellBookSlotForSpell =", okSlot and str(slot) or "ERROR", "| bank =", str(okSlot and slotBank))
        if okSlot and slot then
            inBook = true
            local okInfo, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, slotBank or bank)
            if okInfo and info then
                line(
                    "  book item: spellID =",
                    str(info.spellID),
                    "| actionID =",
                    str(info.actionID),
                    "| itemType =",
                    str(info.itemType),
                    "| isPassive =",
                    str(info.isPassive),
                    "| isOffSpec =",
                    str(info.isOffSpec),
                    "| name =",
                    str(info.name)
                )
            else
                line("  GetSpellBookItemInfo =", okInfo and "nil" or "ERROR")
            end
        end
    end
    line("C_Spell.GetOverrideSpell =", try(C_Spell.GetOverrideSpell, spellID))
    line("C_Spell.IsSpellUsable =", try(C_Spell.IsSpellUsable, spellID))
    line("C_Spell.IsSpellPassive =", try(C_Spell.IsSpellPassive, spellID))
    line("C_Spell.IsSpellDataCached =", try(C_Spell.IsSpellDataCached, spellID))
    if C_ActionBar and C_ActionBar.FindSpellActionButtons then
        local okBar, slots = pcall(C_ActionBar.FindSpellActionButtons, spellID)
        line("action bar slots =", (okBar and slots) and table.concat(slots, ",") or "none")
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    local configInfo = configID and C_Traits.GetConfigInfo(configID)
    line("active configID =", str(configID), "| name =", str(configInfo and configInfo.name))
    if specId then
        local lastSaved = C_ClassTalents.GetLastSelectedSavedConfigID(specId)
        local lastInfo = lastSaved and C_Traits.GetConfigInfo(lastSaved)
        line("last selected loadout =", str(lastSaved), "(" .. str(lastInfo and lastInfo.name) .. ")")
        line("starter build active =", try(C_ClassTalents.GetStarterBuildActive))
        local okList, list = pcall(C_ClassTalents.GetConfigIDsBySpecID, specId)
        if okList and list then
            local names = {}
            for _, id in ipairs(list) do
                local info = C_Traits.GetConfigInfo(id)
                names[#names + 1] = str(id) .. ":" .. str(info and info.name)
            end
            line("saved loadouts =", table.concat(names, " | "))
        end
    end
    if configID then
        line("import string =", try(C_Traits.GenerateImportString, configID))
    end

    -- Nodes that grant the spell, with all their entries. A paired talent in the
    -- same choice node prints here without a hardcoded spell ID.
    local granting = 0
    for _, treeID in ipairs((configInfo and configInfo.treeIDs) or {}) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            local match = false
            for _, entryID in ipairs((node and node.entryIDs) or {}) do
                local entry = C_Traits.GetEntryInfo(configID, entryID)
                local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                if def and (def.spellID == spellID or def.overriddenSpellID == spellID) then
                    match = true
                end
            end
            if match then
                granting = granting + 1
                line(
                    "node",
                    str(nodeID),
                    "| ranksPurchased =",
                    str(node.ranksPurchased),
                    "| activeRank =",
                    str(node.activeRank),
                    "| activeEntry =",
                    str(node.activeEntry and node.activeEntry.entryID),
                    "| visible =",
                    str(node.isVisible)
                )
                for _, entryID in ipairs(node.entryIDs) do
                    local entry = C_Traits.GetEntryInfo(configID, entryID)
                    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                    local entrySpell = def and (def.spellID or def.overriddenSpellID)
                    line(
                        "  entry",
                        str(entryID),
                        "| spellID =",
                        str(entrySpell),
                        "| name =",
                        str(entrySpell and C_Spell.GetSpellName(entrySpell)),
                        "| rank =",
                        str(entry and entry.rank)
                    )
                end
            end
        end
    end
    if granting == 0 then
        line("no talent node in the active config grants this spell")
    end

    if #loadoutLog == 0 then
        line("loadout changes this session: none recorded")
    else
        local now = GetTime()
        for i, rec in ipairs(loadoutLog) do
            line(
                "loadout change",
                str(i),
                "=",
                rec.label,
                "| specIndex =",
                str(rec.spec),
                "|",
                format("%.0f", now - rec.time),
                "s ago"
            )
        end
    end

    if inBook and not isPlayerSpell then
        line("|cffff4040MISMATCH|r: the spell book has the spell but IsPlayerSpell is false (ghost spell).")
    elseif isPlayerSpell and not inBook then
        line("|cffff4040MISMATCH|r: IsPlayerSpell is true but the spell book does not have the spell.")
    else
        line("no mismatch: the learned-state APIs agree.")
    end
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

BR.Display.PrintRuneDebug = PrintRuneDebug
BR.Display.PrintSpellDebug = PrintSpellDebug
BR.Display.PrintSecretDebug = PrintSecretDebug
BR.Display.LogLoadoutChange = LogLoadoutChange
