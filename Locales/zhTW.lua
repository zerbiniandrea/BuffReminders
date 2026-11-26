local _, BR = ... -- luacheck: ignore 211
BR.translatedLocales.zhTW = "繁體中文"
if BR.locale ~= "zhTW" then
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
L["Category.Utility"] = "功能"
L["Category.Custom"] = "自訂"
L["Category.Loadout"] = "天賦構建"

-- Long form (used in Options section headers)
L["Category.RaidBuffs"] = "團隊增益"
L["Category.TargetedBuffs"] = "指向性增益"
L["Category.Consumables"] = "消耗品"
L["Category.UtilityReminders"] = "功能提醒"
L["Category.PresenceBuffs"] = "職業增益"
L["Category.SelfBuffs"] = "自身增益"
L["Category.PetReminders"] = "寵物提示"
L["Category.CustomBuffs"] = "自訂增益"
L["Category.LoadoutReminders"] = "天賦構建提醒"

-- Category notes
L["Category.RaidNote"] = "（全小隊或團隊生效）"
L["Category.TargetedNote"] = "（施放於其他目標的增益）"
L["Category.ConsumableNote"] = "（藥水、食物、符文、刀油）"
L["Category.UtilityNote"] = "(雜務以及非增益的提醒)"
L["Category.PresenceNote"] = "（至少需要一人）"
L["Category.SelfNote"] = "（僅對自己施放的增益）"
L["Category.PetNote"] = "（寵物召喚提示）"
L["Category.CustomNote"] = "（按法術ID追蹤增益或高亮）"
L["Category.LoadoutNote"] = "(當我的裝備或天賦與內容不符時提醒我)"
L["Category.LoadoutTLXNote"] = "已偵測到天賦構建範例 - 它的構建出現在天賦構建選擇器中。"

-- Loadout reminders
L["Loadout.Add"] = "新增天賦構建提醒"
L["Loadout.Edit"] = "編輯天賦構建提醒"
L["Loadout.AddButton"] = "+ 添加天賦構建提醒"
L["Loadout.Empty"] = "尚未有天賦構建提醒。下面新增一個。"
L["Loadout.Name"] = "名稱"
L["Loadout.Expect"] = "預計"
L["Loadout.Applies"] = "套用至"
L["Loadout.Content"] = "內容"
L["Loadout.Requirement"] = "需求"
L["Loadout.EquipmentSet"] = "裝備套裝"
L["Loadout.TalentSpell"] = "天賦法術ID"
L["Loadout.NoSets"] = "未找到裝備套裝。在此角色視窗先建立一個 (裝備管理)。"
L["Loadout.NoSetSelected"] = "先選擇一個裝備套裝。"
L["Loadout.NoLoadouts"] = "此專精沒有儲存的天賦構建。"
L["Loadout.NoLoadoutSelected"] = "先選擇一個天賦構建。"
L["Loadout.TLXTag"] = "|cff9d9d9d(構建範例)|r"
L["Loadout.InvalidSpell"] = "法術ID不存在。請使用天賦的法術ID。"
L["Loadout.CombatBlocked"] = "無法在戰鬥中更換裝備或天賦。"
L["Loadout.EquipFailed"] = "無法穿上裝備套裝，請確認套裝中的每件裝備都在背包裡。"
L["Loadout.OpenTalentsFailed"] = "無法開啟天賦視窗，請手動開啟以修正提醒。"
L["Loadout.Instances"] = "%d 副本"
L["Loadout.LimitRaids"] = "只有指定的團隊副本"
L["Loadout.LimitDungeons"] = "只有指定的地下城"
L["Loadout.Scope.OpenWorld"] = "開放世界"
L["Loadout.Scope.Raid"] = "團隊副本"
L["Loadout.Scope.Dungeon"] = "地下城"
L["Loadout.Scope.Delve"] = "探究"
L["Loadout.Scope.Arena"] = "競技場"
L["Loadout.Scope.Battleground"] = "戰場"
-- Binding label: spec + class, e.g. "Protection Warrior" (reorder for your locale).
L["Loadout.SpecClass"] = "%s %s"
L["Loadout.Require.Gear"] = "裝備套裝"
L["Loadout.Require.Talent"] = "天賦"
L["Loadout.Require.TalentOption"] = "天賦或已知法術"
L["Loadout.Require.Loadout"] = "天賦構建"
-- On-icon "what's wrong" tags (newline wraps them to two lines on the icon)
L["Loadout.Tag.Gear"] = "錯誤\n裝備"
L["Loadout.Tag.Talent"] = "缺少\n天賦"
L["Loadout.Tag.Loadout"] = "錯誤\n構建"

-- ============================================================================
-- BUFF OVERLAY TEXT
-- ============================================================================
-- These must be kept very short (2-4 chars per line) to fit on small icons.
L["Overlay.NoDrPoison"] = "沒有\n毒藥"
L["Overlay.NoAura"] = "沒有\n光環"
L["Overlay.Duplicate"] = "重複"
L["Overlay.NoStone"] = "沒有\n糖"
L["Overlay.NoGem"] = "沒有\n寶石"
L["Overlay.NoSoulstone"] = "沒有\n靈魂石"
L["Overlay.NoFaith"] = "沒有\n信標"
L["Overlay.NoLight"] = "沒有\n信標"
L["Overlay.NoES"] = "沒有\n大地盾"
L["Overlay.NoSource"] = "沒有\n魔源"
L["Overlay.NoScales"] = "沒有\n鱗片"
L["Overlay.NoLink"] = "沒有\n共生"
L["Overlay.NoWeyrnstone"] = "沒有\n龍隊石"
L["Overlay.NoTimeless"] = "沒有\n永恆"
L["Overlay.NoAttune"] = "沒有\n同調"
L["Overlay.NoFamiliar"] = "沒有\n魔寵"
L["Overlay.DropWell"] = "置放\n靈魂井"
L["Overlay.DropTable"] = "置放\n餐桌"
L["Overlay.Repair"] = "修理\n裝備"
L["Overlay.RepairLabel"] = "修理"
L["Overlay.Reagents"] = "材料\n不足"
L["Overlay.ReagentLabel"] = "材料"
L["Overlay.Ammo"] = "彈藥\n不足"
L["Overlay.AmmoLabel"] = "彈藥"
L["Overlay.EquipAmmo"] = "裝備\n彈藥"
L["Overlay.DriveBy"] = "增益\n目標"
L["Overlay.NoTracking"] = "沒有\n跟蹤"
L["Overlay.SleepingBag"] = "睡\n袋"
L["Overlay.CampSit"] = "工具"
L["Overlay.CampKit"] = "營地"
L["Overlay.NoGrim"] = "沒有\n魔典"
L["Overlay.NoSacrifice"] = "沒有\n犧牲"
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
L["Overlay.NoImbue"] = "沒有\n灌注"
L["Overlay.FindLeyline"] = "尋找\n地脈"
L["Overlay.NoPet"] = "沒有\n寵物"
L["Overlay.PassivePet"] = "寵物\n被動"
L["Overlay.WrongPet"] = "寵物\n錯誤"
L["Overlay.FeedPet"] = "餵食\n寵物"
L["Overlay.WrongStance"] = "錯誤\n姿態"
L["Overlay.WrongForm"] = "錯誤\n形態"
L["Overlay.WrongAura"] = "錯誤\n光環"
L["Overlay.NoAspect"] = "沒有\n型態"
L["Overlay.NoArmor"] = "沒有\n護甲"
L["Overlay.NoRighteousFury"] = "沒有\n怒氣"
L["Overlay.NoInnerFire"] = "沒有\n心靈\n之火"
L["Overlay.NoThorns"] = "沒有\n荊棘術"
L["Overlay.NoOath"] = "沒有\n誓言"
L["Overlay.NoRune"] = "沒有\n符文"
L["Overlay.DKWrongRune"] = "符文\n錯誤"
L["Overlay.DKWrongRuneOH"] = "副手\n符文\n錯誤"
L["Overlay.NoFlask"] = "沒有\n精鍊"
L["Overlay.NoFood"] = "沒有\n食物"
L["Overlay.NoMageFood"] = "法師\n餐點桌"
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
L["Label.Imp"] = "小鬼"
L["Label.Voidwalker"] = "虛無行者"
L["Label.Felhunter"] = "惡魔獵犬"
L["Label.Sayaad"] = "薩亞德"
L["Label.Succubus"] = "魅魔"
L["Label.Ghoul"] = "食屍鬼"
L["Label.WaterElemental"] = "水元素"
L["Badge.Hearty"] = "澎"
L["Badge.Fleeting"] = "普"
L["Badge.Cauldron"] = "鍋"

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
L["Buff.DivineSpirit"] = "神聖靈魂"
L["Buff.ShadowProtection"] = "暗影防護"
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
L["Buff.Weyrnstone"] = "龍隊石"
-- Self
L["Buff.ArcaneFamiliar"] = "秘法魔寵"
L["Buff.Attunement"] = "黑曜同調"
L["Buff.CreateSoulwell"] = "製造靈魂之井"
L["Buff.RefreshmentTable"] = "餐點桌"
L["Buff.RepairGear"] = "修理裝備"
L["Buff.LowReagents"] = "材料不足"
L["Buff.LowAmmo"] = "彈藥不足"
L["Buff.DriveByBuffs"] = "槍彈增益"
L["Buff.Tracking"] = "追蹤中"
L["Buff.SleepingBag"] = "舒適的睡袋"
L["Buff.Camp"] = "營地增益"
L["Buff.DruidForm"] = "德魯伊形態"
L["Buff.DemonicSacrificeSoulLink"] = "魔性犧牲 & 靈魂鏈結"
L["Buff.WarlockStone"] = "法術石 / 火焰石"
L["Buff.Spellstone"] = "法術石"
L["Buff.Firestone"] = "火焰石"
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
L["Buff.RockbiterWeapon"] = "石化武器"
L["Buff.FrostbrandWeapon"] = "冰封武器"
L["Buff.EarthShieldSelf"] = "自身大地之盾"
L["Buff.WaterLightningShield"] = "水/閃電之盾"
L["Buff.ShieldNoTalent"] = "盾(無天賦)"
-- Pet
L["Buff.PetPassive"] = "寵物被動"
L["Buff.HunterPet"] = "獵人寵物"
L["Buff.PetHappiness"] = "寵物快樂值"
L["Buff.UnholyGhoul"] = "穢邪食屍鬼"
L["Buff.WarlockDemon"] = "術士惡魔"
L["Buff.WaterElemental"] = "水元素"
L["Buff.WrongDemon"] = "錯誤惡魔"
L["Buff.WarriorStance"] = "戰士姿態"
L["Buff.PaladinAura"] = "聖騎士光環"
L["Buff.PaladinBlessing"] = "聖騎士祝福"
L["Buff.HunterAspect"] = "獵人形態"
L["Buff.TrueshotAura"] = "強擊光環"
L["Buff.MageArmor"] = "霜/冰/魔甲術"
L["Buff.RighteousFury"] = "正義之怒"
L["Buff.InnerFire"] = "心靈之火"
L["Buff.LightningShield"] = "閃電盾"
L["Buff.ShamanImbue"] = "武器灌注"
L["Buff.SkyborneAttunement"] = "同調 / 充能 (天裔)"
L["Buff.WarlockArmor"] = "惡魔皮膚/護甲"
L["Buff.Thorns"] = "荊棘術"
L["Buff.OathOfLight"] = "誓言之光"
-- Consumable
L["Buff.AugmentRune"] = "增強符文"
L["Buff.Flask"] = "精鍊"
L["Buff.DelveFood"] = "探究食物"
L["Buff.Food"] = "食物"
L["Buff.MageFood"] = "法師餐點"
L["Buff.Healthstone"] = "治療石"
L["Buff.ManaGem"] = "法力寶石"
L["Buff.Weapon"] = "武器"
L["Buff.WeaponOH"] = "武器(副手)"

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
    L["Tooltip.PaladinDuplicate"] = "重複檢查"
