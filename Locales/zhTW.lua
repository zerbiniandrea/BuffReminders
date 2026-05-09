local _, BR = ... -- luacheck: ignore 211
if GetLocale() ~= "zhTW" then
    return
end

local L = BR.L -- luacheck: ignore 211

-- Credit by BlueNightSky

-- ============================================================================
-- CATEGORY LABELS
-- ============================================================================
L["Category.Raid"] = "團隊增益"
L["Category.Presence"] = "職業增益"
L["Category.Targeted"] = "指向性增益"
L["Category.Self"] = "自身增益"
L["Category.Pet"] = "寵物"
L["Category.Consumable"] = "消耗品"
L["Category.Custom"] = "自定義"

-- Long form (used in Options section headers)
L["Category.RaidBuffs"] = "團隊增益"
L["Category.TargetedBuffs"] = "指向性增益"
L["Category.Consumables"] = "消耗品"
L["Category.PresenceBuffs"] = "職業增益"
L["Category.SelfBuffs"] = "自身增益"
L["Category.PetReminders"] = "寵物提示"
L["Category.CustomBuffs"] = "自定義增益"

-- Category notes
L["Category.RaidNote"] = "（全小隊或團隊生效）"
L["Category.TargetedNote"] = "（施放於其他目標的增益）"
L["Category.ConsumableNote"] = "（藥水、食物、符文、刀油）"
L["Category.PresenceNote"] = "（至少需要一人）"
L["Category.SelfNote"] = "（僅對自己施放的增益）"
L["Category.PetNote"] = "（寵物召喚提示）"
L["Category.CustomNote"] = "（按法術ID追蹤增益或高亮）"

-- ============================================================================
-- BUFF OVERLAY TEXT
-- ============================================================================
-- These must be kept very short (2-4 chars per line) to fit on small icons.
L["Overlay.NoDrPoison"] = "沒有\n毒藥"
L["Overlay.NoAura"] = "沒有\n光環"
L["Overlay.NoStone"] = "沒有\n糖"
L["Overlay.NoSoulstone"] = "沒有\n靈魂石"
L["Overlay.NoFaith"] = "沒有\n信標"
L["Overlay.NoLight"] = "沒有\n信標"
L["Overlay.NoES"] = "沒有\n大地盾"
L["Overlay.NoSource"] = "沒有\n魔源"
L["Overlay.NoScales"] = "沒有\n鱗片"
L["Overlay.NoLink"] = "沒有\n共生"
L["Overlay.NoTimeless"] = "沒有\n永恆"
L["Overlay.NoAttune"] = "沒有\n同調"
L["Overlay.NoFamiliar"] = "沒有\n魔寵"
L["Overlay.DropWell"] = "置放\n靈魂井"
L["Overlay.NoGrim"] = "沒有\n魔典"
L["Overlay.BurningRush"] = "燃燒狂奔"
L["Overlay.NoRite"] = "沒有\n儀式"
L["Overlay.ApplyPoison"] = "上毒藥"
L["Overlay.NoForm"] = "沒有\n形態"
L["Overlay.NoEL"] = "沒有\n大地生命"
L["Overlay.NoFT"] = "沒有\n火舌"
L["Overlay.NoTG"] = "沒有\n喚潮者"
L["Overlay.NoWF"] = "沒有\n風怒"
L["Overlay.NoSelfES"] = "自身沒有\n大地盾"
L["Overlay.NoShield"] = "沒有\n護盾"
L["Overlay.NoPet"] = "沒有\n寵物"
L["Overlay.PassivePet"] = "寵物\n被動"
L["Overlay.WrongPet"] = "寵物\n錯誤"
L["Overlay.WrongStance"] = "錯誤\n姿態"
L["Overlay.WrongForm"] = "錯誤\n形態"
L["Overlay.NoRune"] = "沒有\n符文"
L["Overlay.DKWrongRune"] = "符文\n錯誤"
L["Overlay.DKWrongRuneOH"] = "副手\n符文\n錯誤"
L["Overlay.NoFlask"] = "沒有\n精鍊"
L["Overlay.NoFood"] = "沒有\n食物"
L["Overlay.NoWeaponBuff"] = "沒有\n武器增益"
L["Overlay.Buff"] = "補BUFF"
L["Overlay.MinutesFormat"] = "%d分"
L["Overlay.LessThanOneMinute"] = "<1分"
L["Overlay.SecondsFormat"] = "%d秒"

-- ============================================================================
-- CONSUMABLE STAT LABELS (icon overlays, keep very short)
-- ============================================================================
L["Label.Crit"] = "致命"
L["Label.Haste"] = "加速"
L["Label.Versatility"] = "臨機"
L["Label.Mastery"] = "精通"
L["Label.Stamina"] = "耐力"
L["Label.Healing"] = "治療"
L["Label.Random"] = "隨機"
L["Label.Speed"] = "速度"
L["Label.PvP"] = "PvP"
L["Label.Feast"] = "大餐"
L["Label.HasteShort"] = "速"
L["Label.VersatilityShort"] = "臨"
L["Label.MasteryShort"] = "精"
L["Label.CritVers"] = "致/臨"
L["Label.MasteryCrit"] = "精/致"
L["Label.MasteryVers"] = "精/臨"
L["Label.MasteryHaste"] = "精/速"
L["Label.HasteCrit"] = "速/致"
L["Label.HasteVers"] = "速/臨"
L["Label.StaminaStr"] = "耐/力"
L["Label.StaminaAgi"] = "耐/敏"
L["Label.StaminaInt"] = "耐/智"
L["Label.HighPrimary"] = "高主屬"
L["Label.HighSecondary"] = "高次屬"
L["Label.MidPrimary"] = "中主屬"
L["Label.LowPrimary"] = "低主屬"
L["Label.LowSecondary"] = "低次屬"
L["Label.RevivePet"] = "復活寵物"
L["Label.Felguard"] = "惡魔守衛"
L["Badge.Hearty"] = "H"
L["Badge.Fleeting"] = "F"

