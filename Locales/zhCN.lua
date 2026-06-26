local _, BR = ... -- luacheck: ignore 211
if GetLocale() ~= "zhCN" then
    return
end

local L = BR.L -- luacheck: ignore 211

-- Credit by neolhfs

-- ============================================================================
-- CATEGORY LABELS
-- ============================================================================
L["Category.Raid"] = "团队增益"
L["Category.Presence"] = "特殊增益"
L["Category.Targeted"] = "指向性增益"
L["Category.Self"] = "自身增益"
L["Category.Pet"] = "宠物"
L["Category.Consumable"] = "消耗品"
L["Category.Custom"] = "自定义"

-- Long form (used in Options section headers)
L["Category.RaidBuffs"] = "团队增益"
L["Category.TargetedBuffs"] = "指向性增益"
L["Category.Consumables"] = "消耗品"
L["Category.PresenceBuffs"] = "特殊增益"
L["Category.SelfBuffs"] = "专属增益"
L["Category.PetReminders"] = "宠物提示"
L["Category.CustomBuffs"] = "自定义增益"

-- Category notes
L["Category.RaidNote"] = "（全小队或团队生效）"
L["Category.TargetedNote"] = "（施放于其他目标的增益）"
L["Category.ConsumableNote"] = "（药水、食物、符文、刀油）"
L["Category.PresenceNote"] = "（至少需要一人）"
L["Category.SelfNote"] = "（仅对自己施放的增益）"
L["Category.PetNote"] = "（宠物召唤提示）"
L["Category.CustomNote"] = "（按法术ID追踪增益或高亮）"

-- ============================================================================
-- BUFF OVERLAY TEXT
-- ============================================================================
-- These must be kept very short (2-4 chars per line) to fit on small icons.
L["Overlay.NoDrPoison"] = "没有\n毒药"
L["Overlay.NoAura"] = "没有\n光环"
L["Overlay.NoStone"] = "没拿糖"
L["Overlay.NoSoulstone"] = "没有\n灵魂石"
L["Overlay.NoFaith"] = "没有\n道标"
L["Overlay.NoLight"] = "没有\n道标"
L["Overlay.NoES"] = "没有\n大地盾"
L["Overlay.NoSource"] = "没有\n魔力之源"
L["Overlay.NoScales"] = "没有\n龙鳞"
L["Overlay.NoLink"] = "没有\n共生"
L["Overlay.NoAttune"] = "没有\n协调"
L["Overlay.NoFamiliar"] = "没有\n魔宠"
L["Overlay.DropWell"] = "拉糖"
L["Overlay.NoGrim"] = "没有\n魔典"
L["Overlay.BurningRush"] = "爆燃冲刺"
L["Overlay.NoRite"] = "没有\n祭礼"
L["Overlay.ApplyPoison"] = "上毒药"
L["Overlay.NoForm"] = "没有\n形态"
L["Overlay.NoEL"] = "没有\n大地生命"
L["Overlay.NoFT"] = "没有\n火舌"
L["Overlay.NoTG"] = "没有\n唤潮护卫"
L["Overlay.NoWF"] = "没有\n风怒"
L["Overlay.NoSelfES"] = "自身没有\n大地盾"
L["Overlay.NoShield"] = "没有\n护盾"
L["Overlay.NoPet"] = "没有\n宠物"
L["Overlay.PassivePet"] = "宠物\n被动"
L["Overlay.WrongPet"] = "宠物\n错误"
L["Overlay.NoRune"] = "没有\n符文"
L["Overlay.DKWrongRune"] = "符文\n错误"
L["Overlay.DKWrongRuneOH"] = "副手\n符文\n错误"
L["Overlay.NoFlask"] = "没有\n合剂"
L["Overlay.NoFood"] = "没有\n食物"
L["Overlay.NoWeaponBuff"] = "没有\n武器增益"
L["Overlay.NoTimeless"] = "缺少\n超脱时间"
L["Overlay.NoWeyrnstone"] = "缺少\n军营石"
L["Overlay.WrongForm"] = "形态错误"
L["Overlay.WrongStance"] = "姿态错误"
L["Overlay.Buff"] = "补BUFF"
L["Overlay.MinutesFormat"] = "%d分"
L["Overlay.LessThanOneMinute"] = "<1分"
L["Overlay.SecondsFormat"] = "%d秒"

-- ============================================================================
-- CONSUMABLE STAT LABELS (icon overlays, keep very short)
-- ============================================================================
L["Label.Crit"] = "爆击"
L["Label.Haste"] = "急速"
L["Label.Versatility"] = "全能"
L["Label.Mastery"] = "精通"
L["Label.Stamina"] = "耐力"
L["Label.Healing"] = "治疗"
L["Label.Random"] = "随机"
L["Label.Speed"] = "加速"
L["Label.PvP"] = "PvP"
L["Label.Feast"] = "大餐"
L["Label.HasteShort"] = "急"
L["Label.VersatilityShort"] = "全"
L["Label.MasteryShort"] = "精"
L["Label.CritVers"] = "爆/全"
L["Label.MasteryCrit"] = "精/爆"
L["Label.MasteryVers"] = "精/全"
L["Label.MasteryHaste"] = "精/急"
L["Label.HasteCrit"] = "急/爆"
L["Label.HasteVers"] = "急/全"
L["Label.StaminaStr"] = "耐/力"
L["Label.StaminaAgi"] = "耐/敏"
L["Label.StaminaInt"] = "耐/智"
L["Label.HighPrimary"] = "高主属性"
L["Label.HighSecondary"] = "高副属性"
L["Label.MidPrimary"] = "中主属性"
L["Label.LowPrimary"] = "低主属性"
L["Label.LowSecondary"] = "低副属性"
L["Label.RevivePet"] = "复活宠物"
L["Label.Felguard"] = "恶魔卫士"
L["Badge.Hearty"] = "丰盛"
L["Badge.Fleeting"] = "飞逝"