L["Tooltip.PaladinAuraDuplicate.Desc"] =
    "當其他聖騎士已經給你相同類型的光環時，會發出警告。如果該光環行有備用光環，則會提示你選擇備用光環。"
L["Tooltip.DriveBy.Desc"] =
    "在非戰鬥狀態下，當目標是隊伍外的友方玩家且缺少你提供的增益效果時，會顯示此資訊。點擊即可施放最適合的增益效果。"
L["Tooltip.SleepingBag.Desc"] = "僅在等級低於最高等級時顯示。在戰鬥中、城市和旅館中隱藏。會在「休息充足」效果結束前發出警告。在睡袋中休息時，圖示會倒數顯示下一層「休息充足」效果的持續時間。當「休息充足」效果達到3層時，會倒數計時顯示下次刷新時間。"
L["Tooltip.InstanceEntryReminder"] = "副本進本提示"
L["Tooltip.InstanceEntryReminder.Desc"] =
    "進入地下城時會短暫顯示放置靈魂井的提示。施放法術或30秒後將消失。"
L["Tooltip.MageFood"] = "僅限治療者"
L["Tooltip.MageFood.Desc"] = "只有當你玩捕時才顯示"
L["Tooltip.TankOnly"] = "坦克檢查"
L["Tooltip.RighteousFuryTank.Desc"] =
    "僅在您擔任坦克角色（或主坦克）時顯示。若要永遠顯示，請在設定中將“顯示”設為“永遠”。"
L["Tooltip.TankHint"] = "(坦克)"
L["Tooltip.TankTarget"] = "坦克目標"
L["Tooltip.ThornsTank.Desc"] =
    "組隊時，它會檢查你的坦克（坦克角色或主坦克），點擊即可對他們施放荊棘術。單人或沒有坦克時，它會檢查你。"
L["Tooltip.DemonSetup"] = "惡魔配置"
L["Tooltip.DemonSetup.Desc"] =
    "展示惡魔配置的下一步。使用靈魂鏈接，將你的惡魔鏈接起來。使用惡魔契約，犧牲一個惡魔，召喚另一個惡魔，然後連結它。"
L["BuffTooltip.ProvidedBy"] = "由 %s 提供"

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
L["Display.Description"] = "一目了然地查看所有缺失的增益。"
L["Display.OpenOptions"] = "打開選項"
L["Display.SlashCommands"] = "使用指令:  /br, /br lock, /br unlock, /br test, /br minimap, /br snooze, /br auras"
L["Display.MinimapLeftClick"] = "|cFFCFCFCF左鍵點擊|r: 選項"
L["Display.MinimapRightClick"] = "|cFFCFCFCF右鍵點擊|r: 測試模式"
L["Display.SnoozeChat.Loading"] = "%s: 已暫停提醒，直到下一個登入畫面。輸入 /br snooze 可再次顯示所有提醒。"
L["Display.SnoozeChat.Rest"] = "%s: 提醒已自動暫停，直到您離開此休息區域。輸入 /br snooze 可再次顯示所有提醒。"
L["Display.UnsnoozeChat"] = "暫停提醒再次顯示。"
L["Display.LoginFirstInstall"] =
    "感謝安裝！輸入 |cFFFFD100/br unlock|r 來移動增益顯示，或者使用 |cFFFFD100/br|r 選項面板底部的按鈕。"
L["Display.LoginSnooze"] =
    "消耗品關閉按鈕現在是右鍵點擊: 右鍵點選消耗品可暫停其提醒，或輸入 |cFFFFD100/br snooze|r。"
L["Display.LoginCasterName"] =
    "外部增益效果現在可以顯示每個增益效果的施放者。在 |cFFFFD100/br|r > 類別 > 外部增益啟用此功能。"

-- ============================================================================
-- OPTIONS: NAVIGATION LABELS
-- ============================================================================
L["Tab.DisplayBehavior"] = "顯示/行為"

-- Sidebar groups
L["Sidebar.AddonSettings"] = "插件設定"
L["Sidebar.Buffs"] = "增益"
L["Sidebar.Appearance"] = "外觀"
L["Sidebar.Display"] = "顯示"
L["Sidebar.Alerts"] = "警告"
-- Externals (present-based display)
L["Externals.Title"] = "外來增益"
L["Externals.NoneTracked"] = "首先在「增益」>「外來增益」頁面上追蹤至少一個增益。"
L["Externals.Sound"] = "聲音警報"
L["Externals.Sound.Tooltip"] =
    "您追蹤的每個增益效果落在您身上時都會播放此聲音。選擇「無」以保持靜音。|n若要為某個增益效果提供自己的聲音，請將指標放在其行末尾的標誌上。|n首領戰鬥期間的更改會在戰鬥結束時生效。"
L["Externals.Sound.Hint"] = "每個增益都可以從其所在行覆蓋此設定。"
L["Externals.Sound.Link"] = "聲音"
L["Externals.Sound.Silent"] = "靜音"
L["Externals.Sound.Change"] = "點擊以更改它。"
L["Externals.Sound.Plays"] = "當這個增益效果落在你身上時，遊戲播放%s。"
L["Externals.Sound.Silenced"] = "此增益效果不發出任何聲音。"
L["Externals.Sound.SilentByDefault"] = "對於共享聲音來說，這個增益效果太頻繁了。覆蓋它以添加一個。"
L["Externals.Sound.NoAlert"] = "未設定聲音警報。點選可賦予該增益其自己的聲音。"
L["Externals.Sound.Override.Desc"] =
    "為這個增益賦予自己的聲音。當此功能關閉時，增益會播放頁面的聲音警報。"
L["DisabledReason.SoundOverride"] = "開啟「覆蓋」來選擇該增益效果的聲音。"
L["Externals.SelectAll"] = "全部"
L["Externals.SelectAll.Tooltip"] = "追蹤該群組中的每個增益。"
L["Externals.SelectNone"] = "無"
L["Externals.SelectNone.Tooltip"] = "停止追蹤該群組中的每個增益。"
L["Externals.PersonalDefensives"] = "在你的防禦"
L["Externals.GroupDefensives"] = "群體防禦"
L["Externals.MinorGroupDefensives"] = "小群體防禦"
L["Externals.Boosts"] = "傷害 & 法力"
L["Externals.Movement"] = "移動"
L["Externals.Aggro"] = "威脅重定向"
L["Externals.Augmentation"] = "強化"
L["Externals.Countdown"] = "倒數計時"
L["Externals.AppearanceNote"] =
    "戰鬥中所做的更改會在你離開戰鬥後立即生效。解鎖框架即可拖曳列。"
L["Externals.ShowSwipe"] = "顯示持續時間轉圈"
L["Externals.ShowSwipe.Desc"] =
    "在圖示上掃一條黑色的線。當增益耗盡時，轉圈會露出圖示。"