-- ============================================================================
-- BUFF NAMES (used in Options panel checkboxes and sound notification list)
-- ============================================================================
-- Raid
L["Buff.ArcaneIntellect"] = "祕法智力"
L["Buff.BattleShout"] = "戰鬥怒吼"
L["Buff.BlessingOfTheBronze"] = "青銅龍的祝福"
L["Buff.MarkOfTheWild"] = "野性印記"
L["Buff.PowerWordFortitude"] = "真言術：韌"
L["Buff.Skyfury"] = "天怒"
-- Presence
L["Buff.AtrophicNumbingPoison"] = "萎縮/麻痺毒藥"
L["Buff.DevotionAura"] = "虔誠光環"
L["Buff.Soulstone"] = "靈魂石"
-- Targeted
L["Buff.BeaconOfFaith"] = "虔信信標"
L["Buff.BeaconOfLight"] = "聖光信標"
L["Buff.BlisteringScales"] = "極熾鱗片"
L["Buff.EarthShield"] = "大地之盾"
L["Buff.SourceOfMagic"] = "魔力之源"
L["Buff.SymbioticRelationship"] = "共生關係"
L["Buff.Timelessness"] = "永恆不朽"
-- Self
L["Buff.ArcaneFamiliar"] = "秘法魔寵"
L["Buff.Attunement"] = "黑曜同調"
L["Buff.CreateSoulwell"] = "製造靈魂之井"
L["Buff.DruidForm"] = "德魯伊形態"
L["Buff.GrimoireOfSacrifice"] = "犧牲魔典"
L["Buff.BurningRush"] = "燃燒狂奔"
L["Buff.RiteOfAdjuration"] = "裁決儀式"
L["Buff.RiteOfSanctification"] = "聖化儀式"
L["Buff.RoguePoisons"] = "盜賊毒藥"
L["Buff.RuneforgeMH"] = "符文熔爐(主手)"
L["Buff.RuneforgeOH"] = "符文熔爐(副手)"
L["Buff.Shadowform"] = "暗影型態"
L["Buff.EarthlivingWeapon"] = "大地生命武器"
L["Buff.FlametongueWeapon"] = "火舌武器"
L["Buff.TidecallersGuard"] = "喚潮者之禦"
L["Buff.WindfuryWeapon"] = "風怒武器"
L["Buff.EarthShieldSelf"] = "自身大地之盾"
L["Buff.WaterLightningShield"] = "水/閃電之盾"
L["Buff.ShieldNoTalent"] = "盾(無天賦)"
-- Pet
L["Buff.PetPassive"] = "寵物被動"
L["Buff.HunterPet"] = "獵人寵物"
L["Buff.UnholyGhoul"] = "穢邪食屍鬼"
L["Buff.WarlockDemon"] = "術士惡魔"
L["Buff.WaterElemental"] = "水元素"
L["Buff.WrongDemon"] = "錯誤惡魔"
L["Buff.WarriorStance"] = "戰士姿態"
-- Consumable
L["Buff.AugmentRune"] = "增強符文"
L["Buff.Flask"] = "精鍊"
L["Buff.DelveFood"] = "探究食物"
L["Buff.Food"] = "食物增益"
L["Buff.Healthstone"] = "治療石"
L["Buff.Weapon"] = "武器增益"
L["Buff.WeaponOH"] = "副手武器增益"

-- ============================================================================
-- BUFF GROUP DISPLAY NAMES
-- ============================================================================
L["Group.Beacons"] = "聖光信標"
L["Group.DKRunes"] = "DK符文"
L["Group.ShamanImbues"] = "薩滿武器灌魔"
L["Group.PaladinRites"] = "聖騎士儀式"
L["Group.Pets"] = "寵物"
L["Group.ShamanShields"] = "薩滿護盾"
L["Group.Flask"] = "精鍊"
L["Group.Food"] = "食物"
L["Group.DelveFood"] = "探究食物"
L["Group.Healthstone"] = "治療石"
L["Group.AugmentRune"] = "強化符文"
L["Group.WeaponBuff"] = "武器增益"

-- ============================================================================
-- BUFF INFO TOOLTIPS
-- ============================================================================
L["Tooltip.MayShowExtraIcon"] = "可能顯示額外圖示"
L["Tooltip.MayShowExtraIcon.Desc"] =
    "在施放此法術之前，該提示可能會與水之護盾/閃電之盾提示同時出現。因為系統無法確定你是想對自己施放大地之盾，還是想給隊友施放大地之盾的同時給自己施放水之護盾/閃電之盾。"
L["Tooltip.InstanceEntryReminder"] = "副本進本提示"
L["Tooltip.InstanceEntryReminder.Desc"] =
    "進入地下城時會短暫顯示放置靈魂井的提示。施放法術或30秒後將消失。"

-- ============================================================================
-- GLOW TYPE NAMES
-- ============================================================================
L["Glow.Pixel"] = "像素"
L["Glow.AutoCast"] = "自動施放"
L["Glow.Border"] = "邊框"
L["Glow.Proc"] = "觸發"

-- ============================================================================
-- CORE
-- ============================================================================
L["Core.Any"] = "任意"

-- ============================================================================
-- PROFILES
-- ============================================================================
L["Profile.SwitchQueued"] = "脫離戰鬥後將切換設定檔。"
L["Profile.Switched"] = "已切換至設定檔 '%s'。"

-- ============================================================================
-- MOVERS
-- ============================================================================
L["Mover.SetPosition"] = "設定位置"
L["Mover.AnchorFrame"] = "定位點框架"
L["Mover.AnchorPoint"] = "定位點位置"
L["Mover.NoneScreenCenter"] = "無（螢幕中心）"
L["Mover.Apply"] = "套用"
L["Mover.BuffAnchor"] = "增益定位點"
L["Mover.DragTooltip"] = "拖動以調整位置\n點擊以打開/關閉坐標編輯器"
L["Mover.MainEmpty"] = "主界面（空）"
L["Mover.MainAll"] = "主界面（全部）"
L["Mover.Detached"] = "已分離"

-- ============================================================================
-- DISPLAY
-- ============================================================================
L["Display.FramesLocked"] = "框架已鎖定。"
L["Display.FramesUnlocked"] = "框架已解鎖。"
L["Display.MinimapHidden"] = "小地圖圖示已隱藏。"
L["Display.MinimapShown"] = "小地圖圖示已顯示。"
L["Display.DebugEnabled"] = "偵錯模式已啟用。再次運行 |cFFFFD100/br debug|r 來關閉。"
L["Display.DebugDisabled"] = "偵錯模式已停用"
L["Display.Description"] = "一目了然地查看所有缺失的增益。"
L["Display.OpenOptions"] = "打開選項"
L["Display.SlashCommands"] = "使用指令: /br, /br lock, /br unlock, /br test, /br minimap"
L["Display.MinimapLeftClick"] = "|cFFCFCFCF左鍵點擊|r: 選項"
L["Display.MinimapRightClick"] = "|cFFCFCFCF右鍵點擊|r: 測試模式"
L["Display.DismissConsumables"] = "在下一次載入畫面前隱藏消耗品提示"
L["Display.DismissConsumablesChat"] = "在下一次載入畫面前消耗品提示將隱藏。"
L["Display.LoginFirstInstall"] =
    "感謝安裝！輸入 |cFFFFD100/br unlock|r 來移動增益顯示，或者使用 |cFFFFD100/br|r 選項面板底部的按鈕。"
