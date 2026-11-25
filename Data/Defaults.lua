local _, ns = ...
---@class BR
local BR = ns

-- The addon's entire default config. Pure data, exported as BR.defaults - the
-- single source; read it directly, no module-namespaced alias.
-- enabledBuffs holds only explicit user choices; it ships empty. A buff's
-- ship default is declared on the buff definition itself (`defaultEnabled = false`
-- for opt-in buffs) and resolved at read time by StateHelpers.IsBuffEnabled - no
-- migration and no per-profile seeding needed for new off-by-default buffs.

---@alias BuffTrackingMode "all"|"my_buffs"|"personal"|"self_only"|"smart"

---@class ExternalsSettings
---@field useCustomAppearance boolean False = the appearance keys inherit from the global `defaults` (BR.GetExternalSetting)
---@field position CategoryPosition
---@field anchorFrame? string Frame name; nil = screen placement, as for the categories
---@field anchorPoint? string
---@field iconSize number
---@field iconWidth? number nil = same as iconSize (square)
---@field iconZoom number
---@field borderSize number
---@field iconAlpha number
---@field spacing number Gap in px
---@field durationSize number Countdown text, centered on the icon
---@field showSwipe boolean Radial sweep that uncovers as the time runs out
---@field growDirection "LEFT"|"RIGHT"|"UP"|"DOWN" The flow layout has no centered growth
---@field showTooltips boolean
---@field showCasterName boolean
---@field casterNameSize number
---@field casterNamePosition "TOP"|"BOTTOM"|"LEFT"|"RIGHT"
---@field casterNameOffsetX number
---@field casterNameOffsetY number
---@field entries table<string, true> Tracked keys. Empty = the display is off
---@field sound? string nil = no sound. Core/Sounds.lua owns the value format
---@field sounds table<string, string> Per-entry override: nil inherits `sound`
---@field custom table<string, ExternalCustomEntry> The player's own entries, keyed like the curated ones

---@class BRProfile
---@field dbVersion? integer
---@field enabledBuffs table<string, boolean> Explicit user choices only
---@field loadoutReminders table<string, LoadoutRule>
---@field customBuffs? table<string, CustomBuff>
---@field showOnlyInGroup boolean
---@field hideWhileResting boolean
---@field hideInCombat boolean
---@field hideExpiringInCombat boolean
---@field buffTrackingMode BuffTrackingMode
---@field outsideInstancesMode BuffTrackingMode|"default"
---@field combatMode BuffTrackingMode|"default"
---@field levelingMode BuffTrackingMode|"default"
---@field hideAllInVehicle boolean
---@field hideWhileMounted boolean
---@field hideInLegacyInstances boolean
---@field hideWhileLeveling boolean
---@field showMissingCountOnly boolean
---@field petPassiveOnlyInCombat boolean
---@field bronzeHideInCombat boolean
---@field druidIgnoreTravelForm boolean
---@field optionsPanelZoom number Percent
---@field showLoginMessages boolean
---@field requestBuffInChat boolean
---@field chatRequestCooldown boolean
---@field chatRequestMessages table<string, string>
---@field dkRunePreferences table<number, table<string, table<number, boolean>>>
---@field roguePoisonPreferences table
---@field minimap table
---@field externals ExternalsSettings
---@field defaults DefaultSettings
---@field categoryVisibility CategoryVisibility
---@field categorySettings AllCategorySettings
---@field detachedIcons? DetachedIcons
---@field buffSounds? table<string, string>
---@field readyCheckOnlyOverrides? table<string, boolean>
---@field groupCast? table<string, boolean> Buff key -> cast the group rank that uses a reagent
---@field rememberedConsumables? table<number, table<string, number>> Spec ID -> category -> spell ID
---@field customAnchorFrames? string[]
---@field position? CategoryPosition

