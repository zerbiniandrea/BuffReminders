local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

local L = BR.L

local floor = math.floor
local max = math.max
local AuraByIndex = BR.Secret.AuraByIndex
local AuraField = BR.Secret.AuraField
local Plain = BR.Secret.Plain
local UnitIsUnit = UnitIsUnit

local REPAIR_LABEL = L["Overlay.RepairLabel"]
local REAGENT_LABEL = L["Overlay.ReagentLabel"]
local AMMO_LABEL = L["Overlay.AmmoLabel"]
local REAGENTS_TEXT = L["Overlay.Reagents"]
local AMMO_TEXT = L["Overlay.Ammo"]
local AMMO_EQUIP_TEXT = L["Overlay.EquipAmmo"]

local _, playerClass = UnitClass("player")

-- Each export mirrors a retail export that shared code reads.

---@type DKRuneforge[]
BR.DK_RUNEFORGES = {}

---@return boolean
function BR.IsInDelve()
    return false
end

---@type string?
BR.CONTENT_GRID_DUNGEON_DESC = nil

BR.SHADOWFORM_SPELL_ID = 15473

BR.EATING_AURA_ICON = 134062

-- Sample icons for the consumable item display preview in the options.
BR.CONSUMABLE_PREVIEW_TEXTURES = {
    flask = { 134842, 134877, 134821 }, -- Titans, Distilled Wisdom, Supreme Power
    food = { 132804, 134020 }, -- Nightfin Soup, Smoked Desert Dumplings
    oil = 134727, -- Brilliant Wizard Oil
}

-- Forever items have no crafted quality, stat labels, Delve food or legacy tier.
BR.CONSUMABLE_FEATURES = { itemLabels = false, delveFood = false, legacyItems = false }

-- Support for this client is in development, so it shows the preview badge and notice.
BR.CLIENT_PREVIEW = true

-- Forever has no housing, scenarios or arenas, and all its dungeons have one difficulty.
-- The raid map holds the raid difficultyIDs that Forever raids use.
---@type InstanceContent
BR.INSTANCE_CONTENT = {
    contentTypes = { "openWorld", "dungeon", "raid", "pvp" },
    difficulties = {
        raid = { "raid40", "raid20" },
    },
    difficultyIDs = {
        raid = {
            [9] = "raid40",
            [186] = "raid40",
            [148] = "raid20",
            [185] = "raid20",
            [226] = "raid20",
        },
    },
    titles = {
        dungeon = L["Content.AnyDungeon"],
        pvp = L["Content.Battlegrounds"],
    },
    legacyLoot = false,
    keystones = false,
}

-- One poison column per hand. Each entry is the rank 1 spell of a poison type.
BR.DEFAULT_POISON_PREFERENCES = {
    mainHand = {
        { spellID = 8679, enabled = true }, -- Instant
        { spellID = 2823, enabled = true }, -- Deadly
        { spellID = 13219, enabled = true }, -- Wound
        { spellID = 3408, enabled = true }, -- Crippling
        { spellID = 5761, enabled = true }, -- Mind-numbing
    },
    offHand = {
        { spellID = 2823, enabled = true }, -- Deadly
        { spellID = 8679, enabled = true }, -- Instant
        { spellID = 13219, enabled = true }, -- Wound
        { spellID = 3408, enabled = true }, -- Crippling
        { spellID = 5761, enabled = true }, -- Mind-numbing
    },
}

---@type PoisonColumn[]
BR.POISON_COLUMNS = {
    { key = "mainHand", label = L["Options.PoisonMainHand"] },
    { key = "offHand", label = L["Options.PoisonOffHand"] },
}

BR.REPAIR_SOURCES = {
    mounts = {},
    items = {},
}

---@type PetSpells
BR.PET_SPELLS = {
    callPet = { 883 },
    demonSummons = { 688, 697, 712, 691 }, -- Imp, Voidwalker, Succubus, Felhunter
    demonChoices = { "imp", "voidwalker", "succubus", "felhunter" },
    -- Voidwalker first for solo play. Felhunter is learned at level 30, Imp at level 1.
    demonPreference = { "voidwalker", "felhunter", "imp", "succubus" },
    felDomination = 18708,
}

-- Food items list every food of every level that gives a food buff.
---@type table<string, table<number, ConsumableItemInfo|boolean>>
BR.CONSUMABLE_ITEMS = {
    food = {
        [724] = true, -- Goretusk Liver Pie
        [733] = true, -- Westfall Stew
        [787] = true, -- Slitherskin Mackerel
        [1017] = true, -- Seasoned Wolf Kabob
        [1082] = true, -- Redridge Goulash
        [2680] = true, -- Spiced Wolf Meat
        [2681] = true, -- Roasted Boar Meat
        [2682] = true, -- Cooked Crab Claw
        [2683] = true, -- Crab Cake
        [2684] = true, -- Coyote Steak
        [2685] = true, -- Succulent Pork Ribs
        [2687] = true, -- Dry Pork Ribs
        [2888] = true, -- Beer Basted Boar Ribs
        [3220] = true, -- Blood Sausage
        [3662] = true, -- Crocolisk Steak
        [3663] = true, -- Murloc Fin Soup
        [3664] = true, -- Crocolisk Gumbo
        [3665] = true, -- Curiously Tasty Omelet
        [3666] = true, -- Gooey Spider Cake
        [3726] = true, -- Big Bear Steak
        [3727] = true, -- Hot Lion Chops
        [3728] = true, -- Tasty Lion Steak
        [3729] = true, -- Soothing Turtle Bisque
        [4457] = true, -- Barbecued Buzzard Wing
        [4592] = true, -- Longjaw Mud Snapper
        [4593] = true, -- Bristle Whisker Catfish
        [4594] = true, -- Rockscale Cod
        [5095] = true, -- Rainbow Fin Albacore
        [5472] = true, -- Kaldorei Spider Kabob
        [5474] = true, -- Roasted Kodo Meat
        [5476] = true, -- Fillet of Frenzy
        [5477] = true, -- Strider Stew
        [5479] = true, -- Crispy Lizard Tail
        [5480] = true, -- Lean Venison
        [5527] = true, -- Goblin Deviled Clams
        [6038] = true, -- Giant Clam Scorcho
        [6290] = true, -- Brilliant Smallfish
        [6316] = true, -- Loch Frenzy Delight
        [6887] = true, -- Spotted Yellowtail
        [6888] = true, -- Herb Baked Egg
        [6890] = true, -- Smoked Bear Meat
        [7806] = true, -- Lollipop
        [7807] = true, -- Candy Bar
        [7808] = true, -- Chocolate Square
        [8364] = true, -- Mithril Head Trout
        [8957] = true, -- Spinefin Halibut
        [10841] = true, -- Goldthorn Tea
        [11584] = true, -- Cactus Apple Surprise
        [11950] = true, -- Windblossom Berries
        [12209] = true, -- Lean Wolf Steak
        [12210] = true, -- Roast Raptor
        [12212] = true, -- Jungle Stew
        [12213] = true, -- Carrion Surprise
        [12214] = true, -- Mystery Stew
        [12215] = true, -- Heavy Kodo Stew
        [12216] = true, -- Spiced Chili Crab
        [12217] = true, -- Dragonbreath Chili
        [12218] = true, -- Monster Omelet
        [12224] = true, -- Crispy Bat Wing
        [13810] = true, -- Blessed Sunfruit
        [13813] = true, -- Blessed Sunfruit Juice
        [13851] = true, -- Hot Wolf Ribs
        [13927] = true, -- Cooked Glossy Mightfish
        [13928] = true, -- Grilled Squid
        [13929] = true, -- Hot Smoked Bass
        [13930] = true, -- Filet of Redgill
        [13931] = true, -- Nightfin Soup
        [13932] = true, -- Poached Sunscale Salmon
        [13933] = true, -- Lobster Stew
        [13934] = true, -- Mightfish Steak
        [13935] = true, -- Baked Salmon
        [16971] = true, -- Clamlette Surprise
        [17197] = true, -- Gingerbread Cookie
        [17198] = true, -- Egg Nog
        [17222] = true, -- Spider Sausage
        [18045] = true, -- Tender Wolf Steak
        [18254] = true, -- Runn Tum Tuber Surprise
        [20074] = true, -- Heavy Crocolisk Stew
        [20452] = true, -- Smoked Desert Dumplings
        [21023] = true, -- Dirge's Kickin' Chimaerok Chops
        [21072] = true, -- Smoked Sagefish
        [21217] = true, -- Sagefish Delight
        [238638] = true, -- Filet o' Flank
        [249865] = true, -- Peace Tea
        [249866] = true, -- Royal Tea
        [249867] = true, -- Root Tea
        [249868] = true, -- Triage Tea
        [249869] = true, -- Sunny Tea
        [249870] = true, -- Sage's Tea
        [249871] = true, -- Venomous Smoothie
        [249872] = true, -- Slimy Smoothie
        [249873] = true, -- Mrrggl Smrrthle
        [249874] = true, -- Calcified Smoothie
        [249875] = true, -- Spicy Smoothie
        [249876] = true, -- Wicked Smoothie
        [250065] = true, -- Savory Stag Sliders
        [250066] = true, -- Soaring Pamplona
        [250067] = true, -- Bat Hachee
        [250068] = true, -- Savory Turtle Stew
        [250069] = true, -- Flank au Poivre
        [250070] = true, -- Bear Bruscitti
        [250071] = true, -- Steaming Stag Steak
        [250072] = true, -- Swiftstrike Steak
        [250073] = true, -- Raging Raptor Ribs
        [250074] = true, -- Bear Brisket
        [250075] = true, -- Prehistoric Pulled Raptor
        [250076] = true, -- Raptor Rouladen
        [250077] = true, -- Twice-Spiced Raptor Slice
        [250078] = true, -- Giant Scrambled Eggs
        [250079] = true, -- Tasty Raptor Bites
        [250080] = true, -- Breakfast Omelette
        [263509] = true, -- Skywall Souffle
        [263512] = true, -- Pincer Bites
        [267341] = true, -- Sweetpaw Jam
        [268912] = true, -- Expiring Crab Cake
        [268913] = true, -- Expiring Crocolisk Steak
        [274971] = true, -- Briny Seafood Stew
        [274976] = true, -- Plain Ol' Paletusk
        [286152] = true, -- Plated Armorfish
        [287973] = true, -- Tender Wolf Steak
        [287974] = true, -- Grilled Squid
    },
    -- Flask of Petrification is absent: a click must never petrify the player.
    flask = {
        [13510] = true, -- Flask of the Titans
        [13511] = true, -- Flask of Distilled Wisdom
        [13512] = true, -- Flask of Supreme Power
        [13513] = true, -- Flask of Chromatic Resistance
    },
    weapon = {
        -- Sharpening stones. Elemental and Consecrated fit any melee weapon.
        [2862] = { weaponClass = "edged" }, -- Rough Sharpening Stone
        [2863] = { weaponClass = "edged" }, -- Coarse Sharpening Stone
        [2871] = { weaponClass = "edged" }, -- Heavy Sharpening Stone
        [7964] = { weaponClass = "edged" }, -- Solid Sharpening Stone
        [12404] = { weaponClass = "edged" }, -- Dense Sharpening Stone
        [18262] = true, -- Elemental Sharpening Stone
        [23122] = true, -- Consecrated Sharpening Stone
        -- Weightstones
        [3239] = { weaponClass = "blunt" }, -- Rough Weightstone
        [3240] = { weaponClass = "blunt" }, -- Coarse Weightstone
        [3241] = { weaponClass = "blunt" }, -- Heavy Weightstone
        [7965] = { weaponClass = "blunt" }, -- Solid Weightstone
        [12643] = { weaponClass = "blunt" }, -- Dense Weightstone
        -- Oils
        [20744] = true, -- Minor Wizard Oil
        [20746] = true, -- Lesser Wizard Oil
        [20750] = true, -- Wizard Oil
        [20749] = true, -- Brilliant Wizard Oil
        [23123] = true, -- Blessed Wizard Oil
        [20745] = true, -- Minor Mana Oil
        [20747] = true, -- Lesser Mana Oil
        [20748] = true, -- Brilliant Mana Oil
        [3824] = true, -- Shadow Oil
        [3829] = true, -- Frost Oil
    },
}