L["Display.LoginSelfOnlyOutside"] =
    "新的預設：在開放世界中，只會追蹤您自己的職業增益。在「設定」標籤中切換|cFFFFD100強制在地下城與團隊副本之外只有自己|r來變更設定。"

-- ============================================================================
-- OPTIONS: NAVIGATION LABELS
-- ============================================================================
L["Tab.DisplayBehavior"] = "顯示/行為"

-- Sidebar groups
L["Sidebar.General"] = "通用"
L["Sidebar.Buffs"] = "增益"
L["Sidebar.DisplayBehavior"] = "顯示與行為"
L["Sidebar.Profiles"] = "設定檔"

-- Page titles
L["Page.General"] = "通用"
L["Page.Defaults"] = "預設"
L["Page.Visibility"] = "可見性"
L["Page.ChatRequests"] = "聊天請求"
L["Page.AnchorFrames"] = "定位框架"
L["Page.Profiles"] = "設定檔"
L["Page.AllBuffs"] = "所有增益"
L["Page.DetachedIcons"] = "分離圖示"
L["Page.Sounds"] = "音效"
L["Page.Sounds.Desc"] =
    "當追蹤的增益缺失時播放聲音。警報適用於所有增益類別 - 每個增益分配一個。"

-- Per-category page section headers
L["Section.Tracking"] = "追蹤"

-- ============================================================================
-- OPTIONS: SOUND ALERTS
-- ============================================================================
L["Options.Sound.NoAlerts"] = "未設定聲音警報。"
L["Options.Sound.AddAlert"] = "新增聲音警報"
L["Options.Sound.Title"] = "新增聲音警報"
L["Options.Sound.EditTitle"] = "編輯聲音警報"
L["Options.Sound.SelectBuff"] = "選擇增益"
L["Options.Sound.SelectSound"] = "選擇聲音"
L["Options.Sound.Preview"] = "預覽"
L["Options.Sound.Save"] = "儲存"
L["Options.Sound.NoBuffs"] = "所有增益都已有音效。"

-- ============================================================================
-- OPTIONS: GLOBAL DEFAULTS
-- ============================================================================
L["Options.GlobalDefaults"] = "全局預設值"
L["Options.GlobalDefaults.Note"] = "（套用於所有類別，除非被自定義外觀覆蓋）"
L["Options.Default"] = "預設"
L["Options.Font"] = "字體"
L["Options.TextOutline"] = "外框樣式"
L["Options.TextOutline.None"] = "無"
L["Options.TextOutline.Outline"] = "外框"
L["Options.TextOutline.Thick"] = "粗外框"
L["Options.TextOutline.Monochrome"] = "單色"
L["Options.TextOutline.OutlineMono"] = "外框 + 單色"
L["Options.TextOutline.ThickMono"] = "粗外框 + 單色"

-- ============================================================================
-- OPTIONS: GLOW SETTINGS
-- ============================================================================
L["Options.GlowReminderIcons"] = "提示圖示發光"
L["Options.GlowReminderIcons.Title"] = "提示圖示發光"
L["Options.GlowReminderIcons.Desc"] =
    "為所有顯示的提示圖示添加發光效果，包括缺失和即將過期的增益。"
L["Options.GlowKind.Expiring"] = "即將過期"
L["Options.GlowKind.Missing"] = "缺失"
L["Options.GlowSettings.Expiring"] = "發光設置 — 即將過期"
L["Options.GlowSettings.Missing"] = "發光設置 — 缺失"
L["Options.Glow.Enabled"] = "啟用"
L["Options.Threshold"] = "閾值"
L["Options.GlowMissingPets"] = "缺失寵物發光"
L["Options.CustomGlowStyle"] = "自定義發光樣式"
L["Options.Expiration"] = "過期"
L["Options.Glow"] = "發光"
L["Options.UseCustomColor"] = "使用自定義顏色"
L["Options.UseCustomColor.Desc"] =
    "啟用後會降低觸發發光的飽和度並更改顏色。\n可能看起來不如預設觸發發光清晰。"
L["Options.ExpirationReminder"] = "過期提示"
L["Options.PreKeyThreshold"] = "鑰石前閾值"
L["Options.PreKeyThreshold.Desc"] =
    "當進入傳奇地下城(M0)於插入鑰石之前，使用較長的過期閾值。\n有助於確保在鑰石插入之前您的增益效果是新鮮的。"

-- Glow params
L["Options.Glow.Type"] = "類型:"
L["Options.Glow.Size"] = "大小:"
L["Options.Glow.Duration"] = "持續時間"
L["Options.Glow.Frequency"] = "頻率"
L["Options.Glow.Length"] = "長度"
L["Options.Glow.Lines"] = "線條"
L["Options.Glow.Particles"] = "粒子"
L["Options.Glow.Scale"] = "縮放比例"
L["Options.Glow.Speed"] = "速度"
L["Options.Glow.StartAnimation"] = "起始動畫"
L["Options.Glow.XOffset"] = "X軸偏移"
L["Options.Glow.YOffset"] = "Y軸偏移"

-- ============================================================================
-- OPTIONS: CONTENT VISIBILITY
-- ============================================================================
L["Options.HidePvPMatchStart"] = "PvP比賽開始時隱藏"
L["Options.HidePvPMatchStart.Title"] = "PvP比賽開始時隱藏"
L["Options.HidePvPMatchStart.Desc"] = "PvP比賽開始後（準備階段結束）隱藏此類別。"
L["Options.ReadyCheckOnly"] = "僅在準備確認時顯示"
L["Options.ReadyCheckOnly.Desc"] = "僅在準備確認後的15秒內顯示此類別中的增益。"
L["Options.Visibility"] = "顯示條件"

