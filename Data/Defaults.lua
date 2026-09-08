local _, BR = ...

-- The addon's entire default config. Pure data, exported as BR.defaults - the
-- single source; read it directly, no module-namespaced alias.
-- enabledBuffs holds only explicit user choices; it ships empty. A buff's
-- ship default is declared on the buff definition itself (`defaultEnabled = false`
-- for opt-in buffs) and resolved at read time by StateHelpers.IsBuffEnabled - no
-- migration and no per-profile seeding needed for new off-by-default buffs.

BR.defaults = {
    enabledBuffs = {},
    -- User-defined loadout reminders (talent / loadout / equipment-set mismatch),
    -- keyed by generated rule key.
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
    optionsPanelZoom = 100, -- percent
    showLoginMessages = true,
    requestBuffInChat = true,
    chatRequestCooldown = true,
    chatRequestMessages = {},

    -- DK runeforge preferences, keyed by spec ID.
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

    -- Externals: a present-based display, the inverse of the reminder pipeline.
    -- Rendered by Blizzard via an AuraContainer, so it works for auras the addon is
    -- not allowed to read. Purely additive schema - DeepCopyDefault seeds it, so
    -- no migration is needed.
    externals = {
        -- false = the appearance keys below inherit from the global `defaults`
        -- table (resolved by BR.GetExternalSetting) and their stored values stay
        -- dormant. Countdown size and direction have no `defaults` counterpart,
        -- so they always come from this table.
        useCustomAppearance = false,
        -- anchorFrame/anchorPoint stay nil until the mover popup sets them, and nil
        -- means screen placement - the same contract the categories use.
        position = { point = "CENTER", x = 0, y = -180 },
        iconSize = 40,
        -- iconWidth: nil = same as iconSize (square). Set explicitly for non-square icons.
        iconZoom = 0,
        borderSize = 2,
        iconAlpha = 1,
        spacing = 4, -- absolute px (Blizzard's elementSpacing), not an iconSize multiplier
        durationSize = 16, -- countdown text, centered on the icon
        showSwipe = true, -- radial sweep over the icon; it uncovers as the time runs out
        growDirection = "RIGHT", -- "LEFT", "RIGHT", "UP" or "DOWN"; the flow layout has no centered growth
        -- Mouse motion on the buttons. The game draws the tooltip, so it names the
        -- aura the addon cannot read. Off keeps the icons out of the mouse's way.
        showTooltips = false,
        -- The tracked set doubles as the on switch: empty means the display is off.
        entries = {}, -- [Data/Externals.lua key] = true
        -- sound: deliberately absent - nil means no sound. One value for every
        -- tracked external, played by the engine when the aura lands, because no
        -- Lua code can see that happen. Core/Sounds.lua owns the value format.
        --
        -- sounds[key] is the per-entry override: nil inherits `sound`, a value
        -- replaces it, and the no-sound sentinel silences that entry alone.
        sounds = {},
        -- The player's own entries, keyed the same way as the curated ones so
        -- `entries` and `sounds` address both sets.
        ---@type table<string, ExternalCustomEntry>
        custom = {},
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
        mageFoodContent = "all", -- "all" | "dungeon" | "raid"
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
        consumableBadgeOnSubIcons = false,
        hideConsumableLabels = false,
        showConsumableTooltips = false,
        rightClickSnooze = true,
        showBuffTooltips = false,
        hideLegacyConsumables = true,
        preferReusableRunes = false,
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
        -- Per-text-item size override, as a percentage of the icon size. An
        -- absent key follows consumableTextScale. Like every key in this table,
        -- the __index metatable serves it and DeepCopyDefault never copies it
        -- into the profile, so write it only through BR.Config.Set - a direct
        -- write lands in this shared table and leaks across profiles.
        textSizes = {},
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
    categorySettings = {
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