-- Petrification is a short stun shield, not the flask that the player runs.
BR.UNREMEMBERED_FLASK_ITEMS = {
    [13506] = true, -- Flask of Petrification
}

-- Pet food type (ItemPetFood ID) -> the items of that type. Buff food is in the list, and
-- the feed click skips it. Quest items are absent.
-- stylua: ignore
local PET_FOOD_ITEMS = {
    [1] = {
        117, 723, 724, 729, 733, 769, 1015, 1017, 1080, 1081, 1082, 2287,
        2672, 2673, 2677, 2679, 2680, 2681, 2684, 2685, 2687, 2886, 2888, 2924,
        3173, 3220, 3404, 3662, 3664, 3665, 3666, 3667, 3712, 3726, 3727, 3728,
        3729, 3730, 3731, 3770, 3771, 4457, 4599, 5465, 5467, 5469, 5470, 5471,
        5472, 5473, 5474, 5477, 5478, 5479, 5480, 6888, 6890, 7097, 8952, 11444,
        12037, 12184, 12202, 12203, 12204, 12205, 12206, 12208, 12209, 12210, 12212, 12213,
        12214, 12215, 12216, 12217, 12218, 12224, 13851, 16971, 17119, 17222, 17407, 17408,
        18045, 18633, 18635, 19223, 19224, 19304, 19305, 19306, 19995, 20074, 20424, 20452,
        21023, 21235, 238637, 238638, 238639, 238641, 238642, 250065, 250066, 250067, 250068, 250069,
        250070, 250071, 250072, 250073, 250074, 250075, 250076, 250077, 250078, 250079, 250080, 252022,
        252029, 262433, 263509, 263512, 268913, 274976, 278117, 278118, 278121, 287963, 287973,
    },
    [2] = {
        787, 1326, 2608, 2674, 2675, 2682, 2683, 3663, 4592, 4593, 4594, 4603,
        4655, 5095, 5468, 5476, 5503, 5504, 5525, 5526, 5527, 6038, 6289, 6290,
        6291, 6292, 6294, 6295, 6299, 6303, 6308, 6309, 6310, 6311, 6316, 6317,
        6358, 6359, 6361, 6362, 6363, 6364, 6458, 6522, 6657, 6887, 7974, 8364,
        8365, 8957, 8959, 9681, 12238, 13422, 13546, 13754, 13755, 13756, 13757, 13758,
        13759, 13760, 13842, 13843, 13844, 13845, 13846, 13847, 13848, 13849, 13876, 13877,
        13878, 13879, 13880, 13882, 13883, 13884, 13885, 13886, 13887, 13888, 13889, 13893,
        13901, 13902, 13903, 13904, 13905, 13906, 13907, 13908, 13909, 13910, 13911, 13912,
        13913, 13914, 13915, 13916, 13917, 13927, 13928, 13929, 13930, 13931, 13932, 13933,
        13934, 13935, 16766, 18254, 18255, 19803, 19804, 19805, 19806, 19807, 19996, 21071,
        21072, 21153, 21217, 21238, 21552, 232436, 232438, 250081, 251524, 251525, 268912, 274971,
        286152, 287974,
    },
    [3] = {
        414, 422, 1707, 2070, 3927, 8932, 16167, 17406, 252023, 252030, 278569,
    },
    [4] = {
        1113, 1114, 1487, 4540, 4541, 4542, 4544, 4601, 5349, 8075, 8076, 8950,
        11109, 13724, 16166, 16169, 17344, 18632, 19060, 19061, 19062, 19301, 19696, 20031,
        20062, 20063, 20064, 20222, 20223, 20224, 20225, 20226, 20227, 20388, 20389, 20390,
        21215, 21236, 21254, 21537, 22895, 23160, 23175, 252026, 252028, 260623, 272053, 272054,
        272055, 278119, 287416,
    },
    [5] = {
        4604, 4605, 4606, 4607, 4608, 5569, 8948, 17747, 267474,
    },
    [6] = {
        4536, 4537, 4538, 4539, 4602, 4656, 5057, 8953, 11415, 11584, 11950, 11951,
        11952, 12763, 16168, 16170, 16171, 19994, 20516, 21030, 21031, 21033, 21240, 22324,
        23172, 249796, 251917, 252032, 260624, 260625, 260627, 260628, 278120, 278122,
    },
    [7] = {
        887, 2085, 3181, 3300, 4879, 8427, 252671,
    },
}

---@type table<number, number>
local PET_FOOD_TYPE = {}
for foodType, items in pairs(PET_FOOD_ITEMS) do
    for _, itemID in ipairs(items) do
        PET_FOOD_TYPE[itemID] = foodType
    end
end

-- Creature family -> pet food mask. Bit n - 1 is set if the family eats food type n.
local PET_DIETS = {
    [1] = 1, -- Wolf
    [2] = 3, -- Cat
    [3] = 1, -- Spider
    [4] = 63, -- Bear
    [5] = 63, -- Boar
    [6] = 3, -- Crocolisk
    [7] = 3, -- Carrion Bird
    [8] = 58, -- Crab
    [9] = 48, -- Gorilla
    [11] = 1, -- Raptor
    [12] = 52, -- Tallstrider
    [20] = 1, -- Scorpid
    [21] = 178, -- Turtle
    [24] = 48, -- Bat
    [25] = 33, -- Hyena
    [26] = 1, -- Bird of Prey
    [27] = 14, -- Wind Serpent
    [312] = 1, -- Core Hound
    [319] = 1, -- Fox
}

local FEED_PET = 6991

---@param diet number? Pet food mask, nil when the family is unknown
---@param foodType number
---@return boolean
local function PetEats(diet, foodType)
    return diet == nil or floor(diet / 2 ^ (foodType - 1)) % 2 == 1
end

---Bag food that the pet eats, highest item level first. Food closer to the pet level
---gives more happiness.
---@return number? itemID
local function FindPetFood()
    local _, familyID = UnitCreatureFamily("pet")
    familyID = Plain(familyID)
    local diet = type(familyID) == "number" and PET_DIETS[familyID] or nil
    local buffFood = BR.CONSUMABLE_ITEMS.food
    local bestID, bestLevel = nil, -1
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            local foodType = itemID and PET_FOOD_TYPE[itemID]
            if foodType and not buffFood[itemID] and PetEats(diet, foodType) then
                local level = select(4, C_Item.GetItemInfo(itemID)) or 0
                if level > bestLevel then
                    bestID, bestLevel = itemID, level
                end
            end
        end
    end
    return bestID
end

---If the Feed Pet cast fails, a /use line makes the hunter eat the food. So the macro
---names food only when Feed Pet and the global cooldown are ready.
---@return string
local function FeedPetMacro()
    local name = BR.GetSpellName(FEED_PET)
    if not name then
        return ""
    end
    local macro = "/cast " .. name
    -- C_Spell.GetSpellCooldown returns secret values when cooldowns are restricted.
    if BR.Restrictions.CooldownsRestricted() then
        return macro
    end
    local info = C_Spell.GetSpellCooldown(FEED_PET)
    local startTime = info and Plain(info.startTime)
    if startTime ~= 0 then
        return macro
    end
    local food = FindPetFood()
    return food and (macro .. "\n/use item:" .. food) or macro
end

---@type SelfBuff
local PET_HAPPINESS = {
    key = "petHappiness",
    name = L["Buff.PetHappiness"],
    class = "HUNTER",
    overlayText = L["Overlay.FeedPet"],
    icons = { textures = { 132165 } }, -- Feed Pet
    defaultEnabled = false, -- opt-in: a content pet still fights at full damage
    requiresSpellID = FEED_PET,
    castSpellID = FEED_PET,
    customCheck = function()
        local happiness = BR.BuffState.GetPetHappiness()
        return happiness ~= nil and happiness < 3 and not UnitIsDead("pet") or nil
    end,
    clickMacro = FeedPetMacro,
}

-- Demonic Sacrifice and its buffs: Burning Shadow, Fel Stamina, Touch of Fire, Fel Energy.
---@type PetSacrifice
local DEMONIC_SACRIFICE = { spellID = 18788, auraIDs = { 18789, 18790, 18791, 18792 } }

-- IsSpellKnown answers true only for the highest rank, so each list holds every rank.
local CREATE_HEALTHSTONE = { 11730, 11729, 5699, 6202, 6201 }
local CONJURE_MANA_GEM = { 10054, 10053, 3552, 759 } -- Ruby, Citrine, Jade, Agate
-- Shaman weapon imbues per setting value, highest rank first.
local SHAMAN_IMBUE_RANKS = {
    windfury = { 16362, 10486, 8235, 8232 },
    flametongue = { 16342, 16341, 16339, 8030, 8027, 8024 },
    rockbiter = { 16316, 16315, 16314, 10399, 8019, 8018, 8017 },
    frostbrand = { 16356, 16355, 10456, 8038, 8033 },
}
-- Frostbrand is cast only when the player picks it.
local SHAMAN_IMBUE_FALLBACK = { "windfury", "flametongue", "rockbiter" }
-- Each rank applies its own temporary enchant. 7566-7569 come from the rank
-- variants 461633-461636, which the addon detects but never casts.
local SHAMAN_IMBUE_ENCHANTS = {}
for _, enchantIDs in ipairs({
    { 29, 6, 1, 503, 1663, 683, 1664 }, -- Rockbiter Weapon
    { 5, 4, 3, 523, 1665, 1666 }, -- Flametongue Weapon
    { 2, 12, 524, 1667, 1668 }, -- Frostbrand Weapon
    { 283, 284, 525, 1669 }, -- Windfury Weapon
    { 7566, 7567, 7568, 7569 },
}) do
    for _, id in ipairs(enchantIDs) do
        SHAMAN_IMBUE_ENCHANTS[id] = true
    end
