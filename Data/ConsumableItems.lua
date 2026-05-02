local _, BR = ...
local L = BR.L

-- Lookup tables of known consumable item IDs, keyed by consumable type.
-- Values: `true` for simple membership, or a table with `label` (stat abbreviation) and optional fields.
-- Food tables: `{ label, badge, legacy }`. Flask tables: `{ label, badge, priority, legacy }`.
-- `badge`: bottom-left overlay text ("H" for hearty food, "R1"/"R2"/"R3" for flask quality).
-- `legacy`: true for items from prior expansions; hidden by the hideLegacyConsumables setting.
BR.CONSUMABLE_ITEMS = {
    food = {
        -- TWW 11.0.0 (legacy)
        [222702] = { label = L["Label.LowSecondary"], legacy = true }, -- Skewered Fillet
        [222703] = { label = L["Label.LowSecondary"], legacy = true }, -- Simple Stew
        [222704] = { label = L["Label.LowSecondary"], legacy = true }, -- Unseasoned Field Steak
        [222705] = { label = L["Label.LowSecondary"], legacy = true }, -- Roasted Mycobloom
        [222706] = { label = L["Label.LowSecondary"], legacy = true }, -- Pan-Seared Mycobloom
        [222707] = { label = L["Label.LowSecondary"], legacy = true }, -- Hallowfall Chili
        [222708] = { label = L["Label.LowSecondary"], legacy = true }, -- Coreway Kabob
        [222709] = { label = L["Label.LowSecondary"], legacy = true }, -- Flashfire Fillet
        [222710] = { label = L["Label.StaminaStr"], legacy = true }, -- Meat and Potatoes
        [222711] = { label = L["Label.StaminaAgi"], legacy = true }, -- Rib Stickers
        [222712] = { label = L["Label.StaminaInt"], legacy = true }, -- Sweet and Sour Meatballs
        [222713] = { label = L["Label.Stamina"], legacy = true }, -- Tender Twilight Jerky
        [222714] = { label = L["Label.HasteShort"], legacy = true }, -- Zesty Nibblers
        [222715] = { label = L["Label.Crit"], legacy = true }, -- Fiery Fish Sticks
        [222716] = { label = L["Label.VersatilityShort"], legacy = true }, -- Ginger-Glazed Fillet
        [222717] = { label = L["Label.MasteryShort"], legacy = true }, -- Salty Dog
        [222718] = { label = L["Label.HasteCrit"], legacy = true }, -- Deepfin Patty
        [222719] = { label = L["Label.HasteVers"], legacy = true }, -- Sweet and Spicy Soup
        [222720] = { label = L["Label.HighSecondary"], legacy = true }, -- The Sushi Special
        [222721] = { label = L["Label.CritVers"], legacy = true }, -- Fish and Chips
        [222722] = { label = L["Label.MasteryCrit"], legacy = true }, -- Salt Baked Seafood
        [222723] = { label = L["Label.MasteryVers"], legacy = true }, -- Marinated Tenderloins
        [222724] = { label = L["Label.StaminaStr"], legacy = true }, -- Sizzling Honey Roast
        [222725] = { label = L["Label.StaminaAgi"], legacy = true }, -- Mycobloom Risotto
        [222726] = { label = L["Label.StaminaInt"], legacy = true }, -- Stuffed Cave Peppers
        [222727] = { label = L["Label.Stamina"], legacy = true }, -- Angler's Delight
        [222728] = { label = L["Label.HighSecondary"], legacy = true }, -- Beledar's Bounty
        [222729] = { label = L["Label.HighSecondary"], legacy = true }, -- Empress' Farewell
        [222730] = { label = L["Label.HighSecondary"], legacy = true }, -- Jester's Board
        [222731] = { label = L["Label.HighSecondary"], legacy = true }, -- Outsider's Provisions
        [222732] = { label = L["Label.Feast"], legacy = true }, -- Feast of the Divine Day
        [222733] = { label = L["Label.Feast"], legacy = true }, -- Feast of the Midnight Masquerade
        [222735] = { label = L["Label.LowSecondary"], legacy = true }, -- Everything Stew
        [222736] = { label = L["Label.MasteryHaste"], legacy = true }, -- Chippy Tea
        [222750] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Skewered Fillet
        [222751] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Simple Stew
        [222752] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Unseasoned Field Steak
        [222753] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Roasted Mycobloom
        [222754] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Pan-Seared Mycobloom
        [222755] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Hallowfall Chili
        [222756] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Coreway Kabob
        [222757] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Flashfire Fillet
        [222758] = { label = L["Label.StaminaStr"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Meat and Potatoes
        [222759] = { label = L["Label.StaminaAgi"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Rib Stickers
        [222760] = { label = L["Label.StaminaInt"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Sweet and Sour Meatballs
        [222761] = { label = L["Label.Stamina"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Tender Twilight Jerky
        [222762] = { label = L["Label.HasteShort"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Zesty Nibblers
        [222763] = { label = L["Label.Crit"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Fiery Fish Sticks
        [222764] = { label = L["Label.VersatilityShort"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Ginger-Glazed Fillet
        [222765] = { label = L["Label.MasteryShort"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Salty Dog
        [222766] = { label = L["Label.HasteCrit"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Deepfin Patty
        [222767] = { label = L["Label.HasteVers"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Sweet and Spicy Soup
        [222768] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Sushi Special
        [222769] = { label = L["Label.CritVers"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Fish and Chips
        [222770] = { label = L["Label.MasteryCrit"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Salt Baked Seafood
        [222771] = { label = L["Label.MasteryVers"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Marinated Tenderloins
        [222772] = { label = L["Label.StaminaStr"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Sizzling Honey Roast
        [222773] = { label = L["Label.StaminaAgi"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Mycobloom Risotto
        [222774] = { label = L["Label.StaminaInt"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Stuffed Cave Peppers
        [222775] = { label = L["Label.Stamina"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Angler's Delight
        [222776] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Beledar's Bounty
        [222777] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Empress' Farewell
        [222778] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Jester's Board
        [222779] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Outsider's Provisions
        [222780] = { label = L["Label.Feast"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Feast of the Divine Day
        [222781] = { label = L["Label.Feast"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Feast of the Midnight Masquerade
        [222783] = { label = L["Label.LowSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Everything Stew
        [222784] = { label = L["Label.MasteryHaste"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Chippy Tea
        [223966] = { label = L["Label.Random"], legacy = true }, -- Everything-on-a-Stick (random Khaz Algar meal)
        [223967] = { label = L["Label.LowSecondary"], legacy = true }, -- Protein Slurp
        [223968] = { label = L["Label.LowSecondary"], legacy = true }, -- Spongey Scramble
        [225592] = { label = L["Label.Speed"], legacy = true }, -- Exquisitely Eviscerated Muscle

        -- TWW 11.1.0 (legacy)
        [235805] = { label = L["Label.HighSecondary"], legacy = true }, -- Authentic Undermine Clam Chowder
        [235853] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"], legacy = true }, -- Hearty Authentic Undermine Clam Chowder

        -- Midnight 12.0.0
        [242272] = { label = L["Label.HighSecondary"] }, -- Quel'dorei Medley
        [242273] = { label = L["Label.HighSecondary"] }, -- Blooming Feast
        [242274] = { label = L["Label.HighSecondary"] }, -- Champion's Bento
        [242275] = { label = L["Label.HighPrimary"] }, -- Royal Roast
        [242276] = { label = L["Label.VersatilityShort"] }, -- Braised Blood Hunter
        [242277] = { label = L["Label.HasteShort"] }, -- Crimson Calamari
        [242278] = { label = L["Label.Crit"] }, -- Tasty Smoked Tetra
        [242279] = { label = L["Label.MidPrimary"] }, -- Baked Lucky Loa
        [242280] = { label = L["Label.VersatilityShort"] }, -- Buttered Root Crab
        [242281] = { label = L["Label.MasteryShort"] }, -- Glitter Skewers
        [242282] = { label = L["Label.HasteShort"] }, -- Null and Void Plate
        [242283] = { label = L["Label.Crit"] }, -- Sun-Seared Lumifin
        [242284] = { label = L["Label.VersatilityShort"] }, -- Void-Kissed Fish Rolls
        [242285] = { label = L["Label.MasteryShort"] }, -- Warped Wise Wings
        [242286] = { label = L["Label.HasteShort"] }, -- Fel-Kissed Filet
        [242287] = { label = L["Label.Crit"] }, -- Arcano Cutlets
        [242288] = { label = L["Label.MidPrimary"] }, -- Twilight Angler's Medley
        [242289] = { label = L["Label.MidPrimary"] }, -- Spellfire Filet
        [242290] = { label = L["Label.CritVers"] }, -- Wise Tails
        [242291] = { label = L["Label.MasteryVers"] }, -- Fried Bloomtail
        [242292] = { label = L["Label.MasteryCrit"] }, -- Eversong Pudding
        [242293] = { label = L["Label.HasteVers"] }, -- Sunwell Delight
        [242294] = { label = L["Label.VersatilityShort"] }, -- Felberry Figs
        [242295] = { label = L["Label.HasteCrit"] }, -- Hearthflame Supper
        [242296] = { label = L["Label.MasteryHaste"] }, -- Bloodthistle-wrapped Cutlets
        [242302] = { label = L["Label.LowPrimary"] }, -- Bloom Skewers
        [242303] = { label = L["Label.LowPrimary"] }, -- Mana-Infused Stew
        [242304] = { label = L["Label.CritVers"] }, -- Spiced Biscuits
        [242305] = { label = L["Label.MasteryVers"] }, -- Silvermoon Standard
        [242306] = { label = L["Label.MasteryCrit"] }, -- Forager's Medley
        [242307] = { label = L["Label.HasteVers"] }, -- Quick Sandwich
        [242308] = { label = L["Label.HasteCrit"] }, -- Portable Snack
        [242309] = { label = L["Label.MasteryHaste"] }, -- Farstrider Rations
        [242532] = { label = L["Label.LowPrimary"] }, -- [PH] Vegetarian Recipe
        [242744] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"] }, -- Hearty Quel'dorei Medley
        [242745] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"] }, -- Hearty Blooming Feast
        [242746] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"] }, -- Hearty Champion's Bento
        [242747] = { label = L["Label.HighPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Royal Roast
        [242748] = { label = L["Label.VersatilityShort"], badge = L["Badge.Hearty"] }, -- Hearty Braised Blood Hunter
        [242749] = { label = L["Label.HasteShort"], badge = L["Badge.Hearty"] }, -- Hearty Crimson Calamari
        [242750] = { label = L["Label.Crit"], badge = L["Badge.Hearty"] }, -- Hearty Tasty Smoked Tetra
        [242751] = { label = L["Label.MidPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Rootland Surprise
        [242752] = { label = L["Label.VersatilityShort"], badge = L["Badge.Hearty"] }, -- Hearty Buttered Root Crab
        [242753] = { label = L["Label.MasteryShort"], badge = L["Badge.Hearty"] }, -- Hearty Glitter Skewers
        [242754] = { label = L["Label.HasteShort"], badge = L["Badge.Hearty"] }, -- Hearty Null and Void Plate
        [242755] = { label = L["Label.Crit"], badge = L["Badge.Hearty"] }, -- Hearty Sun-Seared Lumifin
        [242756] = { label = L["Label.VersatilityShort"], badge = L["Badge.Hearty"] }, -- Hearty Void-Kissed Fish Rolls
        [242757] = { label = L["Label.MasteryShort"], badge = L["Badge.Hearty"] }, -- Hearty Warped Wise Wings
        [242758] = { label = L["Label.HasteShort"], badge = L["Badge.Hearty"] }, -- Hearty Fel-Kissed Filet
        [242759] = { label = L["Label.Crit"], badge = L["Badge.Hearty"] }, -- Hearty Arcano Cutlets
        [242760] = { label = L["Label.MidPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Twilight Angler's Medley
        [242761] = { label = L["Label.MidPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Spellfire Filet
        [242762] = { label = L["Label.CritVers"], badge = L["Badge.Hearty"] }, -- Hearty Wise Tails
        [242763] = { label = L["Label.MasteryVers"], badge = L["Badge.Hearty"] }, -- Hearty Fried Bloomtail
        [242764] = { label = L["Label.MasteryCrit"], badge = L["Badge.Hearty"] }, -- Hearty Eversong Pudding
        [242765] = { label = L["Label.HasteVers"], badge = L["Badge.Hearty"] }, -- Hearty Sunwell Delight
        [242766] = { label = L["Label.VersatilityShort"], badge = L["Badge.Hearty"] }, -- Hearty Felberry Figs
        [242767] = { label = L["Label.HasteCrit"], badge = L["Badge.Hearty"] }, -- Hearty Hearthflame Supper
        [242768] = { label = L["Label.MasteryHaste"], badge = L["Badge.Hearty"] }, -- Hearty Bloodthistle-Wrapped Cutlets
        [242769] = { label = L["Label.LowPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Bloom Skewers
        [242770] = { label = L["Label.LowPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Mana-Infused Stew
        [242771] = { label = L["Label.CritVers"], badge = L["Badge.Hearty"] }, -- Hearty Spiced Biscuits
        [242772] = { label = L["Label.MasteryVers"], badge = L["Badge.Hearty"] }, -- Hearty Silvermoon Standard
        [242773] = { label = L["Label.MasteryCrit"], badge = L["Badge.Hearty"] }, -- Hearty Forager's Medley
        [242774] = { label = L["Label.HasteVers"], badge = L["Badge.Hearty"] }, -- Hearty Quick Sandwich
        [242775] = { label = L["Label.HasteCrit"], badge = L["Badge.Hearty"] }, -- Hearty Portable Snack
        [242776] = { label = L["Label.MasteryHaste"], badge = L["Badge.Hearty"] }, -- Hearty Farstrider Rations
        [255845] = { label = L["Label.Feast"] }, -- Silvermoon Parade
        [255846] = { label = L["Label.Feast"] }, -- Harandar Celebration
        [255847] = { label = L["Label.HighPrimary"] }, -- Impossibly Royal Roast
        [255848] = { label = L["Label.HighSecondary"] }, -- Flora Frenzy
        [266985] = { label = L["Label.Feast"], badge = L["Badge.Hearty"] }, -- Hearty Silvermoon Parade
        [266986] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"] }, -- Hearty Quel'dorei Medley
        [266996] = { label = L["Label.Feast"], badge = L["Badge.Hearty"] }, -- Hearty Harandar Celebration
        [267000] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"] }, -- Hearty Flora Frenzy
        [268679] = { label = L["Label.HighPrimary"], badge = L["Badge.Hearty"] }, -- Hearty Impossibly Royal Roast
        [268680] = { label = L["Label.HighSecondary"], badge = L["Badge.Hearty"] }, -- Hearty Flora Frenzy
        -- Recovery-only (no Well Fed buff, just health/mana restore). Not tracked, listed here for reference.
        -- [260264] = true, -- Quel'Danas Rations
        -- [260275] = true, -- Mukleech Curry
        -- [260276] = true, -- Akil'stew
        -- [260277] = true, -- Sedge Crawler Gumbo
        -- [260286] = true, -- Shrooms and Nectar
        -- [260299] = true, -- Roasted Abyssal Eel
    },
    -- Flask entries: { label } for regular, { label, priority } for fleeting/cauldron
    -- Quality is detected dynamically from item link atlas (shows tier icons instead of R1/R2/R3 text)
    -- priority = sort order (fleeting sort first)
    flask = {
        -- TWW 11.0.0 (3 quality tiers, legacy)
        [212269] = { label = L["Label.Crit"], legacy = true }, -- Flask of Tempered Aggression
        [212270] = { label = L["Label.Crit"], legacy = true }, -- Flask of Tempered Aggression (quality 2)
        [212271] = { label = L["Label.Crit"], legacy = true }, -- Flask of Tempered Aggression (quality 3)
        [212272] = { label = L["Label.Haste"], legacy = true }, -- Flask of Tempered Swiftness
        [212273] = { label = L["Label.Haste"], legacy = true }, -- Flask of Tempered Swiftness (quality 2)
        [212274] = { label = L["Label.Haste"], legacy = true }, -- Flask of Tempered Swiftness (quality 3)
        [212275] = { label = L["Label.Versatility"], legacy = true }, -- Flask of Tempered Versatility
        [212276] = { label = L["Label.Versatility"], legacy = true }, -- Flask of Tempered Versatility (quality 2)
        [212277] = { label = L["Label.Versatility"], legacy = true }, -- Flask of Tempered Versatility (quality 3)
        [212278] = { label = L["Label.Mastery"], legacy = true }, -- Flask of Tempered Mastery
        [212279] = { label = L["Label.Mastery"], legacy = true }, -- Flask of Tempered Mastery (quality 2)
        [212280] = { label = L["Label.Mastery"], legacy = true }, -- Flask of Tempered Mastery (quality 3)
        [212281] = { label = L["Label.Random"], legacy = true }, -- Flask of Alchemical Chaos
        [212282] = { label = L["Label.Random"], legacy = true }, -- Flask of Alchemical Chaos (quality 2)
        [212283] = { label = L["Label.Random"], legacy = true }, -- Flask of Alchemical Chaos (quality 3)
        [212299] = { label = L["Label.Healing"], legacy = true }, -- Flask of Saving Graces
        [212300] = { label = L["Label.Healing"], legacy = true }, -- Flask of Saving Graces (quality 2)
        [212301] = { label = L["Label.Healing"], legacy = true }, -- Flask of Saving Graces (quality 3)
        -- TWW 11.0.0 (fleeting/cauldron, 3 quality tiers, legacy)
        [212725] = { label = L["Label.Crit"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Aggression
        [212727] = { label = L["Label.Crit"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Aggression (quality 2)
        [212728] = { label = L["Label.Crit"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Aggression (quality 3)
        [212729] = { label = L["Label.Haste"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Swiftness
        [212730] = { label = L["Label.Haste"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Swiftness (quality 2)
        [212731] = { label = L["Label.Haste"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Swiftness (quality 3)
        [212732] = { label = L["Label.Versatility"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Versatility
        [212733] = { label = L["Label.Versatility"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Versatility (quality 2)
        [212734] = { label = L["Label.Versatility"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Versatility (quality 3)
        [212735] = { label = L["Label.Mastery"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Mastery
        [212736] = { label = L["Label.Mastery"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Mastery (quality 2)
        [212738] = { label = L["Label.Mastery"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Tempered Mastery (quality 3)
        [212739] = { label = L["Label.Random"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Alchemical Chaos
        [212740] = { label = L["Label.Random"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Alchemical Chaos (quality 2)
        [212741] = { label = L["Label.Random"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Alchemical Chaos (quality 3)
        [212745] = { label = L["Label.Healing"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Saving Graces
        [212746] = { label = L["Label.Healing"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Saving Graces (quality 2)
        [212747] = { label = L["Label.Healing"], badge = L["Badge.Fleeting"], priority = 1, legacy = true }, -- Fleeting Flask of Saving Graces (quality 3)
        -- Midnight 12.0.0 (2 quality tiers)
        [241320] = { label = L["Label.Versatility"] }, -- Flask of Thalassian Resistance
        [241321] = { label = L["Label.Versatility"] }, -- Flask of Thalassian Resistance (quality 2)
        [241322] = { label = L["Label.Mastery"] }, -- Flask of the Magisters
        [241323] = { label = L["Label.Mastery"] }, -- Flask of the Magisters (quality 2)
        [241324] = { label = L["Label.Haste"] }, -- Flask of the Blood Knights
        [241325] = { label = L["Label.Haste"] }, -- Flask of the Blood Knights (quality 2)
        [241326] = { label = L["Label.Crit"] }, -- Flask of the Shattered Sun
        [241327] = { label = L["Label.Crit"] }, -- Flask of the Shattered Sun (quality 2)
        [241334] = { label = L["Label.PvP"] }, -- Vicious Thalassian Flask of Honor
        [241335] = { label = L["Label.PvP"] }, -- Vicious Thalassian Flask of Honor (quality 2)
        -- Midnight 12.0.0 (fleeting, 2 quality tiers)
        [245926] = { label = L["Label.Versatility"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of Thalassian Resistance (quality 2)
        [245927] = { label = L["Label.Versatility"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of Thalassian Resistance
        [245928] = { label = L["Label.Crit"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of the Shattered Sun (quality 2)
        [245929] = { label = L["Label.Crit"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of the Shattered Sun
        [245930] = { label = L["Label.Haste"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of the Blood Knights (quality 2)
        [245931] = { label = L["Label.Haste"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of the Blood Knights
        [245932] = { label = L["Label.Mastery"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of the Magisters (quality 2)
        [245933] = { label = L["Label.Mastery"], badge = L["Badge.Fleeting"], priority = 1 }, -- Fleeting Flask of the Magisters
    },
    -- Rune priority: lower number = use first (Midnight > TWW > Dragonflight > Shadowlands)
    rune = {
        [259085] = { priority = 1 }, -- Void-Touched Augment Rune (Midnight)
        -- Ethereal is TWW but permanent/infinite (see permanentRuneItemIDs in Buffs.lua), so not flagged legacy
        [243191] = { priority = 2 }, -- Ethereal Augment Rune (TWW permanent)
        -- TWW (legacy)
        [246492] = { priority = 3, legacy = true }, -- Soulgorged Augment Rune (TWW, persists through death)
        [224572] = { priority = 4, legacy = true }, -- Crystallized Augment Rune (TWW single use)
        -- Dragonflight / Shadowlands (legacy)
        [211495] = { priority = 5, legacy = true }, -- Dreambound Augment Rune (Dragonflight)
        [201325] = { priority = 6, legacy = true }, -- Draconic Augment Rune (Dragonflight)
        [181468] = { priority = 7, legacy = true }, -- Veiled Augment Rune (Shadowlands)
    },
    weapon = {
        -- Midnight 12.0.0
        [237367] = true, -- Refulgent Weightstone
        [237369] = true, -- Refulgent Weightstone (quality 2)
        [237370] = true, -- Refulgent Whetstone
        [237371] = true, -- Refulgent Whetstone (quality 2)
        [243733] = true, -- Thalassian Phoenix Oil
        [243734] = true, -- Thalassian Phoenix Oil (quality 2)
        [243735] = true, -- Oil of Dawn
        [243736] = true, -- Oil of Dawn (quality 2)
        [243737] = true, -- Smuggler's Enchanted Edge
        [243738] = true, -- Smuggler's Enchanted Edge (quality 2)
        [257749] = true, -- Laced Zoomshots
        [257750] = true, -- Laced Zoomshots (quality 2)
        [257751] = true, -- Weighted Boomshots
        [257752] = true, -- Weighted Boomshots (quality 2)
    },
}

-- Fleeting flask item IDs. These sort first by numeric priority but should NOT be
-- remembered - they would overwrite the user's regular flask preference.
BR.FLEETING_FLASK_ITEMS = {
    [245926] = true, -- Fleeting Flask of Thalassian Resistance (quality 2)
    [245927] = true, -- Fleeting Flask of Thalassian Resistance
    [245928] = true, -- Fleeting Flask of the Shattered Sun (quality 2)
    [245929] = true, -- Fleeting Flask of the Shattered Sun
    [245930] = true, -- Fleeting Flask of the Blood Knights (quality 2)
    [245931] = true, -- Fleeting Flask of the Blood Knights
    [245932] = true, -- Fleeting Flask of the Magisters (quality 2)
    [245933] = true, -- Fleeting Flask of the Magisters
}