-- ============================================================================
-- OPTIONS: HEALTHSTONE
-- ============================================================================
L["Options.Healthstone.ReadyCheckOnly"] = "僅準備確認時"
L["Options.Healthstone.ReadyCheckWarlock"] = "準備確認 + 術士始終顯示"
L["Options.Healthstone.AlwaysShow"] = "始終顯示"
L["Options.Healthstone.Visibility"] = "治療石顯示"
L["Options.Healthstone.Visibility.Desc"] =
    "設置何時顯示治療石提示。\n\n|cffffcc00僅準備確認時:|r 僅在準備確認（15秒內）時顯示。\n|cffffcc00準備確認 + 術士始終顯示:|r 術士始終顯示，其他職業僅在準備確認時顯示。\n|cffffcc00始終顯示:|r 在符合設置的內容類型中始終顯示。"
L["Options.Healthstone.WarlockAlwaysDesc"] = "術士始終顯示提示，其他職業僅在準備確認時顯示"
L["Options.Healthstone.ReadyCheckDesc"] = "在準備確認後15秒內顯示"
L["Options.Healthstone.AlwaysDesc"] = "在符合當前內容類型時始終顯示"
L["Options.Healthstone.LowStock"] = "治療石不足警告"
L["Options.Healthstone.LowStock.Desc"] =
    "當有治療石但數量較少時顯示警告。不管此設置如何，沒有治療石（0個）時都會被追蹤。"
L["Options.Healthstone.Threshold"] = "警告閾值"
L["Options.Healthstone.Threshold.Desc"] =
    "當治療石等於或低於此數量時顯示不足警告。\n\n|cffffcc001:|r 僅在剛好有1個時警告。\n|cffffcc002:|r 有1個或2個時警告。"

-- ============================================================================
-- OPTIONS: SOULSTONE
-- ============================================================================
L["Options.Soulstone.Visibility"] = "靈魂石顯示"
L["Options.Soulstone.Visibility.Desc"] =
    "設置何時顯示靈魂石提示。\n\n|cffffcc00僅準備確認時:|r 僅在準備確認時顯示（預設）。\n|cffffcc00準備確認 + 術士始終顯示:|r 術士始終顯示，其他職業僅在準備確認時顯示。\n|cffffcc00始終顯示:|r 只要職業增益類別可見就顯示。"
L["Options.Soulstone.ReadyCheckOnly"] = "僅準備確認時"
L["Options.Soulstone.ReadyCheckWarlock"] = "準備確認 + 術士始終顯示"
L["Options.Soulstone.AlwaysShow"] = "始終顯示"
L["Options.Soulstone.ReadyCheckDesc"] = "在準備確認後15秒內顯示"
L["Options.Soulstone.WarlockAlwaysDesc"] = "術士始終顯示提示，其他職業僅在準備確認時顯示"
L["Options.Soulstone.AlwaysDesc"] = "只要職業增益類別可見就顯示"
L["Options.Soulstone.HideCooldown"] = "冷卻時隱藏（術士）"
L["Options.Soulstone.HideCooldown.Desc"] =
    "啟用後，當靈魂石法術處於冷卻中時，不會向術士顯示提示。僅適用於術士。"

-- ============================================================================
-- OPTIONS: FREE CONSUMABLES
-- ============================================================================
L["Options.FreeConsumables"] = "免費消耗品"
L["Options.FreeConsumables.Note"] = "（治療石、永久強化符文）"
L["Options.FreeConsumables.Override"] = "覆蓋內容過濾"
L["Options.FreeConsumables.Override.Desc"] =
    "勾選後，免費消耗品將使用下方獨立的內容類型設置。\n\n取消勾選後，它們將遵循與其他消耗品相同的內容過濾規則。"

-- ============================================================================
-- OPTIONS: ICONS
-- ============================================================================
L["Options.Icons"] = "圖示"
L["Options.ShowText"] = "在圖示上顯示文字"
L["Options.ShowText.Desc"] = "在此類別的增益圖示上顯示層數或缺失文字覆蓋。"
L["Options.ShowMissingCountOnly"] = "僅顯示缺失數量"
L["Options.ShowMissingCountOnly.Desc"] =
    "僅顯示缺失增益的數量（例如：”1“），而不是完整的分數形式（例如：”19/20“）。"
L["Options.ShowBuffReminderText"] = "顯示“補BUFF”提示文字"
L["Options.BuffTextOffsetX"] = "“補BUFF” X軸"
L["Options.BuffTextOffsetY"] = "“補BUFF” Y軸"
L["Options.Size"] = "大小"

-- ============================================================================
-- OPTIONS: CLICK TO CAST
-- ============================================================================
L["Options.ClickToCast"] = "點擊施法"
L["Options.ClickToCast.DescFull"] =
    "你可以點擊增益圖示來施放對應的法術（僅限非戰鬥狀態）。只對你的角色可施放的法術有效。"
L["Options.HoverHighlight"] = "懸停高亮"
L["Options.HoverHighlight.Desc"] = "將鼠標懸停在可點擊的增益圖示上時，顯示微弱的高亮效果。"
L["Options.RequestBuffInChat"] = "在聊天中請求缺失的增益"
L["Options.RequestBuffInChat.Desc"] =
    "點擊您的職業無法提供的缺失增益，並在聊天中請求它。自動偵測頻道（副本/團隊/隊伍/說）。每個增益有30秒冷卻時間。"

L["Options.ChatRequest.ResetAll"] = "重置全部"
L["ChatRequests.PerBuffMessages"] = "每個增益的訊息"
-- Chat request messages (keyed by buff.key, sent as-is via SendChatMessage)
-- EU/US translators: leave untranslated so chat messages stay in English.
-- Asian translators: translate these so chat messages match your locale.
L["ChatRequest.intellect"] = "請補上祕法智力的增益"
L["ChatRequest.attackPower"] = "請補上戰鬥怒吼的增益"
L["ChatRequest.bronze"] = "請補上青銅龍的祝福增益"
L["ChatRequest.versatility"] = "請補上野性印記的增益"
L["ChatRequest.stamina"] = "請補上真言術：韌的增益"
L["ChatRequest.skyfury"] = "請補上天怒增益"
L["ChatRequest.atrophicNumbingPoison"] = "請補上萎縮/麻痺毒藥"
L["ChatRequest.devotionAura"] = "請補上虔誠光環"
L["ChatRequest.soulstone"] = "請補上靈魂石"

-- ============================================================================
-- OPTIONS: PET
-- ============================================================================
L["Options.PetSpecIcon"] = "懸停時顯示獵人寵物專精圖示"
L["Options.PetSpecIcon.Title"] = "懸停時寵物專精圖示"
L["Options.PetSpecIcon.Desc"] =
    "鼠標懸停時，寵物圖示將變為對應的專精技能（狡詐、狂野、堅韌）。"