-- ============================================================================
-- BUFF NAMES
-- ============================================================================
L["Buff.ArcaneFamiliar"] = "奥术魔宠"
L["Buff.ArcaneIntellect"] = "奥术智慧"
L["Buff.AtrophicNumbingPoison"] = "萎缩/迟钝毒药"
L["Buff.Attunement"] = "同调"
L["Buff.AugmentRune"] = "强化符文"
L["Buff.BattleShout"] = "战斗怒吼"
L["Buff.BeaconOfFaith"] = "信仰道标"
L["Buff.BeaconOfLight"] = "圣光道标"
L["Buff.BlessingOfTheBronze"] = "青铜龙的祝福"
L["Buff.BlisteringScales"] = "炽火龙鳞"
L["Buff.BurningRush"] = "爆燃冲刺"
L["Buff.CreateSoulwell"] = "制造灵魂井"
L["Buff.DelveFood"] = "地下堡食物"
L["Buff.DevotionAura"] = "虔诚光环"
L["Buff.DruidForm"] = "德鲁伊形态"
L["Buff.EarthShield"] = "大地之盾"
L["Buff.EarthShieldSelf"] = "大地之盾（自己）"
L["Buff.EarthlivingWeapon"] = "大地生命武器"
L["Buff.FlametongueWeapon"] = "火舌武器"
L["Buff.Flask"] = "合剂"
L["Buff.Food"] = "食物"
L["Buff.GrimoireOfSacrifice"] = "牺牲魔典"
L["Buff.Healthstone"] = "治疗石"
L["Buff.HunterPet"] = "猎人宠物"
L["Buff.MarkOfTheWild"] = "野性印记"
L["Buff.PetPassive"] = "宠物被动"
L["Buff.PowerWordFortitude"] = "真言术：韧"
L["Buff.RiteOfAdjuration"] = "恳求祭礼"
L["Buff.RiteOfSanctification"] = "圣言祭礼"
L["Buff.RoguePoisons"] = "潜行者毒药"
L["Buff.RuneforgeMH"] = "符文熔铸（主手）"
L["Buff.RuneforgeOH"] = "符文熔铸（副手）"
L["Buff.Shadowform"] = "暗影形态"
L["Buff.ShieldNoTalent"] = "护盾（无天赋）"
L["Buff.Skyfury"] = "天怒"
L["Buff.Soulstone"] = "灵魂石"
L["Buff.SourceOfMagic"] = "魔力之源"
L["Buff.SymbioticRelationship"] = "共生关系"
L["Buff.TidecallersGuard"] = "唤潮者的护卫"
L["Buff.Timelessness"] = "超脱时间"
L["Buff.UnholyGhoul"] = "食尸鬼"
L["Buff.WarlockDemon"] = "术士恶魔"
L["Buff.WarriorStance"] = "战士姿态"
L["Buff.WaterElemental"] = "水元素"
L["Buff.WaterLightningShield"] = "水盾/闪电盾"
L["Buff.Weapon"] = "武器"
L["Buff.WeaponOH"] = "副手武器"
L["Buff.Weyrnstone"] = "军营石"
L["Buff.WindfuryWeapon"] = "风怒武器"
L["Buff.WrongDemon"] = "恶魔不对"

-- ============================================================================
-- BUFF GROUP DISPLAY NAMES
-- ============================================================================
L["Group.Beacons"] = "圣光道标"
L["Group.DKRunes"] = "DK符文"
L["Group.ShamanImbues"] = "萨满武器注能"
L["Group.PaladinRites"] = "圣骑士祭礼"
L["Group.Pets"] = "宠物"
L["Group.ShamanShields"] = "萨满护盾"
L["Group.Flask"] = "合剂"
L["Group.Food"] = "食物"
L["Group.DelveFood"] = "地下堡食物"
L["Group.Healthstone"] = "治疗石"
L["Group.AugmentRune"] = "强化符文"
L["Group.WeaponBuff"] = "武器增益"

-- ============================================================================
-- BUFF INFO TOOLTIPS
-- ============================================================================
L["Tooltip.MayShowExtraIcon"] = "可能显示额外图标"
L["Tooltip.MayShowExtraIcon.Desc"] =
    "在施放此法术之前，该提示可能会与水盾/闪电盾提示同时出现。因为系统无法确定你是想对自己施放大地盾，还是想给队友施放大地盾的同时给自己施放水盾/闪电盾。"
L["Tooltip.InstanceEntryReminder"] = "副本进本提示"
L["Tooltip.InstanceEntryReminder.Desc"] =
    "进入地下城时会短暂显示放置灵魂井的提示。施放法术或30秒后将消失。"
L["BuffTooltip.ProvidedBy"] = "由%s提供"

-- ============================================================================
-- GLOW TYPE NAMES
-- ============================================================================
L["Glow.Pixel"] = "像素"
L["Glow.AutoCast"] = "自动施放"
L["Glow.Border"] = "边框"
L["Glow.Proc"] = "触发"

-- ============================================================================
-- CORE
-- ============================================================================
L["Core.Any"] = "任意"

-- ============================================================================
-- PROFILES
-- ============================================================================
L["Profile.SwitchQueued"] = "脱离战斗后将切换配置文件。"
L["Profile.Switched"] = "已切换至配置文件 '%s'。"

-- ============================================================================
-- MOVERS
-- ============================================================================
L["Mover.SetPosition"] = "设置位置"
L["Mover.AnchorFrame"] = "锚点框体"
L["Mover.AnchorPoint"] = "锚点位置"
L["Mover.NoneScreenCenter"] = "无（屏幕中心）"
L["Mover.Apply"] = "应用"
L["Mover.BuffAnchor"] = "增益锚点"
L["Mover.DragTooltip"] = "拖动以调整位置\n点击以打开/关闭坐标编辑器"
L["Mover.MainEmpty"] = "主界面（空）"
L["Mover.MainAll"] = "主界面（全部）"
L["Mover.Detached"] = "已分离"

-- ============================================================================
-- DISPLAY
-- ============================================================================
L["Display.FramesLocked"] = "框体已锁定。"
L["Display.FramesUnlocked"] = "框体已解锁。"
L["Display.MinimapHidden"] = "小地图图标已隐藏。"
L["Display.MinimapShown"] = "小地图图标已显示。"
L["Display.Description"] = "一目了然地查看所有缺失的增益。"
L["Display.OpenOptions"] = "打开选项"
L["Display.SlashCommands"] = "斜杠命令: /br, /br lock, /br unlock, /br test, /br minimap"
L["Display.MinimapLeftClick"] = "|cFFCFCFCF左键点击|r: 选项"
L["Display.MinimapRightClick"] = "|cFFCFCFCF右键点击|r: 测试模式"
L["Display.DismissConsumables"] = "在下一次读条前隐藏消耗品提示"
L["Display.DismissConsumablesChat"] = "直到下次蓝条加载前，消耗品提醒被暂时隐藏了。"
L["Display.DebugDisabled"] = "调试模式已禁用。"
L["Display.DebugEnabled"] = "调试模式已启用。再次输入 |cFFFFD100/br debug|r 将其关闭。"
L["Display.LoginFirstInstall"] =
    "感谢安装！输入 |cFFFFD100/br unlock|r 来移动增益显示，或者使用 |cFFFFD100/br|r 选项面板底部的按钮。"