end
local SHAMAN_IMBUES = {}
for _, key in ipairs({ "rockbiter", "flametongue", "frostbrand", "windfury" }) do
    for _, id in ipairs(SHAMAN_IMBUE_RANKS[key]) do
        SHAMAN_IMBUES[#SHAMAN_IMBUES + 1] = id
    end
end

---@param spellIDs number[] Highest rank first
---@return number?
local function HighestKnownSpell(spellIDs)
    for _, id in ipairs(spellIDs) do
        if BR.StateHelpers.IsPlayerSpellCached(id) then
            return id
        end
    end
    return nil
end

-- The macro names the highest spell that the player knows.
---@param spellIDs number[] Highest rank first
---@return string
local function CastHighestKnownMacro(spellIDs)
    local id = HighestKnownSpell(spellIDs)
    return id and ("/cast " .. (BR.GetSpellName(id) or "")) or ""
end

---Highest known rank of the preferred imbue, else of the first known fallback imbue.
---@return number?
local function ShamanImbueCastID()
    local defaults = BR.profile.defaults
    local ranks = SHAMAN_IMBUE_RANKS[defaults and defaults.shamanImbue or "windfury"]
    local id = ranks and HighestKnownSpell(ranks)
    if id then
        return id
    end
    for _, key in ipairs(SHAMAN_IMBUE_FALLBACK) do
        id = HighestKnownSpell(SHAMAN_IMBUE_RANKS[key])
        if id then
            return id
        end
    end
    return nil
end

-- A poison sits in the imbue slot of a weapon, beside a stone or an oil in the temporary slot.
-- Poison items per type, highest rank first. The rank 1 spell names the type.
local POISON_ITEMS = {
    [8679] = { 8928, 8927, 8926, 6950, 6949, 6947 }, -- Instant Poison
    [2823] = { 20844, 8985, 8984, 2893, 2892 }, -- Deadly Poison
    [13219] = { 10922, 10921, 10920, 10918 }, -- Wound Poison
    [3408] = { 3776, 3775 }, -- Crippling Poison
    [5761] = { 9186, 6951, 5237 }, -- Mind-numbing Poison
}
local POISONS_SKILL = 2842
local POISON_HANDS = { { slot = 16, column = "mainHand" }, { slot = 17, column = "offHand" } }

---@param slot number 16 (main hand) or 17 (off hand)
---@return boolean
local function HandHoldsWeapon(slot)
    if slot == 17 then
        return BR.BuffState.HasOffHandWeapon()
    end
    local subclass = BR.BuffState.GetWeaponSubclass(16)
    return subclass ~= nil and subclass ~= 20 -- Enum.ItemWeaponSubclass.Fishingpole
end

---@param column string
---@return { spellID: number, enabled: boolean }[]
local function PoisonList(column)
    local prefs = BR.profile.roguePoisonPreferences
    local list = prefs and prefs[column]
    if not list or #list == 0 then
        list = BR.DEFAULT_POISON_PREFERENCES[column]
    end
    return list
end

---First enabled poison of the hand that the bags hold, as its highest rank item.
---@param column string
---@return number? itemID
---@return number? spellID rank 1 spell of the poison type
local function PickPoison(column)
    local GetItemCountCached = BR.StateHelpers.GetItemCountCached
    for _, entry in ipairs(PoisonList(column)) do
        local items = entry.enabled and POISON_ITEMS[entry.spellID]
        if items then
            for _, itemID in ipairs(items) do
                if GetItemCountCached(itemID) > 0 then
                    return itemID, entry.spellID
                end
            end
        end
    end
    return nil
end

---@param column string
---@return boolean
local function HasEnabledPoison(column)
    for _, entry in ipairs(PoisonList(column)) do
        if entry.enabled and POISON_ITEMS[entry.spellID] then
            return true
        end
    end
    return false
end

---First hand with a weapon, no imbue, and an enabled poison.
---@return { slot: number, column: string }?
local function HandMissingPoison()
    for _, hand in ipairs(POISON_HANDS) do
        if
            HandHoldsWeapon(hand.slot)
            and not BR.BuffState.GetWeaponImbue(hand.slot)
            and HasEnabledPoison(hand.column)
        then
            return hand
        end
    end
    return nil
end

---@return number? remaining seconds on the poison that expires first
local function PoisonRemaining()
    local soonest
    for _, hand in ipairs(POISON_HANDS) do
        if HandHoldsWeapon(hand.slot) then
            local id, remaining = BR.BuffState.GetWeaponImbue(hand.slot)
            if id and remaining and (not soonest or remaining < soonest) then
                soonest = remaining
            end
        end
    end
    return soonest
end

---Applies a poison to the first hand that misses one, else to the hand whose poison expires first.
---@return string
local function PoisonMacro()
    local hand = HandMissingPoison()
    if not hand then
        local soonest
        for _, h in ipairs(POISON_HANDS) do
            local id, remaining = BR.BuffState.GetWeaponImbue(h.slot)
            if HandHoldsWeapon(h.slot) and id and remaining and (not soonest or remaining < soonest) then
                hand, soonest = h, remaining
            end
        end
    end
    if not hand then
        return ""
    end
    local itemID = PickPoison(hand.column)
    return itemID and ("/use item:" .. itemID .. "\n/use " .. hand.slot) or ""
end

local NO_STANCE = BR.NO_STANCE

---@type StanceGrid
local WARRIOR_STANCE_GRID = {
    setting = "warriorStances",
    hint = L["BuffPanel.WarriorStance.Hint"],
    choices = {
        { key = "battle", spellIDs = { 2457 } },
        { key = "defensive", spellIDs = { 71 } },
        { key = "berserker", spellIDs = { 2458 } },
    },
}

-- Bear Form and Dire Bear Form are one choice, so either known spell counts.
---@type StanceGrid
local DRUID_FORM_GRID = {
    setting = "druidForms",
    hint = L["BuffPanel.DruidForm.Hint"],
    choices = {
        { key = "bear", spellIDs = { 9634, 5487 } },
        { key = "cat", spellIDs = { 768 } },
        { key = "moonkin", spellIDs = { 24858 } },
        { key = "caster", spellIDs = {}, label = L["BuffPanel.DruidForm.Caster"], iconSpellID = 5185 },
    },
}

---Highest known spell of a choice, NO_STANCE for the caster choice, or nil if unknown.
---@param choice StanceChoice
---@return number?
local function KnownChoiceSpell(choice)
    if #choice.spellIDs == 0 then
        return NO_STANCE
    end
    return HighestKnownSpell(choice.spellIDs)
end

---A choice counts only if the current content row allows it and the player knows it.
---@param grid StanceGrid
---@return StanceRule
local function GridStanceRule(grid)
    local allowedSet = {}
    return {
        grid = grid,
        -- The set is reused, so a caller must read it before the next call.
        allowed = function()
            wipe(allowedSet)
            local row = BR.StateHelpers.GetContentRow()
            local any = false
            for _, choice in ipairs(grid.choices) do
                local known = KnownChoiceSpell(choice)
                if known and BR.StateHelpers.IsContentChoiceAllowed(grid.setting, row, choice.key) then
                    any = true
                    allowedSet[known] = true
                    for _, id in ipairs(choice.spellIDs) do
                        allowedSet[id] = true
                    end
                end
            end
            return any and allowedSet or nil
        end,
        castID = function()
            local row = BR.StateHelpers.GetContentRow()
            for _, choice in ipairs(grid.choices) do
                local known = KnownChoiceSpell(choice)
                if known and BR.StateHelpers.IsContentChoiceAllowed(grid.setting, row, choice.key) then
                    return known
                end
            end
            return nil
        end,
    }
end

---@type table<string, StanceRule>
BR.STANCE_RULES = {
    WARRIOR = GridStanceRule(WARRIOR_STANCE_GRID),
    DRUID = GridStanceRule(DRUID_FORM_GRID),
}

---@param castID number? Stance spell, or NO_STANCE to cancel the current form
---@return string
local function StanceMacro(castID)
    if castID == NO_STANCE then
        return "/cancelform"
    end
    return castID and ("/cast " .. (BR.GetSpellName(castID) or "")) or ""
end

---@return boolean
local function RighteousFuryWanted()
    local defaults = BR.profile.defaults
    return (defaults ~= nil and defaults.righteousFuryShow == "always") or BR.StateHelpers.IsPlayerTank()
end

-- Ice Armor is the higher rank line of Frost Armor, so both are one choice. Highest rank first.
local ICE_ARMOR_IDS = { 10220, 10219, 7320, 7302, 7301, 7300, 168 }
local MAGE_ARMOR_IDS = { 22783, 22782, 6117 }
local ALL_MAGE_ARMOR_IDS = {}
for _, list in ipairs({ ICE_ARMOR_IDS, MAGE_ARMOR_IDS }) do
    for _, id in ipairs(list) do
        ALL_MAGE_ARMOR_IDS[#ALL_MAGE_ARMOR_IDS + 1] = id
    end
end

---Highest known rank of the preferred armor, else of the other armor.
---@return number?
local function PreferredMageArmor()
    local defaults = BR.profile.defaults
    local preferIce = defaults ~= nil and defaults.mageArmorPreference == "ice"
    local first, second = MAGE_ARMOR_IDS, ICE_ARMOR_IDS
    if preferIce then
        first, second = ICE_ARMOR_IDS, MAGE_ARMOR_IDS
    end
    return HighestKnownSpell(first) or HighestKnownSpell(second)
end

-- State remembers the tank that a role buff goes on. With no tank, the buff goes on the player.
---@param buffKey string
---@return fun(spellID: number?): string
local function TankOrSelfMacro(buffKey)
    return function(spellID)
        local name = BR.GetSpellName(spellID) or ""
        local tank = BR.TargetMemory.Get(buffKey)
        if tank then
            return "/cast [@" .. tank .. ",help,nodead] " .. name
        end
        return "/cast [@player] " .. name
    end
end

local SYMBOL_OF_KINGS = 21177

-- A player keeps one blessing from each paladin, and the same blessing from two
-- paladins does not stack. A Greater Blessing reaches every group member of the
-- target's class.
---@type StanceChoice[]
local PALADIN_BLESSINGS = {
    {
        key = "might",
        spellIDs = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
        groupCast = {
            { spellID = 25916, reagent = SYMBOL_OF_KINGS },
            { spellID = 25782, reagent = SYMBOL_OF_KINGS },
        },
    },
    {
        key = "wisdom",
        spellIDs = { 25290, 19854, 19853, 19852, 19850, 19742 },
        groupCast = {
            { spellID = 25918, reagent = SYMBOL_OF_KINGS },
            { spellID = 25894, reagent = SYMBOL_OF_KINGS },
        },
    },
    {
        key = "kings",
        spellIDs = { 20217 },
        groupCast = { { spellID = 25898, reagent = SYMBOL_OF_KINGS } },
    },
}

-- Every rank of a blessing covers the member, whoever cast it. The stored click
-- action is the first known ID in spellID, so the single-target ranks come first.
local ALL_BLESSING_IDS = {}
---@type table<string, StanceChoice>
local BLESSING_BY_KEY = {}
---@type table<number, StanceChoice> Every aura ID of a blessing -> the blessing
local BLESSING_BY_SPELL = {}
for _, choice in ipairs(PALADIN_BLESSINGS) do
    local auraIDs = {}
    for _, id in ipairs(choice.spellIDs) do
        auraIDs[#auraIDs + 1] = id
        ALL_BLESSING_IDS[#ALL_BLESSING_IDS + 1] = id
    end
    for _, rank in ipairs(choice.groupCast) do
        auraIDs[#auraIDs + 1] = rank.spellID
    end
    choice.auraIDs = auraIDs
    BLESSING_BY_KEY[choice.key] = choice
    for _, id in ipairs(auraIDs) do
        BLESSING_BY_SPELL[id] = choice
    end
end
for _, choice in ipairs(PALADIN_BLESSINGS) do
    for _, rank in ipairs(choice.groupCast) do
        ALL_BLESSING_IDS[#ALL_BLESSING_IDS + 1] = rank.spellID
    end
end

---@type table<string, StanceChoice[]>
local knownBlessingsByClass = {}

---The blessings of the class list that the player knows, in priority order.
---The list is reused, so a caller must read it before the next call for the class.
---@param class string
---@return StanceChoice[]
local function KnownBlessingsForClass(class)
    local list = knownBlessingsByClass[class]
    if list then
        wipe(list)
    else
        list = {}
        knownBlessingsByClass[class] = list
    end
    local defaults = BR.profile.defaults
    local byClass = defaults and defaults.paladinBlessingsByClass
    local order = type(byClass) == "table" and byClass[class]
    if type(order) ~= "table" then
        return list
    end
    for i = 1, #PALADIN_BLESSINGS do
        local choice = BLESSING_BY_KEY[order[i]]
        if choice and HighestKnownSpell(choice.spellIDs) then
            local listed = false
            for j = 1, #list do
                listed = listed or list[j] == choice
            end
            if not listed then
                list[#list + 1] = choice
            end
        end
    end
    return list
end

---@type ClassChoiceGrid
local PALADIN_BLESSING_GRID = {
    setting = "paladinBlessingsByClass",
    choices = PALADIN_BLESSINGS,
    rows = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN" },
    slots = 3,
    clusterEnds = { ROGUE = true, HUNTER = true },
    forClass = KnownBlessingsForClass,
    castID = function(choice)
        return HighestKnownSpell(choice.spellIDs)
    end,
}

---@param order any
---@return StanceChoice?
local function FirstBlessing(order)
    if type(order) ~= "table" then
        return nil
    end
    for i = 1, #PALADIN_BLESSINGS do
        local choice = order[i] and BLESSING_BY_KEY[order[i]]
        if choice then
            return choice
        end
    end
    return nil
end

---The blessing that the player asks for: the first one of the class list in the
---options grid. A missing list uses the default list. An empty list asks for none.
---@return number? spellID
local function RequestedBlessing()
    local defaults = BR.profile.defaults
    local byClass = defaults and defaults.paladinBlessingsByClass
    local order = type(byClass) == "table" and byClass[playerClass]
    if order == nil or order == false then
        order = BR.defaults.defaults.paladinBlessingsByClass[playerClass]
    end
    local choice = FirstBlessing(order)
    return choice and choice.spellIDs[1]
end

-- A unit keeps one aura of each type, whoever casts it. A resistance aura reaches the
-- whole raid. The other auras reach only the party.
---@type ChoiceOrderGrid
local PALADIN_AURA_GRID = {
    setting = "paladinAuraOrder",
    choices = {
        { key = "devotion", spellIDs = { 10293, 10292, 1032, 10291, 643, 10290, 465 } },
        { key = "retribution", spellIDs = { 10301, 10300, 10299, 10298, 7294 } },
        { key = "concentration", spellIDs = { 19746 } },
        { key = "shadowResistance", spellIDs = { 19896, 19895, 19876 }, resistance = true },
        { key = "frostResistance", spellIDs = { 19898, 19897, 19888 }, resistance = true },
        { key = "fireResistance", spellIDs = { 19900, 19899, 19891 }, resistance = true },
        { key = "sanctity", spellIDs = { 20218 } },
    },
    rows = { "world", "dungeon", "raid", "pvp" },
    slots = 2,
    castID = function(choice)
        return HighestKnownSpell(choice.spellIDs)
    end,
}
local PALADIN_AURA_CHOICES = PALADIN_AURA_GRID.choices
---@type table<number, integer>
local PALADIN_AURA_TYPE = {}
---@type table<string, integer>
local PALADIN_AURA_TYPE_BY_KEY = {}
local ALL_PALADIN_AURA_IDS = {}
for auraType, choice in ipairs(PALADIN_AURA_CHOICES) do
    PALADIN_AURA_TYPE_BY_KEY[choice.key] = auraType
    for _, id in ipairs(choice.spellIDs) do
        PALADIN_AURA_TYPE[id] = auraType
        ALL_PALADIN_AURA_IDS[#ALL_PALADIN_AURA_IDS + 1] = id
    end
end

local UnitGUID = UnitGUID
local IsInRaid = IsInRaid
local IsGUIDInGroup = IsGUIDInGroup
local UnitTokenFromGUID = UnitTokenFromGUID
local UnitInSubgroup = UnitInSubgroup

-- The scan reads auras only out of combat. An entry stays while its paladin is out
-- of range or the player is in combat, so a taken aura does not flip back and forth.
---@type table<string, integer> GUID of another paladin -> the aura type that the paladin gives the player
local otherPaladinAuras = {}

---Forget each paladin who left the group. In a raid, a party aura reaches only the
---subgroup of its caster.
local function PruneOtherPaladinAuras()
    local inRaid = IsInRaid()
    for guid, auraType in pairs(otherPaladinAuras) do
        local keep = Plain(IsGUIDInGroup(guid)) ~= false
        if keep and inRaid and not PALADIN_AURA_CHOICES[auraType].resistance then
            local unit = Plain(UnitTokenFromGUID(guid))
            keep = not unit or Plain(UnitInSubgroup(unit)) ~= false
        end
        if not keep then
            otherPaladinAuras[guid] = nil
        end
    end
end

---@param auraType integer
---@return boolean
local function IsAuraTypeTaken(auraType)
    for _, other in pairs(otherPaladinAuras) do
        if other == auraType then
            return true
        end
    end
    return false
end

---The aura that the player runs: the first choice of the content row list that the
---player knows and that no other paladin gives. nil when no choice qualifies.
---@return integer? auraType
---@return number? castID
local function WantedPaladinAura()
    local defaults = BR.profile.defaults
    local byRow = defaults and defaults.paladinAuraOrder
    local order = type(byRow) == "table" and byRow[BR.StateHelpers.GetContentRow()]
    if type(order) ~= "table" then
        return nil
    end
    for i = 1, PALADIN_AURA_GRID.slots do
        local auraType = PALADIN_AURA_TYPE_BY_KEY[order[i]]
        local castID = auraType and HighestKnownSpell(PALADIN_AURA_CHOICES[auraType].spellIDs)
        if castID and not IsAuraTypeTaken(auraType) then
            return auraType, castID
        end
    end
    return nil
end

local NO_AURA_TEXT = L["Overlay.NoAura"]
local WRONG_AURA_TEXT = L["Overlay.WrongAura"]
local DUPLICATE_TEXT = L["Overlay.Duplicate"]

---@type table<integer, true>
local ownAuraTypes = {}
---@type table<integer, true>
local foreignAuraTypes = {}

-- Only for use out of combat. In a restricted context, the enumeration finds no aura.
local function ScanPlayerAuraTypes()
    wipe(ownAuraTypes)
    wipe(foreignAuraTypes)
    local i = 1
    local aura = AuraByIndex("player", i, "HELPFUL")
    while aura do
        local auraType = PALADIN_AURA_TYPE[AuraField(aura, "spellId")]
        if auraType then
            local source = AuraField(aura, "sourceUnit")
            if source and Plain(UnitIsUnit(source, "player")) == true then
                ownAuraTypes[auraType] = true
            else
                foreignAuraTypes[auraType] = true
                local guid = source and Plain(UnitGUID(source))
                if guid then
                    otherPaladinAuras[guid] = auraType
                end
            end
        end
        i = i + 1
        aura = AuraByIndex("player", i, "HELPFUL")
    end
    PruneOtherPaladinAuras()
end

---@return boolean anyKnown The player knows an aura
---@return boolean allOnBar Each known aura type has a slot on the stance bar
local function KnownAurasOnStanceBar()
    local bar = BR.BuffState.GetStanceBarSpells()
    local anyKnown, allOnBar = false, true
    for _, choice in ipairs(PALADIN_AURA_CHOICES) do
        if HighestKnownSpell(choice.spellIDs) then
            anyKnown = true
            local onBar = false
            for _, id in ipairs(choice.spellIDs) do
                onBar = onBar or bar[id] == true
            end
            allOnBar = allOnBar and onBar
        end
    end
    return anyKnown, allOnBar
end

---Overlay text for the aura reminder of a paladin, or nil when the own aura is fine
---or unknown. The stance bar shows the active aura also in combat. Out of combat, an
---own aura instance stands in for an aura with no stance bar slot. A running
---resistance aura counts as a choice for the current boss.
---@param isAuraRestricted boolean
---@return string?
---@return boolean? noClick
local function CheckOwnPaladinAura(isAuraRestricted)
    local stanceID, unstanced = BR.BuffState.GetActiveStance()
    if not stanceID and not unstanced then
        return nil
    end
    local anyKnown, allOnBar = KnownAurasOnStanceBar()
    if not anyKnown then
        return nil
    end
    local runType = stanceID and PALADIN_AURA_TYPE[stanceID]
    local givenByOther = false
    if isAuraRestricted or BR.GameContext.IsInCombat() then
        if not runType then
            return allOnBar and NO_AURA_TEXT or nil
        end
    else
        ScanPlayerAuraTypes()
        runType = runType or next(ownAuraTypes)
        if not runType then
            return NO_AURA_TEXT
        end
        givenByOther = foreignAuraTypes[runType] == true and not ownAuraTypes[runType]
    end
    -- The scan marks each aura of another paladin as taken, so no paladin gives the wanted aura.
    local wantedType = WantedPaladinAura()
    if runType == wantedType then
        return nil
    end
    if givenByOther then
        if wantedType then
            return WRONG_AURA_TEXT
        end
        return DUPLICATE_TEXT, true
    end
    if not wantedType or PALADIN_AURA_CHOICES[runType].resistance then
        return nil
    end
    return WRONG_AURA_TEXT
end

---@class ForeverReagent
---@field item number
---@field icon number
---@field class ClassName
---@field spells number[] Spells that consume the reagent

-- Vendor reagents only. A reagent counts only while the player knows one of its spells,
-- so a rank-bound reagent lists only its own rank.
---@type ForeverReagent[]
local REAGENTS = {
    { item = 17020, icon = 133848, class = "MAGE", spells = { 23028 } }, -- Arcane Powder
    -- Rune of Teleportation
    { item = 17031, icon = 134419, class = "MAGE", spells = { 3561, 3562, 3563, 3565, 3566, 3567, 1297659 } },
    -- Rune of Portals
    { item = 17032, icon = 134421, class = "MAGE", spells = { 10059, 11416, 11417, 11418, 11419, 11420 } },
    { item = 17028, icon = 133752, class = "PRIEST", spells = { 21562 } }, -- Holy Candle
    { item = 17029, icon = 133751, class = "PRIEST", spells = { 21564, 27681, 27683 } }, -- Sacred Candle
    { item = 17021, icon = 133749, class = "DRUID", spells = { 21849 } }, -- Wild Berries
    { item = 17026, icon = 134412, class = "DRUID", spells = { 21850 } }, -- Wild Thornroot
    { item = 17034, icon = 133944, class = "DRUID", spells = { 20484 } }, -- Maple Seed
    { item = 17035, icon = 133944, class = "DRUID", spells = { 20739 } }, -- Stranglethorn Seed
    { item = 17036, icon = 133944, class = "DRUID", spells = { 20742 } }, -- Ashwood Seed
    { item = 17037, icon = 133944, class = "DRUID", spells = { 20747 } }, -- Hornbeam Seed
    { item = 17038, icon = 133944, class = "DRUID", spells = { 20748 } }, -- Ironwood Seed
    -- Symbol of Kings
    { item = 21177, icon = 134471, class = "PALADIN", spells = { 25782, 25916, 25894, 25918, 25898 } },
    { item = 17030, icon = 133439, class = "SHAMAN", spells = { 20608 } }, -- Ankh
    { item = 5140, icon = 134387, class = "ROGUE", spells = { 1856, 1857, 27617, 457437, 1285372 } }, -- Flash Powder
}

---@type ForeverReagent[]
local PLAYER_REAGENTS = {}
for _, reagent in ipairs(REAGENTS) do
    if reagent.class == playerClass then
        PLAYER_REAGENTS[#PLAYER_REAGENTS + 1] = reagent
    end
end

---Reagent with the lowest count among those for known spells. Ties go to the first in list order.
---@return ForeverReagent?
---@return number? count
local function LowestReagent()
    local lowest, lowestCount
    for _, reagent in ipairs(PLAYER_REAGENTS) do
        if HighestKnownSpell(reagent.spells) then
            local count = BR.StateHelpers.GetItemCountCached(reagent.item)
            if not lowestCount or count < lowestCount then
                lowest, lowestCount = reagent, count
            end
        end
    end
    return lowest, lowestCount
end

local AMMO_ICON_ARROW = 132382
local AMMO_ICON_BULLET = 132384
-- Arrows and bullets stack to 200 on Forever.
local AMMO_STACK_SIZE = 200

-- Ranged weapon subclass (Enum.ItemWeaponSubclass) to its ammo items.
---@type table<number, number[]>
local AMMO_BY_WEAPON = {}
do
    -- Every arrow and bullet in the item data, without test, deprecated and creature items.
    local arrows = { 2512, 2515, 3030, 3043, 3464, 9399, 10579, 11285, 12654, 18042, 19316, 223648, 231806, 274387 }
    local bullets = {
        2516,
        2519,
        3033,
        3465,
        4960,
        5568,
        8067,
        8068,
        8069,
        10512,
        10513,
        11284,
        11630,
        13377,
        15997,
        19317,
        231807,
        235699,
        274388,
    }
    AMMO_BY_WEAPON[2] = arrows -- Bow
    AMMO_BY_WEAPON[18] = arrows -- Crossbow
    AMMO_BY_WEAPON[3] = bullets -- Gun
end

-- The client can lack the ranged slot, so the main hand is the fallback.
---@return number? subclassID A ranged weapon that fires ammo
local function AmmoWeaponSubclass()
    local subclass = INVSLOT_RANGED and BR.BuffState.GetWeaponSubclass(INVSLOT_RANGED)
    if not (subclass and AMMO_BY_WEAPON[subclass]) then
        subclass = BR.BuffState.GetWeaponSubclass(16)
    end
    return subclass and AMMO_BY_WEAPON[subclass] and subclass or nil
end

---Count of the ammo that the weapon can fire.
---@param subclass number
---@return number
local function AmmoCount(subclass)
    local getCount = BR.StateHelpers.GetItemCountCached
    local total = 0
    for _, itemID in ipairs(AMMO_BY_WEAPON[subclass]) do
        total = total + getCount(itemID)
    end
    return total
end

---Shots left before the weapon stops firing: the game fires only the equipped ammo type
---and never swaps to another one. A client without an ammo slot fires any matching ammo.
---@param subclass number
---@return number shots
---@return number total All matching ammo in the bags
local function AmmoShots(subclass)
    local total = AmmoCount(subclass)
    if not INVSLOT_AMMO then
        return total, total
    end
    local itemID, count = BR.BuffState.GetEquippedAmmo()
    if itemID then
        for _, id in ipairs(AMMO_BY_WEAPON[subclass]) do
            if id == itemID then
                return count, total
            end
        end
    end
    return 0, total
end

-- Hunters fire ammo all the time; other classes only pull with it.
---@return number threshold In ammo, not stacks
local function AmmoThreshold()
    local defaults = BR.profile.defaults
    if playerClass == "HUNTER" then
        return (defaults and defaults.ammoThresholdStacks or 1) * AMMO_STACK_SIZE
    end
    return defaults and defaults.ammoThresholdShots or 20
end

local BATTLE_SHOUT = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 }

-- Every rank of a raid buff, the group version included.
local RAID_BUFF_IDS = {
    intellect = { 10157, 10156, 1461, 1460, 1459, 23028 },
    spirit = { 27841, 14819, 14818, 14752, 27681 },
    versatility = { 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 },
    stamina = { 10938, 10937, 2791, 1245, 1244, 1243, 21564, 21562 },
}

-- Rage drains between fights, so the reminder shows only while the shout is castable.
-- The usable check includes talents that change the rage cost.
---@return boolean
local function BattleShoutReady()
    if BR.GameContext.IsInCombat() or BR.BuffState.IsRestricted() then
        return false
    end
    for _, id in ipairs(BATTLE_SHOUT) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            return false
        end
    end
    local castID = HighestKnownSpell(BATTLE_SHOUT)
    return castID ~= nil and BR.BuffState.IsSpellUsable(castID)
end

-- Drive-by buffs: the single-target ranks that can buff another player, with the
-- SpellLevel of each rank from the SpellLevels DB2 table. A rank lands only on a
-- target whose level is at least the rank level minus levelSpan.
local DRIVE_BY_RANKS = {
    { 10157, 56 }, -- Arcane Intellect
    { 10156, 42 },
    { 1461, 28 },
    { 1460, 14 },
    { 1459, 1 },
    { 9885, 60 }, -- Mark of the Wild
    { 9884, 50 },
    { 8907, 40 },
    { 5234, 30 },
    { 6756, 20 },
    { 5232, 10 },
    { 1126, 1 },
    { 10938, 60 }, -- Power Word: Fortitude
    { 10937, 48 },
    { 2791, 36 },
    { 1245, 24 },
    { 1244, 12 },
    { 1243, 1 },
    { 27841, 60 }, -- Divine Spirit
    { 14819, 50 },
    { 14818, 40 },
    { 14752, 30 },
    { 25291, 60 }, -- Blessing of Might
    { 19838, 52 },
    { 19837, 42 },
    { 19836, 32 },
    { 19835, 22 },
    { 19834, 12 },
    { 19740, 4 },
    { 25290, 60 }, -- Blessing of Wisdom
    { 19854, 54 },
    { 19853, 44 },
    { 19852, 34 },
    { 19850, 24 },
    { 19742, 14 },
    { 20217, 20 }, -- Blessing of Kings
}
local DRIVE_BY_SPELLS = {}
---@type table<number, number>
local DRIVE_BY_RANK_LEVELS = {}
for i, rank in ipairs(DRIVE_BY_RANKS) do
    DRIVE_BY_SPELLS[i] = rank[1]
    DRIVE_BY_RANK_LEVELS[rank[1]] = rank[2]
end

---@class DriveByData
---@field levelSpan number
---@field rankLevels table<number, number> Spell ID of a single-target rank -> spell level

-- Only code of this client reads this export, so retail has no mirror.
---@type DriveByData
BR.DRIVE_BY = { levelSpan = 10, rankLevels = DRIVE_BY_RANK_LEVELS }

---A single-target blessing rank that the level of the unit accepts.
---@param spellID number
---@param unit string
---@return number
local function FitBlessingRank(spellID, unit)
    local choice = BLESSING_BY_SPELL[spellID]
    local pickRank = BR.DriveBy and BR.DriveBy.PickRank
    if not choice or not pickRank or not DRIVE_BY_RANK_LEVELS[spellID] or unit == "player" then
        return spellID
    end
    return pickRank(choice.spellIDs, BR.Secret.Plain(UnitLevel(unit)) or -1) or spellID
end

---@param def RaidBuff
---@return number? spellID
---@return string? unit
local function BlessingPick(def)
    local spellID, unit = BR.BuffState.GetGroupCastSpellID(def)
    if spellID then
        return spellID, unit or "player"
    end
    spellID, unit = BR.BuffState.GetChoiceCast(def)
    if not spellID then
        return nil
    end
    unit = unit or "player"
    return FitBlessingRank(spellID, unit), unit
end

local otherBlessings = {}

---@param unit string
---@param auraIDs number[]
---@return boolean
local function UnitHasAnyAura(unit, auraIDs)
    for _, id in ipairs(auraIDs) do
        if C_UnitAuras.GetUnitAuraBySpellID(unit, id) then
            return true
        end
    end
    return false
end

---Every known blessing except the one that the main click casts and the ones that
---the unit has from any paladin. The class lists do not apply, so the row can
---override them. A blessing needs a rank that the level of the unit accepts.
---@param unit string
---@param spellID number
---@return number[][]
local function OtherBlessings(_, unit, spellID)
    wipe(otherBlessings)
    local main = BLESSING_BY_SPELL[spellID]
    local pickRank = BR.DriveBy and BR.DriveBy.PickRank
    local level = BR.Secret.Plain(UnitLevel(unit)) or -1
    for _, choice in ipairs(PALADIN_BLESSINGS) do
        local castID
        if pickRank then
            castID = pickRank(choice.spellIDs, level)
        else
            castID = HighestKnownSpell(choice.spellIDs)
        end
        if choice ~= main and castID and not UnitHasAnyAura(unit, choice.auraIDs) then
            otherBlessings[#otherBlessings + 1] = choice.spellIDs
        end
    end
    return otherBlessings
end

---@type SubChoiceRow
local BLESSING_ROW = {
    pick = BlessingPick,
    others = OtherBlessings,
}

---@type SubChoiceRow
local DRIVE_BY_ROW = {
    pick = function()
        local spellID = BR.DriveBy.Pick()
        if spellID then
            return spellID, "target"
        end
        return nil
    end,
    others = function(_, _, spellID)
        return BR.DriveBy.Others(spellID)
    end,
}

local SLEEPING_BAG = {
    itemID = 211527, -- Cozy Sleeping Bag
    auraID = 429959, -- Well-Rested
    restingID = 1331671, -- Resting, while the player lies in the bag
    maxStacks = 3,
    stackSeconds = 60,
}

---@return boolean
local function IsRestingInBag()
    return C_UnitAuras.GetUnitAuraBySpellID("player", SLEEPING_BAG.restingID) ~= nil
end
BR.IsRestingInBag = IsRestingInBag

-- The Resting aura has no duration, so the rest starts when the addon first sees it.
local restInstanceID, restStartedAt

---GetTime()-based moment of the full Well-Rested stack, while the player rests in the bag.
---@return number? endsAt nil when the player is not in the bag or has all the stacks
---@return number? sweepSeconds
---@return string? stacksText
local function SleepingBagRestEnd()
    local GetPlayerAura = C_UnitAuras.GetUnitAuraBySpellID
    local resting = GetPlayerAura("player", SLEEPING_BAG.restingID)
    if not resting then
        restInstanceID = nil
        return nil
    end
    if resting.auraInstanceID ~= restInstanceID then
        restInstanceID = resting.auraInstanceID
        restStartedAt = GetTime()
    end
    local lastStackAt = restStartedAt
    local stacks = 0
    local rested = GetPlayerAura("player", SLEEPING_BAG.auraID)
    if rested then
        stacks = max(rested.applications or 0, 1)
        -- Each stack refreshes the duration, so the aura start is the time of the last stack.
        if rested.duration and rested.duration > 0 then
            lastStackAt = max(lastStackAt, rested.expirationTime - rested.duration)
        end
    end
    if stacks >= SLEEPING_BAG.maxStacks then
        return nil
    end
    local fullSeconds = SLEEPING_BAG.maxStacks * SLEEPING_BAG.stackSeconds
    local endsAt = lastStackAt + (SLEEPING_BAG.maxStacks - stacks) * SLEEPING_BAG.stackSeconds
    return endsAt, fullSeconds, stacks .. "/" .. SLEEPING_BAG.maxStacks
end

local CAMP = {
    benefitsID = 1229741, -- Camp Benefits
    nearbyID = 1283391, -- Campfire Nearby
    countdownIDs = { 1229739, 1289723 }, -- Welcoming Campfire, while the player sits or crafts
    -- Best tier first. Each kit needs a Cooking rank, and all kits share one cooldown.
    kits = { 279974, 279961, 279981 }, -- Expert, Journeyman, Basic Campfire Kit
}
local CAMP_SIT_TEXT = L["Overlay.CampSit"]
local CAMP_KIT_TEXT = L["Overlay.CampKit"]
-- The emote token works in every client language. The /sit command is localized.
local CAMP_SIT_MACRO = '/run DoEmote("SIT")'
local CAMP_KIT_MACROS = {}
local CAMP_KIT_ICONS = {}
for _, itemID in ipairs(CAMP.kits) do
    CAMP_KIT_MACROS[itemID] = "/use item:" .. itemID
    CAMP_KIT_ICONS[itemID] = C_Item.GetItemIconByID(itemID)
end

---@class CampFeature
---@field itemIDs number[] Highest tier first. A higher tier also gives the buff of its tier 1 feature
---@field conflict? number[] Aura IDs of the class buff that does not stack with the feature buff

-- The placeable features that give a buff to players who sit nearby. A feature needs
-- a campfire nearby, and all features share one cooldown.
---@type CampFeature[]
local CAMP_FEATURES = {
    -- Alchemy Laboratory, Fermenter, Mana Well
    { itemIDs = { 279990, 279970, 279956 }, conflict = BLESSING_BY_KEY.wisdom.auraIDs },
    -- Master Forge, Anvil, Sharpening Wheel. Strength of Earth Totem ranks 5 to 1
    { itemIDs = { 279955, 279988, 279944 }, conflict = { 25362, 10441, 8163, 8162, 8076 } },
    -- Arcane Forge, Arcane Salvager, Enchanted Lute
    { itemIDs = { 279987, 279985, 279976 }, conflict = RAID_BUFF_IDS.versatility },
    -- Plague Doctor's Laboratory, Toxin Study, First Aid Kit
    { itemIDs = { 279951, 279940, 279968 }, conflict = RAID_BUFF_IDS.stamina },
    -- Fishing Hut, Fishing Rack, Fish Bowl
    { itemIDs = { 279966, 279965, 279967 }, conflict = BLESSING_BY_KEY.kings.auraIDs },
    -- Seed Hybridizer, Greenhouse, Incense Candle
    { itemIDs = { 279947, 279964, 279962 }, conflict = RAID_BUFF_IDS.intellect },
    -- Molten Foundry, Rock Garden, Lodestone
    { itemIDs = { 279952, 279948, 279960 }, conflict = BLESSING_BY_KEY.might.auraIDs },
    -- Field Guide, Camp Chair. Moonkin Aura
    { itemIDs = { 279969, 279979 }, conflict = { 24907 } },
    -- Loom, Spinning Wheel, Faction Banner (Horde, Alliance)
    { itemIDs = { 279959, 279943, 279972, 279973 }, conflict = RAID_BUFF_IDS.spirit },
    -- Sewing Machine, Tanning Rack, Camp Tent
    { itemIDs = { 279945, 279941, 279978 } },
}
---@type table<number, SubChoiceItem>
local CAMP_FEATURE_CHOICES = {}
for _, feature in ipairs(CAMP_FEATURES) do
    for _, itemID in ipairs(feature.itemIDs) do
        CAMP_FEATURE_CHOICES[itemID] = { itemID = itemID }
    end
end

---@return "sit"|"camp"|nil stage
---@return number? kitID The kit that the click uses at the camp stage
local function ComputeCampStage()
    local GetPlayerAura = C_UnitAuras.GetUnitAuraBySpellID
    if GetPlayerAura("player", CAMP.benefitsID) then
        return nil
    end
    if GetPlayerAura("player", CAMP.nearbyID) then
        for _, spellID in ipairs(CAMP.countdownIDs) do
            if GetPlayerAura("player", spellID) then
                return nil
            end
        end
        return "sit"
    end
    local defaults = BR.profile.defaults
    if defaults and defaults.campLightFire == false then
        return nil
    end
    -- IsUsableItem also answers false indoors, so a cached answer goes stale on the way out.
    local kitID
    for _, itemID in ipairs(CAMP.kits) do
        if BR.StateHelpers.GetItemCountCached(itemID) > 0 and C_Item.IsUsableItem(itemID) then
            kitID = itemID
            break
        end
    end
    if not kitID or not BR.BuffState.IsItemOffCooldown(kitID) then
        return nil
    end
    -- A campfire alone gives no benefit: the benefits come from the features placed near it.
    for itemID in pairs(CAMP_FEATURE_CHOICES) do
        if BR.StateHelpers.GetItemCountCached(itemID) > 0 then
            return "camp", kitID
        end
    end
    return nil
end

-- One refresh asks for the stage from several callbacks in the same frame.
local campStageAt, campStage, campKitID
---@return "sit"|"camp"|nil stage
---@return number? kitID
local function CampStage()
    local now = GetTime()
    if campStageAt ~= now then
        campStageAt = now
        campStage, campKitID = ComputeCampStage()
    end
    return campStage, campKitID
end

local campChoices = {}

---The carried camp features, while the player can place one. A feature whose buff
---the player already has from a class buff goes last.
---@return SubChoiceItem[]
local function CampFeatureChoices()
    wipe(campChoices)
    if CampStage() ~= "sit" then
        return campChoices
    end
    local GetItemCount = BR.StateHelpers.GetItemCountCached
    local covered = 0
    for _, feature in ipairs(CAMP_FEATURES) do
        local last = feature.conflict ~= nil and UnitHasAnyAura("player", feature.conflict)
        for _, itemID in ipairs(feature.itemIDs) do
            if GetItemCount(itemID) > 0 then
                local choice = CAMP_FEATURE_CHOICES[itemID]
                if last then
                    covered = covered + 1
                    tinsert(campChoices, choice)
                else
                    tinsert(campChoices, #campChoices - covered + 1, choice)
                end
            end
        end
    end
    if campChoices[1] and not BR.BuffState.IsItemOffCooldown(campChoices[1].itemID) then
        wipe(campChoices)
    end
    return campChoices
end

---@type SubChoiceRow
local CAMP_ROW = {
    pick = function()
        if CampStage() == "sit" then
            return CAMP.benefitsID, "player"
        end
        return nil
    end,
    others = CampFeatureChoices,
}

---@alias TrackingKind "gathering"|"creature"

---@class TrackingSpell
---@field spellID number
---@field kind TrackingKind
---@field form? number Stance spell that the cast needs. The game ends the tracking when the form ends

-- Minimap tracking spells, in the order of the fallback pick. The game allows one active tracking.
---@type TrackingSpell[]
BR.TRACKING_SPELLS = {
    { spellID = 2383, kind = "gathering" }, -- Find Herbs
    { spellID = 2580, kind = "gathering" }, -- Find Minerals
    { spellID = 2481, kind = "gathering" }, -- Find Treasure
    { spellID = 1494, kind = "creature" }, -- Track Beasts
    { spellID = 19883, kind = "creature" }, -- Track Humanoids
    { spellID = 19884, kind = "creature" }, -- Track Undead
    { spellID = 19878, kind = "creature" }, -- Track Demons
    { spellID = 19880, kind = "creature" }, -- Track Elementals
    { spellID = 19882, kind = "creature" }, -- Track Giants
    { spellID = 19879, kind = "creature" }, -- Track Dragonkin
    { spellID = 19885, kind = "creature" }, -- Track Hidden
    { spellID = 5225, kind = "creature", form = 768 }, -- Track Humanoids (Druid), Cat Form
    { spellID = 5502, kind = "creature" }, -- Sense Undead
    { spellID = 5500, kind = "creature" }, -- Sense Demons
}

---@type number[]
local TRACKING_SPELL_IDS = {}
for i, spell in ipairs(BR.TRACKING_SPELLS) do
    TRACKING_SPELL_IDS[i] = spell.spellID
end

---@type SubChoiceRow
local TRACKING_ROW = {
    pick = function()
        local spellID = BR.Tracking.Pick()
        if spellID then
            return spellID, "player"
        end
        return nil
    end,
    others = function(_, _, spellID)
        return BR.Tracking.Others(spellID)
    end,
}

-- Spells have ranks, and every rank ID counts as the buff. Click-to-cast casts the
-- first ID in spellID that the player knows, so each list starts with the highest rank.
-- A raid buff lists its single-target ranks before its reagent group version.
-- A single-target raid buff sets castOnMissing, so that the click casts on a member
-- who lacks the buff. groupCast lists its group ranks, highest first.
---@type BuffTables
BR.BUFF_TABLES = {
    ---@type RaidBuff[]
    raid = {
        {
            spellID = RAID_BUFF_IDS.intellect,
            key = "intellect",
            name = L["Buff.ArcaneIntellect"],
            class = "MAGE",
            reach = "raid",
            icons = { spells = { 10157 } },
            castOnMissing = true,
            groupCast = { { spellID = 23028, reagent = 17020 } },
            chatRequestable = true,
        },
        {
            spellID = BATTLE_SHOUT,
            key = "attackPower",
            name = L["Buff.BattleShout"],
            class = "WARRIOR",
            reach = "raid",
            requiresKnownSpell = true,
            visibilityCondition = BattleShoutReady,
        },
        {
            spellID = RAID_BUFF_IDS.spirit,
            key = "spirit",
            name = L["Buff.DivineSpirit"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 27841 } },
            castOnMissing = true,
            groupCast = { { spellID = 27681, reagent = 17029 } },
            -- A talent: only a priest who knows it sees the reminder.
            requiresKnownSpell = true,
        },
        {
            spellID = RAID_BUFF_IDS.versatility,
            key = "versatility",
            name = L["Buff.MarkOfTheWild"],
            class = "DRUID",
            reach = "raid",
            icons = { spells = { 9885 } },
            castOnMissing = true,
            groupCast = { { spellID = 21850, reagent = 17026 }, { spellID = 21849, reagent = 17021 } },
            chatRequestable = true,
        },
        -- Each member gets the blessing of their class list in the options grid.
        {
            spellID = ALL_BLESSING_IDS,
            key = "paladinBlessing",
            name = L["Buff.PaladinBlessing"],
            class = "PALADIN",
            reach = "raid",
            icons = { spells = { 25291 } },
            castOnMissing = true,
            requiresKnownSpell = true,
            classChoices = PALADIN_BLESSING_GRID,
            subChoices = BLESSING_ROW,
            levelRequired = 4, -- Blessing of Might rank 1
            chatRequestable = true,
            chatRequestSpell = RequestedBlessing,
            target = function()
                local defaults = BR.profile.defaults
                return defaults ~= nil and defaults.paladinBlessingScope == "self" and "self" or "group"
            end,
        },
        {
            spellID = RAID_BUFF_IDS.stamina,
            key = "stamina",
            name = L["Buff.PowerWordFortitude"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 10938 } },
            castOnMissing = true,
            groupCast = { { spellID = 21564, reagent = 17029 }, { spellID = 21562, reagent = 17028 } },
            chatRequestable = true,
        },
        {
            spellID = { 10958, 10957, 976, 27683 },
            key = "shadowProtection",
            name = L["Buff.ShadowProtection"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 10958 } },
            castOnMissing = true,
            groupCast = { { spellID = 27683, reagent = 17029 } },
            defaultEnabled = false, -- opt-in: only shadow damage fights want it
            chatRequestable = true,
        },
    },
    ---@type PresenceBuff[]
    presence = {
        {
            spellID = ALL_PALADIN_AURA_IDS,
            key = "paladinAura",
            name = L["Buff.PaladinAura"],
            class = "PALADIN",
            reach = "party",
            icons = {
                spells = { 10293 },
                dynamic = function()
                    local _, castID = WantedPaladinAura()
                    return castID and BR.Icons.GetBuffTexture(castID)
                end,
            },
            overlayText = L["Overlay.NoAura"],
            casterCheck = CheckOwnPaladinAura,
            choiceOrder = PALADIN_AURA_GRID,
            clickMacro = function(spellID)
                local _, castID = WantedPaladinAura()
                return "/cast " .. (BR.GetSpellName(castID or spellID) or "")
            end,
            infoTooltip = { title = L["Tooltip.PaladinDuplicate"], desc = L["Tooltip.PaladinAuraDuplicate.Desc"] },
        },
    },
    ---@type TargetedBuff[]
    targeted = {
        {
            spellID = { 9910, 9756, 8914, 1075, 782, 467 },
            key = "thorns",
            name = L["Buff.Thorns"],
            class = "DRUID",
            overlayText = L["Overlay.NoThorns"],
            levelRequired = 6, -- Thorns rank 1
            target = "tankOrSelf",
            copies = "any",
            targetHint = L["Tooltip.TankHint"],
            chatRequestable = true,
            -- A tank of another class sees the request only when the user turns it on.
            visibilityCondition = function()
                local defaults = BR.profile.defaults
                return playerClass == "DRUID" or (defaults ~= nil and defaults.thornsRequest == true)
            end,
            clickMacro = TankOrSelfMacro("thorns"),
            infoTooltip = { title = L["Tooltip.TankTarget"], desc = L["Tooltip.ThornsTank.Desc"] },
        },
        {
            spellID = 1328548,
            key = "oathOfLight",
            target = "allyOrSelf",
            name = L["Buff.OathOfLight"],
            class = "PALADIN",
            overlayText = L["Overlay.NoOath"],
            clickMacro = BR.TargetedClickMacro("oathOfLight"),
        },
    },
    ---@type SelfBuff[]
    self = {
        {
            spellID = {
                11735, -- Demon Armor
                11734,
                11733,
                1086,
                706,
                696, -- Demon Skin
                687,
            },
            key = "warlockArmor",
            icons = { spells = { 11735 } },
            name = L["Buff.WarlockArmor"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoArmor"],
        },
        -- The stance bar stays readable in combat, so this reminder works there.
        {
            key = "druidWrongForm",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.DruidForm"],
            class = "DRUID",
            overlayText = L["Overlay.WrongForm"],
            icons = {
                spells = { 5487, 768, 24858 }, -- Bear, Cat, Moonkin
                dynamic = function()
                    local expected = BR.BuffState.GetExpectedDruidFormID()
                    if expected and expected ~= NO_STANCE then
                        return BR.Icons.GetBuffTexture(expected)
                    end
                    return BR.BuffState.GetCurrentStanceIcon()
                end,
            },
            -- Any known form enables the click. The caster choice cancels a form.
            castSpellID = { 9634, 5487, 768, 24858 },
            customCheck = function()
                return BR.BuffState.IsWrongDruidForm()
            end,
            clickMacro = function()
                return StanceMacro(BR.BuffState.GetExpectedDruidFormID())
            end,
        },
        {
            spellID = ALL_MAGE_ARMOR_IDS,
            key = "mageArmor",
            icons = {
                spells = { 10220 },
                dynamic = function()
                    local castID = PreferredMageArmor()
                    return castID and BR.Icons.GetBuffTexture(castID)
                end,
            },
            name = L["Buff.MageArmor"],
            class = "MAGE",
            overlayText = L["Overlay.NoArmor"],
            clickMacro = function(spellID)
                return "/cast " .. (BR.GetSpellName(PreferredMageArmor() or spellID) or "")
            end,
        },
        {
            spellID = {
                25296, -- Aspect of the Hawk
                14322,
                14321,
                14320,
                14319,
                14318,
                13165,
                13163, -- Aspect of the Monkey
                20190, -- Aspect of the Wild
                20043,
                1299447, -- Aspect of the Beast
                1299446,
                1299445,
                13161,
                5118, -- Aspect of the Cheetah
                13159, -- Aspect of the Pack
            },
            key = "hunterAspect",
            icons = { spells = { 25296 } },
            name = L["Buff.HunterAspect"],
            class = "HUNTER",
            overlayText = L["Overlay.NoAspect"],
        },
        {
            spellID = { 10952, 10951, 1006, 602, 7128, 588 },
            key = "innerFire",
            name = L["Buff.InnerFire"],
            class = "PRIEST",
            overlayText = L["Overlay.NoInnerFire"],
        },
        {
            spellID = { 10432, 10431, 8134, 945, 905, 325, 324 },
            key = "lightningShield",
            name = L["Buff.LightningShield"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoShield"],
        },
        {
            spellID = 25780,
            key = "righteousFury",
            name = L["Buff.RighteousFury"],
            class = "PALADIN",
            overlayText = L["Overlay.NoRighteousFury"],
            visibilityCondition = RighteousFuryWanted,
            infoTooltip = { title = L["Tooltip.TankOnly"], desc = L["Tooltip.RighteousFuryTank.Desc"] },
        },
        {
            icons = {
                spells = { 8679, 2823 }, -- Instant Poison, Deadly Poison
                dynamic = function()
                    local hand = HandMissingPoison()
                    local _, spellID = PickPoison(hand and hand.column or "mainHand")
                    return spellID and BR.Icons.GetBuffTexture(spellID)
                end,
            },
            key = "roguePoisons",
            name = L["Buff.RoguePoisons"],
            class = "ROGUE",
            overlayText = L["Overlay.ApplyPoison"],
            requiresSpellID = POISONS_SKILL,
            castSpellID = POISONS_SKILL,
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted()
            end,
            customCheck = function()
                return HandMissingPoison() ~= nil
            end,
            getExpirationInfo = PoisonRemaining,
            enchantDuration = 1800, -- seconds
            clickMacro = PoisonMacro,
        },
        -- The stance bar shows Shadowform, and it stays readable in combat.
        {
            key = "shadowform",
            name = L["Buff.Shadowform"],
            class = "PRIEST",
            overlayText = L["Overlay.NoForm"],
            icons = { textures = { 136200 } }, -- spell_shadow_shadowform
            requiresSpellID = BR.SHADOWFORM_SPELL_ID,
            castSpellID = BR.SHADOWFORM_SPELL_ID,
            noExpirationGlow = true,
            customCheck = function()
                return not BR.BuffState.IsShadowFormActive()
            end,
        },
        {
            spellID = { 20906, 20905, 19506, 1299348, 1299346 },
            key = "trueshotAura",
            name = L["Buff.TrueshotAura"],
            class = "HUNTER",
            overlayText = L["Overlay.NoAura"],
        },
        -- The stance bar stays readable in combat, so this reminder works there.
        {
            key = "warriorWrongStance",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.WarriorStance"],
            class = "WARRIOR",
            overlayText = L["Overlay.WrongStance"],
            icons = {
                spells = { 2457, 71, 2458 }, -- Battle, Defensive, Berserker
                dynamic = function()
                    local current = BR.BuffState.GetCurrentStanceIcon()
                    if current then
                        return current
                    end
                    local expected = BR.BuffState.GetExpectedWarriorStanceID()
                    return expected and BR.Icons.GetBuffTexture(expected)
                end,
            },
            castSpellID = 2457, -- Battle Stance: known from level 1
            customCheck = function()
                return BR.BuffState.IsWrongWarriorStance()
            end,
            clickMacro = function()
                return StanceMacro(BR.BuffState.GetExpectedWarriorStanceID())
            end,
        },
        -- Vanilla shamans do not dual-wield, so any imbue on the weapon counts.
        {
            spellID = SHAMAN_IMBUES,
            key = "shamanImbue",
            name = L["Buff.ShamanImbue"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoImbue"],
            enchantID = SHAMAN_IMBUE_ENCHANTS,
            enchantDuration = 3600, -- seconds
            -- An unarmed hand or a fishing pole takes no imbue.
            visibilityCondition = function()
                local subclass = BR.BuffState.GetWeaponSubclass(16)
                return subclass ~= nil and subclass ~= 20 -- Enum.ItemWeaponSubclass.Fishingpole
            end,
            icons = {
                spells = { 16362, 16342, 16316, 16356 }, -- Windfury, Flametongue, Rockbiter, Frostbrand
                dynamic = function()
                    local id = ShamanImbueCastID()
                    return id and BR.Icons.GetBuffTexture(id)
                end,
            },
            clickMacro = function()
                local id = ShamanImbueCastID()
                return id and ("/cast " .. (BR.GetSpellName(id) or "")) or ""
            end,
        },
    },
    ---@type SelfBuff[]
    pet = {
        {
            key = "petPassive",
            name = L["Buff.PetPassive"],
            overlayText = L["Overlay.PassivePet"],
            icons = { textures = { 132311 } },
            customCheck = function()
                return BR.PetHelpers.IsPetOnPassive()
            end,
        },
        -- A hunter tames the first pet at level 10, where Call Pet is learned.
        {
            key = "hunterPet",
            name = L["Buff.HunterPet"],
            class = "HUNTER",
            overlayText = L["Overlay.NoPet"],
            icons = { textures = { 132161 } }, -- Call Pet
            requiresSpellID = 883,
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet") or UnitIsDead("pet") or nil
            end,
        },
        {
            key = "warlockPet",
            name = L["Buff.WarlockDemon"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoPet"],
            icons = { textures = { 136218 } }, -- Summon Imp
            requiresSpellID = 688, -- Summon Imp
            petSacrifice = DEMONIC_SACRIFICE,
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            key = "warlockWrongPet",
            name = L["Buff.WrongDemon"],
            class = "WARLOCK",
            overlayText = L["Overlay.WrongPet"],
            icons = { textures = { 136217 } }, -- Summon Felhunter
            groupId = "pets",
            customCheck = function()
                local defaults = BR.profile.defaults
                if defaults and defaults.warlockWrongDemon == false then
                    return false
                end
                return BR.BuffState.IsWrongDemonPet()
            end,
            getPetActions = function()
                return BR.PetHelpers.GetDesiredWarlockDemonList()
            end,
        },
    },
    custom = {},
    loadout = {},
    ---@type ConsumableBuff[]
    consumable = {
        {
            spellID = {
                17626, -- Flask of the Titans
                17627, -- Distilled Wisdom
                17628, -- Supreme Power
                17629, -- Chromatic Resistance
                17624, -- Petrification
            },
            icons = { spells = { 17626, 17627, 17628, 17629 } },
            key = "flask",
            name = L["Buff.Flask"],
            overlayText = L["Overlay.NoFlask"],
            groupId = "flask",
            consumableCategory = "flask",
            disabledInCompetitivePvP = true,
        },
        -- The list holds each aura that a food item gives. Icon 136000 also catches the
        -- older Well Fed auras that no item gives.
        {
            spellID = {
                1248406, -- Well Fed (Stamina)
                1248420, -- Well Fed (Agility)
                1248421, -- Well Fed (Intellect)
                1248422, -- Well Fed (Strength)
                1302064, -- Well Fed (Strength)
                1249519, -- Well Fed (Attack Power)
                1249520, -- Well Fed (Spell Damage)
                1249521, -- Well Fed (Fishing)
                1249523, -- Well Fed (Critical Strike)
                1319310, -- Well Fed (Armor)
                1225779, -- Well Fed (Agility and Stamina)
                1248688, -- Well Fed (movement speed in Westfall)
                1294007, -- Well Fed (movement speed in Hyjal)
                1249907, -- Well Fed (Herbalism, Goldthorn Tea)
                1249926, -- Well Fed (Spirit, smoothies)
                1249927, -- Well Fed (Healing Power, teas)
                19705, -- Well Fed (Stamina and Spirit)
                19706,
                19708,
                19709,
                19710,
                19711,
                25661, -- Increased Stamina (Dirge's Kickin' Chimaerok Chops)
                18191, -- Increased Stamina (Windblossom Berries)
                18125, -- Blessed Sunfruit
                18141, -- Blessed Sunfruit Juice
                15852, -- Dragonbreath Chili
            },
            buffIconID = 136000,
            icons = { textures = { 133943 } },
            key = "food",
            name = L["Buff.Food"],
            overlayText = L["Overlay.NoFood"],
            groupId = "food",
            consumableCategory = "food",
            disabledInCompetitivePvP = true,
        },
        -- A healthstone is unique and has one use. No Soulwell exists.
        {
            itemID = {
                9421, -- Major Healthstone
                19012,
                19013,
                5510, -- Greater Healthstone
                19010,
                19011,
                5509, -- Healthstone
                19008,
                19009,
                5511, -- Lesser Healthstone
                19006,
                19007,
                5512, -- Minor Healthstone
                19004,
                19005,
            },
            key = "healthstone",
            name = L["Buff.Healthstone"],
            casterClass = "WARLOCK",
            overlayText = L["Overlay.NoStone"],
            groupId = "healthstone",
            icons = { textures = { 135230 } },
            freeConsumable = true,
            chatRequestable = true,
            clickMacro = function()
                return CastHighestKnownMacro(CREATE_HEALTHSTONE)
            end,
        },
        {
            itemID = {
                8008, -- Mana Ruby
                8007, -- Mana Citrine
                5513, -- Mana Jade
                5514, -- Mana Agate
            },
            key = "manaGem",
            name = L["Buff.ManaGem"],
            casterClass = "MAGE",
            overlayText = L["Overlay.NoGem"],
            icons = { textures = { 134128 } },
            freeConsumable = true,
            visibilityCondition = function()
                return playerClass == "MAGE" and HighestKnownSpell(CONJURE_MANA_GEM) ~= nil
            end,
            clickMacro = function()
                return CastHighestKnownMacro(CONJURE_MANA_GEM)
            end,
        },
        {
            checkWeaponEnchant = true,
            enchantDuration = 1800, -- seconds
            key = "weaponBuff",
            name = L["Buff.Weapon"],
            overlayText = L["Overlay.NoWeaponBuff"],
            groupId = "weaponBuff",
            icons = { textures = { 134727, 135252 } }, -- Brilliant Wizard Oil, Dense Sharpening Stone
            consumableCategory = "weapon",
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted()
            end,
            disabledInCompetitivePvP = true,
        },
        {
            checkWeaponEnchantOH = true,
            enchantDuration = 1800, -- seconds
            key = "weaponBuffOH",
            name = L["Buff.WeaponOH"],
            overlayText = L["Overlay.NoWeaponBuff"],
            groupId = "weaponBuff",
            icons = { textures = { 134727, 135252 } }, -- Brilliant Wizard Oil, Dense Sharpening Stone
            consumableCategory = "weapon",
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted() and BR.BuffState.HasOffHandWeapon()
            end,
            disabledInCompetitivePvP = true,
        },
    },
    ---@type UtilityBuff[]
    utility = {
        -- spellID gives the click overlay a known spell. PreClick replaces it with the pick.
        {
            key = "driveByBuffs",
            defaultEnabled = false, -- opt-in: casts on strangers
            name = L["Buff.DriveByBuffs"],
            spellID = DRIVE_BY_SPELLS,
            icons = {
                spells = { 10157, 10938, 9885 },
                dynamic = function()
                    local spellID = BR.DriveBy.Pick()
                    return spellID and BR.Icons.GetBuffTexture(spellID)
                end,
            },
            overlayText = L["Overlay.DriveBy"],
            infoTooltip = { title = L["Buff.DriveByBuffs"], desc = L["Tooltip.DriveBy.Desc"] },
            castUnit = "target",
            subChoices = DRIVE_BY_ROW,
            clickSpell = function()
                return BR.DriveBy.Pick()
            end,
            customCheck = function()
                return BR.DriveBy.Pick() ~= nil
            end,
        },
        {
            key = "tracking",
            name = L["Buff.Tracking"],
            spellID = TRACKING_SPELL_IDS,
            icons = {
                spells = { 2383, 2580, 1494 },
                dynamic = function()
                    local spellID = BR.Tracking.Pick()
                    return spellID and BR.Icons.GetBuffTexture(spellID)
                end,
            },
            overlayText = L["Overlay.NoTracking"],
            subChoices = TRACKING_ROW,
            clickSpell = function()
                return BR.Tracking.Pick()
            end,
            customCheck = function()
                if BR.GameContext.IsInCombat() then
                    return false
                end
                return BR.Tracking.Pick() ~= nil and not BR.BuffState.IsTrackingActive()
            end,
        },
        {
            key = "sleepingBag",
            name = L["Buff.SleepingBag"],
            icons = { textures = { C_Item.GetItemIconByID(SLEEPING_BAG.itemID) or 134400 } }, -- else a question mark
            overlayText = L["Overlay.SleepingBag"],
            infoTooltip = { title = L["Buff.SleepingBag"], desc = L["Tooltip.SleepingBag.Desc"] },
            clickItem = SLEEPING_BAG.itemID,
            countdown = SleepingBagRestEnd,
            -- The bag cannot go down in a city or an inn, and the buff gives only experience.
            customCheck = function(isAuraRestricted)
                local GameContext = BR.GameContext
                if isAuraRestricted or GameContext.IsInCombat() then
                    return false
                end
                if GameContext.GetPlayerLevel() >= GameContext.GetMaxExpansionLevel() then
                    return false
                end
                -- The bag itself makes the player rest, so this check comes before the rest check.
                if SleepingBagRestEnd() then
                    return true
                end
                if GameContext.IsResting() then
                    return false
                end
                if BR.StateHelpers.GetItemCountCached(SLEEPING_BAG.itemID) == 0 then
                    return false
                end
                if C_UnitAuras.GetUnitAuraBySpellID("player", SLEEPING_BAG.auraID) then
                    return false
                end
                return BR.BuffState.IsItemOffCooldown(SLEEPING_BAG.itemID)
            end,
        },
        {
            key = "camp",
            name = L["Buff.Camp"],
            icons = {
                spells = { CAMP.benefitsID },
                dynamic = function()
                    local stage, kitID = CampStage()
                    -- A nil icon keeps the texture of the previous stage on the frame.
                    if stage == "camp" and kitID then
                        local icon = CAMP_KIT_ICONS[kitID] or C_Item.GetItemIconByID(kitID)
                        CAMP_KIT_ICONS[kitID] = icon
                        return icon
                    end
                    return BR.Icons.GetBuffTexture(CAMP.benefitsID)
                end,
            },
            overlayText = CAMP_SIT_TEXT,
            overlayTextFn = function()
                return CampStage() == "camp" and CAMP_KIT_TEXT or CAMP_SIT_TEXT
            end,
            subChoices = CAMP_ROW,
            clickMacroText = function()
                local stage, kitID = CampStage()
                if stage == "sit" then
                    return CAMP_SIT_MACRO
                end
                return kitID and CAMP_KIT_MACROS[kitID]
            end,
            -- The game blocks both the sit and the kit while the player is mounted.
            customCheck = function(isAuraRestricted)
                local GameContext = BR.GameContext
                if isAuraRestricted or GameContext.IsInCombat() or GameContext.IsResting() or IsMounted() then
                    return false
                end
                return CampStage() ~= nil
            end,
        },
        {
            key = "lowAmmo",
            name = L["Buff.LowAmmo"],
            icons = {
                textures = { AMMO_ICON_ARROW },
                dynamic = function()
                    return AmmoWeaponSubclass() == 3 and AMMO_ICON_BULLET or AMMO_ICON_ARROW -- 3 = Gun
                end,
            },
            overlayText = AMMO_TEXT,
            overlayTextFn = function()
                local subclass = AmmoWeaponSubclass()
                if not subclass then
                    return AMMO_TEXT
                end
                -- Enough other ammo in the bags: a swap fixes it, not a vendor.
                local shots, total = AmmoShots(subclass)
                if total - shots >= AmmoThreshold() or (shots == 0 and total > 0) then
                    return AMMO_EQUIP_TEXT
                end
                return AMMO_LABEL .. "\n" .. shots
            end,
            customCheck = function()
                if BR.GameContext.IsInCombat() then
                    return false
                end
                local subclass = AmmoWeaponSubclass()
                if not subclass then
                    return false
                end
                return AmmoShots(subclass) < AmmoThreshold()
            end,
        },
        {
            key = "lowReagents",
            name = L["Buff.LowReagents"],
            icons = {
                textures = { PLAYER_REAGENTS[1] and PLAYER_REAGENTS[1].icon or 133848 }, -- else Arcane Powder
                dynamic = function()
                    local reagent = LowestReagent()
                    return reagent and reagent.icon
                end,
            },
            overlayText = REAGENTS_TEXT,
            overlayTextFn = function()
                local _, count = LowestReagent()
                return count and (REAGENT_LABEL .. "\n" .. count) or REAGENTS_TEXT
            end,
            customCheck = function()
                if BR.GameContext.IsInCombat() then
                    return false
                end
                local defaults = BR.profile.defaults
                if (not defaults or defaults.reagentRestedOnly ~= false) and not BR.GameContext.IsResting() then
                    return false
                end
                local _, count = LowestReagent()
                return count ~= nil and count < (defaults and defaults.reagentThreshold or 5)
            end,
        },
        {
            key = "repairGear",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.RepairGear"],
            icons = { textures = { 136241 } }, -- Trade_BlackSmithing
            overlayText = L["Overlay.Repair"],
            -- floor, not round: 84.9% must never read as the 85% threshold it crossed.
            overlayTextFn = function()
                return REPAIR_LABEL .. "\n" .. floor(BR.BuffState.GetLowestDurability() * 100) .. "%"
            end,
            customCheck = function()
                return BR.BuffState.GetLowestDurability() < (BR.Config.Get("defaults.repairThreshold", 20) / 100)
            end,
        },
    },
}

-- The happiness reminder exists only on a client with pet happiness.
if C_PetInfo and C_PetInfo.GetPetHappiness then
    table.insert(BR.BUFF_TABLES.pet, 1, PET_HAPPINESS)
end