---@type BRProfile
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
    -- Forever players level in open-world groups, so buffs on group mates matter there.
    outsideInstancesMode = BR.ByClient({ retail = "self_only", forever = "my_buffs" }),
    combatMode = "default",
    levelingMode = BR.ByClient({ retail = "my_buffs", forever = "default" }),
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
    -- Shared with Data/Buffs.lua. Each profile gets its own copy from the AceDB defaults.
    roguePoisonPreferences = BR.DEFAULT_POISON_PREFERENCES,

    minimap = {
        hide = true,
    },

    -- Externals: a present-based display, the inverse of the reminder pipeline.
    -- Rendered by Blizzard via an AuraContainer, so it works for auras the addon is
    -- not allowed to read. Purely additive schema - the AceDB defaults seed it,
    -- so no migration is needed.
    externals = {
        -- Countdown size and direction have no `defaults` counterpart, so they
        -- always come from this table, even while the appearance inherits.
        useCustomAppearance = false,
        position = { point = "CENTER", x = 0, y = -180 },
        iconSize = 40,
        iconZoom = 0,
        borderSize = 2,
        iconAlpha = 1,
        spacing = 4,
        durationSize = 16,
        showSwipe = true,
        growDirection = "RIGHT",
        -- The game draws the tooltip, so it names the aura the addon cannot read.
        -- Off keeps the icons out of the mouse's way.
        showTooltips = false,
        showCasterName = false,
        casterNameSize = 12,
        casterNamePosition = "BOTTOM",
        casterNameOffsetX = 0,
        casterNameOffsetY = 0,
        entries = {},
        -- The engine plays the sound when the aura lands, because no Lua code can
        -- see that happen. The no-sound sentinel in `sounds` silences one entry.
        sounds = {},
        custom = {},
    },

    -- Global defaults (inherited by categories unless overridden)
    ---@type DefaultSettings
    defaults = {
        -- Appearance
        iconSize = 64,
        -- iconWidth: nil = same as iconSize (square). Set explicitly for non-square icons.
        textSize = BR.ByClient({ retail = 20, forever = 17 }),
        textOutline = "OUTLINE",
        slugOutline = true,
        iconAlpha = 1,
        textAlpha = 1,
        textColor = { 1, 1, 1 },
        spacing = BR.ByClient({ retail = 8, forever = 4 }), -- px
        iconZoom = 0, -- percentage (additional zoom on top of base TEXCOORD_INSET crop)
        borderSize = 2,
        growDirection = "CENTER", -- "LEFT", "CENTER", "RIGHT", "UP", "DOWN"
        iconStyle = BR.ByClient({ retail = "modern", forever = "blizzard" }),
        -- Behavior (glow settings)
        showExpirationGlow = false,
        showMissingGlow = false,
        expirationThreshold = BR.ByClient({ retail = 15, forever = 5 }), -- minutes
        expirationShare = 25, -- percent of a buff duration, capped by expirationThreshold
        preKeyThreshold = 0, -- minutes (0 = off); used in M0 before inserting a keystone
        glowType = 2, -- BR.Glow.Type: Pixel=1, AutoCast=2, Border=3, Proc=4 (expiring default)
        glowSize = 2,
        showConsumablesWithoutItems = true,
        showWithoutItemsOnlyOnReadyCheck = true,
        delveFoodOnly = true,
        delveFoodTimer = false,
        mageFoodContent = "all", -- "all" | "dungeon" | "raid"
        shamanImbue = "windfury", -- "windfury" | "flametongue" | "rockbiter" | "frostbrand"
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
        reagentThreshold = 5, -- the reagent reminder shows below this count
        reagentRestedOnly = true,
        campLightFire = true, -- WoW Forever: the camp reminder also asks for a campfire kit
        ammoThresholdStacks = 1, -- hunters: the ammo reminder shows below this many stacks
        ammoThresholdShots = 20, -- other classes: the ammo reminder shows below this many shots
        groupCastMin = 2, -- group members who lack a buff before the click casts its group version
        driveByGreeting = "none",
        -- driveByWhisper, driveByEmoteText: absent - nil means the localized default text
        driveByEmote = "WAVE",
        driveByAllowPvP = false,
        soulstoneVisibility = BR.SOULSTONE_DEFAULT_VISIBILITY,
        soulstoneHideCooldown = false,
        -- soulstonePinnedTarget: deliberately absent - nil means "no pin" (set via BuffPanel drawer)
        consumableDisplayMode = "sub_icons",
        consumableTextScale = 25,
        consumableBadgeOnSubIcons = false,
        hideConsumableLabels = false,
        clickable = true,
        clickableHighlight = true,
        showDescriptionTooltips = false,
        rightClickMenu = true,
        subIconReveal = "hover",
        subIconSide = "BOTTOM",
        hideLegacyConsumables = true,
        preferReusableRunes = false,
        placeAtPlayer = true,
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
        -- Allowed warlock demons per content row (WARLOCK_DEMON_CHOICES keys). A row
        -- with none allows all demons. Demonology with Felguard talented ignores it.
        -- WoW Forever rows allow a demon below level 30, where Felhunter is not learned.
        warlockDemons = BR.ByClient({
            retail = {
                world = { felhunter = true },
                dungeon = { felhunter = true },
                raid = { imp = true, felhunter = true, sayaad = true },
                pvp = { felhunter = true },
            },
            forever = {
                world = { imp = true, voidwalker = true, succubus = true, felhunter = true },
                dungeon = { imp = true, felhunter = true },
                raid = { imp = true, succubus = true },
                pvp = { succubus = true, felhunter = true },
            },
        }),
        warlockWrongDemon = true,
        -- The blessings of each class (WoW Forever), in priority order. A member gets the
        -- first one that no other paladin gives them. Every slot holds a value, so that
        -- AceDB cannot fill a slot that the user emptied.
        paladinBlessingsByClass = BR.ByClient({
            retail = BR.NONE,
            forever = {
                WARRIOR = { "might", "kings", false },
                ROGUE = { "might", "kings", false },
                HUNTER = { "kings", "wisdom", false },
                MAGE = { "wisdom", "kings", false },
                WARLOCK = { "wisdom", "kings", false },
                PRIEST = { "wisdom", "kings", false },
                DRUID = { "wisdom", "kings", false },
                SHAMAN = { "wisdom", "kings", false },
                PALADIN = { "wisdom", "kings", false },
            },
        }),
        -- WoW Forever: "self" checks and blesses only the player.
        paladinBlessingScope = BR.ByClient({ retail = BR.NONE, forever = "group" }),
        -- WoW Forever: "all" adds creature tracking to the gathering tracking.
        trackingScope = BR.ByClient({ retail = BR.NONE, forever = "gathering" }),
        -- The paladin auras of each content row (WoW Forever): the main aura, then the
        -- backup. An empty row accepts any aura. Every slot holds a value, so that AceDB
        -- cannot fill a slot that the user emptied.
        paladinAuraOrder = BR.ByClient({
            retail = BR.NONE,
            forever = {
                world = { false, false },
                dungeon = { false, false },
                raid = { false, false },
                pvp = { false, false },
            },
        }),
        -- thornsRequest: absent - nil means off
        righteousFuryShow = BR.ByClient({ retail = BR.NONE, forever = "tank" }),
        mageArmorPreference = BR.ByClient({ retail = BR.NONE, forever = "mage" }),
        -- Per-text-item size override, as a percentage of the icon size. An
        -- absent key follows consumableTextScale.
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
            -- Forever druids keep Thorns on themselves while leveling in the open world.
            openWorld = BR.ByClient({ retail = false, forever = true }),
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
            -- Forever players use food, stones and poisons while leveling in the open world.
            openWorld = BR.ByClient({ retail = false, forever = true }),
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
                raid40 = true,
                raid20 = true,
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
            priority = 1,
        },
        presence = {
            position = { point = "CENTER", x = 0, y = 220 },
            useCustomAppearance = false,
            split = false,
            priority = 2,
        },
        targeted = {
            position = { point = "CENTER", x = 0, y = 180 },
            useCustomAppearance = false,
            split = false,
            priority = 3,
        },
        self = {
            position = { point = "CENTER", x = 0, y = 140 },
            useCustomAppearance = false,
            split = false,
            priority = 4,
        },
        pet = {
            position = { point = "CENTER", x = 0, y = 100 },
            useCustomAppearance = false,
            split = false,
            priority = 5,
        },
        consumable = {
            position = { point = "CENTER", x = 0, y = 60 },
            useCustomAppearance = false,
            split = false,
            priority = 6,
        },
        utility = {
            position = { point = "CENTER", x = 0, y = -60 },
            useCustomAppearance = false,
            split = false,
            priority = 9,
        },
        custom = {
            position = { point = "CENTER", x = 0, y = 20 },
            useCustomAppearance = false,
            split = false,
            priority = 7,
        },
        loadout = {
            position = { point = "CENTER", x = 0, y = -20 },
            useCustomAppearance = false,
            split = false,
            priority = 8,
        },
    },
}