L["Externals.ShowTooltips"] = "顯示工具提示"
L["Externals.ShowTooltips.Desc"] =
    "當滑鼠位於圖示上時顯示遊戲的增益工具提示。這些圖示不需要點擊，只需要移動滑鼠。"
L["Externals.CasterName"] = "施法者名字"
L["Externals.CasterName.Desc"] =
    "在圖示旁顯示施放增益效果的人員，顏色以職業顏色表示。"
L["Externals.CasterNameOff"] = "首先為施法者的名字挑選一個陣營。"
L["Externals.Sound.Claimed"] = "%s 已經為此法術ID播放一個聲音。"
-- Externals: the player's own entries
L["Externals.Custom"] = "你的增益"
L["Externals.Custom.SpellID"] = "法術ID"
L["Externals.Custom.Name"] = "名字"
L["Externals.Custom.Add"] = "添加"
L["Externals.Custom.Edit"] = "編輯"
L["Externals.Custom.Delete"] = "刪除此增益"
L["Externals.Custom.Empty"] = "你自己還沒有增益。"
L["Externals.Custom.SpellIDs"] = "法術ID"
L["Externals.Custom.RemoveID"] = "移除此法術ID"
L["Externals.Custom.Hint"] =
    "使用增益工具提示中的光環ID，而不是技能ID。逗號將多個ID組合到一個圖示中。"
L["Externals.Custom.Unknown"] = "未知ID %d"
L["Externals.Custom.AlreadyIn"] = "已存在於 %s"
L["Externals.Custom.RowTooltip"] = "法術ID: %s"
L["Externals.Custom.Grab"] = "我的增益"
L["Externals.Custom.GrabTitle"] = "現在你身上有增益"
L["Externals.Custom.Grab.Tooltip"] =
    "請從你的增益中挑選現在沒有條目涵蓋的。您選擇的那個將填滿該欄位。"
L["Externals.Custom.GrabEmpty"] =
    "你身上沒有新的增益。遊戲在戰鬥、首領戰和傳奇鑰石運行中隱藏了你的增益。"
L["Externals.Custom.GrabMore"] = "還有 %d 個"

-- Page titles
L["Page.General"] = "通用"
L["Page.Defaults"] = "預設"
L["Page.Visibility"] = "可見性"
L["Page.ChatRequests"] = "聊天請求"
L["Page.Layout"] = "佈局"
L["Page.Categories"] = "類別"
L["Page.Profiles"] = "設定檔"
L["Page.Reminders"] = "提醒"
L["Page.CustomAnchors"] = "自訂定位"

-- Per-category page section headers
L["Section.Tracking"] = "追蹤"
L["Section.TrackingOverrides"] = "追蹤覆寫"
L["Section.TrackingOverrides.Desc"] =
    "縮小一種情況的追蹤模式。預設保留上述模式。如果有兩個同時適用時，限制最嚴格的那個獲勝。"
L["DisabledReason.PvPDisabled"] = "此類別在PvP中完全隱藏 (請看可見性頁面)。"

-- ============================================================================
-- OPTIONS: SOUND ALERTS
-- ============================================================================
L["Options.Sound.Preview"] = "預覽"
L["Options.Preview"] = "預覽"

-- ============================================================================
-- OPTIONS: GLOBAL DEFAULTS
-- ============================================================================
L["Options.GlobalDefaults.Note"] = "（套用於所有類別，除非被自訂外觀覆蓋）"
L["Options.Default"] = "預設"
L["Options.Text"] = "文字"
L["Options.AppliesEverywhere"] = "適用於所有類別。類別不能覆蓋此規則。"
L["Options.Font"] = "字體"
L["Options.TextOutline"] = "外框樣式"
L["Options.TextOutline.None"] = "無"
L["Options.TextOutline.Outline"] = "外框"
L["Options.TextOutline.Thick"] = "粗外框"
L["Options.TextOutline.Monochrome"] = "單色"
L["Options.TextOutline.OutlineMono"] = "外框 + 單色"
L["Options.TextOutline.ThickMono"] = "粗外框 + 單色"
L["Options.SlugOutline"] = "平滑外框"
L["Options.SlugOutline.Desc"] =
    "使用客戶端的Slug文字渲染器繪製外框。邊緣更平滑，但外框可能看起來稍微粗一點。"
L["Options.SlugOutline.Disabled"] = '僅適用於"外框"和"粗外框"樣式。'

-- ============================================================================
-- OPTIONS: GLOW SETTINGS
-- ============================================================================
L["Options.GlowReminderIcons.Title"] = "提示圖示發光"
L["Options.GlowReminderIcons.CpuWarning"] =
    "每偵發光動畫，因此只要圖示處於開啟狀態，就會消耗CPU資源。預設關閉。"
L["Options.GlowKind.Expiring"] = "即將過期"
L["Options.GlowKind.Missing"] = "缺失"
L["Options.ExpiringGlow"] = "過期發光"
L["Options.ExpiringGlow.Desc"] = "發光圖示代表增益效果仍然有效，但很快就會結束。"
L["Options.MissingGlow"] = "缺失發光"
L["Options.MissingGlow.Desc"] = "增益完全缺失時發光圖示。"
L["Options.GlowSettings.Expiring"] = "發光設置 — 即將過期"
L["Options.GlowSettings.Missing"] = "發光設置 — 缺失"
L["Options.Glow.Enabled"] = "啟用"
L["Options.GlowMissingPets"] = "缺失寵物發光"
L["Options.Expiration"] = "過期"
L["Options.Glow"] = "發光"
L["Options.UseCustomColor"] = "使用自訂顏色"
L["Options.UseCustomColor.Desc"] =
    "啟用後會降低觸發發光的飽和度並更改顏色。\n可能看起來不如預設觸發發光清晰。"
L["Options.ExpirationReminder"] = "過期提示"
L["Options.ExpirationWarning"] = "低於多少時警告"
L["Options.ExpirationWarning.Note"] = "持續時間較短的增益效果會更早發出警告，警告時間與其持續時間成正比。滑鼠懸停可查看範例。"
L["Options.ExpirationWarning.Desc"] =
    "持續時間較長的增益效果會在此階段發出警告。持續時間較短的增益效果會在其持續時間的一部分時間發出警告（請參閱「進階」部分）。持續時間為 5 分鐘或更短的增益效果僅在消失時顯示警告。自訂增益效果的持續時間由其自行決定。"
L["Options.ExpirationAdvanced"] = "進階"
L["Options.ExpirationShare"] = "共享持續時間"
L["Options.ExpirationShare.Note"] = "當增益效果剩餘約 %d%% 時發出警告，但結束以前絕不會超過 %s 秒。"
L["Options.ExpirationShare.Example"] = "%s 增益: %s."
L["Options.ExpirationShare.Formula"] = "警告時間 = 分(%d%% x 持續時間，%s)，向下取整到整分鐘"
L["Options.ExpirationShare.Off"] = "過期警告已關閉。"
L["Options.ExpirationPreview.Header"] = "警告時間根據增益持續時間:"
L["Options.ExpirationPreview.Line"] = "%s: %s"
L["Options.ExpirationPreview.OrMore"] = "%s 或更多"
L["Options.Override.Expiration.Desc"] =
    "為該類別設定警告時間。關閉此功能後，將採用預設設定頁面中的時間。"
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
L["Options.Healthstone.LowStock"] = "當低於時警告"
L["Options.Healthstone.LowStock.Desc"] =
    "當您有治療石但不夠時顯示溫和警告。無論此設定如何，始終會追蹤缺失的治療石(0)。"
L["Options.Healthstone.Threshold"] = "當有時警告"
L["Options.Healthstone.Threshold.Desc"] =
    "當治療石等於或低於此數量時顯示不足警告。\n\n|cffffcc001:|r 僅在剛好有1個時警告。\n|cffffcc002:|r 有1個或2個時警告。"

L["Options.Repair.Threshold"] = "低於多少警告"
L["Options.Repair.Threshold.Desc"] = "當裝備的物品耐久度低於多少百分比時顯示修理提醒。"
L["Options.RepairHideInCombat"] = "戰鬥中隱藏"
L["Options.RepairHideInCombat.Desc"] =
    "在戰鬥中時隱藏修理提醒。戰鬥中你無法修理。"
L["Options.Reagent.Threshold"] = "低於多少警告"
L["Options.Reagent.Threshold.Desc"] =
    "當你攜帶的用於你所掌握的法術的材料數量少於多少數量時發出警告。"
L["Options.Reagent.RestedOnly"] = "只有在休息區域"
L["Options.Camp.LightFire"] = "提醒放置篝火"
L["Options.Camp.LightFire.Desc"] =
    "如果附近沒有篝火，當你攜帶可用的篝火工具包和至少一件營地設施時，提醒會顯示「營地」。點擊放置最合適的工具包，然後點擊地面。"
L["Options.Ammo.Threshold"] = "獵人 (堆疊)"
L["Options.Ammo.Threshold.Desc"] =
    "警告獵人裝備的彈藥數量不得低於此數量（每組 200 發）。"
L["Options.Ammo.Shots"] = "其他 (射擊)"
L["Options.Ammo.Shots.Desc"] = "戰士和盜賊使用弓箭或槍械。以下警告指出他們只能射擊這麼多次。"