-- ============================================================================
-- OPTIONS: NAVIGATION LABELS
-- ============================================================================
L["Tab.DisplayBehavior"] = "显示与行为"

-- Sidebar groups
L["Sidebar.Buffs"] = "增益"
L["Sidebar.DisplayBehavior"] = "显示与行为"
L["Sidebar.General"] = "常规"
L["Sidebar.Profiles"] = "配置文件"

-- Page titles
L["Page.AllBuffs"] = "所有增益"
L["Page.AnchorFrames"] = "锚点框体"
L["Page.ChatRequests"] = "聊天频道请求"
L["Page.Defaults"] = "默认值"
L["Page.DetachedIcons"] = "已分离图标"
L["Page.General"] = "常规"
L["Page.Profiles"] = "配置文件"
L["Page.Sounds"] = "声音提醒"
L["Page.Sounds.Desc"] =
    "当追踪的增益缺失时播放声音。警报适用于所有增益类别——请为每个增益单独指定。"
L["Page.Visibility"] = "可见性"

-- Section headers
L["Section.Tracking"] = "追踪"

-- ============================================================================
-- OPTIONS: GLOBAL DEFAULTS
-- ============================================================================
L["Options.GlobalDefaults"] = "全局默认值"
L["Options.GlobalDefaults.Note"] = "（应用于所有类别，除非被自定义外观覆盖）"
L["Options.Default"] = "默认"
L["Options.Font"] = "字体"

-- ============================================================================
-- OPTIONS: GLOW SETTINGS
-- ============================================================================
L["Options.GlowReminderIcons"] = "提示图标发光"
L["Options.GlowReminderIcons.Title"] = "提示图标发光"
L["Options.GlowReminderIcons.Desc"] =
    "为所有显示的提示图标添加发光效果，包括缺失和即将过期的增益。"
L["Options.GlowKind.Expiring"] = "即将过期"
L["Options.GlowKind.Missing"] = "缺失"
L["Options.PreKeyThreshold"] = "插钥匙前阈值"
L["Options.PreKeyThreshold.Desc"] =
    "在史诗地下城（0层）中，插入钥石前使用更长的过期提醒阈值。\n有助于确保插钥匙前你的增益时间充足。"
L["Options.GlowSettings.Expiring"] = "发光设置 - 即将过期"
L["Options.GlowSettings.Missing"] = "发光设置 - 缺失"
L["Options.Glow.Enabled"] = "启用"
L["Options.Threshold"] = "阈值"
L["Options.GlowMissingPets"] = "缺失宠物发光"
L["Options.CustomGlowStyle"] = "自定义发光样式"
L["Options.Expiration"] = "过期"
L["Options.Glow"] = "发光"
L["Options.UseCustomColor"] = "使用自定义颜色"
L["Options.UseCustomColor.Desc"] =
    "启用后会降低触发发光的饱和度并更改颜色。\n可能看起来不如默认触发发光清晰。"
L["Options.ExpirationReminder"] = "过期提示"

-- Glow params
L["Options.Glow.Type"] = "类型:"
L["Options.Glow.Size"] = "大小:"
L["Options.Glow.Duration"] = "持续时间"
L["Options.Glow.Frequency"] = "频率"
L["Options.Glow.Length"] = "长度"
L["Options.Glow.Lines"] = "线条"
L["Options.Glow.Particles"] = "粒子"
L["Options.Glow.Scale"] = "缩放比例"
L["Options.Glow.Speed"] = "速度"
L["Options.Glow.StartAnimation"] = "起始动画"
L["Options.Glow.XOffset"] = "X轴偏移"
L["Options.Glow.YOffset"] = "Y轴偏移"

-- ============================================================================
-- OPTIONS: CONTENT VISIBILITY
-- ============================================================================
L["Options.HidePvPMatchStart"] = "PvP比赛开始时隐藏"
L["Options.HidePvPMatchStart.Title"] = "PvP比赛开始时隐藏"
L["Options.HidePvPMatchStart.Desc"] = "PvP比赛开始后（准备阶段结束）隐藏此类别。"
L["Options.ReadyCheckOnly"] = "仅在就位确认时显示"
L["Options.ReadyCheckOnly.Desc"] = "仅在就位确认后的15秒内显示此类别中的增益。"
L["Options.Visibility"] = "显示条件"

-- ============================================================================
-- OPTIONS: HEALTHSTONE
-- ============================================================================
L["Options.Healthstone.ReadyCheckOnly"] = "仅就位确认时"
L["Options.Healthstone.ReadyCheckWarlock"] = "就位确认 + 术士始终显示"
L["Options.Healthstone.AlwaysShow"] = "始终显示"
L["Options.Healthstone.Visibility"] = "治疗石显示"
L["Options.Healthstone.Visibility.Desc"] =
    "设置何时显示治疗石提示。\n\n|cffffcc00仅就位确认时:|r 仅在就位确认（15秒内）时显示。\n|cffffcc00就位确认 + 术士始终显示:|r 术士始终显示，其他职业仅在就位确认时显示。\n|cffffcc00始终显示:|r 在符合设置的内容类型中始终显示。"
L["Options.Healthstone.WarlockAlwaysDesc"] = "术士始终显示提示，其他职业仅在就位确认时显示"
L["Options.Healthstone.ReadyCheckDesc"] = "在就位确认后15秒内显示"
L["Options.Healthstone.AlwaysDesc"] = "在符合当前内容类型时始终显示"
L["Options.Healthstone.LowStock"] = "治疗石不足警告"
L["Options.Healthstone.LowStock.Desc"] =
    "当有治疗石但数量较少时显示警告。不管此设置如何，没有治疗石（0个）时都会被追踪。"
L["Options.Healthstone.Threshold"] = "警告阈值"
L["Options.Healthstone.Threshold.Desc"] =
    "当治疗石等于或低于此数量时显示不足警告。\n\n|cffffcc001:|r 仅在刚好有1个时警告。\n|cffffcc002:|r 有1个或2个时警告。"

