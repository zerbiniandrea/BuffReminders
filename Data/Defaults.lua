local _, BR = ...

-- The addon's entire default config. Pure data, consumed by the bootstrap (AceDB
-- seeding + migrations), the display layer, and the options panel. Exported as
-- BR.defaults - the single source; read it directly, no module-namespaced alias.
-- Note: enabledBuffs holds only explicit user choices; it ships empty. A buff's
-- ship default is declared on the buff definition itself (`defaultEnabled = false`
-- for opt-in buffs) and resolved at read time by StateHelpers.IsBuffEnabled - no
-- migration and no per-profile seeding needed for new off-by-default buffs.

BR.defaults = {
    locked = true,
    enabledBuffs = {},
    -- User-defined loadout reminders (talent / loadout / equipment-set mismatch).
    -- Keyed by generated rule key; empty by default. See Options/Dialogs/LoadoutReminder.lua.
    loadoutReminders = {},
    showOnlyInGroup = false,
    hideWhileResting = false,
    hideInCombat = false,
    hideExpiringInCombat = true,
    buffTrackingMode = "all",
    -- Per-context tracking overrides: each is a tracking mode, or "default" for
    -- no override. When several apply at once, the most restrictive mode wins.
    outsideInstancesMode = "self_only",
    combatMode = "default",
    levelingMode = "my_buffs",
    hideAllInVehicle = false,
    hideWhileMounted = false,
    hideInLegacyInstances = true,
    hideWhileLeveling = false,
    showMissingCountOnly = false,
    petPassiveOnlyInCombat = false,
    bronzeHideInCombat = false,
    druidIgnoreTravelForm = true, -- hide the wrong-form reminder while traveling/mounted
    optionsPanelScale = 1.2, -- base scale (displayed as 100%)
    showLoginMessages = true,
    requestBuffInChat = true,
    chatRequestCooldown = true,
    chatRequestMessages = {},

    -- DK runeforge preferences: [specId] = { mainhand, dw_mainhand, dw_offhand }
    -- No runes selected = no reminder for that spec (implicit disable)
    dkRunePreferences = {
        [250] = { mainhand = { [6241] = true } }, -- Blood: Sanguination
        [251] = {
            mainhand = { [3368] = true }, -- 2H: Fallen Crusader
            dw_mainhand = { [3370] = true }, -- DW MH: Razorice
            dw_offhand = { [3368] = true }, -- DW OH: Fallen Crusader
        },
        [252] = { mainhand = { [6245] = true } }, -- Unholy: Apocalypse
    },

    -- Rogue poison preferences: ordered list per category, array index = priority (1 = highest).
    -- Shared with Data/Buffs.lua; DeepCopyDefault produces an independent per-profile copy.
    roguePoisonPreferences = BR.DEFAULT_POISON_PREFERENCES,

    minimap = {
        hide = true,
    },

    -- Global defaults (inherited by categories unless overridden)
    ---@type DefaultSettings
    defaults = {
        -- Appearance
        iconSize = 64,
        -- iconWidth: nil = same as iconSize (square). Set explicitly for non-square icons.
        textSize = 20,
        textOutline = "OUTLINE",
        iconAlpha = 1,
        textAlpha = 1,
        textColor = { 1, 1, 1 },
        spacing = 0.2, -- multiplier of iconSize
        iconZoom = 0, -- percentage (additional zoom on top of base TEXCOORD_INSET crop)
        borderSize = 2,
        growDirection = "CENTER", -- "LEFT", "CENTER", "RIGHT", "UP", "DOWN"
        -- Behavior (glow settings)
        showExpirationGlow = false,
        showMissingGlow = false,
        expirationThreshold = 15, -- minutes
        preKeyThreshold = 0, -- minutes (0 = off); used in M0 before inserting a keystone
        glowType = 2, -- BR.Glow.Type: Pixel=1, AutoCast=2, Border=3, Proc=4 (expiring default)
        glowSize = 2,
        showConsumablesWithoutItems = true,
        showWithoutItemsOnlyOnReadyCheck = true,
        delveFoodOnly = true,
        delveFoodTimer = false,
        freeConsumableMode = "override",
        freeConsumableVisibility = {
            openWorld = false,
            scenario = true,
            dungeon = true,
            raid = true,
            housing = false,
            pvp = true,
        },
        healthstoneVisibility = "readyCheck",
        healthstoneThreshold = 1,
        healthstoneLowStock = false,
        repairThreshold = 20, -- percent; repair reminder shows below this durability
        repairHideInCombat = true,
        soulstoneVisibility = "readyCheck",
        soulstoneHideCooldown = false,
        -- soulstonePinnedTarget: deliberately absent - nil means "no pin" (set via BuffPanel drawer)
        consumableDisplayMode = "sub_icons",
        consumableTextScale = 25,
        hideConsumableLabels = false,
        showConsumableTooltips = false,
        showBuffTooltips = false,
        hideLegacyConsumables = true,
        petDisplayMode = "generic", -- "generic" or "expanded"
        petLabels = true,
        petLabelScale = 100,
        petSpecIconOnHover = true,
        petLabelClasses = {
            HUNTER = true,
            WARLOCK = true,
            DEATHKNIGHT = true,
            MAGE = true,
        },
        useFelDomination = false,
        -- Per-text-item placement (zone + pixel nudge). See Core/TextPositions.lua
        -- for zone constants. Defaults preserve the prior hard-coded anchors so
        -- existing users see no visual change until they edit a value.
        textPositions = {
            count = { zone = "INSIDE_C", offsetX = 0, offsetY = 0 },
            stackCount = { zone = "INSIDE_BR", offsetX = 0, offsetY = 0 },
            statLabel = { zone = "INSIDE_TL", offsetX = 0, offsetY = 0 },
            badge = { zone = "INSIDE_L", offsetX = 0, offsetY = 0 },
            buffReminder = { zone = "BELOW_C", offsetX = 0, offsetY = 0 },
            -- petLabel: BELOW_C baseline is dy=-4; prior hard-coded anchor was
            -- dy=-2, so a +2 offsetY keeps the visual identical for users who
            -- never touch this setting.
            petLabel = { zone = "BELOW_C", offsetX = 0, offsetY = 2 },
        },
    },

    ---@type CategoryVisibility
    categoryVisibility = { -- Which content types each category shows in
        raid = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
            raidDifficulty = {
                lfr = false,
            },
        },
        presence = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
            raidDifficulty = {
                lfr = false,
            },
        },
        targeted = {
            openWorld = false,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
        },
        self = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
        },
        utility = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
        },
        pet = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = false,
        },
        loadout = {
            openWorld = true,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = false,
        },
        consumable = {
            openWorld = false,
            dungeon = true,
            scenario = true,
            raid = true,
            housing = false,
            pvp = true,
            hideInPvPMatch = true,
            pvpType = { arena = true, bg = true },
            scenarioDifficulty = {
                delves = true,
                others = false,
            },
            dungeonDifficulty = {
                normal = false,
                heroic = false,
                mythic = true,
                mythicPlus = false,
                timewalking = false,
                follower = false,
            },
            raidDifficulty = {
                lfr = false,
                normal = true,
                heroic = true,
                mythic = true,
            },
        },
    },

    ---@type AllCategorySettings
    categorySettings = { -- Per-category settings
        main = {
            position = { point = "CENTER", x = 0, y = 200 },
            -- main frame always uses defaults for appearance/behavior
        },
        raid = {
            position = { point = "CENTER", x = 0, y = 260 },
            useCustomAppearance = false,
            showBuffReminder = true,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 1,
        },
        presence = {
            position = { point = "CENTER", x = 0, y = 220 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 2,
        },
        targeted = {
            position = { point = "CENTER", x = 0, y = 180 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 3,
        },
        self = {
            position = { point = "CENTER", x = 0, y = 140 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 4,
        },
        pet = {
            position = { point = "CENTER", x = 0, y = 100 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 5,
        },
        consumable = {
            position = { point = "CENTER", x = 0, y = 60 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            subIconSide = "BOTTOM",
            priority = 6,
        },
        utility = {
            position = { point = "CENTER", x = 0, y = -60 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 9,
        },
        custom = {
            position = { point = "CENTER", x = 0, y = 20 },
            useCustomAppearance = false,
            split = false,
            clickable = false,
            clickableHighlight = true,
            priority = 7,
        },
        loadout = {
            position = { point = "CENTER", x = 0, y = -20 },
            useCustomAppearance = false,
            split = false,
            clickable = true,
            clickableHighlight = true,
            priority = 8,
        },
    },
}
