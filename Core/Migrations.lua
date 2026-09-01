local _, BR = ...

-- ============================================================================
-- Versioned SavedVariables migrations.
--
-- Each entry runs exactly once, gated by db.dbVersion: on login the runner
-- executes every migration with an index in (db.dbVersion, DB_VERSION] in
-- order, then stamps db.dbVersion = DB_VERSION.
--
-- NEVER delete or renumber an existing migration: WoW has no forced upgrade,
-- so a profile can return from any historical dbVersion. An old profile then
-- skips the schema reshaping it still needs. Append new migrations at the end
-- and bump DB_VERSION.
--
-- The pre-AceDB format conversion (old flat layout -> AceDB) is NOT here:
-- it must run before AceDB:New(), so it lives inline in Display/Display.lua's
-- ADDON_LOADED handler.
-- ============================================================================

local floor = math.floor
local max = math.max

BR.Migrations = {}

BR.Migrations.DB_VERSION = 54

-- Run pending migrations against the profile `db`, using code `defaults` for
-- fallbacks. `ctx` carries the Display.lua file-scope values the migrations
-- read (CATEGORIES).
function BR.Migrations.Run(db, defaults, ctx)
    local CATEGORIES = ctx.CATEGORIES

    local migrations = {
        -- [1] Consolidate all pre-versioning migrations (v2.8 -> v3.x)
        [1] = function()
            -- DeepCopyDefault runs later, so db.defaults can be absent here.
            if not db.defaults then
                db.defaults = {}
            end

            local isOldSchema = db.iconSize ~= nil
                or db.spacing ~= nil
                or db.growDirection ~= nil
                or db.showExpirationGlow ~= nil
            if isOldSchema then
                db.defaults.iconSize = db.iconSize or defaults.defaults.iconSize
                db.defaults.spacing = db.spacing or defaults.defaults.spacing
                db.defaults.growDirection = db.growDirection or defaults.defaults.growDirection
                db.defaults.showExpirationGlow = db.showExpirationGlow ~= false
                db.defaults.expirationThreshold = db.expirationThreshold or defaults.defaults.expirationThreshold
                db.defaults.glowStyle = db.glowStyle or 1
                db.iconSize = nil
                db.spacing = nil
                db.growDirection = nil
            end

            if db.splitCategories then
                for cat, isSplit in pairs(db.splitCategories) do
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings[cat] then
                        db.categorySettings[cat] = {}
                    end
                    db.categorySettings[cat].split = isSplit
                end
                db.splitCategories = nil
            end

            if isOldSchema and db.categorySettings then
                for cat, catSettings in pairs(db.categorySettings) do
                    if cat ~= "main" and catSettings.iconSize then
                        catSettings.useCustomAppearance = catSettings.split == true
                    end
                end
            end

            -- Migrate root-level showBuffReminder to raid category (v2.8.1 users)
            if db.showBuffReminder ~= nil then
                if db.categorySettings and db.categorySettings.raid then
                    db.categorySettings.raid.showBuffReminder = db.showBuffReminder
                end
            end

            if db.categorySettings then
                for cat, catSettings in pairs(db.categorySettings) do
                    if cat ~= "main" then
                        if cat == "raid" then
                            if catSettings.useCustomBehavior == false and catSettings.showBuffReminder == nil then
                                catSettings.showBuffReminder = db.defaults and db.defaults.showBuffReminder ~= false
                            end
                        else
                            catSettings.showBuffReminder = nil
                        end
                        catSettings.useCustomBehavior = nil
                        catSettings.showExpirationGlow = nil
                        catSettings.expirationThreshold = nil
                        catSettings.glowStyle = nil
                    end
                end
            end

            if db.showExpirationGlow ~= nil then
                db.defaults.showExpirationGlow = db.showExpirationGlow
                db.showExpirationGlow = nil
            end
            if db.expirationThreshold ~= nil then
                db.defaults.expirationThreshold = db.expirationThreshold
                db.expirationThreshold = nil
            end
            if db.glowStyle ~= nil then
                db.defaults.glowStyle = db.glowStyle
                db.glowStyle = nil
            end

            -- Remove showBuffReminder from defaults (now per-category raid-only)
            if db.defaults then
                db.defaults.showBuffReminder = nil
            end
            db.showBuffReminder = nil

            -- Remove showOnlyInInstance (replaced by per-category W/S/D/R visibility toggles)
            db.showOnlyInInstance = nil

            if not db.categorySettings then
                db.categorySettings = {}
            end
            if not db.categorySettings.main then
                db.categorySettings.main = {}
            end

            if db.position and not db.categorySettings.main.position then
                db.categorySettings.main.position = {
                    point = db.position.point,
                    x = db.position.x,
                    y = db.position.y,
                }
            end
        end,

        -- [2] Strip db.defaults keys matching code defaults (enable metatable inheritance)
        [2] = function()
            if db.defaults then
                for key, value in pairs(db.defaults) do
                    if defaults.defaults[key] ~= nil and value == defaults.defaults[key] then
                        db.defaults[key] = nil
                    end
                end
            end
        end,

        -- [3] Add pet category (new first-class category for pet summon reminders)
        [3] = function()
            if not db.categorySettings then
                db.categorySettings = {}
            end
            if not db.categorySettings.pet then
                db.categorySettings.pet = {}
            end
            if not db.categoryVisibility then
                db.categoryVisibility = {}
            end
            if not db.categoryVisibility.pet then
                db.categoryVisibility.pet = {
                    openWorld = true,
                    dungeon = true,
                    scenario = true,
                    raid = true,
                }
            end
        end,

        -- [4] Remove useGlowFallback (glow fallback is now always enabled)
        [4] = function()
            db.useGlowFallback = nil
        end,

        -- [5] Remove vestigial db.position (now fully in categorySettings.main.position)
        [5] = function()
            if db.position then
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings.main then
                    db.categorySettings.main = {}
                end
                if not db.categorySettings.main.position then
                    db.categorySettings.main.position = {
                        x = db.position.x or 0,
                        y = db.position.y or 0,
                    }
                end
                db.position = nil
            end
        end,

        -- [6] Add difficulty defaults for consumables (mythic only, no LFR)
        [6] = function()
            if not db.categoryVisibility then
                return
            end
            local vis = db.categoryVisibility.consumable
            if not vis then
                return
            end
            if not vis.dungeonDifficulty then
                vis.dungeonDifficulty = {
                    normal = false,
                    heroic = false,
                    mythic = true,
                    mythicPlus = false,
                    timewalking = false,
                    follower = false,
                }
            end
            if not vis.raidDifficulty then
                vis.raidDifficulty = {
                    lfr = false,
                    normal = true,
                    heroic = true,
                    mythic = true,
                }
            end
        end,

        -- [7] Rename custom buff specId -> requireSpecId (unify with built-in buff field names)
        [7] = function()
            if db.customBuffs then
                for _, customBuff in pairs(db.customBuffs) do
                    if customBuff.specId ~= nil then
                        customBuff.requireSpecId = customBuff.specId
                        customBuff.specId = nil
                    end
                end
            end
        end,

        -- [8] Seed pre-configured Burning Rush custom buff (disabled by default)
        [8] = function()
            if not db.customBuffs then
                db.customBuffs = {}
            end
            local key = "burningRush"
            if not db.customBuffs[key] then
                db.customBuffs[key] = {
                    spellID = 111400,
                    key = key,
                    name = "Burning Rush",
                    overlayText = "",
                    class = "WARLOCK",
                    showWhenPresent = true,
                }
            end
            if not db.enabledBuffs then
                db.enabledBuffs = {}
            end
            if db.enabledBuffs[key] == nil then
                db.enabledBuffs[key] = false
            end
        end,

        -- [9] Fix consumable dungeon difficulty default: mythic not M+
        [9] = function()
            local vis = db.categoryVisibility and db.categoryVisibility.consumable
            if not vis or not vis.dungeonDifficulty then
                return
            end
            local dd = vis.dungeonDifficulty
            -- Only fix if the user still has the old wrong defaults (M+ on, mythic off)
            if dd.mythicPlus == true and dd.mythic == false then
                dd.mythic = true
                dd.mythicPlus = false
            end
        end,

        -- [10] Clean up consumableItems: the bag scan replaces the manual config
        [10] = function()
            db.consumableItems = nil
        end,

        -- [11] Migrate showOnlyPlayerClassBuff/showOnlyPlayerMissing to buffTrackingMode
        [11] = function()
            local classBuff = db.showOnlyPlayerClassBuff
            local playerMissing = db.showOnlyPlayerMissing
            if classBuff then
                db.buffTrackingMode = "my_buffs"
            elseif playerMissing then
                db.buffTrackingMode = "personal"
            else
                db.buffTrackingMode = "all"
            end
            db.showOnlyPlayerClassBuff = nil
            db.showOnlyPlayerMissing = nil
        end,
        -- [12] Migrate glowStyle (1-5 color variants) to glowType + glowColor (LibCustomGlow)
        [12] = function()
            if not db.defaults then
                return
            end
            local oldStyle = db.defaults.glowStyle
            if oldStyle ~= nil then
                -- All old styles were atlas-based pulsing -> map to Pixel glow with the color
                local colorMap = {
                    [1] = { 0.95, 0.57, 0.07, 1 }, -- Orange
                    [2] = { 1, 0.82, 0, 1 }, -- Gold
                    [3] = { 1, 0.8, 0, 1 }, -- Yellow
                    [4] = { 0.9, 0.9, 0.9, 1 }, -- White
                    [5] = { 1, 0.2, 0.2, 1 }, -- Red
                }
                db.defaults.glowType = 1 -- Pixel
                db.defaults.glowColor = colorMap[oldStyle] or { 0.95, 0.57, 0.07, 1 }
                db.defaults.glowStyle = nil
            end
        end,
        -- [13] Unify consumable rebuff warning into per-category expiration glow
        [13] = function()
            if not db.defaults then
                return
            end
            local defs = db.defaults
            local globalThreshold = defs.expirationThreshold or 15

            if defs.consumableRebuffWarning == false then
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings.consumable then
                    db.categorySettings.consumable = {}
                end
                db.categorySettings.consumable.useCustomAppearance = true
                db.categorySettings.consumable.showExpirationGlow = false
            end

            if defs.consumableRebuffThreshold ~= nil and defs.consumableRebuffThreshold ~= globalThreshold then
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings.consumable then
                    db.categorySettings.consumable = {}
                end
                db.categorySettings.consumable.useCustomAppearance = true
                db.categorySettings.consumable.expirationThreshold = defs.consumableRebuffThreshold
            end

            defs.consumableRebuffWarning = nil
            defs.consumableRebuffThreshold = nil
            defs.consumableRebuffColor = nil
        end,
        -- [14] Tie growDirection to useCustomAppearance (was previously tied to split)
        [14] = function()
            if not db.categorySettings then
                return
            end
            local gd = db.defaults or {}
            for _, catSettings in pairs(db.categorySettings) do
                -- Split plus a custom direction, but no custom appearance, loses
                -- the direction setting without this migration.
                if catSettings.split and catSettings.growDirection ~= nil and not catSettings.useCustomAppearance then
                    catSettings.useCustomAppearance = true
                    -- Snapshot the global defaults so the category is independent.
                    if catSettings.iconSize == nil then
                        catSettings.iconSize = gd.iconSize or 64
                    end
                    if catSettings.spacing == nil then
                        catSettings.spacing = gd.spacing or 0.2
                    end
                    if catSettings.iconZoom == nil then
                        catSettings.iconZoom = gd.iconZoom or 8
                    end
                    if catSettings.borderSize == nil then
                        catSettings.borderSize = gd.borderSize or 2
                    end
                    if catSettings.iconAlpha == nil then
                        catSettings.iconAlpha = gd.iconAlpha or 1
                    end
                    if catSettings.textAlpha == nil then
                        catSettings.textAlpha = gd.textAlpha or 1
                    end
                    if catSettings.textColor == nil and gd.textColor then
                        local tc = gd.textColor
                        catSettings.textColor = { tc[1], tc[2], tc[3] }
                    end
                end
            end
        end,
        -- [15] Migrate invertGlow boolean to glowMode enum
        [15] = function()
            if not db.customBuffs then
                return
            end
            for _, buff in pairs(db.customBuffs) do
                if buff.invertGlow then
                    buff.glowMode = "whenNotGlowing"
                end
                buff.invertGlow = nil
            end
        end,
        -- [16] Migrate glow color: old orange default -> new yellow default,
        -- and auto-enable useCustomGlowColor for users who had a custom color
        [16] = function()
            local oldOrange = { 0.95, 0.57, 0.07, 1 }
            local newDefault = BR.Glow.DEFAULT_COLOR
            local function isOldOrange(c)
                return c and c[1] == oldOrange[1] and c[2] == oldOrange[2] and c[3] == oldOrange[3]
            end
            if db.defaults and db.defaults.glowColor then
                if isOldOrange(db.defaults.glowColor) then
                    db.defaults.glowColor = { newDefault[1], newDefault[2], newDefault[3], newDefault[4] }
                else
                    db.defaults.useCustomGlowColor = true
                end
            end
            if db.categorySettings then
                for _, catSettings in pairs(db.categorySettings) do
                    if catSettings.glowColor then
                        if isOldOrange(catSettings.glowColor) then
                            catSettings.glowColor = { newDefault[1], newDefault[2], newDefault[3], newDefault[4] }
                        else
                            catSettings.useCustomGlowColor = true
                        end
                    end
                end
            end
        end,

        -- [17] Migrate showOnlyOnReadyCheck from global to per-category
        [17] = function()
            if db.showOnlyOnReadyCheck then
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                for _, cat in ipairs({ "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }) do
                    if not db.categorySettings[cat] then
                        db.categorySettings[cat] = {}
                    end
                    db.categorySettings[cat].showOnlyOnReadyCheck = true
                end
            end
            db.showOnlyOnReadyCheck = nil
            db.readyCheckDuration = nil
        end,

        -- [18] Add housing = false to existing categoryVisibility entries
        [18] = function()
            if db.categoryVisibility then
                for _, cat in ipairs({ "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }) do
                    local vis = db.categoryVisibility[cat]
                    if vis and vis.housing == nil then
                        vis.housing = false
                    end
                end
            end
        end,

        -- [19] Custom buffs now use per-buff loadConditions; migrate category-level custom visibility
        [19] = function()
            local oldVis = db.categoryVisibility and db.categoryVisibility.custom
            local oldReadyCheck = db.categorySettings
                and db.categorySettings.custom
                and db.categorySettings.custom.showOnlyOnReadyCheck
            if db.customBuffs then
                for _, buff in pairs(db.customBuffs) do
                    if not buff.loadConditions then
                        local lc = {}
                        if oldVis then
                            for _, key in ipairs({ "openWorld", "scenario", "dungeon", "raid", "housing" }) do
                                if oldVis[key] == false then
                                    lc[key] = false
                                end
                            end
                            if oldVis.dungeonDifficulty then
                                lc.dungeonDifficulty = {}
                                for dk, dv in pairs(oldVis.dungeonDifficulty) do
                                    lc.dungeonDifficulty[dk] = dv
                                end
                            end
                            if oldVis.raidDifficulty then
                                lc.raidDifficulty = {}
                                for dk, dv in pairs(oldVis.raidDifficulty) do
                                    lc.raidDifficulty[dk] = dv
                                end
                            end
                        else
                            -- No custom visibility was set; apply old default (housing off)
                            lc.housing = false
                        end
                        if oldReadyCheck then
                            lc.readyCheckOnly = true
                        end
                        -- Only store if any value is non-default
                        if next(lc) then
                            buff.loadConditions = lc
                        end
                    end
                end
            end
            if db.categoryVisibility then
                db.categoryVisibility.custom = nil
            end
            if db.categorySettings and db.categorySettings.custom then
                db.categorySettings.custom.showOnlyOnReadyCheck = nil
            end
        end,

        -- [20] (no-op, minimap cleanup now handled by DeepCopyDefault skip)
        [20] = function() end,

        -- [21] Enable delve food by default (was opt-in, now opt-out)
        [21] = function()
            if db.enabledBuffs and db.enabledBuffs.delveFood == false then
                db.enabledBuffs.delveFood = nil
            end
        end,

        -- [22] Default delveFoodOnly to true (show only delve food in delves)
        [22] = function()
            if db.defaults and db.defaults.delveFoodOnly == false then
                db.defaults.delveFoodOnly = true
            end
        end,

        -- [23] Decouple zoom from base texcoord inset: subtract old base (8) from stored values
        [23] = function()
            if db.defaults and db.defaults.iconZoom then
                db.defaults.iconZoom = max(0, db.defaults.iconZoom - 8)
            end
            if db.categorySettings then
                for _, catSettings in pairs(db.categorySettings) do
                    if catSettings.iconZoom then
                        catSettings.iconZoom = max(0, catSettings.iconZoom - 8)
                    end
                end
            end
        end,

        -- [24] Remove glowWhenMissing (glow is now all-or-nothing) and stale showExpirationReminder
        [24] = function()
            if db.defaults then
                db.defaults.glowWhenMissing = nil
                db.defaults.showExpirationReminder = nil
            end
            for _, cat in ipairs(CATEGORIES) do
                local catSettings = db.categorySettings and db.categorySettings[cat]
                if catSettings then
                    catSettings.glowWhenMissing = nil
                    catSettings.showExpirationReminder = nil
                end
            end
        end,
        [25] = function()
            db.instanceEntryReminder = nil
        end,
        -- [26] Rename missingText -> overlayText on saved custom buffs
        [26] = function()
            if db.customBuffs then
                for _, buff in pairs(db.customBuffs) do
                    if buff.missingText ~= nil and buff.overlayText == nil then
                        buff.overlayText = buff.missingText
                        buff.missingText = nil
                    end
                end
            end
        end,
        -- [27] Per-category glow is now opt-in via useCustomGlow.
        -- Remove useCustomGlowColor (color swatch is now always active).
        -- Migrate old per-category glow keys: if a category had any glow overrides,
        -- enable useCustomGlow and keep the values; otherwise clean up.
        [27] = function()
            if db.defaults then
                if not db.defaults.useCustomGlowColor then
                    db.defaults.glowColor = nil
                end
                db.defaults.useCustomGlowColor = nil
            end
            local globalDefaults = db.defaults or {}
            for _, catSettings in pairs(db.categorySettings or {}) do
                catSettings.useCustomGlowColor = nil
                local hasOverride = false
                if catSettings.glowType ~= nil and catSettings.glowType ~= globalDefaults.glowType then
                    hasOverride = true
                end
                if catSettings.glowSize ~= nil and catSettings.glowSize ~= globalDefaults.glowSize then
                    hasOverride = true
                end
                if catSettings.glowColor ~= nil then
                    hasOverride = true
                end
                if hasOverride then
                    catSettings.useCustomGlow = true
                else
                    catSettings.glowType = nil
                    catSettings.glowSize = nil
                    catSettings.glowColor = nil
                end
            end
        end,
        -- [28] Add arena and bg visibility keys for existing users.
        -- Derive from their current dungeon setting; arena forced off for consumable.
        [28] = function()
            if db.categoryVisibility then
                for cat, vis in pairs(db.categoryVisibility) do
                    if type(vis) == "table" then
                        if vis.pvp == nil then
                            vis.pvp = vis.dungeon ~= false
                        end
                        if cat == "consumable" and not vis.pvpType then
                            vis.pvpType = { arena = false, bg = true }
                        end
                        if vis.hideInPvPMatch == nil then
                            vis.hideInPvPMatch = cat ~= "pet"
                        end
                    end
                end
            end
        end,
        -- [29] Default free consumables (healthstones, permanent runes) to ready-check-only
        -- so they do not show for the full instance.
        [29] = function()
            if db.defaults and db.defaults.freeConsumableReadyCheckOnly == false then
                db.defaults.freeConsumableReadyCheckOnly = true
            end
        end,
        -- [30] Rename freeConsumableReadyCheckOnly -> healthstoneVisibility (string mode),
        -- and clean up hideInPvPMatch from free consumable visibility.
        [30] = function()
            if db.defaults then
                local old = db.defaults.freeConsumableReadyCheckOnly
                if old == true then
                    db.defaults.healthstoneVisibility = "readyCheck"
                elseif old == false then
                    db.defaults.healthstoneVisibility = "always"
                end
                db.defaults.freeConsumableReadyCheckOnly = nil
                if db.defaults.freeConsumableVisibility then
                    db.defaults.freeConsumableVisibility.hideInPvPMatch = nil
                end
            end
        end,
        -- [31] Arena consumable restriction now handled at data layer (disabledInCompetitivePvP);
        -- re-enable the arena toggle so healthstones can show via category visibility.
        [31] = function()
            local vis = db.categoryVisibility and db.categoryVisibility.consumable
            if vis and vis.pvpType and vis.pvpType.arena == false then
                vis.pvpType.arena = true
            end
        end,

        -- [32] Remove sanguithorn tea (reverted by Blizzard)
        [32] = function()
            if db.enabledBuffs then
                db.enabledBuffs.sanguithorn = nil
            end
            if db.rememberedConsumables then
                for _, specMem in pairs(db.rememberedConsumables) do
                    if type(specMem) == "table" then
                        specMem.sanguithorn = nil
                    end
                end
            end
        end,

        -- [33] Clean up stale keys
        [33] = function()
            db.hidePetWhileMounted = nil
            if db.defaults and db.defaults.textSize == 12 then
                db.defaults.textSize = nil
            end
        end,
        [34] = function()
            -- Split glow: showExpirationGlow controlled both the missing and the
            -- expiring glow.
            if db.defaults and db.defaults.showExpirationGlow ~= nil then
                db.defaults.showMissingGlow = db.defaults.showExpirationGlow
            end
            if db.categorySettings then
                for _, catSettings in pairs(db.categorySettings) do
                    if catSettings.showExpirationGlow ~= nil then
                        catSettings.showMissingGlow = catSettings.showExpirationGlow
                    end
                end
            end
        end,
        [35] = function()
            -- Expiring glow default: Pixel (1) -> AutoCast (2).
            if db.defaults then
                if db.defaults.glowType == nil or db.defaults.glowType == 1 then
                    db.defaults.glowType = 2
                end
            end
        end,
        [36] = function()
            -- textSize is now an explicit default (20), not derived from iconSize.
            -- Materialize the derived value for a non-default iconSize, so the
            -- text size does not jump to 20.
            if db.defaults and db.defaults.textSize == nil then
                local iconSize = db.defaults.iconSize or 64
                if iconSize ~= 64 then
                    db.defaults.textSize = floor(iconSize * 0.32)
                end
            end
            if db.categorySettings then
                for _, cs in pairs(db.categorySettings) do
                    if cs.useCustomAppearance and cs.textSize == nil then
                        local iconSize = cs.iconSize or 64
                        if iconSize ~= 64 then
                            cs.textSize = floor(iconSize * 0.32)
                        end
                    end
                end
            end
        end,
        [37] = function()
            -- Move Burning Rush from a seeded custom buff to a self-buff.
            if db.customBuffs and db.customBuffs.burningRush then
                db.customBuffs.burningRush = nil
            end
            -- enabledBuffs.burningRush keeps the same key, so it needs no change.

            -- Migrate soulstone readyCheckOnlyOverrides to soulstoneVisibility
            local overrides = db.readyCheckOnlyOverrides
            if overrides and overrides.soulstone == false then
                if not db.defaults then
                    db.defaults = {}
                end
                db.defaults.soulstoneVisibility = "always"
                overrides.soulstone = nil
            end
        end,
        [38] = function()
            -- Enable "show consumables without items" + "only on ready check" for all users
            if not db.defaults then
                db.defaults = {}
            end
            db.defaults.showConsumablesWithoutItems = true
            db.defaults.showWithoutItemsOnlyOnReadyCheck = true
        end,

        [39] = function()
            -- Migrate custom buff expiration from category-level to per-buff
            -- Resolve effective threshold: category override > global default > code default (15)
            local catThreshold = 15
            if db.defaults and db.defaults.expirationThreshold then
                catThreshold = db.defaults.expirationThreshold
            end
            if db.categorySettings and db.categorySettings.custom then
                local catCustom = db.categorySettings.custom
                if catCustom.expirationThreshold ~= nil then
                    catThreshold = catCustom.expirationThreshold
                end
                -- Custom buffs no longer read the category-level expiration keys.
                catCustom.expirationThreshold = nil
                catCustom.showExpirationGlow = nil
            end
            if db.customBuffs then
                for _, buff in pairs(db.customBuffs) do
                    if buff.expirationThreshold == nil then
                        buff.expirationThreshold = catThreshold
                    end
                end
            end
        end,

        -- [40] Disable druidWrongForm by default. Nested defaults do not
        -- reliably merge once a profile has its own enabledBuffs table, so the
        -- migration writes the value directly. It also drops the retired
        -- legacyConsumablesNoticeShown global flag.
        [40] = function()
            if not db.enabledBuffs then
                db.enabledBuffs = {}
            end
            if db.enabledBuffs.druidWrongForm == nil then
                db.enabledBuffs.druidWrongForm = false
                db.enabledBuffs.warriorWrongStance = false
            end
            if BR.aceDB and BR.aceDB.global then
                BR.aceDB.global.legacyConsumablesNoticeShown = nil
            end
        end,

        -- [41] Fold legacy textOffsetX/Y (count) and buffTextOffsetX/Y
        -- (BUFF! reminder) into defaults.textPositions. Text positions are
        -- global only: each repositionable item has one realistic consumer
        -- (buffReminder = raid; statLabel/badge/stackCount = consumable;
        -- count is visually identical across categories).
        -- BUFF! reminder Y nudge: the old display added a -6 base offset on
        -- top of buffTextOffsetY. The BELOW_C zone bakes in -4, so the
        -- migration shifts a stored buffTextOffsetY by -2 to keep the total Y.
        [41] = function()
            local function ensurePos(item, zoneFallback)
                if not db.defaults then
                    db.defaults = {}
                end
                if not db.defaults.textPositions then
                    db.defaults.textPositions = {}
                end
                if not db.defaults.textPositions[item] then
                    db.defaults.textPositions[item] = { zone = zoneFallback, offsetX = 0, offsetY = 0 }
                end
                return db.defaults.textPositions[item]
            end

            -- defaults.textOffsetX/Y -> defaults.textPositions.count
            if db.defaults and (db.defaults.textOffsetX ~= nil or db.defaults.textOffsetY ~= nil) then
                local pos = ensurePos("count", "INSIDE_C")
                if db.defaults.textOffsetX ~= nil then
                    pos.offsetX = db.defaults.textOffsetX
                    db.defaults.textOffsetX = nil
                end
                if db.defaults.textOffsetY ~= nil then
                    pos.offsetY = db.defaults.textOffsetY
                    db.defaults.textOffsetY = nil
                end
            end

            -- categorySettings.raid.buffTextOffsetX/Y -> defaults.textPositions.buffReminder
            if db.categorySettings and db.categorySettings.raid then
                local raidCs = db.categorySettings.raid
                if raidCs.buffTextOffsetX ~= nil or raidCs.buffTextOffsetY ~= nil then
                    local pos = ensurePos("buffReminder", "BELOW_C")
                    if raidCs.buffTextOffsetX ~= nil then
                        pos.offsetX = raidCs.buffTextOffsetX
                        raidCs.buffTextOffsetX = nil
                    end
                    if raidCs.buffTextOffsetY ~= nil then
                        pos.offsetY = raidCs.buffTextOffsetY - 2
                        raidCs.buffTextOffsetY = nil
                    end
                end
            end

            -- Drop any per-category text-offset / textPositions data: the
            -- resolver no longer reads from there. A profile with custom
            -- appearance overrides loses its per-category nudge (rare).
            if db.categorySettings then
                for _, cs in pairs(db.categorySettings) do
                    if type(cs) == "table" then
                        cs.textOffsetX = nil
                        cs.textOffsetY = nil
                        cs.textPositions = nil
                    end
                end
            end
        end,

        -- [42] Enable click-to-cast for targeted buffs by default.
        -- The previous default was false, so existing profiles inherited "off"
        -- without a choice. The flip to true happens once, so a user who turns
        -- it back off keeps that setting.
        [42] = function()
            if db.categorySettings and db.categorySettings.targeted then
                db.categorySettings.targeted.clickable = true
            end
        end,

        -- [43] Materialize defaults.textPositions.petLabel for a profile that
        -- already has a saved textPositions table. The BELOW_C zone baseline
        -- is dy=-4, but the prior hard-coded anchor was dy=-2, so offsetY
        -- bakes in +2 to keep the exact visual. A profile with no saved
        -- textPositions is skipped: AceDB serves the code default on first
        -- access.
        [43] = function()
            if db.defaults and type(db.defaults.textPositions) == "table" then
                if db.defaults.textPositions.petLabel == nil then
                    db.defaults.textPositions.petLabel = { zone = "BELOW_C", offsetX = 0, offsetY = 2 }
                end
            end
        end,

        -- [44] Tracking overrides: convert the three boolean overrides into
        -- per-context mode enums (value = a tracking mode, or "default" for no
        -- override). Map each old boolean to the mode it used to force, so every
        -- profile keeps the current effective behavior, then clear the old keys.
        -- Guard on the OLD key's presence, not the new one: the new root keys
        -- live in the AceDB profile defaults, so copyDefaults already rawset
        -- them before the migrations run (`db.outsideInstancesMode == nil` is
        -- never true here). A missing old key means the profile kept its
        -- historical default (which AceDB stripped on logout), so the
        -- eagerly-copied new default stays - it matches the old behavior.
        [44] = function()
            if db.selfOnlyOutsideInstances ~= nil then
                db.outsideInstancesMode = db.selfOnlyOutsideInstances and "self_only" or "default"
            end
            if db.hideOthersInCombat ~= nil then
                db.combatMode = db.hideOthersInCombat and "my_buffs" or "default"
            end
            if db.myBuffsOnlyWhileLeveling ~= nil then
                db.levelingMode = db.myBuffsOnlyWhileLeveling and "my_buffs" or "default"
            end
            db.selfOnlyOutsideInstances = nil
            db.hideOthersInCombat = nil
            db.myBuffsOnlyWhileLeveling = nil
        end,

        -- [45] Drop the retired selfOnlyOutsideNoticeShown global flag. The
        -- one-time login notice it gated no longer exists.
        [45] = function()
            if BR.aceDB and BR.aceDB.global then
                BR.aceDB.global.selfOnlyOutsideNoticeShown = nil
            end
        end,

        -- [46] expirationThreshold is no longer an appearance key: it now uses
        -- the standard per-key fallback regardless of useCustomAppearance.
        -- A category can hold a stale threshold from an earlier
        -- custom-appearance stint. The flag hid that value while it was off;
        -- without cleanup the value becomes active.
        -- Drop it wherever custom appearance is currently disabled.
        [46] = function()
            if db.categorySettings then
                for _, catSettings in pairs(db.categorySettings) do
                    if type(catSettings) == "table" and not catSettings.useCustomAppearance then
                        catSettings.expirationThreshold = nil
                    end
                end
            end
        end,

        -- [47] Custom glow no longer requires custom appearance: useCustomGlow
        -- is now an independent override switch, and the per-kind glow ENABLE
        -- flags (showExpirationGlow/showMissingGlow) moved from the appearance
        -- gate to the glow gate. Two behavior-preserving fixups:
        -- a) useCustomGlow stored while custom appearance was off had no
        --    effect - drop it so it does not activate stale style values.
        -- b) Categories whose enable-flag overrides were live through the
        --    appearance gate (custom appearance on, custom glow off) stay
        --    live through useCustomGlow, with the currently-effective global
        --    glow STYLE mirrored in. This overwrites stale stored style keys:
        --    the old two-flag gate always took style from the defaults, so a
        --    dormant category value changes the visuals if it comes back.
        --
        -- Deliberately NOT preserved: categories with custom appearance on
        -- and NO stored enable flags rendered glow unconditionally (raw nil
        -- passed the consumers' `~= false` checks) while every checkbox
        -- displayed glow as off. That UI/runtime contradiction is resolved
        -- toward the UI: such categories now inherit the global enable flags.
        [47] = function()
            local GLOW_STYLE_KEYS = {
                "glowType",
                "glowSize",
                "glowPixelLines",
                "glowPixelFrequency",
                "glowPixelLength",
                "glowAutocastParticles",
                "glowAutocastFrequency",
                "glowAutocastScale",
                "glowBorderFrequency",
                "glowProcDuration",
                "glowProcStartAnim",
                "glowProcUseCustomColor",
                "glowXOffset",
                "glowYOffset",
                "missingGlowType",
                "missingGlowSize",
                "missingGlowPixelLines",
                "missingGlowPixelFrequency",
                "missingGlowPixelLength",
                "missingGlowAutocastParticles",
                "missingGlowAutocastFrequency",
                "missingGlowAutocastScale",
                "missingGlowBorderFrequency",
                "missingGlowProcDuration",
                "missingGlowProcStartAnim",
                "missingGlowProcUseCustomColor",
                "missingGlowXOffset",
                "missingGlowYOffset",
            }
            local gd = db.defaults or {}
            for _, cs in pairs(db.categorySettings or {}) do
                if type(cs) == "table" then
                    if cs.useCustomGlow and not cs.useCustomAppearance then
                        cs.useCustomGlow = nil
                    elseif
                        cs.useCustomAppearance
                        and not cs.useCustomGlow
                        and (cs.showExpirationGlow ~= nil or cs.showMissingGlow ~= nil)
                    then
                        cs.useCustomGlow = true
                        for _, key in ipairs(GLOW_STYLE_KEYS) do
                            cs[key] = gd[key]
                        end
                        for _, colorKey in ipairs({ "glowColor", "missingGlowColor" }) do
                            local c = gd[colorKey]
                            cs[colorKey] = c and { c[1], c[2], c[3], c[4] } or nil
                        end
                    end
                end
            end
        end,

        -- [48] (no-op, retired: repairGear/mageFood now ship off-by-default via the
        -- buff def's `defaultEnabled = false`, resolved at read time by
        -- StateHelpers.IsBuffEnabled - no per-profile seeding needed)
        [48] = function() end,

        -- [49] Frame lock is now session-only (starts locked every login), so the
        -- persisted `locked` field is dead - drop it. Also clears the retired
        -- glowDefaultNoticeCount global flag (per-profile migration runs once each,
        -- and one pass is enough for the shared global).
        [49] = function()
            db.locked = nil
            if BR.aceDB and BR.aceDB.global then
                BR.aceDB.global.glowDefaultNoticeCount = nil
            end
        end,

        -- [50] The entry set is the externals switch: a ticked buff is a tracked
        -- buff, so the separate enable flag is gone. A profile that kept ticks
        -- while that flag was off starts drawing them, which is what the ticks
        -- always asked for.
        [50] = function()
            if db.externals then
                db.externals.enabled = nil
            end
        end,
        -- [51] Guardian of the Forgotten Queen leaves the curated externals list:
        -- it is a PvP talent, too niche to offer everyone. A player who already
        -- tracks it keeps it as an entry of their own, sound override included.
        -- labelSpellID rather than a stored name: aura 228050 reads as "Divine
        -- Shield", and the ability that grants it localizes on every client.
        [51] = function()
            local externals = db.externals
            local entries = externals and externals.entries
            if not entries or not entries.forgottenQueen then
                return
            end

            externals.custom = externals.custom or {}
            local key = BR.NewExternalKey(228050)
            externals.custom[key] = { spellIDs = { 228050 }, labelSpellID = 228049 }
            entries[key] = true
            entries.forgottenQueen = nil

            local sounds = externals.sounds
            if sounds and sounds.forgottenQueen ~= nil then
                sounds[key] = sounds.forgottenQueen
                sounds.forgottenQueen = nil
            end
        end,
        -- [52] The options panel zoom replaces a raw frame scale that held
        -- PANEL_DENSITY at 100%. This pass covers every profile, not only `db`:
        -- migrations never run against an inactive profile, so a stale profile
        -- keeps the dead key and falls back to 100%.
        [52] = function()
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            for _, profile in pairs(profiles) do
                if type(profile) == "table" then
                    if type(profile.optionsPanelScale) == "number" then
                        profile.optionsPanelZoom = BR.ZoomFromLegacyScale(profile.optionsPanelScale)
                    end
                    profile.optionsPanelScale = nil
                end
            end
        end,
        -- [53] Aura Mastery leaves the curated externals list: aura 31821 lands on
        -- the paladin who casts it, not on the group, so the entry can never fire
        -- for the player it was offered to. Nothing walks a tracked key without a
        -- matching entry, so this pass only clears the dead saved keys.
        [53] = function()
            local externals = db.externals
            if not externals then
                return
            end
            if externals.entries then
                externals.entries.auraMastery = nil
            end
            if externals.sounds then
                externals.sounds.auraMastery = nil
            end
        end,
        -- [54] Luminous Barrier and Earthen Wall Totem leave the curated externals
        -- list: the game removed both abilities, so auras 271466 and 201633 can never
        -- apply. Nothing walks a tracked key without a matching entry, so this pass
        -- only clears the dead saved keys.
        [54] = function()
            local externals = db.externals
            if not externals then
                return
            end
            if externals.entries then
                externals.entries.luminousBarrier = nil
                externals.entries.earthenWall = nil
            end
            if externals.sounds then
                externals.sounds.luminousBarrier = nil
                externals.sounds.earthenWall = nil
            end
        end,
    }

    for version = (db.dbVersion or 0) + 1, BR.Migrations.DB_VERSION do
        if migrations[version] then
            migrations[version]()
        end
    end
    db.dbVersion = BR.Migrations.DB_VERSION
end