-- ============================================================================
-- OPTIONS: SOULSTONE
-- ============================================================================
L["Options.Soulstone.Visibility"] = "灵魂石显示"
L["Options.Soulstone.Visibility.Desc"] =
    "设置何时显示灵魂石提示。\n\n|cffffcc00仅就位确认时:|r 仅在就位确认时显示（默认）。\n|cffffcc00就位确认 + 术士始终显示:|r 术士始终显示，其他职业仅在就位确认时显示。\n|cffffcc00始终显示:|r 只要特殊增益类别可见就显示。"
L["Options.Soulstone.ReadyCheckOnly"] = "仅就位确认时"
L["Options.Soulstone.ReadyCheckWarlock"] = "就位确认 + 术士始终显示"
L["Options.Soulstone.AlwaysShow"] = "始终显示"
L["Options.Soulstone.ReadyCheckDesc"] = "在就位确认后15秒内显示"
L["Options.Soulstone.WarlockAlwaysDesc"] = "术士始终显示提示，其他职业仅在就位确认时显示"
L["Options.Soulstone.AlwaysDesc"] = "只要特殊增益类别可见就显示"
L["Options.Soulstone.HideCooldown"] = "冷却时隐藏（术士）"
L["Options.Soulstone.HideCooldown.Desc"] =
    "启用后，当灵魂石法术处于冷却中时，不会向术士显示提示。仅适用于术士。"

-- ============================================================================
-- OPTIONS: FREE CONSUMABLES
-- ============================================================================
L["Options.FreeConsumables"] = "免费消耗品"
L["Options.FreeConsumables.Note"] = "（治疗石、永久强化符文）"
L["Options.FreeConsumables.Override"] = "覆盖内容过滤"
L["Options.FreeConsumables.Override.Desc"] =
    "勾选后，免费消耗品将使用下方独立的内容类型设置。\n\n取消勾选后，它们将遵循与其他消耗品相同的内容过滤规则。"
L["Options.HideLegacyConsumables"] = "隐藏旧版本消耗品"
L["Options.HideLegacyConsumables.Title"] = "隐藏旧版本消耗品"
L["Options.HideLegacyConsumables.Desc"] =
    "启用后，来自旧资料片的食物、合剂和符文将从动作按钮中过滤掉。如果你还在为了时光漫游、单刷旧团本或给低装等小号使用旧版消耗品，请禁用此项。"

-- ============================================================================
-- OPTIONS: ICONS
-- ============================================================================
L["Options.Icons"] = "图标"
L["Options.ShowText"] = "在图标上显示文本"
L["Options.ShowText.Desc"] = "在此类别的增益图标上显示层数或缺失文本覆盖。"
L["Options.ShowMissingCountOnly"] = "仅显示缺失数量"
L["Options.ShowMissingCountOnly.Desc"] =
    "仅显示缺失增益的数量（例如：”1“），而不是完整的分数形式（例如：”19/20“）。"
L["Options.ShowBuffReminderText"] = "显示“补BUFF”提示文本"
L["Options.Size"] = "大小"

-- ============================================================================
-- OPTIONS: CLICK TO CAST
-- ============================================================================
L["Options.ClickToCast"] = "点击施法"
L["Options.ClickToCast.DescFull"] =
    "你可以点击增益图标来施放对应的法术（仅限非战斗状态）。只对你的角色可施放的法术有效。"
L["Options.HoverHighlight"] = "悬停高亮"
L["Options.HoverHighlight.Desc"] = "将鼠标悬停在可点击的增益图标上时，显示微弱的高亮效果。"
L["Options.RequestBuffInChat"] = "在聊天频道中请求缺失的增益"
L["Options.RequestBuffInChat.Desc"] =
    "点击你的职业无法提供的缺失增益，可在聊天频道中发送请求。插件会自动检测当前合适的频道（副本/团队/小队/说）。每个增益有30秒的喊话冷却时间。"
L["Options.ChatRequest.FixAttempt"] = "|cffffd200实验版|r 尝试修复喊话请求无法发送的问题"
L["Options.ChatRequest.FixAttempt.Desc"] =
    "仅当你的喊话请求无法发送时才启用此项。这同时会禁用防止误触刷屏的5秒点击冷却限制。"
L["Options.ChatRequest.ResetAll"] = "全部重置"
L["ChatRequests.PerBuffMessages"] = "独立增益喊话信息"
-- Chat request messages
L["ChatRequest.atrophicNumbingPoison"] = "补下毒药"
L["ChatRequest.attackPower"] = "来个攻强"
L["ChatRequest.bronze"] = "来个龙BUFF"
L["ChatRequest.devotionAura"] = "来个虔诚光环"
L["ChatRequest.intellect"] = "来个智力"
L["ChatRequest.skyfury"] = "来个天怒"
L["ChatRequest.soulstone"] = "绑下灵魂石"
L["ChatRequest.stamina"] = "来个耐力"
L["ChatRequest.versatility"] = "来个爪子"

-- ============================================================================
-- OPTIONS: PET
-- ============================================================================
L["Options.PetSpecIcon"] = "悬停时显示猎人宠物专精图标"
L["Options.PetSpecIcon.Title"] = "悬停时宠物专精图标"
L["Options.PetSpecIcon.Desc"] =
    "鼠标悬停时，宠物图标将变为对应的专精技能（狡诈、狂野、坚韧）。"
L["Options.ShowItemTooltips"] = "显示物品提示信息"
L["Options.ShowItemTooltips.Desc"] = "将鼠标悬停在消耗品图标上时显示物品详细信息。"
L["Options.ShowBuffTooltips"] = "显示增益鼠标提示信息"
L["Options.ShowBuffTooltips.Desc"] =
    "当鼠标悬停在团队增益或特殊增益图标上时，显示法术提示信息以及提供该增益的职业。"
L["Options.Behavior"] = "行为"
L["Options.PetPassiveCombat"] = "仅在战斗中提示被动宠物"
L["Options.PetPassiveCombat.Desc"] = "仅在战斗中显示被动宠物提示。禁用时则始终显示。"
L["Options.FelDomination"] = "召唤前使用邪能统御"
L["Options.FelDomination.Title"] = "邪能统御"
L["Options.FelDomination.Desc"] =
    "通过点击施法召唤恶魔前自动施放邪能统御。如果邪能统御在冷却中，则正常召唤。需要点出邪能统御天赋。"