L["Options.ShowItemTooltips"] = "顯示物品提示訊息"
L["Options.ShowItemTooltips.Desc"] = "將鼠標懸停在消耗品圖示上時顯示物品詳細訊息。"
L["Options.Behavior"] = "行為"
L["Options.PetPassiveCombat"] = "僅在戰鬥中提示被動寵物"
L["Options.PetPassiveCombat.Desc"] = "僅在戰鬥中顯示被動寵物提示。禁用時則始終顯示。"
L["Options.FelDomination"] = "召喚前使用惡魔支配"
L["Options.FelDomination.Title"] = "惡魔支配"
L["Options.FelDomination.Desc"] =
    "通過點擊施法召喚惡魔前自動施放惡魔支配。如果惡魔支配在冷卻中，則正常召喚。需要點出惡魔支配天賦。"

-- ============================================================================
-- OPTIONS: PET DISPLAY
-- ============================================================================
L["Options.PetDisplay"] = "寵物顯示"
L["Options.PetDisplay.Generic"] = "通用圖示"
L["Options.PetDisplay.GenericDesc"] = "單一的預設“無寵物”圖示"
L["Options.PetDisplay.Summon"] = "召喚法術"
L["Options.PetDisplay.SummonDesc"] = "將每個召喚寵物法術顯示為單獨的圖示"
L["Options.PetDisplay.Mode"] = "寵物顯示模式"
L["Options.PetDisplay.Mode.Desc"] = "設置缺失寵物提示的顯示方式。"
L["Options.PetLabels"] = "寵物標簽"
L["Options.PetLabels.Desc"] = "在每個圖示下方顯示寵物名稱和專精。"
L["Options.PetLabels.SizePct"] = "尺寸占比 %"

-- ============================================================================
-- OPTIONS: CONSUMABLE DISPLAY
-- ============================================================================
L["Options.ConsumableTextScale"] = "文字縮放"
L["Options.ConsumableTextScale.Title"] = "消耗品文字大小"
L["Options.ConsumableTextScale.Desc"] = "物品數量和品質標簽相對於圖示大小的字體縮放比例。"
L["Options.HideConsumableLabels"] = "隱藏屬性標籤"
L["Options.HideConsumableLabels.Title"] = "隱藏消耗品屬性標籤"
L["Options.HideConsumableLabels.Desc"] =
    '隱藏顯示在消耗品圖示左上的小屬性標籤 (例如 "高主屬"、"低次屬")。'
L["Options.ItemDisplay"] = "物品顯示"
L["Options.ItemDisplay.IconOnly"] = "僅圖示"
L["Options.ItemDisplay.IconOnlyDesc"] = "顯示數量最多的物品"
L["Options.ItemDisplay.SubIcons"] = "子圖示"
L["Options.ItemDisplay.SubIconsDesc"] = "在每個圖示下方顯示較小的物品變體圖示"
L["Options.ItemDisplay.Expanded"] = "展開"
L["Options.ItemDisplay.ExpandedDesc"] = "將每個物品變體顯示為全尺寸圖示"
L["Options.ItemDisplay.Mode"] = "消耗品物品顯示"
L["Options.ItemDisplay.Mode.Desc"] =
    "設置具有多個變體的消耗品物品（例如各種精鍊類型）的顯示方式。"
L["Options.SubIconSide"] = "方向"
L["Options.SubIconSide.Bottom"] = "底部"
L["Options.SubIconSide.Top"] = "頂部"
L["Options.SubIconSide.Left"] = "左側"
L["Options.SubIconSide.Right"] = "右側"
L["Options.ShowWithoutItems"] = "背包中沒有也顯示"
L["Options.ShowWithoutItems.Title"] = "沒有物品也顯示"
L["Options.ShowWithoutItems.Desc"] =
    "啟用後，即使背包中沒有該物品，也會顯示消耗品提示。禁用後，僅顯示實際擁有的消耗品。"
L["Options.ShowWithoutItemsReadyCheckOnly"] = "只有在準備確認"
L["Options.ShowWithoutItemsReadyCheckOnly.Title"] = "只在準備確認時顯示缺失的物品"
L["Options.ShowWithoutItemsReadyCheckOnly.Desc"] =
    "當啟用後，不在您背包中的消耗品僅在準備確認時顯示。對於在拉怪前快速提醒補充庫存很有用。"
L["Options.DelveFoodOnly"] = "在探究中僅顯示探究食物"
L["Options.DelveFoodOnly.Desc"] = "在探究中隱藏除探究食物外的所有消耗品提示。"
L["Options.HideLegacyConsumables"] = "隱藏舊版消耗品"
L["Options.HideLegacyConsumables.Title"] = "隱藏舊版消耗品"
L["Options.HideLegacyConsumables.Desc"] =
    "啟用後，先前資料片中的食物、精煉和符文將從動作按鈕中過濾掉。如果您仍然使用舊版消耗品進行時光漫遊、農舊團隊副本或裝備不足的替代品，請停用。"

-- ============================================================================
-- OPTIONS: DK RUNEFORGE PREFERENCES
-- ============================================================================
L["Options.RuneforgePreferences"] = "DK符文偏好"
L["Options.RuneforgeNote"] =
    "為每個專精選擇你期望的DK符文。如果套用了錯誤的符文或缺少符文，將顯示提示。"
L["Options.RuneMainHand"] = "主手"
L["Options.RuneOffHand"] = "副手"
L["Options.RuneTwoHanded"] = "雙手"
L["Options.RuneDualWield"] = "雙持"

-- ============================================================================
-- OPTIONS: ROGUE POISON PREFERENCES
-- ============================================================================
L["Options.RoguePoisonPreferences"] = "盜賊毒藥偏好"
L["Options.RoguePoisonNote"] =
    "選擇要應用的毒藥及其優先順序（頂部=最高）。停用的毒藥永遠不會被施放，也不會觸發提醒。"
L["Options.PoisonLethal"] = "致命"
L["Options.PoisonNonLethal"] = "非致命"
L["Options.PoisonMoveUp"] = "優先級上升"
L["Options.PoisonMoveDown"] = "優先級下降"
L["Options.PoisonReset"] = "重置回預設"