-- ============================================================================
-- OPTIONS: SOULSTONE
-- ============================================================================
L["Options.Soulstone.HideCooldown"] = "冷卻時隱藏（術士）"
L["Options.Soulstone.HideCooldown.Desc"] =
    "啟用後，當靈魂石法術處於冷卻中時，不會向術士顯示提示。僅適用於術士。"
L["Options.Soulstone.PinnedTarget"] = "始終施放"
L["Tooltip.PinNotInGroup"] = "(不在隊伍中)"
L["Tooltip.TargetLine"] = "施放在: %s"
L["Tooltip.Next"] = "下一個:"
L["Tooltip.ChoiceSpell"] = "· %s"

-- ============================================================================
-- OPTIONS: FREE CONSUMABLES
-- ============================================================================
L["Options.FreeConsumables"] = "免費消耗品"
L["Options.FreeConsumables.Note"] = "（治療石、永久強化符文）"
L["Options.FreeConsumables.Override"] = "覆蓋內容過濾"
L["Options.FreeConsumables.Follows"] = "根據上方篩選條件所顯示。"
L["Options.FreeConsumables.Override.Desc"] =
    "勾選後，免費消耗品將使用下方獨立的內容類型設置。\n\n取消勾選後，它們將遵循與其他消耗品相同的內容過濾規則。"

-- ============================================================================
-- OPTIONS: ICONS
-- ============================================================================
L["Options.Icons"] = "圖示"
L["Options.IconStyle"] = "圖示樣式"
L["Options.IconStyle.Desc"] =
    "現代: 扁平的方形邊框。其他選項: 遊戲中的圓形動作按鈕邊框。不用於外部或消耗品按鈕。"
L["Options.IconStyle.Modern"] = "現代"
L["Options.IconStyle.Blizzard"] = "暴雪"
L["Options.IconStyle.Forever"] = "永恆"
L["DisabledReason.IconStyleFrame"] = '此圖示樣式自備邊框。如需新增邊框，請將圖示樣式設定為「%s」（預設值頁面）。'
L["DisabledReason.IconStyleMasque"] = "Masque 可以設定圖示樣式。若要使用此功能，請在 Masque 中停用 BuffReminders 群組。"
L["DisabledReason.IconStyleNoArt"] = "此遊戲用戶端缺少按鈕圖示。圖示風格保持現代風格。"
L["Options.ShowTextToggle"] = "顯示"
L["Options.MainText.Desc"] =
    "在圖示上顯示主要文字：例如 17/20 這樣的計數，或像禁止寵物這樣的標籤。 預設設定頁面可以設定其位置。倒數計時始終可見。"
L["Options.ShowMissingCountOnly"] = "僅顯示缺失數量"
L["Options.ShowMissingCountOnly.Desc"] =
    "僅顯示缺失增益的數量（例如：”1“），而不是完整的分數形式（例如：”19/20“）。"

-- ============================================================================
-- OPTIONS: TEXT POSITIONS
-- ============================================================================
L["Options.TextPositions.Zone"] = "位置"
L["Options.TextPositions.Offset"] = "偏移"
L["Options.TextPositions.OffsetX.Short"] = "X"
L["Options.TextPositions.OffsetY.Short"] = "Y"
L["Options.TextPositions.Size"] = "大小"
L["Options.TextPositions.MainText"] = "主文字"
L["Options.TextPositions.MainText.Note"] =
    "大文字的位置：計數、倒數計時和標籤。"
L["Options.TextPositions.StackCount"] = "堆疊計數"
L["Options.TextPositions.StatLabel"] = "屬性標籤"
L["Options.TextPositions.Badge"] = "標誌 (H / F / C)"
L["Options.TextSizes.Note"] =
    "自動將文字保持為基礎大小。設定一個值以調整文字本身的大小（以圖示的百分比表示）。"
L["Options.TextPositions.Vertical.Above"] = "上方"
L["Options.TextPositions.Vertical.InsideTop"] = "頂部"
L["Options.TextPositions.Vertical.InsideMiddle"] = "中央"
L["Options.TextPositions.Vertical.InsideBottom"] = "底部"
L["Options.TextPositions.Vertical.Below"] = "下方"
L["Options.TextPositions.Align.Left"] = "左側"
L["Options.TextPositions.Align.Center"] = "中央"
L["Options.TextPositions.Align.Right"] = "右側"

-- ============================================================================
-- OPTIONS: CLICK TO CAST
-- ============================================================================
L["Options.Interaction"] = "互動"
L["Options.TextOverlays"] = "文字 & 遮蓋層"
L["Options.BuffReminderText"] = '"補增益!" 文字'
L["Options.ItemFilters"] = "物品"
L["Options.Direction.Default"] = "預設"
L["Options.Direction.Desc"] =
    "此框架中圖示的增長方向。預設值與預設頁面上的方向一致。"
L["Options.ClickToCast"] = "點擊施法"
L["Options.ClickToCast.DescFull"] =
    "你可以點擊增益圖示來施放對應的法術（僅限非戰鬥狀態）。只對你的角色可施放的法術有效。"
L["Options.HoverHighlight"] = "懸停高亮顯示"
L["Options.ClickToCast.Custom.Desc"] =
    "使該類別圖示在右鍵選單和懸停高亮顯示時可點選。即使此功能關閉，具有自訂點擊操作的增益效果仍可點擊。"
L["Options.HoverHighlight.Desc"] = "當滑鼠懸停在可點擊的增益圖示上時，顯示細微的高亮顯示。"
L["Options.RightClickMenu"] = "右鍵點擊: 暫停和設定選單"
L["Options.RightClickMenu.Desc"] =
    "右鍵點擊需要點擊多次才能打開的提醒圖示，即可開啟選單。此選單可以暫停提醒、暫停其所屬類別或暫停所有提醒，並開啟提醒的設定。此選單僅在非戰鬥狀態下可用。如果此選項關閉，則右鍵單擊與左鍵單擊的功能相同。"
L["Options.SubIconReveal"] = "顯示替代的"
L["Options.SubIconReveal.Desc"] =
    "某些提醒會顯示替代方案的小圖示。例如：背包中的其他消耗品、其他祝福、其他追蹤功能、營地功能，以及團隊或單人版本的團隊增益效果。啟用「懸停時」後，當遊標停留在提醒圖示上時，這些圖示就會顯示。點擊圖示即可使用對應的替代方案。點選操作需要在提醒類別（「類別」標籤頁）中啟用「點擊施放」選項。如果「點擊施放」選項關閉，消耗品圖示會顯示您的物品，但無法點擊，其他替代方案也不會顯示。"
L["Options.SubIconReveal.Hover"] = "懸停時"
L["Options.SubIconReveal.Always"] = "永遠"
L["Options.Snooze.Note"] =
    "暫停提醒會持續到下一個登入畫面出現，或直到你離開開始設定提醒的城市或旅館。輸入 |cFFFFD100/br snooze|r 可暫停所有提醒，再次輸入即可顯示提醒。"
L["Options.RequestBuffInChat"] = "在聊天中請求缺失的增益"
L["Options.RequestBuffInChat.Tooltip"] = "點選你職業無法施放的缺失增益，向你的隊友請求幫助。"
L["ChatRequests.PageNote"] = "點選你職業無法施放的缺失增益，即可在聊天框中請求獲得該增益。"
L["Options.ChatRequest.Wait"] = "請求之間等待 5 秒"
L["Options.ChatRequest.Wait.Desc"] = "阻止雙擊發送垃圾訊息。"
L["Options.ChatRequest.Cooldown.Hint"] = "請求未顯示在聊天中？把它關掉。"
L["Options.ChatRequest.ResetAll"] = "重置全部"
L["ChatRequests.Messages"] = "訊息"
L["ChatRequests.Restore"] = "恢復: %s"
L["DisabledReason.ChatRequestsOff"] = "請求停用時也關閉。"
L["DisabledReason.NoCustomMessages"] = "無自訂訊息。"
-- Chat request messages
-- Asian translators: translate these so chat messages match your locale.
L["ChatRequest.intellect"] = "請補上祕法智力增益"
L["ChatRequest.attackPower"] = "請補上戰鬥怒吼增益"
L["ChatRequest.bronze"] = "請補上青銅龍的祝福增益"
L["ChatRequest.versatility"] = "請補上野性印記增益"
L["ChatRequest.stamina"] = "請補上真言術：韌的增益"
L["ChatRequest.shadowProtection"] = "請補上暗影防護增益"
L["ChatRequest.skyfury"] = "請補上天怒增益"
L["ChatRequest.atrophicNumbingPoison"] = "請補上萎縮/麻痺毒藥"
L["ChatRequest.devotionAura"] = "請補上虔誠光環"
L["ChatRequest.soulstone"] = "請補上靈魂石"
L["ChatRequest.healthstone"] = "請給我治療石"
L["ChatRequest.mageFood"] = "法師請放餐點桌"
L["ChatRequest.thorns"] = "請給我荊棘術"
L["ChatRequest.paladinBlessing"] = "請給我%s"

-- ============================================================================
-- OPTIONS: PET
-- ============================================================================
L["Options.PetSpecIcon"] = "懸停時顯示獵人寵物專精圖示"
L["Options.PetSpecIcon.Title"] = "懸停時寵物專精圖示"
L["Options.PetSpecIcon.Desc"] =
    "鼠標懸停時，寵物圖示將變為對應的專精技能（狡詐、狂野、堅韌）。"