-- ============================================================================
-- OPTIONS: PET DISPLAY
-- ============================================================================
L["Options.PetDisplay"] = "宠物显示"
L["Options.PetDisplay.Generic"] = "通用图标"
L["Options.PetDisplay.GenericDesc"] = "单一的默认“无宠物”图标"
L["Options.PetDisplay.Summon"] = "召唤法术"
L["Options.PetDisplay.SummonDesc"] = "将每个召唤宠物法术显示为单独的图标"
L["Options.PetDisplay.Mode"] = "宠物显示模式"
L["Options.PetDisplay.Mode.Desc"] = "设置缺失宠物提示的显示方式。"
L["Options.PetLabels"] = "宠物标签"
L["Options.PetLabels.Desc"] = "在每个图标下方显示宠物名称和专精。"
L["Options.PetLabels.SizePct"] = "尺寸占比 %"

-- ============================================================================
-- OPTIONS: CONSUMABLE DISPLAY
-- ============================================================================
L["Options.ConsumableTextScale"] = "文本缩放"
L["Options.ConsumableTextScale.Title"] = "消耗品文本大小"
L["Options.ConsumableTextScale.Desc"] = "物品数量和品质标签相对于图标大小的字体缩放比例。"
L["Options.ItemDisplay"] = "物品显示"
L["Options.ItemDisplay.IconOnly"] = "仅图标"
L["Options.ItemDisplay.IconOnlyDesc"] = "显示数量最多的物品"
L["Options.ItemDisplay.SubIcons"] = "子图标"
L["Options.ItemDisplay.SubIconsDesc"] = "在每个图标下方显示较小的物品变体图标"
L["Options.ItemDisplay.Expanded"] = "展开"
L["Options.ItemDisplay.ExpandedDesc"] = "将每个物品变体显示为全尺寸图标"
L["Options.ItemDisplay.Mode"] = "消耗品物品显示"
L["Options.ItemDisplay.Mode.Desc"] =
    "设置具有多个变体的消耗品物品（例如各种合剂类型）的显示方式。"
L["Options.SubIconSide"] = "方向"
L["Options.SubIconSide.Bottom"] = "底部"
L["Options.SubIconSide.Top"] = "顶部"
L["Options.SubIconSide.Left"] = "左侧"
L["Options.SubIconSide.Right"] = "右侧"
L["Options.ShowWithoutItems"] = "背包中没有也显示"
L["Options.ShowWithoutItems.Title"] = "没有物品也显示"
L["Options.ShowWithoutItems.Desc"] =
    "启用后，即使背包中没有该物品，也会显示消耗品提示。禁用后，仅显示实际拥有的消耗品。"
L["Options.ShowWithoutItemsReadyCheckOnly"] = "仅在就位确认时"
L["Options.ShowWithoutItemsReadyCheckOnly.Title"] = "仅在就位确认时显示缺失物品"
L["Options.ShowWithoutItemsReadyCheckOnly.Desc"] =
    "启用后，背包中未拥有的消耗品仅在就位确认期间显示。这非常适合作为开打前去补充物品的快速提醒。"
L["Options.DelveFoodOnly"] = "在地下堡中仅显示地下堡食物"
L["Options.DelveFoodOnly.Desc"] = "在地下堡中隐藏除地下堡食物外的所有消耗品提示。"
L["Options.HideConsumableLabels"] = "隐藏属性标签"
L["Options.HideConsumableLabels.Title"] = "隐藏消耗品属性标签"
L["Options.HideConsumableLabels.Desc"] =
    "隐藏消耗品图标左上角显示的小型属性标签（例如“高主”、“低副”）。"

-- ============================================================================
-- OPTIONS: DK RUNEFORGE PREFERENCES
-- ============================================================================
L["Options.RuneforgePreferences"] = "DK符文偏好"
L["Options.RuneforgeNote"] =
    "为每个专精选择你期望的DK符文。如果应用了错误的符文或缺少符文，将显示提示。"
L["Options.RuneMainHand"] = "主手"
L["Options.RuneOffHand"] = "副手"
L["Options.RuneTwoHanded"] = "双手"
L["Options.RuneDualWield"] = "双持"

-- ============================================================================
-- OPTIONS: ROGUE POISON PREFERENCES
-- ============================================================================
L["Options.RoguePoisonPreferences"] = "潜行者毒药偏好"
L["Options.RoguePoisonNote"] =
    "选择要涂抹的毒药及其优先级顺序（最上方优先级最高）。被禁用的毒药永远不会被施放，也不会触发提示。"
L["Options.PoisonLethal"] = "致命"
L["Options.PoisonNonLethal"] = "非致命"
L["Options.PoisonMoveUp"] = "提高优先级"
L["Options.PoisonMoveDown"] = "降低优先级"
L["Options.PoisonReset"] = "重置为默认"

-- ============================================================================
-- OPTIONS: BUFF SETTINGS GEAR ICONS
-- ============================================================================
L["Options.HealthstoneSettings"] = "治疗石设置"
L["Options.HealthstoneSettings.Note"] = "设置显示条件和不足警告阈值。"
L["Options.SoulstoneSettings"] = "灵魂石设置"
L["Options.SoulstoneSettings.Note"] = "设置何时显示灵魂石提示。"
L["Options.BronzeSettings"] = "青铜龙的祝福设置"
L["Options.BronzeSettings.Note"] = "配置青铜龙的祝福提示。"
L["Options.BronzeHideInCombat"] = "战斗中隐藏"
L["Options.BronzeHideInCombat.Desc"] =
    "在战斗中隐藏青铜龙的祝福提示。这个增益没那么关键，你通常不会想在战斗中途去补它。"
L["Options.PetPassiveSettings"] = "被动宠物设置"
L["Options.PetPassiveSettings.Note"] = "设置被动模式宠物的提示行为。"
L["Options.PetSummonSettings"] = "宠物召唤设置"
L["Options.PetSummonSettings.Note"] = "配置宠物召唤行为。"
L["Options.DelveFoodSettings"] = "地下堡食物设置"
L["Options.DelveFoodSettings.Note"] = "配置地下堡食物提示行为。"
L["Options.DelveFoodTimer"] = "30秒后自动隐藏"
L["Options.DelveFoodTimer.Desc"] =
    "启用后，地下堡食物提示会在进入地下堡后显示30秒，然后自动隐藏。禁用后，只要你在地下堡中且缺少该增益，提示就会一直显示。"

-- ============================================================================
-- OPTIONS: DETACHED ICONS
-- ============================================================================
L["DetachedIcons.PageNote"] =
    "将单个增益从其所属类别中提取出来，放入可独立定位的框体中。分离的图标保留其自身的锚点，并在框体解锁时可独立移动。"