-- ============================================================================
-- OPTIONS: BUFF SETTINGS GEAR ICONS
-- ============================================================================
L["Options.HealthstoneSettings"] = "治療石設置"
L["Options.HealthstoneSettings.Note"] = "設置顯示條件和不足警告閾值。"
L["Options.SoulstoneSettings"] = "靈魂石設置"
L["Options.SoulstoneSettings.Note"] = "設置何時顯示靈魂石提示。"
L["Options.BronzeSettings"] = "青銅龍的祝福設定"
L["Options.BronzeSettings.Note"] = "設置青銅龍的祝福的提醒。"
L["Options.BronzeHideInCombat"] = "戰鬥中隱藏"
L["Options.BronzeHideInCombat.Desc"] =
    "當戰鬥中隱藏青銅龍的祝福的提醒。這個增益不太重要，你可能不想在戰鬥中補上。"
L["Options.PetPassiveSettings"] = "被動寵物設置"
L["Options.PetPassiveSettings.Note"] = "設置被動模式寵物的提示行為。"
L["Options.PetSummonSettings"] = "寵物召喚設置"
L["Options.PetSummonSettings.Note"] = "配置寵物召喚行為。"
L["Options.DelveFoodSettings"] = "探究食物設定"
L["Options.DelveFoodSettings.Note"] = "設置探究食物的提示行為。"
L["Options.DelveFoodTimer"] = "30秒後自動隱藏"
L["Options.DelveFoodTimer.Desc"] =
    "當啟用後，進入探究後，探究食物提醒僅出現30秒，然後自動隱藏。當停用後，只要您位於探究並且缺少增益效果，該提醒就會保持可見。"

-- ============================================================================
-- OPTIONS: LAYOUT
-- ============================================================================
L["Options.Layout"] = "布局"
L["Options.SplitFrame"] = "分離為獨立框架"
L["Options.SplitFrame.Desc"] = "將此類別中的增益顯示在可獨立移動的單獨框架中。"

-- Display Order section (Defaults page) - drives the same priority field the
-- old per-category slider wrote, but as a single ordered list across all
-- non-split categories.
L["Options.DisplayOrder"] = "顯示順序"
L["Options.DisplayOrder.Note"] =
    "類別如何在組合框架內從上到下堆疊。分離的類別存在於它們自己的框架中不參與。"
L["Options.DisplayOrder.SplitGroup"] = "分離 (獨立框架)"
L["Options.DisplayOrder.SplitBadge"] = "分離"

-- Detached Icons page (search-driven dual-list manager).
L["DetachedIcons.PageNote"] =
    "將單一增益從其類別中拉出到其自己的獨立定位框架中。分離的圖示保留自己的定位點，並且在框架解鎖時可以獨立移動。"
L["DetachedIcons.Search"] = "搜尋:"
L["DetachedIcons.Available"] = "可用"
L["DetachedIcons.CurrentlyDetachedCount"] = "目前已分離 (%d)"
L["DetachedIcons.NoneDetached"] = "沒有分離的圖示。找到下面的增益並點擊分離"
L["DetachedIcons.NoMatches"] = "無符合的。"
L["DetachedIcons.Detach"] = "分離"
L["DetachedIcons.Reattach"] = "重新連接"
L["DetachedIcons.ResetPos"] = "重置"
L["DetachedIcons.ReattachAll"] = "全部重新連接"

-- ============================================================================
-- OPTIONS: APPEARANCE
-- ============================================================================
L["Options.CustomAppearance"] = "使用自定義外觀"
L["Options.CustomAppearance.Desc"] =
    "禁用時，此類別將繼承全局預設值的外觀設置。必須分離為獨立框架才能自定義增長方向。"
L["Options.Customize"] = "自定義"
L["Options.ResetPosition"] = "重置位置"
L["Options.MasqueNote"] = "縮放和邊框設置由Masque管理。"

-- ============================================================================
-- OPTIONS: SETTINGS TAB
-- ============================================================================
L["Options.ShowLoginMessages"] = "顯示登入訊息"
L["Options.ShowMinimapButton"] = "顯示小地圖按鈕"

-- Hide when section
L["Options.HideWhen"] = "隱藏條件:"
L["Options.HideWhen.Alone"] = "單獨時"
L["Options.HideWhen.Alone.Title"] = "單獨時隱藏"
L["Options.HideWhen.Alone.Desc"] = "當不在隊伍或團隊中時隱藏所有增益提醒"
L["Options.HideWhen.Resting"] = "休息時"
L["Options.HideWhen.Resting.Title"] = "休息時隱藏"
L["Options.HideWhen.Resting.Desc"] = "在旅店或主城時隱藏增益提示。"
L["Options.HideWhen.Combat"] = "戰鬥中"
L["Options.HideWhen.Expiring"] = "戰鬥中不提示即將過期"
L["Options.HideWhen.Expiring.Title"] = "戰鬥中不提示即將結束的增益"
L["Options.HideWhen.Expiring.Desc"] =
    "在戰鬥中不會顯示即將結束的增益，僅顯示完全缺失的增益。"
L["Options.HideWhen.Vehicle"] = "載具中"
L["Options.HideWhen.Vehicle.Title"] = "載具中隱藏"
L["Options.HideWhen.Vehicle.Desc"] =
    "使用任務載具時隱藏所有增益提示。即使禁用，團隊和職業增益仍會顯示。"
L["Options.HideWhen.Mounted"] = "坐騎上"
L["Options.HideWhen.Mounted.Title"] = "上坐騎時隱藏"
L["Options.HideWhen.Mounted.Desc"] =
    "乘騎坐騎時隱藏所有增益提示。優先級高於類別特定的坐騎隱藏設置。"
L["Options.HideWhen.Legacy"] = "舊資料片副本"
L["Options.HideWhen.Legacy.Title"] = "在舊資料片副本中隱藏"
L["Options.HideWhen.Legacy.Desc"] = "在啟用傳統戰利品模式的舊資料片副本中隱藏所有增益提示。"
L["Options.HideWhen.Leveling"] = "升級中"
L["Options.HideWhen.Leveling.Title"] = "在升級過程隱藏"
L["Options.HideWhen.Leveling.Desc"] = "當低於最高等級時隱藏所有增益提醒"

-- ============================================================================
-- OPTIONS: BUFF TRACKING MODE
-- ============================================================================
L["Options.BuffTracking"] = "增益追蹤"
L["Options.BuffTracking.All"] = "所有增益，所有玩家"
L["Options.BuffTracking.All.Desc"] =
    "顯示所有職業的團隊和職業增益，並追蹤整個隊伍的套用情況。"
L["Options.BuffTracking.MyBuffs"] = "僅我的增益，所有玩家"
L["Options.BuffTracking.MyBuffs.Desc"] =
    "僅顯示你的職業能提供的增益，但會追蹤整個隊伍的套用情況。"