L["Options.ShowDescriptionTooltips"] = "顯示提示訊息"
L["Options.ShowDescriptionTooltips.Desc"] =
    "當滑鼠懸停在提示圖示上時，顯示點擊所用法術或物品的工具提示。如果點選請求隊伍獲得增益效果，工具提示會顯示增益效果及其提供者。戰鬥中不顯示工具提示。"
L["Options.TooltipModifier"] = "提示鍵"
L["Options.TooltipModifier.Desc"] =
    "選取某個按鍵後，增益效果和物品的提示訊息僅在按住該按鍵時顯示。您可以先將滑鼠指標指向圖標，然後再按下按鍵。您可以在「預設設定」頁面的「互動」部分啟用提示訊息。"
L["Options.TooltipModifier.None"] = "無"
L["Options.TooltipModifier.Shift"] = "Shift"
L["Options.TooltipModifier.Ctrl"] = "Ctrl"
L["Options.TooltipModifier.Alt"] = "Alt"
L["Menu.Snooze"] = "暫停 %s"
L["Menu.SnoozeAll"] = "暫停所有提醒"
L["Menu.AllReminders"] = "全部提醒"
L["Menu.Settings"] = "設定..."
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
L["Options.PetLabels.Classes"] = "標籤用於"
L["Options.PetLabels.Classes.Desc"] = "寵物標籤僅顯示在已勾選類別的寵物身上。"
L["Options.PetLabels.Desc"] = "在每個圖示下方顯示寵物名稱和專精。"

-- ============================================================================
-- OPTIONS: CONSUMABLE DISPLAY
-- ============================================================================
L["Options.ItemTextSize"] = "物品文字大小"
L["Options.ItemTextSize.Title"] = "物品文字大小"
L["Options.ItemTextSize.Desc"] =
    "堆疊計數、統計標籤和徽章的字體大小。以下三者均可進行自訂設定。"
L["Options.ConsumableBadgeOnSubIcons"] = "在子圖示上顯示品質標記"
L["Options.ConsumableBadgeOnSubIcons.Title"] = "品質標記在子圖示上"
L["Options.ConsumableBadgeOnSubIcons.Desc"] =
    '在每個子圖示顯示食物品質字母 (例如 "澎"為澎湃，"普"為普通的)，而非只在主圖示。'
L["Options.ItemDisplay"] = "物品顯示"
L["Options.ItemDisplay.IconOnly"] = "僅圖示"
L["Options.ItemDisplay.IconOnlyDesc"] = "顯示數量最多的物品"
L["Options.ItemDisplay.SubIcons"] = "子圖示"
L["Options.ItemDisplay.SubIconsDesc"] =
    "其他項目以小圖示的形式顯示在主圖示旁。\"顯示替代的\" 在「預設值」頁面上設定它們何時顯示。"
L["Options.ItemDisplay.Expanded"] = "展開"
L["Options.ItemDisplay.ExpandedDesc"] = "將每個物品變體顯示為全尺寸圖示"
L["Options.ItemDisplay.Mode"] = "消耗品物品顯示"
L["Options.ItemDisplay.Mode.Desc"] =
    "設置具有多個變體的消耗品物品（例如各種精鍊類型）的顯示方式。"
L["Options.SubIconSide"] = "替代方向"
L["Options.SubIconSide.Desc"] = "選擇替代圖示要顯示在提醒圖示的哪一側。"
L["Options.SubIconSide.Bottom"] = "底部"
L["Options.SubIconSide.Top"] = "頂部"
L["Options.SubIconSide.Left"] = "左側"
L["Options.SubIconSide.Right"] = "右側"
L["Options.ShowWithoutItems"] = "背包中沒有也顯示"
L["Options.ShowWithoutItems.Title"] = "沒有物品也顯示"
L["Options.ShowWithoutItems.Desc"] =
    "顯示您未攜帶的物品的消耗品提醒。"
L["Options.ShowWithoutItemsReadyCheckOnly"] = "只有在準備確認"
L["Options.ShowWithoutItemsReadyCheckOnly.Title"] = "只在準備確認時顯示缺失的物品"
L["Options.ShowWithoutItemsReadyCheckOnly.Desc"] =
    "僅在準備檢查時顯示您未攜帶的消耗品。"
L["Options.DelveFoodOnly"] = "在探究中僅顯示探究食物"
L["Options.DelveFoodOnly.Desc"] = "在探究中隱藏除探究食物外的所有消耗品提示。"
L["Options.HideLegacyConsumables"] = "隱藏舊版消耗品"
L["Options.HideLegacyConsumables.Title"] = "隱藏舊版消耗品"
L["Options.HideLegacyConsumables.Desc"] =
    "隱藏過去資料片中的食物、精鍊和符文。保留它們用於時光漫遊或舊團隊副本。"
L["Options.PreferReusableRunes"] = "偏好可重複使用的增強符文"
L["Options.PreferReusableRunes.Title"] = "偏好可重複使用的增強符文"
L["Options.PreferReusableRunes.Desc"] =
    "如果您有可重複使用的增強符文，僅顯示該符文。如果沒有，顯示其他符文。"
L["Options.PlaceAtPlayer"] = "放置盛宴和大鍋在腳下"
L["Options.PlaceAtPlayer.Desc"] =
    "點擊盛宴或大鍋圖示將放置在您的位置。如果此選項關閉，您必須選擇地面上的一個點。"

-- ============================================================================
-- OPTIONS: DK RUNEFORGE PREFERENCES
-- ============================================================================
L["Options.RuneMainHand"] = "主手"
L["Options.RuneOffHand"] = "副手"
L["Options.RuneTwoHanded"] = "雙手"
L["Options.RuneDualWield"] = "雙持"

-- ============================================================================
-- OPTIONS: ROGUE POISON PREFERENCES
-- ============================================================================
L["Options.RoguePoisonNote"] =
    "選擇要應用的毒藥及其優先順序（頂部=最高）。停用的毒藥永遠不會被施放，也不會觸發提醒。"
L["Options.PoisonLethal"] = "致命"
L["Options.PoisonNonLethal"] = "非致命"
L["Options.PoisonMainHand"] = "主手"
L["Options.PoisonOffHand"] = "副手"
L["Options.PoisonMoveUp"] = "優先級上升"
L["Options.PoisonMoveDown"] = "優先級下降"
L["Options.PoisonReset"] = "重置回預設"

-- ============================================================================
-- OPTIONS: BUFF SETTINGS GEAR ICONS
-- ============================================================================
L["Options.BronzeHideInCombat"] = "戰鬥中隱藏"
L["Options.BronzeHideInCombat.Desc"] =
    "當戰鬥中隱藏青銅龍的祝福的提醒。"
L["Options.DruidIgnoreTravelForm"] = "當旅行中忽略"
L["Options.DruidIgnoreTravelForm.Desc"] =
    "隱藏上坐騎時錯誤的旅行型態或坐騎型態的提醒。"
L["Options.DelveFoodTimer"] = "30秒後自動隱藏"
L["Options.DelveFoodTimer.Desc"] =
    "進入探究後30秒，探究食物的提醒將隱藏。"

-- ============================================================================
-- OPTIONS: LAYOUT
-- ============================================================================
L["Options.Layout"] = "佈局"
L["Options.SplitFrame"] = "分離為獨立框架"
L["Options.SplitFrame.Desc"] = "將此類別中的增益顯示在可獨立移動的單獨框架中。"

L["Options.DisplayOrder"] = "堆疊順序"

-- Layout page
L["Layout.DetachedIcons"] = "分離的圖示"
L["Layout.NoDetached"] =
    '沒有獨立的圖示。從所有增益頁面上的設定面板中分離增益 ("自己的框架")。'
L["Layout.FrameNotFound"] =
    "該框架目前在遊戲中不存在。 \n一旦其插件創建它，它將出現在定位點下拉列表中。"

-- Buff panel
L["BuffPanel.SettingsLink"] = "設定"
L["BuffRow.SettingsLink.Tooltip"] = "此增益的聲音警報、顯示模式和分離選項。"
L["BuffRow.Extras"] = "附加功能"
L["BuffRow.Option.Poisons"] = "毒藥"
L["BuffRow.Option.Runeforge"] = "符文鎔鑄"
-- Row state glyphs
L["BuffRow.Glyph.Sound"] = "聲音警報"
L["BuffRow.Glyph.Detached"] = "獨立的圖示"
L["BuffRow.Glyph.Detached.Desc"] =
    "該圖示可以自由放置在螢幕上。在增益的設定或佈局頁面上進行管理。"
L["BuffRow.Glyph.New"] = "新增益"
L["BuffRow.Glyph.New.Desc"] = "在最後更新加入。"
L["Options.SearchReminders"] = "搜尋提醒"
L["Options.SearchReminders.Desc"] = "按名稱、法術名稱或職業名稱尋找提醒。"
-- %d is the number of matching reminders
L["Options.SearchCount"] = "%d 找到"
L["Options.SearchEmpty"] = "沒有找到與此搜尋相符的提醒。"
-- %s is the option name
L["BuffPanel.EditOption"] = "編輯 %s"
L["BuffPanel.Show"] = "顯示"
L["BuffPanel.MageFoodContent"] = "何處"
L["BuffPanel.MageFoodContent.All"] = "所有副本"
L["BuffPanel.MageFoodContent.Dungeon"] = "僅限地下城"
L["BuffPanel.MageFoodContent.Raid"] = "僅限團隊副本"
L["BuffPanel.ShamanImbue"] = "點擊施放"
L["BuffPanel.ShamanImbue.Desc"] =
    "在你學會之前，點擊會依序施放風怒、火舌和石化。"