L["DetachedIcons.CurrentlyDetachedCount"] = "当前已分离 (%d)"
L["DetachedIcons.NoneDetached"] = "没有已分离的图标。请在下方找到增益并点击“分离”。"
L["DetachedIcons.Available"] = "可用"
L["DetachedIcons.Search"] = "搜索："
L["DetachedIcons.NoMatches"] = "没有匹配项。"
L["DetachedIcons.Detach"] = "分离"
L["DetachedIcons.Reattach"] = "归位"
L["DetachedIcons.ReattachAll"] = "全部归位"
L["DetachedIcons.ResetPos"] = "重置"

-- ============================================================================
-- OPTIONS: LAYOUT
-- ============================================================================
L["Options.Layout"] = "布局"
L["Options.SplitFrame"] = "分离为独立框体"
L["Options.SplitFrame.Desc"] = "将此类别中的增益显示在可独立移动的单独框体中。"
L["Options.DisplayOrder"] = "显示顺序"
L["Options.DisplayOrder.Note"] =
    "整合框体中各类别的自上而下排列顺序。已分离的类别位于独立的框体中，不参与此排序。"
L["Options.DisplayOrder.SplitBadge"] = "分离"
L["Options.DisplayOrder.SplitGroup"] = "已分离（独立框体）"

-- ============================================================================
-- OPTIONS: APPEARANCE
-- ============================================================================
L["Options.CustomAppearance"] = "使用自定义外观"
L["Options.CustomAppearance.Desc"] =
    "禁用时，此类别将继承全局默认值的外观设置。必须分离为独立框体才能自定义生长方向。"
L["Options.Customize"] = "自定义"
L["Options.ResetPosition"] = "重置位置"
L["Options.MasqueNote"] = "缩放和边框设置由Masque管理。"

-- ============================================================================
-- OPTIONS: TEXT OUTLINE
-- ============================================================================
L["Options.TextOutline"] = "描边"
L["Options.TextOutline.None"] = "无"
L["Options.TextOutline.Outline"] = "描边"
L["Options.TextOutline.Thick"] = "粗描边"
L["Options.TextOutline.Monochrome"] = "单色"
L["Options.TextOutline.OutlineMono"] = "描边 + 单色"
L["Options.TextOutline.ThickMono"] = "粗描边 + 单色"

-- ============================================================================
-- OPTIONS: TEXT POSITIONS
-- ============================================================================
L["Options.TextPositions"] = "文本"
L["Options.TextPositions.Zone"] = "位置"
L["Options.TextPositions.StackCount"] = "层数"
L["Options.TextPositions.StatLabel"] = "属性标签"
L["Options.TextPositions.Badge"] = "标签 (丰盛/飞逝)"
L["Options.TextPositions.Align.Left"] = "靠左"
L["Options.TextPositions.Align.Center"] = "居中"
L["Options.TextPositions.Align.Right"] = "靠右"
L["Options.TextPositions.Vertical.Above"] = "顶部上方"
L["Options.TextPositions.Vertical.InsideTop"] = "内部顶部"
L["Options.TextPositions.Vertical.InsideMiddle"] = "内部居中"
L["Options.TextPositions.Vertical.InsideBottom"] = "内部底部"
L["Options.TextPositions.Vertical.Below"] = "底部下方"
L["Options.TextPositions.OffsetX.Short"] = "X轴"
L["Options.TextPositions.OffsetY.Short"] = "Y轴"

-- ============================================================================
-- OPTIONS: SETTINGS TAB
-- ============================================================================
L["Options.ShowLoginMessages"] = "显示登录信息"
L["Options.ShowMinimapButton"] = "显示小地图按钮"

-- Hide when section
L["Options.HideWhen"] = "隐藏条件:"
L["Options.HideWhen.Resting"] = "休息时"
L["Options.HideWhen.Resting.Title"] = "休息时隐藏"
L["Options.HideWhen.Resting.Desc"] = "在旅店或主城时隐藏增益提示。"
L["Options.HideWhen.Combat"] = "战斗中"
L["Options.HideWhen.Expiring"] = "战斗中不提示即将过期"
L["Options.HideWhen.Expiring.Title"] = "战斗中不提示即将结束的增益"
L["Options.HideWhen.Expiring.Desc"] =
    "在战斗中不会显示即将结束的增益，仅显示完全缺失的增益。"
L["Options.HideWhen.Vehicle"] = "载具中"
L["Options.HideWhen.Vehicle.Title"] = "载具中隐藏"
L["Options.HideWhen.Vehicle.Desc"] =
    "使用任务载具时隐藏所有增益提示。即使禁用，团队和特殊增益仍会显示。"
L["Options.HideWhen.Mounted"] = "乘骑坐骑时"
L["Options.HideWhen.Mounted.Title"] = "乘骑坐骑时隐藏"
L["Options.HideWhen.Mounted.Desc"] =
    "乘骑坐骑时隐藏所有增益提示。优先级高于类别特定的坐骑隐藏设置。"
L["Options.HideWhen.Legacy"] = "旧资料片副本"
L["Options.HideWhen.Legacy.Title"] = "在旧资料片副本中隐藏"
L["Options.HideWhen.Legacy.Desc"] = "在激活传承战利品模式的旧资料片副本中隐藏所有增益提示。"
L["Options.HideWhen.Leveling"] = "练级时"
L["Options.HideWhen.Leveling.Title"] = "练级时隐藏"
L["Options.HideWhen.Leveling.Desc"] = "未满级时隐藏所有增益提示"
L["Options.HideWhen.Alone"] = "单人时"
L["Options.HideWhen.Alone.Title"] = "单人时隐藏"
L["Options.HideWhen.Alone.Desc"] = "不在小队或团队中时，隐藏所有增益提示"

-- ============================================================================
-- OPTIONS: BUFF TRACKING MODE
-- ============================================================================
L["Options.BuffTracking"] = "增益追踪"
L["Options.BuffTracking.All"] = "所有增益，所有玩家"
L["Options.BuffTracking.All.Desc"] =
    "显示所有职业的团队和特殊增益，并追踪整个队伍的应用情况。"
L["Options.BuffTracking.MyBuffs"] = "仅我的增益，所有玩家"
L["Options.BuffTracking.MyBuffs.Desc"] =
    "仅显示你的职业能提供的增益，但会追踪整个队伍的应用情况。"
L["Options.BuffTracking.OnlyMine"] = "仅我需要的增益"
L["Options.BuffTracking.OnlyMine.Desc"] =
    "显示所有类型的增益，但仅检查自身是否应用。不显示队伍数量。"