L["Options.BuffTracking.OnlyMine"] = "所有增益，僅我需要的"
L["Options.BuffTracking.OnlyMine.Desc"] =
    "顯示所有類型的增益，但僅檢查自身是否擁有。不顯示團體數量統計。"
L["Options.BuffTracking.SelfOnly"] = "只有我的增益，僅我需要的"
L["Options.BuffTracking.SelfOnly.Desc"] =
    "只顯示你的職業可以提供的增益，並且僅檢查自身是否擁有。沒有團體數量統計，也沒有你對其他人施加的增益。"
L["Options.BuffTracking.Smart"] = "智能"
L["Options.BuffTracking.Smart.Desc"] =
    "對你的職業提供的增益追蹤整個隊伍，對其他職業的增益僅檢查自身。"
L["Options.BuffTracking.Mode"] = "增益追蹤模式"
L["Options.BuffTracking.Mode.Desc"] =
    "設置要顯示的團隊和職業增益，以及是追蹤整個隊伍還是僅追蹤自身。"
L["Options.BuffTracking.SelfOnlyOutsideInstances"] = "強制在地下城與團隊副本之外只有自己"
L["Options.BuffTracking.SelfOnlyOutsideInstances.Desc"] =
    "當啟用以後，在開放世界中，只會追蹤您自己的職業增益。選定的追蹤模式仍然在地下城、團隊副本、場景和 PvP中使用。"

-- ============================================================================
-- OPTIONS: PROFILES TAB
-- ============================================================================
L["Options.ActiveProfile"] = "當前設定檔"
L["Options.ActiveProfile.Desc"] = "在已保存的設置之間切換。每個角色可以使用不同的設定檔。"
L["Options.SelectProfile"] = "選擇設定檔"
L["Options.Profile"] = "設定檔"
L["Options.CopyFrom"] = "複製自"
L["Options.Delete"] = "刪除"
L["Options.PerSpecProfiles"] = "按專精設定檔"
L["Options.PerSpecProfiles.Desc"] = "切換專精時自動切換設定檔。"
L["Options.PerSpecProfiles.Enable"] = "啟用按專精設定檔"

-- ============================================================================
-- OPTIONS: IMPORT/EXPORT
-- ============================================================================
L["Options.ExportSettings"] = "導出設置"
L["Options.ExportSettings.Desc"] = "複製下方字符串以分享你的設置。"
L["Options.ImportSettings"] = "導入設置"
L["Options.ImportSettings.DescPlain"] = "在下方粘貼設置字符串。"
L["Options.ImportSettings.Overwrite"] = "將覆蓋當前啟用的設定檔。"
L["Options.Export"] = "導出"
L["Options.Import"] = "導入"
L["Options.ImportSuccess"] = "設置導入成功！"
L["Options.FailedExport"] = "導出失敗"
L["Options.UnknownError"] = "未知錯誤"

-- ============================================================================
-- OPTIONS: DIALOGS
-- ============================================================================
L["Dialog.Cancel"] = "取消"
L["Dialog.DeleteCustomBuff"] = '是否刪除自定義增益 "%s"？'
L["Dialog.ResetProfile"] =
    "是否將當前設定檔重置為預設值？\n\n當前設定檔的所有自定義設置將被刪除並重載UI。"
L["Dialog.Reset"] = "重置"
L["Dialog.ReloadPrompt"] = "設置導入成功！\n是否重載UI以套用更改？"
L["Dialog.Reload"] = "重載"
L["Dialog.NewProfilePrompt"] = "請輸入新設定檔的名稱："
L["Dialog.Create"] = "創建"
L["Dialog.DiscordPrompt"] = "加入BuffReminders的Discord頻道！\n複製下方網址以加入："
L["Dialog.Close"] = "關閉"

-- ============================================================================
-- OPTIONS: TEST / LOCK
-- ============================================================================
L["Options.LockUnlock"] = "鎖定 / 解鎖"
L["Options.LockUnlock.Desc"] = "解鎖後將顯示定位點手柄，以便調整增益框架的位置。"
L["Options.TestAppearance"] = "測試圖示外觀"
L["Options.TestAppearance.Desc"] = "使用模擬數據顯示選定的增益以預覽外觀。"
L["Options.Test"] = "測試"
L["Options.StopTest"] = "停止測試"
L["Options.AnchorHint"] = "點擊定位點以更改其對齊位置或坐標。"
L["Options.Lock"] = "鎖定"
L["Options.Unlock"] = "解鎖"

-- ============================================================================
-- OPTIONS: CUSTOM BUFF MODAL
-- ============================================================================
L["CustomBuff.Edit"] = "編輯自定義增益"
L["CustomBuff.EditShort"] = "編輯"
L["CustomBuff.Add"] = "添加自定義增益"
L["CustomBuff.AddButton"] = "+ 添加自定義增益"
L["CustomBuff.SpellIDs"] = "法術ID:"
L["CustomBuff.Lookup"] = "查找"
L["CustomBuff.AddSpellID"] = "+ 添加法術ID"
L["CustomBuff.Name"] = "名稱:"
L["CustomBuff.Text"] = "文字:"
L["CustomBuff.LineBreakHint"] = "（使用 \\n 換行）"
L["CustomBuff.Appearance"] = "外觀"
L["CustomBuff.BuffTracking"] = "增益追蹤"
L["CustomBuff.Requirements"] = "請求"
L["CustomBuff.ShowIn"] = "顯示在"
L["CustomBuff.ClickAction"] = "點擊動作"

-- Custom buff mode toggles
L["CustomBuff.WhenActive"] = "啟用時"
L["CustomBuff.WhenMissing"] = "缺失時"
L["CustomBuff.OnlyIfSpellKnown"] = "只限已知法術"

-- Custom buff class dropdown
L["Class.Any"] = "任意"
L["Class.DeathKnight"] = "死亡騎士"
L["Class.DemonHunter"] = "惡魔獵人"
L["Class.Druid"] = "德魯伊"
L["Class.Evoker"] = "喚能師"
L["Class.Hunter"] = "獵人"
L["Class.Mage"] = "法師"
L["Class.Monk"] = "武僧"
L["Class.Paladin"] = "聖騎士"
L["Class.Priest"] = "牧師"
L["Class.Rogue"] = "盜賊"
L["Class.Shaman"] = "薩滿"
L["Class.Warlock"] = "術士"
L["Class.Warrior"] = "戰士"

