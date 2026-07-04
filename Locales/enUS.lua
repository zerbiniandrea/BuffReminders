local _, BR = ...

-- ============================================================================
-- LOCALIZATION (English - Default)
-- ============================================================================
-- This file defines all user-facing strings for BuffReminders.
-- Keys use PascalCase dot notation: "Section.SubSection.Key"
-- Missing translations fall back to English automatically.

-- English strings (used as fallback for missing translations)
local english = {}

-- L reads from the main table first, falls back to english table
local L = setmetatable({}, {
    __index = english,
})
---@type table<string, string>
BR.L = L

-- ============================================================================
-- CATEGORY LABELS
-- ============================================================================
english["Category.Raid"] = "Raid"
english["Category.Presence"] = "Presence"
english["Category.Targeted"] = "Targeted"
english["Category.Self"] = "Self"
english["Category.Pet"] = "Pet"
english["Category.Consumable"] = "Consumable"
english["Category.Custom"] = "Custom"
english["Category.Loadout"] = "Loadout"

-- Long form (used in Options section headers)
english["Category.RaidBuffs"] = "Raid Buffs"
english["Category.TargetedBuffs"] = "Targeted Buffs"
english["Category.Consumables"] = "Consumables"
english["Category.PresenceBuffs"] = "Presence Buffs"
english["Category.SelfBuffs"] = "Self Buffs"
english["Category.PetReminders"] = "Pet Reminders"
english["Category.CustomBuffs"] = "Custom Buffs"
english["Category.LoadoutReminders"] = "Loadout Reminders"

-- Category notes
english["Category.RaidNote"] = "(for the whole group)"
english["Category.TargetedNote"] = "(buffs on someone else)"
english["Category.ConsumableNote"] = "(flasks, food, runes, oils)"
english["Category.PresenceNote"] = "(at least 1 person needs)"
english["Category.SelfNote"] = "(buffs strictly on yourself)"
english["Category.PetNote"] = "(pet summon reminders)"
english["Category.CustomNote"] = "(track any buff/glow by spell ID)"
english["Category.LoadoutNote"] = "(remind me when my gear or talents don't match the content)"
english["Category.LoadoutTLXNote"] = "Talent Loadout Ex detected - its loadouts appear in the talent loadout picker."