L["BuffPanel.WarlockStone.Hint"] = "選擇每組天賦中的一塊石頭。如果行中沒有石頭，則兩塊石頭都可以。"
L["BuffPanel.TalentGroup.Primary"] = "主要"
L["BuffPanel.TalentGroup.Secondary"] = "次要"
L["BuffPanel.DriveBy.AllowPvP"] = "允許 PvP 標記的目標"
L["BuffPanel.DriveBy.AllowPvP.Desc"] =
    "給已開啟 PvP 模式的玩家加增益效果也會使你被標記為 PvP 玩家。關閉此功能後，除非你也被標記為 PvP 玩家，否則其他已標記的玩家將被忽略。"
L["BuffPanel.DriveBy.Greeting"] = "問候"
L["BuffPanel.DriveBy.Greeting.Desc"] =
    "增益效果生效後，你可以密語或使用表情動作與該玩家互動，每位玩家每局限一次。戰鬥中不可使用。\n\n{name} = 玩家名字，{spell} = 增益。"
L["BuffPanel.DriveBy.Greeting.None"] = "沒什麼"
L["BuffPanel.DriveBy.Greeting.Whisper"] = "密語"
L["BuffPanel.DriveBy.Greeting.Emote"] = "表情"
L["BuffPanel.DriveBy.Whisper"] = "文字"
L["BuffPanel.DriveBy.Emote"] = "表情"
L["BuffPanel.DriveBy.Emote.Wave"] = "揮手"
L["BuffPanel.DriveBy.Emote.Hello"] = "問好"
L["BuffPanel.DriveBy.Emote.Bow"] = "鞠躬"
L["BuffPanel.DriveBy.Emote.Salute"] = "敬禮"
L["BuffPanel.DriveBy.Emote.Smile"] = "微笑"
L["BuffPanel.DriveBy.Emote.Cheer"] = "歡呼"
L["BuffPanel.DriveBy.Emote.Custom"] = "自訂表情..."
L["DriveBy.WhisperDefault"] = "使用{spell}強化你，祝你玩得開心！"
L["DriveBy.EmoteDefault"] = "使用{spell}強化{name}。祝你玩得開心！"
L["BuffPanel.WarlockDemon.Warn"] = "當不同的惡魔出現時發出警告"
L["BuffPanel.WarlockDemon.Warn.Desc"] = "如果啟用惡魔不是您允許此內容使用的惡魔之一，則顯示錯誤惡魔提醒。"
L["BuffPanel.WarlockDemon.Hint"] = "點擊一個惡魔以允許它。您可以允許多個。如果你清除了一排，所有惡魔都可以在那裡。"
L["BuffPanel.SacrificeDemon.Hint"] =
    "在每個天賦組中選擇要獻祭的惡魔。如果已有其他惡魔可用，點擊會先召喚它。空白行則使用你選擇的惡魔。"
L["BuffPanel.WarlockDemon.World"] = "世界"
L["BuffPanel.WarlockDemon.Dungeon"] = "地下城"
L["BuffPanel.WarlockDemon.Dungeon.Desc"] = "還涵蓋場景和探究。"
L["BuffPanel.WarlockDemon.Raid"] = "團隊"
L["BuffPanel.WarlockDemon.PvP"] = "PvP"
L["BuffPanel.WarlockDemon.Felguard"] = "如果有天賦的話，惡魔學識總是會召喚惡魔守衛。"
L["BuffPanel.WarriorStance.Hint"] = "點擊姿勢即可按內容啟用。未學習的姿勢不計入在內。空白行不顯示任何提示。"
L["BuffPanel.DruidForm.Hint"] = "點擊型態即可按內容啟用它們。未學習的型態不計​​入。空白行不顯示任何提醒。"
L["BuffPanel.DruidForm.Caster"] = "施放者 (無型態)"
L["BuffPanel.PaladinBlessing.Hint"] =
    "每個職業的主要祝福。如果其他聖騎士給予祝福，則由你提供備用祝福。"
L["BuffPanel.Blessing.Give"] = "給予"
L["BuffPanel.Blessing.IfTaken"] = "如果收到"
L["BuffPanel.Blessing.InGive"] = "在給予"
L["BuffPanel.Blessing.InBackup"] = "在如果收到"
L["BuffPanel.Blessing.NotLearnedShort"] = "尚未學會"
L["BuffPanel.Blessing.Clear"] = "清除"
L["BuffPanel.Blessing.MainTip"] = "你把這個給每個%s。"
L["BuffPanel.Blessing.BackupTip"] = "如果其他聖騎士提供 %s，則使用這個。"
L["BuffPanel.Blessing.NotLearned"] = "尚未學會。你給予 %s 替代。"
L["BuffPanel.Blessing.NotLearnedNone"] = "尚未學會。已略過。"
L["BuffPanel.Blessing.None"] = "無祝福"
L["BuffPanel.Blessing.None.Desc"] = "此職業沒有提醒。"
L["BuffPanel.Blessing.AddBackup"] = "新增備用"
L["BuffPanel.Blessing.ClickToChange"] = "點擊更改。"
L["BuffPanel.Blessing.ResetRow"] = "重置回預設"
L["BuffPanel.Blessing.SelfOnlyNote"] = "僅聖騎士職業適用。"
L["DisabledReason.BlessSelfOnly"] = '當"只有祝福我自己"啟用時關閉。'
L["DisabledReason.BlessingDefaults"] = "所有職業都使用其預設值。"
L["BuffPanel.BlessSelfOnly"] = "只有祝福我自己"
L["BuffPanel.BlessSelfOnly.Desc"] =
    "只檢查並祝福自己"
L["BuffPanel.Tracking.Scope"] = "追蹤"
L["BuffPanel.Tracking.Scope.Desc"] =
    "此提醒功能提供追蹤功能。一次只能啟用一個追蹤功能。如果已啟用任何追蹤功能，則此提醒將被隱藏。"
L["BuffPanel.Tracking.Scope.Gathering"] = "只限採集"
L["BuffPanel.Tracking.Scope.All"] = "全部追蹤"
L["BuffPanel.GroupCast"] = "自動群體版本 (使用材料)"
L["BuffPanel.GroupCast.Desc"] =
    "如果你的隊伍中有足夠多的成員沒有增益效果且在有效範圍內，並且你擁有所需的材料，則左鍵點擊會對你施放群體版本。否則，會施放單體版本。將滑鼠懸停在圖示上即可選擇另一種施法版本。"
L["BuffPanel.GroupCast.Blessing.Desc"] =
    "如果一個職業中有足夠多的成員缺少相同的祝福，點擊即可施放更強大的版本（需要王者印記）。只有當你將該祝福賦予整個職業時才會發生這種情況。"
L["BuffPanel.GroupCastMin"] = "群體版本在"
L["BuffPanel.GroupCastMin.Suffix"] = " 缺少"
L["BuffPanel.GroupCastMin.Desc"] =
    "隊伍中或某職業中，有多少成員沒有該增益效果，點擊即可施放群體版本的增益效果：對於強效祝福，則需滿足此條件。所有增益效果適用相同數值。"
L["DisabledReason.GroupCast"] = '請先啟用「自動群體版本」。'
L["BuffPanel.PaladinAura.Hint"] =
    "每個內容只能使用一個主要光環。如果其他聖騎士使用了該光環，則使用備用光環。空行可以接受任何光環。抗性光環在生效期間始終有效。"
L["BuffPanel.PaladinAura.Run"] = "運行"
L["BuffPanel.PaladinAura.InRun"] = "在運行"
L["BuffPanel.PaladinAura.MainTip"] = "你在 %s 內容中運行此光環。"
L["BuffPanel.PaladinAura.NotLearned"] = "尚未學會。你使用 %s 替代。"
L["BuffPanel.PaladinAura.None"] = "無光環"
L["BuffPanel.PaladinAura.None.Desc"] = "任何光環都算。"
L["DisabledReason.AuraDefaults"] = "所有內容行均使用其預設值。"
L["BuffPanel.ThornsRequest"] = "坦克可以請求荊棘"
L["BuffPanel.ThornsRequest.Desc"] =
    "如果你擔任坦克，且隊伍中有德魯伊（6級以上），則會顯示你缺少荊棘效果。點擊即可在聊天框中請求效果。需要在「聊天請求」頁面啟用「在聊天中請求缺少的增益效果」選項。"
L["BuffPanel.RighteousFuryShow"] = "顯示"
L["BuffPanel.RighteousFuryShow.Tank"] = "擔任坦克時"
L["BuffPanel.RighteousFuryShow.Always"] = "永遠"
L["BuffPanel.RighteousFuryShow.Desc"] =
    "擔任坦克時：僅限坦克職業或主坦克標記。永遠：單人或組隊均可。"
L["BuffPanel.MageArmor"] = "施放"
L["BuffPanel.MageArmor.Mage"] = "魔甲術"
L["BuffPanel.MageArmor.Ice"] = "霜/冰甲術"
L["BuffPanel.MageArmor.Desc"] =
    "圖示上顯示護甲，點擊即可施放。任何護甲都符合要求。如果您還未學習這件護甲，則使用其他護甲。"