L["Options.BuffTracking.Smart"] = "智能"
L["Options.BuffTracking.Smart.Desc"] =
    "对你的职业提供的增益追踪整个队伍，对其他职业的增益仅检查自身。"
L["Options.BuffTracking.SelfOnly"] = "仅我的增益，仅限自身"
L["Options.BuffTracking.SelfOnly.Desc"] =
    "仅显示你的职业能提供的增益，且仅检查你自身是否拥有。不计算团队数量，不包含你对他人施放的增益。"
L["Options.BuffTracking.Mode"] = "增益追踪模式"
L["Options.BuffTracking.Mode.Desc"] =
    "设置要显示的团队和特殊增益，以及是追踪整个队伍还是仅追踪自身。"

-- ============================================================================
-- OPTIONS: PROFILES TAB
-- ============================================================================
L["Options.ActiveProfile"] = "当前配置文件"
L["Options.ActiveProfile.Desc"] = "在已保存的设置之间切换。每个角色可以使用不同的配置文件。"
L["Options.SelectProfile"] = "选择配置文件"
L["Options.Profile"] = "配置文件"
L["Options.CopyFrom"] = "复制自"
L["Options.Delete"] = "删除"
L["Options.PerSpecProfiles"] = "按专精配置文件"
L["Options.PerSpecProfiles.Desc"] = "切换专精时自动切换配置文件。"
L["Options.PerSpecProfiles.Enable"] = "启用按专精配置文件"

-- ============================================================================
-- OPTIONS: IMPORT/EXPORT
-- ============================================================================
L["Options.ExportSettings"] = "导出设置"
L["Options.ExportSettings.Desc"] = "复制下方字符串以分享你的设置。"
L["Options.ImportSettings"] = "导入设置"
L["Options.ImportSettings.DescPlain"] = "在下方粘贴设置字符串。"
L["Options.ImportSettings.Overwrite"] = "将覆盖当前激活的配置文件。"
L["Options.Export"] = "导出"
L["Options.Import"] = "导入"
L["Options.ImportSuccess"] = "设置导入成功！"
L["Options.FailedExport"] = "导出失败"
L["Options.UnknownError"] = "未知错误"

-- ============================================================================
-- OPTIONS: SOUND ALERTS
-- ============================================================================
L["Options.Sound.AddAlert"] = "添加声音提醒"
L["Options.Sound.NoAlerts"] = "未配置声音提醒。"
L["Options.Sound.NoBuffs"] = "所有增益已配置声音提醒。"
L["Options.Sound.Preview"] = "预览"
L["Options.Sound.Save"] = "保存"
L["Options.Sound.SelectBuff"] = "选择增益"
L["Options.Sound.SelectSound"] = "选择声音提醒"
L["Options.Sound.Title"] = "添加声音提醒"
L["Options.Sound.EditTitle"] = "编辑声音提醒"

-- ============================================================================
-- OPTIONS: DIALOGS
-- ============================================================================
L["Dialog.Cancel"] = "取消"
L["Dialog.DeleteCustomBuff"] = '是否删除自定义增益 "%s"？'
L["Dialog.ResetProfile"] =
    "是否将当前配置文件重置为默认值？\n\n当前配置文件的所有自定义设置将被删除并重载UI。"
L["Dialog.Reset"] = "重置"
L["Dialog.ReloadPrompt"] = "设置导入成功！\n是否重载UI以应用更改？"
L["Dialog.Reload"] = "重载"
L["Dialog.NewProfilePrompt"] = "请输入新配置文件的名称："
L["Dialog.Create"] = "创建"
L["Dialog.DiscordPrompt"] = "加入BuffReminders的Discord频道！\n复制下方URL以加入："
L["Dialog.Close"] = "关闭"

-- ============================================================================
-- OPTIONS: TEST / LOCK
-- ============================================================================
L["Options.LockUnlock"] = "锁定 / 解锁"
L["Options.LockUnlock.Desc"] = "解锁后将显示锚点手柄，以便调整增益框体的位置。"
L["Options.TestAppearance"] = "测试图标外观"
L["Options.TestAppearance.Desc"] = "使用模拟数据显示选定的增益以预览外观。"
L["Options.Test"] = "测试"
L["Options.StopTest"] = "停止测试"
L["Options.AnchorHint"] = "点击锚点以更改其对齐位置或坐标。"
L["Options.Lock"] = "锁定"
L["Options.Unlock"] = "解锁"

-- ============================================================================
-- OPTIONS: CUSTOM BUFF DIALOG
-- ============================================================================
L["CustomBuff.Edit"] = "编辑自定义增益"
L["CustomBuff.EditShort"] = "编辑"
L["CustomBuff.Add"] = "添加自定义增益"
L["CustomBuff.AddButton"] = "+ 添加自定义增益"
L["CustomBuff.SpellIDs"] = "法术ID:"
L["CustomBuff.Lookup"] = "查找"
L["CustomBuff.AddSpellID"] = "+ 添加法术ID"
L["CustomBuff.Name"] = "名称:"
L["CustomBuff.Text"] = "文本:"
L["CustomBuff.LineBreakHint"] = "（使用 \\n 换行）"
L["CustomBuff.Appearance"] = "外观"
L["CustomBuff.ShowIn"] = "显示位置"
L["CustomBuff.ClickAction"] = "点击动作"
L["CustomBuff.BuffTracking"] = "增益追踪"
L["CustomBuff.Requirements"] = "要求"
L["CustomBuff.ItemCooldown"] = "冷却："
L["CustomBuff.ItemCooldown.Any"] = "任意"
L["CustomBuff.ItemCooldown.OffCooldown"] = "冷却完毕"
L["CustomBuff.ItemCooldown.OnCooldown"] = "冷却中"

-- Custom buff mode toggles
L["CustomBuff.WhenActive"] = "激活时"
L["CustomBuff.WhenMissing"] = "缺失时"
L["CustomBuff.OnlyIfSpellKnown"] = "仅当掌握法术时"

-- Custom buff class dropdown
L["Class.Any"] = "任意"
L["Class.DeathKnight"] = "死亡骑士"
L["Class.DemonHunter"] = "恶魔猎手"
L["Class.Druid"] = "德鲁伊"
L["Class.Evoker"] = "唤魔师"
L["Class.Hunter"] = "猎人"
L["Class.Mage"] = "法师"
L["Class.Monk"] = "武僧"
L["Class.Paladin"] = "圣骑士"
L["Class.Priest"] = "牧师"
L["Class.Rogue"] = "潜行者"
L["Class.Shaman"] = "萨满祭司"
L["Class.Warlock"] = "术士"
L["Class.Warrior"] = "战士"