-- Loadout reminders
english["Loadout.Add"] = "Add Loadout Reminder"
english["Loadout.Edit"] = "Edit Loadout Reminder"
english["Loadout.AddButton"] = "+ Add Loadout Reminder"
english["Loadout.Empty"] = "No loadout reminders yet. Add one below."
english["Loadout.Name"] = "Name"
english["Loadout.Expect"] = "EXPECT"
english["Loadout.Applies"] = "APPLIES TO"
english["Loadout.Content"] = "Content"
english["Loadout.Requirement"] = "Require"
english["Loadout.EquipmentSet"] = "Equipment set"
english["Loadout.TalentSpell"] = "Talent spell ID"
english["Loadout.NoSets"] = "No equipment sets found. Create one from the character sheet (Equipment Manager) first."
english["Loadout.NoSetSelected"] = "Select an equipment set first."
english["Loadout.NoLoadouts"] = "No saved talent loadouts for this spec."
english["Loadout.NoLoadoutSelected"] = "Select a talent loadout first."
english["Loadout.TLXTag"] = "|cff9d9d9d(Loadout Ex)|r"
english["Loadout.InvalidSpell"] = "That spell ID doesn't exist. Use a talent's spell ID."
english["Loadout.CombatBlocked"] = "Can't change gear or talents in combat."
english["Loadout.Instances"] = "%d instances"
english["Loadout.LimitRaids"] = "Only specific raids"
english["Loadout.LimitDungeons"] = "Only specific dungeons"
-- Content scope (you can't swap gear/talents once a key or match starts, so the
-- rule only needs the content you're in - no per-difficulty granularity).
english["Loadout.Scope.Raid"] = "Raid"
english["Loadout.Scope.Dungeon"] = "Dungeon"
english["Loadout.Scope.Arena"] = "Arena"
english["Loadout.Scope.Battleground"] = "Battleground"
-- Binding label: spec + class, e.g. "Protection Warrior" (reorder for your locale).
english["Loadout.SpecClass"] = "%s %s"
english["Loadout.Require.Gear"] = "Equipment set"
english["Loadout.Require.Talent"] = "Talent"
english["Loadout.Require.Loadout"] = "Talent loadout"
-- On-icon "what's wrong" tags (newline wraps them to two lines on the icon)
english["Loadout.Tag.Gear"] = "WRONG\nGEAR"
english["Loadout.Tag.Talent"] = "MISSING\nTALENT"
english["Loadout.Tag.Loadout"] = "WRONG\nBUILD"

-- ============================================================================
-- BUFF OVERLAY TEXT
-- ============================================================================
-- These must be kept very short (2-4 chars per line) to fit on small icons.
english["Overlay.NoDrPoison"] = "NO\nDR\nPOISON"
english["Overlay.NoAura"] = "NO\nAURA"
english["Overlay.NoStone"] = "NO\nSTONE"
english["Overlay.NoSoulstone"] = "NO\nSS"
english["Overlay.NoFaith"] = "NO\nFAITH"
english["Overlay.NoLight"] = "NO\nLIGHT"
english["Overlay.NoES"] = "NO\nES"
english["Overlay.NoSource"] = "NO\nSOURCE"
english["Overlay.NoScales"] = "NO\nSCALES"
english["Overlay.NoLink"] = "NO\nLINK"
english["Overlay.NoWeyrnstone"] = "NO\nWEYRN"
english["Overlay.NoTimeless"] = "NO\nTIMELESS"
english["Overlay.NoAttune"] = "NO\nATTUNE"
english["Overlay.NoFamiliar"] = "NO\nFAMILIAR"
english["Overlay.DropWell"] = "DROP\nWELL"
english["Overlay.NoGrim"] = "NO\nGRIM"
english["Overlay.BurningRush"] = "RUSH"
english["Overlay.NoRite"] = "NO\nRITE"
english["Overlay.ApplyPoison"] = "APPLY\nPOISON"
english["Overlay.NoForm"] = "NO\nFORM"
english["Overlay.NoEL"] = "NO\nEL"
english["Overlay.NoFT"] = "NO\nFT"
english["Overlay.NoTG"] = "NO\nTG"
english["Overlay.NoWF"] = "NO\nWF"
english["Overlay.NoSelfES"] = "NO\nSELF ES"
english["Overlay.NoShield"] = "NO\nSHIELD"
english["Overlay.NoPet"] = "NO\nPET"
english["Overlay.PassivePet"] = "PASSIVE\nPET"
english["Overlay.WrongPet"] = "WRONG\nPET"
english["Overlay.WrongStance"] = "WRONG\nSTANCE"
english["Overlay.WrongForm"] = "WRONG\nFORM"
english["Overlay.NoRune"] = "NO\nRUNE"
english["Overlay.DKWrongRune"] = "WRONG\nRUNE"
english["Overlay.DKWrongRuneOH"] = "WRONG\nOH\nRUNE"
english["Overlay.NoFlask"] = "NO\nFLASK"
english["Overlay.NoFood"] = "NO\nFOOD"
english["Overlay.NoWeaponBuff"] = "NO\nWEAPON\nBUFF"
english["Overlay.Buff"] = "BUFF!"
english["Overlay.MinutesFormat"] = "%dm"
english["Overlay.LessThanOneMinute"] = "<1m"
english["Overlay.SecondsFormat"] = "%ds"

-- ============================================================================
-- CONSUMABLE STAT LABELS (icon overlays, keep very short)
-- ============================================================================
english["Label.Crit"] = "Crit"
english["Label.Haste"] = "Haste"
english["Label.Versatility"] = "Vers"
english["Label.Mastery"] = "Mast"
english["Label.Stamina"] = "Stam"
english["Label.Healing"] = "Heal"
english["Label.Random"] = "Rand"
english["Label.Speed"] = "Speed"
english["Label.PvP"] = "PvP"
english["Label.Feast"] = "Feast"
english["Label.HasteShort"] = "H"
english["Label.VersatilityShort"] = "V"
english["Label.MasteryShort"] = "M"
english["Label.CritVers"] = "Crit/V"
english["Label.MasteryCrit"] = "M/Crit"
english["Label.MasteryVers"] = "M/V"
english["Label.MasteryHaste"] = "M/H"
english["Label.HasteCrit"] = "H/Crit"
english["Label.HasteVers"] = "H/V"
english["Label.StaminaStr"] = "Stam/Str"
english["Label.StaminaAgi"] = "Stam/Agi"
english["Label.StaminaInt"] = "Stam/Int"
english["Label.HighPrimary"] = "Hi 1st"
english["Label.HighSecondary"] = "Hi 2nd"
english["Label.MidPrimary"] = "Mid 1st"
english["Label.LowPrimary"] = "Lo 1st"
english["Label.LowSecondary"] = "Lo 2nd"
english["Label.RevivePet"] = "Revive Pet"
english["Label.Felguard"] = "Felguard"
english["Badge.Hearty"] = "H"
english["Badge.Fleeting"] = "F"

-- ============================================================================
-- BUFF NAMES (used in Options panel checkboxes and sound notification list)
-- ============================================================================
-- Raid
english["Buff.ArcaneIntellect"] = "Arcane Intellect"
english["Buff.BattleShout"] = "Battle Shout"
english["Buff.BlessingOfTheBronze"] = "Blessing of the Bronze"
english["Buff.MarkOfTheWild"] = "Mark of the Wild"
english["Buff.PowerWordFortitude"] = "Power Word: Fortitude"
english["Buff.Skyfury"] = "Skyfury"
-- Presence
english["Buff.AtrophicNumbingPoison"] = "Atrophic/Numbing Poison"
english["Buff.DevotionAura"] = "Devotion Aura"
english["Buff.Soulstone"] = "Soulstone"
-- Targeted
english["Buff.BeaconOfFaith"] = "Beacon of Faith"
english["Buff.BeaconOfLight"] = "Beacon of Light"
english["Buff.BlisteringScales"] = "Blistering Scales"
english["Buff.EarthShield"] = "Earth Shield"
english["Buff.SourceOfMagic"] = "Source of Magic"
english["Buff.SymbioticRelationship"] = "Symbiotic Relationship"
english["Buff.Timelessness"] = "Timelessness"
english["Buff.Weyrnstone"] = "Weyrnstone"
-- Self
english["Buff.ArcaneFamiliar"] = "Arcane Familiar"
english["Buff.Attunement"] = "Attunement"
english["Buff.CreateSoulwell"] = "Create Soulwell"
english["Buff.DruidForm"] = "Druid Form"
english["Buff.GrimoireOfSacrifice"] = "Grimoire of Sacrifice"
english["Buff.BurningRush"] = "Burning Rush"
english["Buff.RiteOfAdjuration"] = "Rite of Adjuration"
english["Buff.RiteOfSanctification"] = "Rite of Sanctification"
english["Buff.RoguePoisons"] = "Rogue Poisons"
english["Buff.RuneforgeMH"] = "Runeforge (Main Hand)"
english["Buff.RuneforgeOH"] = "Runeforge (Off Hand)"
english["Buff.Shadowform"] = "Shadowform"
english["Buff.EarthlivingWeapon"] = "Earthliving Weapon"
english["Buff.FlametongueWeapon"] = "Flametongue Weapon"
english["Buff.TidecallersGuard"] = "Tidecaller's Guard"
english["Buff.WindfuryWeapon"] = "Windfury Weapon"
english["Buff.EarthShieldSelf"] = "Earth Shield (Self)"
english["Buff.WaterLightningShield"] = "Water/Lightning Shield"
english["Buff.ShieldNoTalent"] = "Shield (No Talent)"
-- Pet
english["Buff.PetPassive"] = "Pet Passive"
english["Buff.HunterPet"] = "Hunter Pet"
english["Buff.UnholyGhoul"] = "Unholy Ghoul"
english["Buff.WarlockDemon"] = "Warlock Demon"
english["Buff.WaterElemental"] = "Water Elemental"
english["Buff.WrongDemon"] = "Wrong Demon"
english["Buff.WarriorStance"] = "Warrior Stance"
-- Consumable
english["Buff.AugmentRune"] = "Augment Rune"
english["Buff.Flask"] = "Flask"
english["Buff.DelveFood"] = "Delve Food"
english["Buff.Food"] = "Food"
english["Buff.Healthstone"] = "Healthstone"
english["Buff.Weapon"] = "Weapon"
english["Buff.WeaponOH"] = "Weapon (OH)"

-- ============================================================================
-- BUFF GROUP DISPLAY NAMES
-- ============================================================================
english["Group.Beacons"] = "Beacons"
english["Group.DKRunes"] = "Runeforges"
english["Group.ShamanImbues"] = "Shaman Imbues"
english["Group.PaladinRites"] = "Paladin Rites"
english["Group.Pets"] = "Pets"
english["Group.ShamanShields"] = "Shaman Shields"
english["Group.Flask"] = "Flask"
english["Group.Food"] = "Food"
english["Group.DelveFood"] = "Delve Food"
english["Group.Healthstone"] = "Healthstone"
english["Group.AugmentRune"] = "Augment Rune"
english["Group.WeaponBuff"] = "Weapon Buff"

-- ============================================================================
-- BUFF INFO TOOLTIPS
-- ============================================================================
english["Tooltip.MayShowExtraIcon"] = "May Show Extra Icon"
english["Tooltip.MayShowExtraIcon.Desc"] =
    "Until you cast this, you might see both this and the Water/Lightning Shield reminder. I can't tell if you want Earth Shield on yourself, or Earth Shield on an ally + Water/Lightning Shield on yourself."
english["Tooltip.InstanceEntryReminder"] = "Instance Entry Reminder"
english["Tooltip.InstanceEntryReminder.Desc"] =
    "Briefly shown when entering a dungeon as a reminder to drop a Soulwell. Dismissed after casting or after 30 seconds."
english["BuffTooltip.ProvidedBy"] = "Provided by %s"

-- ============================================================================
-- GLOW TYPE NAMES
-- ============================================================================
english["Glow.Pixel"] = "Pixel"
english["Glow.AutoCast"] = "AutoCast"
english["Glow.Border"] = "Border"
english["Glow.Proc"] = "Proc"

-- ============================================================================
-- CORE
-- ============================================================================
english["Core.Any"] = "Any"

-- ============================================================================
-- PROFILES
-- ============================================================================
english["Profile.SwitchQueued"] = "Profile switch queued until combat ends."
english["Profile.Switched"] = "Switched to profile '%s'."

-- ============================================================================
-- MOVERS
-- ============================================================================
english["Mover.SetPosition"] = "Set Position"
english["Mover.AnchorFrame"] = "Anchor Frame"
english["Mover.AnchorPoint"] = "Anchor Point"
english["Mover.NoneScreenCenter"] = "None (Screen Center)"
english["Mover.Apply"] = "Apply"
english["Mover.BuffAnchor"] = "Buff Anchor"
english["Mover.DragTooltip"] = "Drag to reposition\nClick to toggle coordinate editor"
english["Mover.MainEmpty"] = "Main (empty)"
english["Mover.MainAll"] = "Main (all)"
english["Mover.Detached"] = "Detached"

-- ============================================================================
-- DISPLAY
-- ============================================================================
english["Display.FramesLocked"] = "Frames locked."
english["Display.FramesUnlocked"] = "Frames unlocked."
english["Display.MinimapHidden"] = "Minimap icon hidden."
english["Display.MinimapShown"] = "Minimap icon shown."
english["Display.DebugEnabled"] = "Debug mode ENABLED. Run |cFFFFD100/br debug|r again to turn off."
english["Display.DebugDisabled"] = "Debug mode disabled."
english["Display.Description"] = "Track missing buffs at a glance."
english["Display.OpenOptions"] = "Open Options"
english["Display.SlashCommands"] = "Slash commands: /br, /br lock, /br unlock, /br test, /br minimap"
english["Display.MinimapLeftClick"] = "|cFFCFCFCFLeft click|r: Options"
english["Display.MinimapRightClick"] = "|cFFCFCFCFRight click|r: Test mode"
english["Display.DismissConsumables"] = "Hide consumable reminders until next loading screen"
english["Display.DismissConsumablesChat"] = "Consumable reminders hidden until next loading screen."
english["Display.LoginFirstInstall"] =
    "Thanks for installing! Type |cFFFFD100/br unlock|r to move the buff display, or use the button at the bottom of the |cFFFFD100/br|r options panel."
english["Display.LoginLoadout"] = "New: loadout reminders! Set them up on the Gear & Talents page in |cFFFFD100/br|r."
english["Display.LoginGlowDefaultChanged"] =
    "Buff glow is now off by default to reduce CPU usage. Re-enable it any time on the Defaults page in |cFFFFD100/br|r."

-- ============================================================================
-- OPTIONS: NAVIGATION LABELS
-- ============================================================================
english["Tab.DisplayBehavior"] = "Display/Behavior"

-- Sidebar groups
english["Sidebar.General"] = "General"
english["Sidebar.BuffsReminders"] = "Buffs & Reminders"
english["Sidebar.Appearance"] = "Appearance"
english["Sidebar.Display"] = "Display"
english["Sidebar.Alerts"] = "Alerts"
english["Sidebar.Profiles"] = "Profiles"

-- Page titles
english["Page.General"] = "General"
english["Page.Defaults"] = "Defaults"
english["Page.Visibility"] = "Visibility"
english["Page.ChatRequests"] = "Chat Requests"
english["Page.Layout"] = "Layout"
english["Page.Categories"] = "Categories"
english["Page.Profiles"] = "Profiles"
english["Page.AllBuffs"] = "All Buffs"

-- Per-category page section headers
english["Section.Tracking"] = "Tracking"
english["Section.TrackingOverrides"] = "Tracking Overrides"
english["Section.TrackingOverrides.Desc"] =
    "Narrow the tracking mode in specific situations. Leave a situation on Default to always use the mode above. When several apply at once (e.g. fighting while leveling), the most restrictive one wins."
english["DisabledReason.PvPDisabled"] = "This category is hidden in PvP entirely (see the Visibility page)."

-- ============================================================================
-- OPTIONS: SOUND ALERTS
-- ============================================================================
-- Sound alerts are set per buff in the buff panel (BuffPanel); the sound
-- dropdown + Preview button live there. The old standalone Sounds page and
-- add/edit dialog were retired, so only the in-panel labels remain.
english["Options.Sound.Preview"] = "Preview"
english["Options.Preview"] = "Preview"

-- ============================================================================
-- OPTIONS: GLOBAL DEFAULTS
-- ============================================================================
english["Options.GlobalDefaults"] = "Global Defaults"
english["Options.GlobalDefaults.Note"] = "(All categories inherit these unless overridden with a custom appearance)"
english["Options.Default"] = "Default"
english["Options.Font"] = "Font"
english["Options.TextOutline"] = "Outline"
english["Options.TextOutline.None"] = "None"
english["Options.TextOutline.Outline"] = "Outline"
english["Options.TextOutline.Thick"] = "Thick Outline"
english["Options.TextOutline.Monochrome"] = "Monochrome"
english["Options.TextOutline.OutlineMono"] = "Outline + Monochrome"
english["Options.TextOutline.ThickMono"] = "Thick + Monochrome"

-- ============================================================================
-- OPTIONS: GLOW SETTINGS
-- ============================================================================
english["Options.GlowReminderIcons.Title"] = "Glow Reminder Icons"
english["Options.GlowReminderIcons.CpuWarning"] =
    "Glow animates every frame for each icon on screen, so it uses more CPU. If an icon stays up for a long time (e.g. a buff you don't rebuff mid-fight), that cost is continuous. Disabled by default for this reason."
english["Options.GlowKind.Expiring"] = "Expiring"
english["Options.GlowKind.Missing"] = "Missing"
english["Options.ExpiringGlow"] = "Expiring glow"
english["Options.ExpiringGlow.Desc"] = "Glow icons whose buff is still active but running out soon."
english["Options.MissingGlow"] = "Missing glow"
english["Options.MissingGlow.Desc"] = "Glow icons whose buff is completely missing."
english["Options.GlowSettings.Expiring"] = "Glow Settings - Expiring"
english["Options.GlowSettings.Missing"] = "Glow Settings - Missing"
english["Options.Glow.Enabled"] = "Enabled"
english["Options.Threshold"] = "Threshold"
english["Options.GlowMissingPets"] = "Glow missing pets"
english["Options.Expiration"] = "Expiration"
english["Options.Glow"] = "Glow"
english["Options.UseCustomColor"] = "Use Custom Color"
english["Options.UseCustomColor.Desc"] =
    "When enabled, the proc glow is desaturated and recolored.\nThis looks less vibrant than the default proc glow."
english["Options.ExpirationReminder"] = "Expiration Reminder"
english["Options.Timing"] = "Timing"
english["Options.UseDefaultThreshold"] = "Use default threshold"
english["Options.UseDefaultThreshold.Desc"] =
    "When checked, this category follows the global expiration threshold from the Defaults page.\nUncheck to set a category-specific threshold."
english["Options.PreKeyThreshold"] = "Pre-Key Threshold"
english["Options.PreKeyThreshold.Desc"] =
    "Use a longer expiration threshold when inside a Mythic dungeon (M0) before a keystone is inserted.\nHelps ensure your buffs are fresh before the key goes in."

-- Glow params
english["Options.Glow.Type"] = "Type:"
english["Options.Glow.Size"] = "Size:"
english["Options.Glow.Duration"] = "Duration"
english["Options.Glow.Frequency"] = "Frequency"
english["Options.Glow.Length"] = "Length"
english["Options.Glow.Lines"] = "Lines"
english["Options.Glow.Particles"] = "Particles"
english["Options.Glow.Scale"] = "Scale"
english["Options.Glow.Speed"] = "Speed"
english["Options.Glow.StartAnimation"] = "Start Animation"
english["Options.Glow.XOffset"] = "X Offset"
english["Options.Glow.YOffset"] = "Y Offset"

-- ============================================================================
-- OPTIONS: CONTENT VISIBILITY
-- ============================================================================
english["Options.HidePvPMatchStart"] = "Hide when PvP match starts"
english["Options.HidePvPMatchStart.Title"] = "Hide When PvP Match Starts"
english["Options.HidePvPMatchStart.Desc"] = "Hide this category once a PvP match begins (after prep phase ends)."
english["Options.ReadyCheckOnly"] = "Show only on ready check"
english["Options.ReadyCheckOnly.Desc"] = "Only show this category's buffs for 15 seconds after a ready check starts"
english["Options.Visibility"] = "Visibility"

-- ============================================================================
-- OPTIONS: HEALTHSTONE
-- ============================================================================
english["Options.Healthstone.LowStock"] = "Warn when low"
english["Options.Healthstone.LowStock.Desc"] =
    "Show a soft warning when you have healthstones but not enough. Missing healthstones (0) are always tracked regardless of this setting."
english["Options.Healthstone.Threshold"] = "Warn when having"
english["Options.Healthstone.Threshold.Desc"] =
    "Show a low-stock warning when you have this many healthstones or fewer.\n\n|cffffcc001:|r Warn when you have exactly 1.\n|cffffcc002:|r Warn when you have 1 or 2."

-- ============================================================================
-- OPTIONS: SOULSTONE
-- ============================================================================
english["Options.Soulstone.HideCooldown"] = "Hide when on cooldown (warlock)"
english["Options.Soulstone.HideCooldown.Desc"] =
    "When enabled, warlocks won't see the soulstone reminder while the spell is on cooldown. Only applies to warlocks."

-- ============================================================================
-- OPTIONS: FREE CONSUMABLES
-- ============================================================================
english["Options.FreeConsumables"] = "Free Consumables"
english["Options.FreeConsumables.Note"] = "(healthstones, permanent augment runes)"
english["Options.FreeConsumables.Override"] = "Override content filters"
english["Options.FreeConsumables.Override.Desc"] =
    "When checked, free consumables use their own content type visibility settings below.\n\nWhen unchecked, they follow the same content filters as other consumables."

-- ============================================================================
-- OPTIONS: ICONS
-- ============================================================================
english["Options.Icons"] = "Icons"
english["Options.ShowText"] = "Show text on icons"
english["Options.ShowText.Desc"] =
    "Display count and missing-buff text overlays on buff icons for this category. The expiring countdown timer always stays visible"
english["Options.ShowMissingCountOnly"] = "Show missing count only"
english["Options.ShowMissingCountOnly.Desc"] =
    'Show only the number of missing buffs (e.g., "1") instead of the full count (e.g., "19/20")'
english["Options.ShowBuffReminderText"] = 'Show "BUFF!" reminder text'
english["Options.Size"] = "Size"

-- ============================================================================
-- OPTIONS: TEXT POSITIONS
-- ============================================================================
english["Options.TextPositions"] = "Text"
english["Options.TextPositions.Zone"] = "Position"
english["Options.TextPositions.OffsetX.Short"] = "X"
english["Options.TextPositions.OffsetY.Short"] = "Y"
english["Options.TextPositions.StackCount"] = "Stack count"
english["Options.TextPositions.StatLabel"] = "Stat label"
english["Options.TextPositions.Badge"] = "Badge (H / F)"
english["Options.TextPositions.Vertical.Above"] = "Above"
english["Options.TextPositions.Vertical.InsideTop"] = "Top"
english["Options.TextPositions.Vertical.InsideMiddle"] = "Center"
english["Options.TextPositions.Vertical.InsideBottom"] = "Bottom"
english["Options.TextPositions.Vertical.Below"] = "Below"
english["Options.TextPositions.Align.Left"] = "Left"
english["Options.TextPositions.Align.Center"] = "Center"
english["Options.TextPositions.Align.Right"] = "Right"

-- ============================================================================
-- OPTIONS: CLICK TO CAST
-- ============================================================================
english["Options.ClickToCast"] = "Click to cast"
english["Options.ClickToCast.DescFull"] =
    "Make buff icons clickable to cast the corresponding spell (out of combat only). Only works for spells your character can cast."
english["Options.HoverHighlight"] = "Hover highlight"
english["Options.HoverHighlight.Desc"] = "Show a subtle highlight when hovering over clickable buff icons."
english["Options.RequestBuffInChat"] = "Request missing buffs in chat"
english["Options.RequestBuffInChat.Desc"] =
    "Click a missing buff your class cannot provide to request it in chat. Auto-detects channel (instance/raid/party/say)."
english["Options.ChatRequest.Cooldown"] = "Chat request cooldown"
english["Options.ChatRequest.Cooldown.Desc"] =
    "Waits 5 seconds between chat requests to prevent accidental spam-clicking.\nIf your requests sometimes aren't sent to chat at all, turn this off."
english["Options.ChatRequest.Cooldown.Hint"] = "Requests not showing up in chat? Turn this off."
english["Options.ChatRequest.ResetAll"] = "Reset All"
english["ChatRequests.PerBuffMessages"] = "Per-buff messages"
-- Chat request messages (keyed by buff.key, sent as-is via SendChatMessage)
-- EU/US translators: leave untranslated so chat messages stay in English.
-- Asian translators: translate these so chat messages match your locale.
english["ChatRequest.intellect"] = "Arcane Intellect buff pls"
english["ChatRequest.attackPower"] = "Battle Shout buff pls"
english["ChatRequest.bronze"] = "Blessing of the Bronze buff pls"
english["ChatRequest.versatility"] = "Mark of the Wild buff pls"
english["ChatRequest.stamina"] = "Power Word: Fortitude buff pls"
english["ChatRequest.skyfury"] = "Skyfury buff pls"
english["ChatRequest.atrophicNumbingPoison"] = "Atrophic/Numbing Poison pls"
english["ChatRequest.devotionAura"] = "Devotion Aura pls"
english["ChatRequest.soulstone"] = "Soulstone pls"
english["ChatRequest.healthstone"] = "Healthstones pls"

-- ============================================================================
-- OPTIONS: PET
-- ============================================================================
english["Options.PetSpecIcon"] = "Show hunter pet spec icon on hover"
english["Options.PetSpecIcon.Title"] = "Pet spec icon on hover"
english["Options.PetSpecIcon.Desc"] =
    "Swap the pet icon to its specialization ability (Cunning, Ferocity, Tenacity) when hovering."
english["Options.ShowItemTooltips"] = "Show item tooltips"
english["Options.ShowItemTooltips.Desc"] = "When hovering over a consumable icon, show its item tooltip."
english["Options.ShowBuffTooltips"] = "Show buff tooltips"
english["Options.ShowBuffTooltips.Desc"] =
    "When hovering over a raid or presence buff icon, show the spell tooltip and which class provides the buff."
english["Options.Behavior"] = "Behavior"
english["Options.PetPassiveCombat"] = "Pet passive only in combat"
english["Options.PetPassiveCombat.Desc"] =
    "Only show the passive pet reminder while in combat. When disabled, the reminder is always shown."
english["Options.FelDomination"] = "Use Fel Domination before summoning"
english["Options.FelDomination.Title"] = "Fel Domination"
english["Options.FelDomination.Desc"] =
    "Automatically cast Fel Domination before summoning a demon via click-to-cast. If Fel Domination is on cooldown, the summon proceeds normally. Requires the Fel Domination talent."

-- ============================================================================
-- OPTIONS: PET DISPLAY
-- ============================================================================
english["Options.PetDisplay"] = "Pet display"
english["Options.PetDisplay.Generic"] = "Generic icon"
english["Options.PetDisplay.GenericDesc"] = "A single generic 'NO PET' icon"
english["Options.PetDisplay.Summon"] = "Summon spells"
english["Options.PetDisplay.SummonDesc"] = "Each pet summon spell as its own icon"
english["Options.PetDisplay.Mode"] = "Pet display mode"
english["Options.PetDisplay.Mode.Desc"] = "How missing pet reminders are displayed."
english["Options.PetLabels"] = "Pet labels"
english["Options.PetLabels.Desc"] = "Show pet name and specialization below each icon."
english["Options.PetLabels.SizePct"] = "Size %"

-- ============================================================================
-- OPTIONS: CONSUMABLE DISPLAY
-- ============================================================================
english["Options.ConsumableTextScale"] = "Text scale"
english["Options.ConsumableTextScale.Title"] = "Consumable text scale"
english["Options.ConsumableTextScale.Desc"] =
    "Font size for item counts and quality (R1/R2/R3) labels as a percentage of icon size."
english["Options.HideConsumableLabels"] = "Hide stat labels"
english["Options.HideConsumableLabels.Title"] = "Hide consumable stat labels"
english["Options.HideConsumableLabels.Desc"] =
    'Hide the small stat labels (e.g. "Hi 1st", "Lo 2nd") shown on the top-left of consumable icons.'
english["Options.ItemDisplay"] = "Item display"
english["Options.ItemDisplay.IconOnly"] = "Icon only"
english["Options.ItemDisplay.IconOnlyDesc"] = "Shows the item with the highest count"
english["Options.ItemDisplay.SubIcons"] = "Sub-icons"
english["Options.ItemDisplay.SubIconsDesc"] = "Small clickable item variants below each icon"
english["Options.ItemDisplay.Expanded"] = "Expanded"
english["Options.ItemDisplay.ExpandedDesc"] = "Each item variant as a full-sized icon"
english["Options.ItemDisplay.Mode"] = "Consumable item display"
english["Options.ItemDisplay.Mode.Desc"] =
    "How consumable items with multiple variants (e.g. different flask types) are displayed."
english["Options.SubIconSide"] = "Side"
english["Options.SubIconSide.Bottom"] = "Bottom"
english["Options.SubIconSide.Top"] = "Top"
english["Options.SubIconSide.Left"] = "Left"
english["Options.SubIconSide.Right"] = "Right"
english["Options.ShowWithoutItems"] = "Show when not in bags"
english["Options.ShowWithoutItems.Title"] = "Show consumables without items"
english["Options.ShowWithoutItems.Desc"] =
    "When enabled, consumable reminders are shown even if you don't have the item in your bags. When disabled, only consumables you actually carry are shown."
english["Options.ShowWithoutItemsReadyCheckOnly"] = "Only on ready check"
english["Options.ShowWithoutItemsReadyCheckOnly.Title"] = "Show missing items only on ready check"
english["Options.ShowWithoutItemsReadyCheckOnly.Desc"] =
    "When enabled, consumables not in your bags are only shown during a ready check. Useful for a quick reminder to restock before a pull."
english["Options.DelveFoodOnly"] = "Only delve food in delves"
english["Options.DelveFoodOnly.Desc"] = "When inside a delve, hide all consumable reminders except delve food."
english["Options.HideLegacyConsumables"] = "Hide legacy consumables"
english["Options.HideLegacyConsumables.Title"] = "Hide legacy consumables"
english["Options.HideLegacyConsumables.Desc"] =
    "When enabled, food, flasks, and runes from previous expansions are filtered out of the action buttons. Disable if you still use older consumables for Timewalking, old-raid farming, or undergeared alts."

-- ============================================================================
-- OPTIONS: DK RUNEFORGE PREFERENCES
-- ============================================================================
english["Options.RuneMainHand"] = "Main Hand"
english["Options.RuneOffHand"] = "Off Hand"
english["Options.RuneTwoHanded"] = "Two-Handed"
english["Options.RuneDualWield"] = "Dual Wield"

-- ============================================================================
-- OPTIONS: ROGUE POISON PREFERENCES
-- ============================================================================
english["Options.RoguePoisonNote"] =
    "Choose which poisons to apply and their priority order (top = highest). Disabled poisons are never cast and do not trigger reminders."
english["Options.PoisonLethal"] = "Lethal"
english["Options.PoisonNonLethal"] = "Non-Lethal"
english["Options.PoisonMoveUp"] = "Move up in priority"
english["Options.PoisonMoveDown"] = "Move down in priority"
english["Options.PoisonReset"] = "Reset to Default"

-- ============================================================================
-- OPTIONS: BUFF SETTINGS GEAR ICONS
-- ============================================================================
english["Options.BronzeHideInCombat"] = "Hide in combat"
english["Options.BronzeHideInCombat.Desc"] =
    "Hide the Blessing of the Bronze reminder during combat. This buff is less critical and you may not want to rebuff mid-fight."
english["Options.DruidIgnoreTravelForm"] = "Ignore while traveling"
english["Options.DruidIgnoreTravelForm.Desc"] =
    "Hide the wrong-form reminder while in Travel Form (ground, aquatic, flight, or Mount Form) or while mounted, so it doesn't nag you when you're intentionally traveling."
english["Options.DelveFoodTimer"] = "Auto-hide after 30 seconds"
english["Options.DelveFoodTimer.Desc"] =
    "When enabled, the delve food reminder only appears for 30 seconds after entering a delve, then hides automatically. When disabled, the reminder stays visible as long as you are in a delve and missing the buff."

-- ============================================================================
-- OPTIONS: LAYOUT
-- ============================================================================
english["Options.Layout"] = "Layout"
english["Options.SplitFrame"] = "Split into separate frame"
english["Options.SplitFrame.Desc"] = "Display this category's buffs in a separate, independently movable frame"

-- Display Order section (Defaults page) - drives the same priority field the
-- old per-category slider wrote, but as a single ordered list across all
-- non-split categories.
english["Options.DisplayOrder"] = "Stacking Order"
english["Options.DisplayOrder.Moved"] = "Looking for Display Order? It moved to the Layout page."

-- Layout page
english["Layout.PositionFrames"] = "Position Frames"
english["Layout.PositionFrames.Note"] =
    "Unlock to get drag handles in-game. Click a handle to type exact coordinates; drag to reposition. Anchored frames keep their anchor while dragging."
english["Layout.SplitFrames"] = "Split Frames"
english["Layout.SplitFrames.Note"] =
    "Categories split into their own independently positioned frame. Split a category from the Layout section of its page."
english["Layout.NoSplitFrames"] = "No categories are split into their own frame."
english["Layout.DetachedIcons"] = "Detached Icons"
english["Layout.NoDetached"] =
    'No detached icons. Detach a buff from its settings panel on the All Buffs page ("Own frame").'
english["Layout.AnchorTargets"] = "Anchor Targets"
english["Layout.AnchorFrame.Desc"] = "Attach this frame to another frame instead of a fixed screen position."
english["Layout.AnchorPoint.Desc"] = "Which corner or edge of the anchor frame to attach to."
english["Layout.FrameNotFound"] =
    "This frame doesn't currently exist in-game.\nIt will appear in anchor dropdowns once its addon creates it."
english["DisabledReason.AnchorPoint"] =
    "Pick an anchor frame first - anchor points only apply when anchored to a frame."

-- Buff panel (uniform per-buff settings dialog)
english["BuffPanel.SettingsLink"] = "Settings"
english["BuffRow.SettingsLink.Tooltip"] = "Sound alert, show mode, and detach options for this buff."
-- Row captions: the gold "option: value" line under buffs with their own
-- options (All Buffs page). %s is the current value. The trailing "clickable
-- link" chevron is appended in code (_BuffRow.lua), not stored here, so
-- translators never handle the raw escape.
english["BuffRow.Caption.Poisons"] = "Poisons: %s"
english["BuffRow.Caption.PoisonsUnset"] = "Choose which poisons you use"
english["BuffRow.Caption.Runeforge"] = "Runeforge: %s"
english["BuffRow.Caption.RuneforgeUnset"] = "Set your runeforge per spec"
english["BuffRow.Caption.Healthstone"] = "Low-stock alert: below %d"
english["BuffRow.Caption.HealthstoneOff"] = "Low-stock alert: off"
english["BuffRow.Caption.SoulstoneHidden"] = "Hidden while on cooldown"
english["BuffRow.Caption.SoulstoneShown"] = "Shown while on cooldown"
english["BuffRow.Caption.BronzeHidden"] = "Hidden in combat"
english["BuffRow.Caption.BronzeShown"] = "Shown in combat"
english["BuffRow.Caption.TravelIgnored"] = "Travel Form ignored"
english["BuffRow.Caption.TravelCounts"] = "Travel Form counts as wrong"
english["BuffRow.Caption.PetPassiveCombat"] = "Warns in combat only"
english["BuffRow.Caption.PetPassiveAlways"] = "Warns anywhere"
english["BuffRow.Caption.FelOn"] = "Uses Fel Domination"
english["BuffRow.Caption.FelOff"] = "Fel Domination off"
english["BuffRow.Caption.FoodTimerOn"] = "Shows expiry timer"
english["BuffRow.Caption.FoodTimerOff"] = "No expiry timer"
-- Trailing link on the All Buffs row: a gold "Extras" for any buff with its own
-- options (vs the gray "Settings" for the rest); the specific option is named
-- inside the drawer. The two rich editors keep their name for the drawer's
-- "Edit X" door.
english["BuffRow.Extras"] = "Extras"
english["BuffRow.Option.Poisons"] = "Poisons"
english["BuffRow.Option.Runeforge"] = "Runeforge"
-- Row state glyph tooltips (the small sound / pin markers left of the link).
english["BuffRow.Glyph.Sound"] = "Sound alert"
english["BuffRow.Glyph.Detached"] = "Detached icon"
english["BuffRow.Glyph.Detached.Desc"] =
    "This icon is placed freely on screen. Manage it in the buff's Settings or on the Layout page."
-- Drawer door to a buff's focused editor (poison/runeforge). %s = option name.
english["BuffPanel.EditOption"] = "Edit %s"
english["BuffPanel.Show"] = "Show"
english["BuffPanel.Sound"] = "Sound"
english["BuffPanel.Sound.None"] = "None"
english["BuffPanel.Detached"] = "Own frame (detached)"
english["BuffPanel.Detached.Desc"] =
    "Pull this buff out of its category into its own independently positioned frame.\nPosition it from the Layout page or by unlocking frames."
english["BuffPanel.CasterAlways"] = "Warlocks always see it"
english["BuffPanel.CasterAlways.Desc"] =
    "Warlocks (who provide this) always see the reminder; everyone else only on ready check."
english["DisabledReason.NotDetached"] = "This buff isn't detached - it sits inside its category frame."
english["DisabledReason.CasterAlways"] = 'Only applies in ready-check mode. Switch "Show" back to ready check first.'
english["Options.DisplayOrder.Note"] =
    "How categories stack inside the combined frame, from top to bottom. Split categories live in their own frames and don't participate."

-- Detached Icons (inline manager on the Layout page).
english["DetachedIcons.Reattach"] = "Return to category"
english["DetachedIcons.ResetPos"] = "Reset position"

-- ============================================================================
-- OPTIONS: APPEARANCE
-- ============================================================================
english["Options.Appearance"] = "Appearance"
english["Options.Override"] = "Override"
english["Options.Override.Inherited"] = "Inherited from Defaults"
english["Options.Override.Overriding"] = "Overriding defaults"
english["Options.Override.Appearance.Desc"] =
    "Override the global appearance defaults for this category.\nWhile off, the controls below show the inherited values from the Defaults page."
english["Options.Override.Glow.Desc"] =
    "Override the global glow settings for this category.\nWhile off, the controls below show the inherited values from the Defaults page."
english["Options.Customize"] = "Customize"
english["Options.ResetPosition"] = "Reset Position"
english["Options.MasqueNote"] = "Zoom and Border settings are managed by Masque"

-- ============================================================================
-- OPTIONS: SETTINGS TAB
-- ============================================================================
english["Options.ShowLoginMessages"] = "Show login messages"
english["Options.ShowMinimapButton"] = "Show minimap button"

-- Hide when section
english["Options.HideWhen"] = "Hide when"
english["Options.HideWhen.Alone"] = "Alone"
english["Options.HideWhen.Alone.Title"] = "Hide while alone"
english["Options.HideWhen.Alone.Desc"] = "Hide all buff reminders while not in a party or raid group"
english["Options.HideWhen.Resting"] = "Resting"
english["Options.HideWhen.Resting.Title"] = "Hide while resting"
english["Options.HideWhen.Resting.Desc"] = "Hide buff reminders while in inns or capital cities"
english["Options.HideWhen.Combat"] = "In combat"
english["Options.HideWhen.Expiring"] = "Expiring in combat"
english["Options.HideWhen.Expiring.Title"] = "Hide expiring buffs in combat"
english["Options.HideWhen.Expiring.Desc"] =
    "During combat, hide buffs that are expiring soon and only show completely missing ones"
english["Options.HideWhen.Vehicle"] = "In vehicle"
english["Options.HideWhen.Vehicle.Title"] = "Hide in vehicle"
english["Options.HideWhen.Vehicle.Desc"] =
    "Hide all buff reminders while in a quest vehicle. When disabled, raid and presence buffs still show"
english["Options.HideWhen.Mounted"] = "Mounted"
english["Options.HideWhen.Mounted.Title"] = "Hide while mounted"
english["Options.HideWhen.Mounted.Desc"] =
    "Hide all buff reminders while mounted. Overrides the per-category pet mount hiding setting"
english["Options.HideWhen.Legacy"] = "In legacy instances"
english["Options.HideWhen.Legacy.Title"] = "Hide in legacy instances"
english["Options.HideWhen.Legacy.Desc"] =
    "Hide all buff reminders in trivially old instances (where legacy loot is enabled)"
english["Options.HideWhen.Leveling"] = "Leveling"
english["Options.HideWhen.Leveling.Title"] = "Hide while leveling"
english["Options.HideWhen.Leveling.Desc"] = "Hide all buff reminders when below max level"

-- ============================================================================
-- OPTIONS: BUFF TRACKING MODE
-- ============================================================================
english["Options.BuffTracking"] = "Buff tracking"
english["Options.BuffTracking.All"] = "All buffs, all players"
english["Options.BuffTracking.All.Desc"] =
    "Show all raid and presence buffs for every class, tracking full group coverage."
english["Options.BuffTracking.MyBuffs"] = "Only my buffs, all players"
english["Options.BuffTracking.MyBuffs.Desc"] =
    "Only show buffs your class can provide. Still tracks full group coverage."
english["Options.BuffTracking.OnlyMine"] = "All buffs, just on me"
english["Options.BuffTracking.OnlyMine.Desc"] =
    "Show all buff types, but only check whether you personally have them. No group counts."
english["Options.BuffTracking.SelfOnly"] = "Only my buffs, just on me"
english["Options.BuffTracking.SelfOnly.Desc"] =
    "Only show buffs your class can provide, and only check whether you personally have them. No group counts, no buffs you cast on others."
english["Options.BuffTracking.Smart"] = "Smart"
english["Options.BuffTracking.Smart.Desc"] =
    "Buffs your class provides track full group coverage. Other class buffs only check you personally."
english["Options.BuffTracking.Mode"] = "Buff tracking mode"
english["Options.BuffTracking.Mode.Desc"] =
    "Controls which raid and presence buffs are shown, and whether they track the full group or only you."
english["Options.BuffTracking.Override.Default"] = "Default (use mode above)"
english["Options.BuffTracking.Override.OutsideInstances"] = "Outside dungeons & raids"
english["Options.BuffTracking.Override.OutsideInstances.Desc"] =
    "Tracking mode to use in the open world. The mode selected above is still used inside dungeons, raids, scenarios, and PvP."
english["Options.BuffTracking.Override.Combat"] = "In combat"
english["Options.BuffTracking.Override.Combat.Desc"] =
    "Tracking mode to use while in combat. For example, narrowing to 'Only my buffs' keeps reminders for buffs from other classes visible out of combat so you can call them out, but hides them once the fight starts."
english["Options.BuffTracking.Override.Leveling"] = "While leveling"
english["Options.BuffTracking.Override.Leveling.Desc"] =
    "Tracking mode to use below max level. Once you reach max level, the mode selected above is used."

-- ============================================================================
-- OPTIONS: PROFILES TAB
-- ============================================================================
english["Options.ActiveProfile"] = "Active Profile"
english["Options.ActiveProfile.Desc"] =
    "Switch between saved configurations. Each character can use a different profile."
english["Options.SelectProfile"] = "Select a profile"
english["Options.Profile"] = "Profile"
english["Options.CopyFrom"] = "Copy From"
english["Options.Delete"] = "Delete"
english["Options.PerSpecProfiles"] = "Per-Specialization Profiles"
english["Options.PerSpecProfiles.Desc"] = "Automatically switch profiles when you change specialization."
english["Options.PerSpecProfiles.Enable"] = "Enable per-specialization profiles"

-- ============================================================================
-- OPTIONS: IMPORT/EXPORT
-- ============================================================================
english["Options.ExportSettings"] = "Export Settings"
english["Options.ExportSettings.Desc"] = "Copy the string below to share your settings with others."
english["Options.ImportSettings"] = "Import Settings"
english["Options.ImportSettings.DescPlain"] = "Paste a settings string below."
english["Options.ImportSettings.Overwrite"] = "This will overwrite the active profile."
english["Options.Export"] = "Export"
english["Options.Import"] = "Import"
english["Options.ImportSuccess"] = "Settings imported successfully!"
english["Options.FailedExport"] = "Failed to export"
english["Options.UnknownError"] = "Unknown error"

-- ============================================================================
-- OPTIONS: DIALOGS
-- ============================================================================
english["Dialog.Cancel"] = "Cancel"
english["Dialog.DeleteCustomBuff"] = 'Delete custom buff "%s"?'
english["Dialog.DeleteLoadout"] = 'Delete loadout reminder "%s"?'
english["Dialog.ResetProfile"] =
    "Reset the active profile to defaults?\n\nThis will erase all customizations\nin the current profile and reload the UI."
english["Dialog.Reset"] = "Reset"
english["Dialog.ReloadPrompt"] = "Settings imported successfully!\nReload UI to apply changes?"
english["Dialog.Reload"] = "Reload"
english["Dialog.NewProfilePrompt"] = "Enter a name for the new profile:"
english["Dialog.Create"] = "Create"
english["Dialog.DiscordPrompt"] = "Join the BuffReminders Discord!\nCopy the URL below (Ctrl+C):"
english["Dialog.KofiPrompt"] = "Thank you for supporting BuffReminders!\nCopy the URL below (Ctrl+C):"
english["Dialog.Close"] = "Close"

-- ============================================================================
-- OPTIONS: TEST / LOCK
-- ============================================================================
english["Options.LockUnlock"] = "Lock / Unlock"
english["Options.LockUnlock.Desc"] = "Unlock to show anchor handles for repositioning buff frames."
english["Options.TestAppearance"] = "Test icon's appearance"
english["Options.TestAppearance.Desc"] =
    "Shows your selected buffs with fake values so you can preview their appearance."
english["Options.Test"] = "Test"
english["Options.StopTest"] = "Stop Test"
english["Options.AnchorHint"] = "Click an anchor to update its anchor point or coordinates"
english["Options.Lock"] = "Lock"
english["Options.Unlock"] = "Unlock"

-- ============================================================================
-- OPTIONS: CUSTOM BUFF DIALOG
-- ============================================================================
english["CustomBuff.Edit"] = "Edit Custom Buff"
english["CustomBuff.EditShort"] = "Edit"
english["CustomBuff.Add"] = "Add Custom Buff"
english["CustomBuff.AddButton"] = "+ Add Custom Buff"
english["CustomBuff.Empty"] = "No custom buffs yet. Add one below."
english["CustomBuff.SpellIDs"] = "Spell IDs:"
english["CustomBuff.Lookup"] = "Lookup"
english["CustomBuff.AddSpellID"] = "+ Add Spell ID"
english["CustomBuff.Name"] = "Name:"
english["CustomBuff.Text"] = "Text:"
english["CustomBuff.LineBreakHint"] = "(use \\n for line break)"
english["CustomBuff.Appearance"] = "APPEARANCE"
english["CustomBuff.BuffTracking"] = "BUFF TRACKING"
english["CustomBuff.Requirements"] = "REQUIREMENTS"
english["CustomBuff.ShowIn"] = "SHOW IN"
english["CustomBuff.ClickAction"] = "CLICK ACTION"

-- Custom buff mode toggles
english["CustomBuff.WhenActive"] = "When active"
english["CustomBuff.WhenMissing"] = "When missing"
english["CustomBuff.OnlyIfSpellKnown"] = "Only if spell known"

-- Custom buff class dropdown
english["Class.Any"] = "Any"
english["Class.DeathKnight"] = "Death Knight"
english["Class.DemonHunter"] = "Demon Hunter"
english["Class.Druid"] = "Druid"
english["Class.Evoker"] = "Evoker"
english["Class.Hunter"] = "Hunter"
english["Class.Mage"] = "Mage"
english["Class.Monk"] = "Monk"
english["Class.Paladin"] = "Paladin"
english["Class.Priest"] = "Priest"
english["Class.Rogue"] = "Rogue"
english["Class.Shaman"] = "Shaman"
english["Class.Warlock"] = "Warlock"
english["Class.Warrior"] = "Warrior"

-- Custom buff fields
english["CustomBuff.Spec"] = "Spec:"
english["CustomBuff.Class"] = "Class:"
english["CustomBuff.RequireItem"] = "Require item:"
english["CustomBuff.RequireItem.EquippedBags"] = "Equipped/Bags"
english["CustomBuff.RequireItem.Equipped"] = "Equipped"
english["CustomBuff.RequireItem.InBags"] = "In bags"
english["CustomBuff.RequireItem.Hint"] = "item ID - hide if not found"
english["CustomBuff.ItemCooldown"] = "Cooldown:"
english["CustomBuff.ItemCooldown.Any"] = "Any"
english["CustomBuff.ItemCooldown.OffCooldown"] = "Off cooldown"
english["CustomBuff.ItemCooldown.OnCooldown"] = "On cooldown"

-- Bar glow options
english["CustomBuff.BarGlow.WhenGlowing"] = "Detect when glowing"
english["CustomBuff.BarGlow.WhenNotGlowing"] = "Detect when not glowing"
english["CustomBuff.BarGlow.Disabled"] = "Disabled"
english["CustomBuff.BarGlow"] = "Bar glow:"
english["CustomBuff.BarGlow.Title"] = "Action bar glow fallback"
english["CustomBuff.BarGlow.Desc"] =
    "Fallback detection using action bar spell glows during M+/PvP/combat when buff API is restricted. Disable if you only want buff presence tracking."

-- Ready check / level
english["CustomBuff.ReadyCheckOnly"] = "Only on ready check"
english["CustomBuff.Level"] = "Level:"
english["CustomBuff.Level.Any"] = "Any level"
english["CustomBuff.Level.Max"] = "Max level only"
english["CustomBuff.Level.BelowMax"] = "Below max level"

-- Click action
english["CustomBuff.Action.None"] = "None"
english["CustomBuff.Action.Spell"] = "Spell"
english["CustomBuff.Action.Item"] = "Item"
english["CustomBuff.Action.Macro"] = "Macro"
english["CustomBuff.Action.OnClick"] = "On click:"
english["CustomBuff.Action.Title"] = "Click action"
english["CustomBuff.Action.Desc"] =
    "What happens when you click this buff icon. Spell casts a spell, Item uses an item, Macro runs a macro command."
english["CustomBuff.Action.MacroHint"] = "e.g. /use item:12345\\n/use 13"

-- Save/Cancel/Delete
english["CustomBuff.Save"] = "Save"
english["CustomBuff.ValidateError"] = "Please validate at least one spell ID"

-- Custom buff status
english["CustomBuff.InvalidID"] = "Invalid ID"
english["CustomBuff.NotFound"] = "Not found"
english["CustomBuff.NotFoundRetry"] = "Not found (try again)"
english["CustomBuff.Error"] = "Error:"

-- ============================================================================
-- OPTIONS: DISCORD
-- ============================================================================
english["Options.JoinDiscord"] = "Join Discord"
english["Options.JoinDiscord.Title"] = "Click for invite link"
english["Options.JoinDiscord.Desc"] = "Got feedback, feature requests, or bug reports?\nJoin the Discord!"

-- ============================================================================
-- OPTIONS: KO-FI
-- ============================================================================
english["Options.SupportKofi"] = "Support on Ko-fi"
english["Options.SupportKofi.Title"] = "Click for the link"
english["Options.SupportKofi.Desc"] = "Enjoying BuffReminders?\nConsider supporting development on Ko-fi!"

-- ============================================================================
-- OPTIONS: CUSTOM ANCHOR FRAMES
-- ============================================================================
english["Options.CustomAnchorFrames.Desc"] =
    "Add global frame names to the anchor dropdown (e.g. MyAddon_PlayerFrame). \nFrames that don't exist in-game are silently skipped."
english["Options.Add"] = "Add"
english["Options.New"] = "New"
english["Options.ResetToDefaults"] = "Reset to Defaults"

-- ============================================================================
-- OPTIONS: MISC
-- ============================================================================
english["Options.Off"] = "Off"
english["Options.Always"] = "Always"
english["Options.ReadyCheck"] = "Ready check"
english["Options.Min"] = "min"

-- ============================================================================
-- COMPONENTS (UI/Components.lua)
-- ============================================================================
-- Content filter tooltip
english["Content.ClickToFilter"] = "Click to filter by %s difficulty"

-- Mover labels
english["Mover.AnchorGrowth"] = "Anchor · Growth %s"
english["Mover.AnchorGrowthFrame"] = "Anchor · Growth %s · > %s"

-- Pet labels
english["Pet.SpiritBeast"] = "Spirit Beast"

-- Appearance grid labels
english["Appearance.Width"] = "Width"
english["Appearance.Height"] = "Height"
english["Appearance.Zoom"] = "Zoom"
english["Appearance.Border"] = "Border"
english["Appearance.Spacing"] = "Spacing"
english["Appearance.Alpha"] = "Alpha"
english["Appearance.Text"] = "Text"

-- Slider tooltip
english["Component.AdjustValue"] = "Adjust value"
english["Component.AdjustValue.Desc"] = "Click to type or use mouse wheel"
english["Component.AdjustValue.ClickHint"] = "Click the number to input a specific value"

-- Scope tag for globally-stored controls on category pages
english["Options.GlobalTag"] = "GLOBAL"
english["Options.GlobalTag.Title"] = "Applies everywhere"
english["Options.GlobalTag.Desc"] =
    "This setting is stored once for the whole addon.\nChanging it here changes it for every category, not just this one."

-- Disabled-control explanations (shown on hover while the control is disabled)
english["Component.DisabledReason.Title"] = "Why is this disabled?"
english["DisabledReason.GrowDirection"] =
    'Grow direction needs this category in its own frame.\nEnable "Split into separate frame" in the Layout section first.'
english["DisabledReason.ResetPosition"] =
    'Only split categories have their own position.\nEnable "Split into separate frame" first.'
english["DisabledReason.OverrideSection"] = 'Turn on "Override" at the top of this section first.'
english["DisabledReason.CombatOverride"] =
    '"In combat" hiding is enabled above, so nothing shows in combat and this override would have no effect.\nUncheck it to use a combat tracking override.'
english["DisabledReason.LevelingOverride"] =
    '"Leveling" hiding is enabled above, so nothing shows while leveling and this override would have no effect.\nUncheck it to use a leveling tracking override.'
english["DisabledReason.ExpiringInCombat"] =
    '"In combat" hiding is enabled, so everything is already hidden during combat.'
english["DisabledReason.HealthstoneThreshold"] = 'Enable "Warn when low" first.'
english["DisabledReason.UseDefaultThreshold"] = 'Uncheck "Use default threshold" to set a category-specific value.'

-- Direction labels
english["Direction.Left"] = "Left"
english["Direction.Center"] = "Center"
english["Direction.Right"] = "Right"
english["Direction.Up"] = "Up"
english["Direction.Down"] = "Down"
english["Direction.Label"] = "Direction"

-- Content visibility
english["Content.ShowIn"] = "Show in:"

-- Content toggle definitions
english["Content.OpenWorld"] = "Open World"
english["Content.Housing"] = "Housing"
english["Content.Scenarios"] = "Scenarios (Delves, Torghast, etc.)"
english["Content.Dungeons"] = "Dungeons (including M+)"
english["Content.Raids"] = "Raids"
english["Content.PvP"] = "PvP (Arena & Battlegrounds)"

-- Scenario difficulty
english["Content.Delves"] = "Delves"
english["Content.OtherScenarios"] = "Other Scenarios (Torghast, etc.)"

-- Dungeon difficulty
english["Content.NormalDungeons"] = "Normal Dungeons"
english["Content.HeroicDungeons"] = "Heroic Dungeons"
english["Content.MythicDungeons"] = "Mythic Dungeons"
english["Content.MythicPlus"] = "Mythic+ Keystones"
english["Content.TimewalkingDungeons"] = "Timewalking Dungeons"
english["Content.FollowerDungeons"] = "Follower Dungeons"

-- Raid difficulty
english["Content.LFR"] = "Looking for Raid"
english["Content.NormalRaids"] = "Normal Raids"
english["Content.HeroicRaids"] = "Heroic Raids"
english["Content.MythicRaids"] = "Mythic Raids"

-- PvP types
english["Content.Arena"] = "Arena"
english["Content.Battlegrounds"] = "Battlegrounds"