L["BuffPanel.Sound"] = "聲音"
L["BuffPanel.Sound.None"] = "無"
L["BuffPanel.Detached"] = "自己的框架 (分離)"
L["BuffPanel.Detached.Desc"] =
    "將此增益從其所屬類別中取出，放到一個獨立的框架中。\n從佈局頁面或解鎖框架來定位它。"
L["BuffPanel.ShowSharedWithHealthstone"] = "治療石也使用這種設定。"
L["BuffPanel.Show.ReadyCheck"] = "僅在準備確認時"
L["BuffPanel.Show.ReadyCheck.Desc"] = "只有在準備確認檢查時，所有人才能看到它。"
L["BuffPanel.Show.ReadyCheckSolo"] = "準備確認，以及當單獨時"
L["BuffPanel.Show.ReadyCheckSolo.Desc"] = "在準備確認檢查期間，所有人都能看到它，術士在單獨時也能看到它。"
L["BuffPanel.Show.Caster"] = "術士總是可見"
L["BuffPanel.Show.Caster.Desc"] = "術士到處都能看到它，其他人則是在準備確認時看到它。"
L["BuffPanel.Show.Always"] = "永遠可見，所有人"
L["BuffPanel.Show.Always.Desc"] = "任何人到處都能看到它。"
L["DisabledReason.NotDetached"] = "這個增益並非分離的，而是位於其所屬類別框架內。"
L["Options.DisplayOrder.Note"] =
    "類別如何在組合框架內從上到下堆疊。分離的類別存在於它們自己的框架中並不參與。"

-- Detached Icons
L["DetachedIcons.Reattach"] = "返回到類別"
L["DetachedIcons.ResetPos"] = "重置位置"

-- ============================================================================
-- OPTIONS: APPEARANCE
-- ============================================================================
L["Options.Appearance"] = "外觀"
L["Options.Override"] = "覆蓋"
L["Options.Override.Inherited"] = "繼承自預設值"
L["Options.Override.Overriding"] = "覆蓋預設值"
L["Options.Override.Appearance.Desc"] =
    "覆寫此類別的全域外觀預設值。 \n關閉時，下方的控制項顯示從「預設值」頁面繼承的值。"
L["Options.Override.Interaction.Desc"] =
    "覆寫此類別的全域互動設定。\n關閉時，下面的控制項會顯示從「預設值」頁面繼承的值。"
L["Options.Override.Glow.Desc"] =
    "覆寫此類別的全域發光設定。 \n關閉時，下方的控制項顯示從「預設值」頁面繼承的值。"
L["Options.Override.Externals.Desc"] =
    "覆蓋這些圖示的全域外觀預設值。\n關閉時，大小、縮放、邊框和間距控制顯示從「預設值」頁面繼承的值。倒數計時的大小和方向總是分開的。"
L["Options.Override.OpenDefaults"] = "開啟"
L["Options.Customize"] = "自訂"
L["Options.ResetPosition"] = "重置位置"
L["Options.MasqueNote"] = "縮放和邊框設置由Masque管理。"

-- ============================================================================
-- OPTIONS: SETTINGS TAB
-- ============================================================================
L["Options.ShowLoginMessages"] = "顯示登入訊息"
L["Options.ShowMinimapButton"] = "顯示小地圖按鈕"
L["Options.Language"] = "語言"
L["Options.Language.Auto"] = "自動 (遊戲客戶端)"
L["Options.Language.Desc"] = "插件文字的語言。自動模式下使用遊戲客戶端的語言。"
    .. "未翻譯的文字以英文顯示。"
-- Each language names itself, so a reader finds their own language in any locale.
-- Do not translate this.
L["Language.enUS"] = "L"

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
L["Options.BuffTracking.SelfOnly"] = "只有我的增益，只在我身上"
L["Options.BuffTracking.SelfOnly.Desc"] =
    "只顯示你的職業可以提供的增益，並且僅檢查自身是否擁有。沒有團體數量統計，也沒有你對其他人施加的增益。"
L["Options.BuffTracking.Smart"] = "智能"
L["Options.BuffTracking.Smart.Desc"] =
    "對你的職業提供的增益追蹤整個隊伍，對其他職業的增益僅檢查自身。"
L["Options.BuffTracking.Mode"] = "增益追蹤模式"
L["Options.BuffTracking.Mode.Desc"] =
    "設置要顯示的團隊和職業增益，以及是追蹤整個隊伍還是僅追蹤自身。"
L["Options.BuffTracking.Override.Default"] = "預設 (使用上方模式)"
L["Options.BuffTracking.Override.OutsideInstances"] = "地城與團隊副本外"
L["Options.BuffTracking.Override.OutsideInstances.Desc"] =
    "在開放世界中使用的追蹤模式。在地城、團隊副本、事件與 PvP 中仍會使用上方所選的模式。"
L["Options.BuffTracking.Override.Combat"] = "戰鬥中"
L["Options.BuffTracking.Override.Combat.Desc"] =
    "戰鬥時使用的追蹤模式。例如，縮小為「僅我的增益」可在戰鬥外保留其他職業增益的提醒以便喊話，進入戰鬥後則隱藏。"
L["Options.BuffTracking.Override.Leveling"] = "升級過程中"
L["Options.BuffTracking.Override.Leveling.Desc"] =
    "未達等級上限時使用的追蹤模式。達到等級上限後，將改用上方所選的模式。"

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
L["Dialog.DeleteCustomBuff"] = '是否刪除自訂增益 "%s"？'
L["Dialog.DeleteProfile"] = '是否刪除設定檔 "%s"？你將無法復原它。'
L["Dialog.DeleteLoadout"] = '是否刪除天賦構建提醒 "%s"？'
L["Dialog.ResetProfile"] =
    "是否將當前設定檔重置為預設值？\n\n當前設定檔的所有自訂設置將被刪除並重載UI。"
L["Dialog.Reset"] = "重置"
L["Dialog.ReloadPrompt"] = "設置導入成功！\n是否重載UI以套用更改？"
L["Dialog.Reload"] = "重載"
L["Dialog.ReloadLanguage"] = "新語言將在使用者介面重新載入後生效。\n現在重載嗎？"
L["Dialog.NewProfilePrompt"] = "請輸入新設定檔的名稱："
L["Dialog.Create"] = "創建"
L["Dialog.DiscordPrompt"] = "加入BuffReminders的Discord頻道！\n複製下方網址以加入："
L["Dialog.KofiPrompt"] = "感謝您對BuffReminders的支持！\n複製下方網址 (Ctrl+C):"
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
-- OPTIONS: CUSTOM BUFF DIALOG
-- ============================================================================
L["CustomBuff.Edit"] = "編輯自訂增益"
L["CustomBuff.EditShort"] = "編輯"
L["CustomBuff.Add"] = "添加自訂增益"
L["CustomBuff.AddButton"] = "+ 添加自訂增益"
L["CustomBuff.Empty"] = "尚未有自訂增益。下面新增一個。"
L["CustomBuff.RestrictedNote"] =
    "當與首領以及傳奇+戰鬥時隱藏 - WoW阻止在那裡讀取光環。條形發光檢測在戰鬥中有效。"
L["CustomBuff.SpellIDs"] = "法術ID:"
L["CustomBuff.AddSpellID"] = "+ 添加法術ID"
L["CustomBuff.PickFromAuras"] = "從我的增益中挑選"

L["AuraPicker.Title"] = "光環與法術ID"
L["AuraPicker.PickTitle"] = "挑選個增益"
L["AuraPicker.Buffs"] = "增益"
L["AuraPicker.Debuffs"] = "減益"
L["AuraPicker.SpellID"] = "法術ID"
L["AuraPicker.Name"] = "名字"
L["AuraPicker.Refresh"] = "刷新"
L["AuraPicker.CopyHint"] = "按一下行或複製圖示，然後按 Ctrl+C。"
L["AuraPicker.Stacks"] = "堆疊"
L["AuraPicker.Source"] = "來源"
L["AuraPicker.Time"] = "時間"
L["AuraPicker.CopyRow"] = "複製行"
L["AuraPicker.CopyField"] = "複製"
L["AuraPicker.CopyAll"] = "複製全部"
L["AuraPicker.ShowList"] = "回到清單"
L["AuraPicker.CopyAllHint"] = "按Ctrl+C，然後按Esc返回。"
L["AuraPicker.SelectedHint"] = "按 Ctrl+C。再次按一下該行或按 Esc 取消選擇。"
L["AuraPicker.Copied"] = "已複製。"
L["AuraPicker.PickHint"] = "點選增益即可新增其法術ID。"
L["AuraPicker.Restricted"] =
    "魔獸世界會在戰鬥、首領戰、傳奇+和PvP中隱藏光環資料。請在這些場景之外再次開啟此清單。"
L["AuraPicker.NoUnit"] = "該單位不存在。用法：/br auras [單位]，例如 /br auras target。"
L["CustomBuff.Text"] = "疊加文字"
L["CustomBuff.LineBreakHint"] = "（使用 \\n 換行）"

-- Custom buff dialog tabs
L["CustomBuff.Tab.Buff"] = "增益"

-- Custom buff dialog section headers
L["CustomBuff.Section.Track"] = "法術"
L["CustomBuff.Section.ShowIcon"] = "顯示"
L["CustomBuff.Section.Who"] = "角色"
L["CustomBuff.Section.Where"] = "顯示的地方"
L["CustomBuff.Section.OnClick"] = "點擊動作"