-- Custom buff fields
L["CustomBuff.Spec"] = "專精:"
L["CustomBuff.Class"] = "職業:"
L["CustomBuff.RequireItem"] = "需要物品:"
L["CustomBuff.RequireItem.EquippedBags"] = "已裝備/背包中"
L["CustomBuff.RequireItem.Equipped"] = "已裝備"
L["CustomBuff.RequireItem.InBags"] = "背包中"
L["CustomBuff.RequireItem.Hint"] = "物品ID — 缺失時隱藏"
L["CustomBuff.ItemCooldown"] = "冷卻:"
L["CustomBuff.ItemCooldown.Any"] = "任何"
L["CustomBuff.ItemCooldown.OffCooldown"] = "關閉冷卻"
L["CustomBuff.ItemCooldown.OnCooldown"] = "開啟冷卻"

-- Bar glow options
L["CustomBuff.BarGlow.WhenGlowing"] = "發光時檢測"
L["CustomBuff.BarGlow.WhenNotGlowing"] = "不發光時檢測"
L["CustomBuff.BarGlow.Disabled"] = "禁用"
L["CustomBuff.BarGlow"] = "動作條發光:"
L["CustomBuff.BarGlow.Title"] = "動作條發光替代檢測"
L["CustomBuff.BarGlow.Desc"] =
    "在傳奇鑰石/PvP/戰鬥中由於增益API受限，使用動作條法術發光作為替代檢測方法。若僅追蹤增益是否存在，請禁用此項。"

-- Ready check / level
L["CustomBuff.ReadyCheckOnly"] = "僅準備確認時"
L["CustomBuff.Level"] = "等級:"
L["CustomBuff.Level.Any"] = "任意等級"
L["CustomBuff.Level.Max"] = "僅滿級"
L["CustomBuff.Level.BelowMax"] = "未滿級"

-- Click action
L["CustomBuff.Action.None"] = "無"
L["CustomBuff.Action.Spell"] = "法術"
L["CustomBuff.Action.Item"] = "物品"
L["CustomBuff.Action.Macro"] = "巨集"
L["CustomBuff.Action.OnClick"] = "點擊時:"
L["CustomBuff.Action.Title"] = "點擊動作"
L["CustomBuff.Action.Desc"] =
    "設置點擊此增益圖示時的動作。法術會施放法術，物品會使用物品，巨集會執行巨集。"
L["CustomBuff.Action.MacroHint"] = "例：/use item:12345\n/use 13"

-- Save/Cancel/Delete
L["CustomBuff.Save"] = "保存"
L["CustomBuff.ValidateError"] = "需要至少1個有效的法術ID"

-- Custom buff status
L["CustomBuff.InvalidID"] = "無效ID"
L["CustomBuff.NotFound"] = "未找到"
L["CustomBuff.NotFoundRetry"] = "未找到 (重試)"
L["CustomBuff.Error"] = "錯誤:"

-- ============================================================================
-- OPTIONS: DISCORD
-- ============================================================================
L["Options.JoinDiscord"] = "加入Discord"
L["Options.JoinDiscord.Title"] = "點擊查看邀請鏈接"
L["Options.JoinDiscord.Desc"] = "有反饋、功能請求或發現BUG？\n歡迎加入我們的Discord！"

-- ============================================================================
-- OPTIONS: CUSTOM ANCHOR FRAMES
-- ============================================================================
L["Options.CustomAnchorFrames.Desc"] =
    "在定位點下拉選單中添加全局框架名稱。（例：MyAddon_PlayerFrame）\n游戲中不存在的框架會自動跳過。"
L["Options.Add"] = "添加"
L["Options.New"] = "新建"
L["Options.ResetToDefaults"] = "重置為預設值"

-- ============================================================================
-- OPTIONS: MISC
-- ============================================================================
L["Options.Off"] = "關閉"
L["Options.Always"] = "始終"
L["Options.ReadyCheck"] = "準備確認"
L["Options.Min"] = "分鐘"

-- ============================================================================
-- COMPONENTS (UI/Components.lua)
-- ============================================================================
-- Content filter tooltip
L["Content.ClickToFilter"] = "點擊以按 %s 難度過濾"

-- Mover labels
L["Mover.AnchorGrowth"] = "定位點 \194\183 增長方向 %s"
L["Mover.AnchorGrowthFrame"] = "定位點 \194\183 增長方向 %s \194\183 > %s"

-- Pet labels
L["Pet.SpiritBeast"] = "靈獸"

-- Appearance grid labels
L["Appearance.Width"] = "寬度"
L["Appearance.Height"] = "高度"
L["Appearance.Zoom"] = "縮放"
L["Appearance.Border"] = "邊框"
L["Appearance.Spacing"] = "間距"
L["Appearance.Alpha"] = "透明度"
L["Appearance.Text"] = "文字"
L["Appearance.TextX"] = "文字 X軸"
L["Appearance.TextY"] = "文字 Y軸"

-- Slider tooltip
L["Component.AdjustValue"] = "調整數值"
L["Component.AdjustValue.Desc"] = "點擊輸入或使用鼠標滾輪。"

-- Direction labels
L["Direction.Left"] = "左側"
L["Direction.Center"] = "中心"
L["Direction.Right"] = "右側"
L["Direction.Up"] = "上方"
L["Direction.Down"] = "下方"
L["Direction.Label"] = "方向"

-- Content visibility
L["Content.ShowIn"] = "顯示條件:"

-- Content toggle definitions
L["Content.OpenWorld"] = "野外"
L["Content.Housing"] = "房屋"
L["Content.Scenarios"] = "場景戰役"
L["Content.Dungeons"] = "地下城"
L["Content.Raids"] = "團隊副本"
L["Content.PvP"] = "PvP"

-- Scenario difficulty
L["Content.Delves"] = "探究"
L["Content.OtherScenarios"] = "其他場景戰役"

-- Dungeon difficulty
L["Content.NormalDungeons"] = "普通地下城"
L["Content.HeroicDungeons"] = "英雄地下城"
L["Content.MythicDungeons"] = "傳奇地下城"
L["Content.MythicPlus"] = "傳奇+鑰石"
L["Content.TimewalkingDungeons"] = "時光漫游地下城"
L["Content.FollowerDungeons"] = "追隨者地下城"

-- Raid difficulty
L["Content.LFR"] = "隨機團隊"
L["Content.NormalRaids"] = "普通團隊副本"
L["Content.HeroicRaids"] = "英雄團隊副本"
L["Content.MythicRaids"] = "傳奇團隊副本"

-- PvP types
L["Content.Arena"] = "競技場"
L["Content.Battlegrounds"] = "戰場"
