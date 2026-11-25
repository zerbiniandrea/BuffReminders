local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Food items list every food of every level that gives a food buff.
---@type table<string, table<number, ConsumableItemInfo|boolean>>
local ITEMS = {
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
local UNREMEMBERED_FLASKS = {
    [13506] = true, -- Flask of Petrification
}

---@type ConsumableData
BR.ConsumableData = {
    items = ITEMS,
    unrememberedFlasks = UNREMEMBERED_FLASKS,
    previewTextures = {
        flask = { 134842, 134877, 134821 }, -- Titans, Distilled Wisdom, Supreme Power
        food = { 132804, 134020 }, -- Nightfin Soup, Smoked Desert Dumplings
        oil = 134727, -- Brilliant Wizard Oil
    },
    -- Forever items have no crafted quality, stat labels, Delve food or legacy tier.
    features = { itemLabels = false, delveFood = false, legacyItems = false },
}