-- Custom buff dialog header
L["CustomBuff.NamePlaceholder"] = "命名此提醒器"
L["CustomBuff.NoSpellYet"] = "尚未有法術 - 在下方新增一個ID"

-- Custom buff mode toggles
L["CustomBuff.WhenActive"] = "啟用時"
L["CustomBuff.WhenMissing"] = "缺失時"
L["CustomBuff.OnlyIfSpellKnown"] = "只限已知法術"
L["CustomBuff.ShowWhen"] = "顯示"
L["CustomBuff.Expiration.Disabled"] = "過期警告僅適用於您缺失時顯示的增益"

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
L["CustomBuff.Spec"] = "專精"
L["CustomBuff.Class"] = "職業"
L["CustomBuff.ItemCooldown"] = "冷卻"
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
L["CustomBuff.Content"] = "內容"

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
L["CustomBuff.Action.SpellID"] = "法術ID"
L["CustomBuff.Action.ItemID"] = "物品ID"
L["CustomBuff.Action.MacroText"] = "巨集"
L["CustomBuff.Action.SpellHint"] = "這可能與被追蹤的法術不同。追蹤此增益並施放技能。"

-- Save/Cancel/Delete
L["CustomBuff.Save"] = "保存"
L["CustomBuff.ValidateError"] = "加入一個有效的法術ID進行儲存。"

-- Share one custom buff
L["CustomBuff.Share.Export"] = "導出"
L["CustomBuff.Share.ExportTitle"] = "導出自訂增益"
L["CustomBuff.Share.ExportDesc"] = "複製下面的字串並將其交給其他玩家。"
L["CustomBuff.Share.Import"] = "導入"
L["CustomBuff.Share.ImportTitle"] = "導入自訂增益"
L["CustomBuff.Share.ImportDesc"] = "在下面貼上自訂增益字串。導入會新增一個新條目。"
L["CustomBuff.Share.Invalid"] = "這不是自訂增益的字串。"
L["CustomBuff.Share.ImportDisabled"] = "請先貼上一個自訂增益字串。"
L["CustomBuff.Share.MacroWarning"] = "點擊此增益即可運行上面的巨集。僅從您信任的來源匯入它。"
L["CustomBuff.Share.Spells"] = "法術:"
L["CustomBuff.Share.Runs"] = "點擊運行:"

-- Custom buff status
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
-- OPTIONS: KO-FI
-- ============================================================================
L["Options.SupportKofi"] = "在Ko-fi支持"
L["Options.SupportKofi.Title"] = "點擊取得連結"
L["Options.SupportKofi.Desc"] = "喜歡BuffReminders嗎？\n考慮在Ko-fi支持開發！"

-- ============================================================================
-- OPTIONS: CUSTOM ANCHOR FRAMES
-- ============================================================================
L["Options.CustomAnchorFrames.Desc"] =
    "在定位點下拉選單中添加全局框架名稱。（例：MyAddon_PlayerFrame）\n游戲中不存在的框架會自動跳過。"
L["Options.CustomAnchorFrames.PickNote"] =
    "您使用“挑選”按鈕選擇的每一框架都會落在此處，因此只需單擊一下即可。"
L["Options.Add"] = "添加"
L["Options.New"] = "新建"
L["Options.ResetToDefaults"] = "重置為預設值"

-- ============================================================================
-- OPTIONS: MISC
-- ============================================================================
L["Options.Off"] = "關閉"
L["Options.Auto"] = "自動"
L["Options.Always"] = "始終"
L["Options.ReadyCheck"] = "準備確認"
L["Options.Min"] = "分鐘"

-- ============================================================================
-- COMPONENTS (UI/Components.lua)
-- ============================================================================
-- Content filter tooltip
L["Content.ClickToFilter"] = "點擊以按 %s 難度過濾"
L["Content.ClickToToggleVisibility"] = "點擊切換 %s 的可視性"

-- Width and height link
L["DimensionLink.Link"] = "寬度和高度連動"
L["DimensionLink.Unlink"] = "取消寬度和高度的連動"
L["DimensionLink.Desc"] = "連動後，更改其中一個會同時更新兩個。"

-- Mover labels
L["Mover.AnchorGrowth"] = "定位點 \194\183 增長方向 %s"
L["Mover.AnchorGrowthFrame"] = "定位點 \194\183 增長方向 %s \194\183 > %s"
-- Anchor dropdown: "%s %s" takes the owner (Blizzard, Cell, ...) and the role.
-- "%s (%s)" takes the role and the frame's own name, for a discovered unit frame.
L["Mover.AnchorFrameEntry"] = "%s %s"
L["Mover.UnitFrameEntry"] = "%s (%s)"
L["Mover.Role.Player"] = "玩家框架"
L["Mover.Role.Target"] = "目標框架"
L["Mover.Role.Focus"] = "焦點框架"
L["Mover.Role.Pet"] = "寵物框架"
L["Mover.Role.Party"] = "隊伍框架"
L["Mover.Role.Raid"] = "團隊框架"
L["Mover.Role.Boss"] = "首領框架"
L["Mover.Frame.Minimap"] = "小地圖"
L["Mover.Frame.ObjectiveTracker"] = "目標追蹤器"
L["Mover.PickFrame"] = "挑選"
L["Mover.PickHint"] = "指向一個框架並點擊它。右鍵或按Esc鍵取消。"
L["Mover.PickNone"] = "鼠標下沒有框架"
L["Mover.Frame.EssentialCooldowns"] = "基本冷卻時間"
L["Mover.Frame.UtilityCooldowns"] = "功能冷卻時間"
L["Mover.Frame.TrackedBuffIcons"] = "追蹤增益圖示"
L["Mover.Frame.TrackedBuffBars"] = "追蹤增益條"
L["Mover.AnchorHidden"] = "(隱藏)"
L["Mover.AnchorNotFound"] = "(未找到)"

-- Pet labels
L["Pet.SpiritBeast"] = "靈獸"

-- Appearance grid labels
L["Appearance.Width"] = "寬度"
L["Appearance.Height"] = "高度"
L["Appearance.Zoom"] = "縮放"
L["Appearance.Border"] = "邊框"
L["Appearance.Spacing"] = "間距"
L["Appearance.Alpha"] = "透明度"
L["Appearance.CountSize"] = "計數大小"
L["Appearance.MissingSize"] = "缺失標籤大小"
L["Appearance.CaptionSize"] = "標題大小"
L["Appearance.CaptionSize.Desc"] = "增益！文字和裝備名稱的字體大小。"

-- Slider tooltip
L["Component.AdjustValue"] = "調整數值"
L["Component.AdjustValue.Desc"] = "點擊輸入或使用鼠標滾輪。"
L["Component.AdjustValue.ClickHint"] = "點擊數字即可輸入具體數值"

-- Disabled-control explanations
L["Component.DisabledReason.Title"] = "為什麼這個被禁用了？"
L["DisabledReason.OverrideSection"] = "首先開啟本部分頂部的「覆蓋」。"
L["DisabledReason.CombatOverride"] =
    '上面"戰鬥中"隱藏已啟用，因此戰鬥中不會顯示任何內容，且此覆蓋不會產生任何效果。\n取消勾選以使用戰鬥追踪覆蓋。'
L["DisabledReason.LevelingOverride"] =
    '上面"升級"隱藏已啟用，因此在升級時不會顯示任何內容，且此覆蓋不會產生任何效果。\nU取消勾選以使用升級追蹤覆蓋。'
L["DisabledReason.ExpiringInCombat"] = '"戰鬥中"隱藏已啟用，所以在戰鬥中一切都被隱藏了。'
L["DisabledReason.HealthstoneThreshold"] = '請先啟用"低時發出警告"。'
L["DisabledReason.ClickToCast"] = '請先啟用"點擊施法"。'
L["DisabledReason.ShowWithoutItems"] = '請先開啟「不在包包裡時顯示」功能。'
L["DisabledReason.PetLabelsOff"] = '首先確定「寵物標籤」的位置。'
L["DisabledReason.OverrideRow"] = '首先勾選此行的「覆蓋」選項。'
L["DisabledReason.RaidClickToCast"] =
    '需要啟用「點擊施法」才能施放團隊增益效果（預設頁面，或團隊標籤頁的互動覆蓋）。'

-- Direction labels
L["Direction.Left"] = "左側"
L["Direction.Center"] = "中心"
L["Direction.Right"] = "右側"
L["Direction.Up"] = "上方"
L["Direction.Down"] = "下方"
L["Direction.Label"] = "方向"

-- Content visibility
L["Content.ShowIn"] = "顯示在:"

-- Content toggle definitions
L["Content.OpenWorld"] = "野外"
L["Content.Housing"] = "房屋"
L["Content.Scenarios"] = "場景戰役(探究、挑戰等)"
L["Content.Dungeons"] = "地下城(包含M+)"
L["Content.AnyDungeon"] = "地下城"
L["Content.Raids"] = "團隊副本"
L["Content.PvP"] = "PvP(競技場與戰場)"

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
L["Content.Raids40"] = "40人團隊副本"
L["Content.Raids20"] = "20人團隊副本"

-- PvP types
L["Content.Arena"] = "競技場"
L["Content.Battlegrounds"] = "戰場"