-- Custom buff fields
L["CustomBuff.Spec"] = "专精:"
L["CustomBuff.Class"] = "职业:"
L["CustomBuff.RequireItem"] = "需要物品:"
L["CustomBuff.RequireItem.EquippedBags"] = "已装备/背包中"
L["CustomBuff.RequireItem.Equipped"] = "已装备"
L["CustomBuff.RequireItem.InBags"] = "背包中"
L["CustomBuff.RequireItem.Hint"] = "物品ID - 缺失时隐藏"

-- Bar glow options
L["CustomBuff.BarGlow.WhenGlowing"] = "发光时检测"
L["CustomBuff.BarGlow.WhenNotGlowing"] = "不发光时检测"
L["CustomBuff.BarGlow.Disabled"] = "禁用"
L["CustomBuff.BarGlow"] = "动作条发光:"
L["CustomBuff.BarGlow.Title"] = "动作条发光替代检测"
L["CustomBuff.BarGlow.Desc"] =
    "在史诗钥石/PvP/战斗中由于增益API受限，使用动作条法术发光作为替代检测方法。若仅追踪增益是否存在，请禁用此项。"

-- Ready check / level
L["CustomBuff.ReadyCheckOnly"] = "仅就位确认时"
L["CustomBuff.Level"] = "等级:"
L["CustomBuff.Level.Any"] = "任意等级"
L["CustomBuff.Level.Max"] = "仅满级"
L["CustomBuff.Level.BelowMax"] = "未满级"

-- Click action
L["CustomBuff.Action.None"] = "无"
L["CustomBuff.Action.Spell"] = "法术"
L["CustomBuff.Action.Item"] = "物品"
L["CustomBuff.Action.Macro"] = "宏"
L["CustomBuff.Action.OnClick"] = "点击时:"
L["CustomBuff.Action.Title"] = "点击动作"
L["CustomBuff.Action.Desc"] =
    "设置点击此增益图标时的动作。法术会施放法术，物品会使用物品，宏会执行宏。"
L["CustomBuff.Action.MacroHint"] = "例：/use item:12345\n/use 13"

-- Save/Cancel/Delete
L["CustomBuff.Save"] = "保存"
L["CustomBuff.ValidateError"] = "需要至少1个有效的法术ID"

-- Custom buff status
L["CustomBuff.InvalidID"] = "无效ID"
L["CustomBuff.NotFound"] = "未找到"
L["CustomBuff.NotFoundRetry"] = "未找到 (重试)"
L["CustomBuff.Error"] = "错误:"

-- ============================================================================
-- OPTIONS: DISCORD
-- ============================================================================
L["Options.JoinDiscord"] = "加入Discord"
L["Options.JoinDiscord.Title"] = "点击查看邀请链接"
L["Options.JoinDiscord.Desc"] = "有反馈、功能请求或发现BUG？\n欢迎加入我们的Discord！"

-- ============================================================================
-- OPTIONS: CUSTOM ANCHOR FRAMES
-- ============================================================================
L["Options.CustomAnchorFrames.Desc"] =
    "在锚点下拉菜单中添加全局框体名称。（例：MyAddon_PlayerFrame）\n游戏中不存在的框体会自动跳过。"
L["Options.Add"] = "添加"
L["Options.New"] = "新建"
L["Options.ResetToDefaults"] = "重置为默认值"

-- ============================================================================
-- OPTIONS: MISC
-- ============================================================================
L["Options.Off"] = "关闭"
L["Options.Always"] = "始终"
L["Options.ReadyCheck"] = "就位确认"
L["Options.Min"] = "分钟"

-- ============================================================================
-- COMPONENTS (UI/Components.lua)
-- ============================================================================
-- Content filter tooltip
L["Content.ClickToFilter"] = "点击以按 %s 难度过滤"

-- Mover labels
L["Mover.AnchorGrowth"] = "锚点 \194\183 增长方向 %s"
L["Mover.AnchorGrowthFrame"] = "锚点 \194\183 增长方向 %s \194\183 > %s"

-- Pet labels
L["Pet.SpiritBeast"] = "灵魂兽"

-- Appearance grid labels
L["Appearance.Width"] = "宽度"
L["Appearance.Height"] = "高度"
L["Appearance.Zoom"] = "缩放"
L["Appearance.Border"] = "边框"
L["Appearance.Spacing"] = "间距"
L["Appearance.Alpha"] = "透明度"
L["Appearance.Text"] = "文本"

-- Slider tooltip
L["Component.AdjustValue"] = "调整数值"
L["Component.AdjustValue.Desc"] = "点击输入或使用鼠标滚轮。"
L["Component.AdjustValue.ClickHint"] = "点击数字以输入具体数值"

-- Direction labels
L["Direction.Left"] = "左侧"
L["Direction.Center"] = "中心"
L["Direction.Right"] = "右侧"
L["Direction.Up"] = "上方"
L["Direction.Down"] = "下方"
L["Direction.Label"] = "方向"

-- Content visibility
L["Content.ShowIn"] = "显示条件:"

-- Content toggle definitions
L["Content.OpenWorld"] = "野外"
L["Content.Housing"] = "家园"
L["Content.Scenarios"] = "场景战役"
L["Content.Dungeons"] = "地下城"
L["Content.Raids"] = "团队副本"
L["Content.PvP"] = "PvP"

-- Scenario difficulty
L["Content.Delves"] = "地下堡"
L["Content.OtherScenarios"] = "其他场景战役"

-- Dungeon difficulty
L["Content.NormalDungeons"] = "普通地下城"
L["Content.HeroicDungeons"] = "英雄地下城"
L["Content.MythicDungeons"] = "史诗地下城"
L["Content.MythicPlus"] = "史诗钥石"
L["Content.TimewalkingDungeons"] = "时光漫游地下城"
L["Content.FollowerDungeons"] = "追随者地下城"

-- Raid difficulty
L["Content.LFR"] = "随机团队"
L["Content.NormalRaids"] = "普通团队副本"
L["Content.HeroicRaids"] = "英雄团队副本"
L["Content.MythicRaids"] = "史诗团队副本"

-- PvP types
L["Content.Arena"] = "竞技场"
L["Content.Battlegrounds"] = "战场"
