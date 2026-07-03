local _, BR = ... -- luacheck: ignore 211
if GetLocale() ~= "koKR" then
    return
end

local L = BR.L -- luacheck: ignore 211

-- Credit by Elnarfim

-- ============================================================================
-- CATEGORY LABELS
-- ============================================================================
L["Category.Raid"] = "공격대 버프"
L["Category.Presence"] = "특수 버프"
L["Category.Targeted"] = "대상 지정"
L["Category.Self"] = "자신"
L["Category.Pet"] = "소환수"
L["Category.Consumable"] = "소모품"
L["Category.Custom"] = "사용자 지정"
L["Category.Loadout"] = "구성"

-- Long form (used in Options section headers)
L["Category.RaidBuffs"] = "공격대 버프"
L["Category.TargetedBuffs"] = "대상 지정 버프"
L["Category.Consumables"] = "소모품"
L["Category.PresenceBuffs"] = "특수 버프"
L["Category.SelfBuffs"] = "내 전용 버프"
L["Category.PetReminders"] = "소환수 알림"
L["Category.CustomBuffs"] = "사용자 지정 버프"
L["Category.LoadoutReminders"] = "구성 알림"

-- Category notes
L["Category.RaidNote"] = "(그룹 전체 대상)"
L["Category.TargetedNote"] = "(다른 대상에게 거는 버프)"
L["Category.ConsumableNote"] = "(영약, 음식, 증강 룬, 기름)"
L["Category.PresenceNote"] = "(최소 1명 필요)"
L["Category.SelfNote"] = "(자신에게만 거는 버프)"
L["Category.PetNote"] = "(소환수 소환 알림)"
L["Category.CustomNote"] = "(주문 ID로 버프/반짝임 추적)"
L["Category.LoadoutNote"] = "(장비나 특성이 현재 콘텐츠와 맞지 않을 때 알림)"

-- Loadout reminders
L["Loadout.Add"] = "구성 알림 추가"
L["Loadout.Edit"] = "구성 알림 편집"
L["Loadout.AddButton"] = "+ 구성 알림 추가"
L["Loadout.Empty"] = "구성 알림이 없습니다. 아래 메뉴로 하나 추가하세요."
L["Loadout.Name"] = "이름"
L["Loadout.Expect"] = "요구 조건"
L["Loadout.Applies"] = "적용 대상"
L["Loadout.Content"] = "콘텐트"
L["Loadout.Requirement"] = "필요 조건"
L["Loadout.EquipmentSet"] = "장비 구성"
L["Loadout.TalentSpell"] = "특성 주문 ID"
L["Loadout.NoSets"] =
    "장비 구성이 없습니다. 캐릭터 정보 (장비 관리) 창에서 먼저 하나를 만드세요."
L["Loadout.NoSetSelected"] = "먼저 장비 구성을 선택하세요."
L["Loadout.NoLoadouts"] = "이 전문화에는 저장된 특성 구성이 없습니다."
L["Loadout.NoLoadoutSelected"] = "먼저 특성 구성을 선택하세요."
L["Loadout.InvalidSpell"] = "해당 주문 ID는 존재하지 않습니다. 특성의 주문 ID를 사용하세요."
L["Loadout.CombatBlocked"] = "전투 중에는 장비나 특성을 바꿀 수 없습니다."
L["Loadout.Instances"] = "인스턴스 %d개"
L["Loadout.LimitRaids"] = "특정 레이드만"
L["Loadout.LimitDungeons"] = "특정 던전만"
-- Content scope (you can't swap gear/talents once a key or match starts, so the
-- rule only needs the content you're in - no per-difficulty granularity).
L["Loadout.Scope.Raid"] = "레이드"
L["Loadout.Scope.Dungeon"] = "던전"
L["Loadout.Scope.Arena"] = "투기장"
L["Loadout.Scope.Battleground"] = "전장"
-- Binding label: spec + class, e.g. "Protection Warrior" (reorder for your locale).
L["Loadout.Require.Gear"] = "장비 구성"
L["Loadout.Require.Talent"] = "특성"
L["Loadout.Require.Loadout"] = "특성 구성"
-- On-icon "what's wrong" tags (newline wraps them to two lines on the icon)
L["Loadout.Tag.Gear"] = "잘못된\n장비"
L["Loadout.Tag.Talent"] = "특성\n없음"
L["Loadout.Tag.Loadout"] = "잘못된\n구성"

-- ============================================================================
-- BUFF OVERLAY TEXT
-- ============================================================================
-- These must be kept very short (2-4 chars per line) to fit on small icons.
L["Overlay.NoDrPoison"] = "독\n없음"
L["Overlay.NoAura"] = "오라\n없음"
L["Overlay.NoStone"] = "생석\n없음"
L["Overlay.NoSoulstone"] = "영석\n없음"
L["Overlay.NoFaith"] = "신봉\n없음"
L["Overlay.NoLight"] = "봉화\n없음"
L["Overlay.NoES"] = "대보\n없음"
L["Overlay.NoSource"] = "원천\n없음"
L["Overlay.NoScales"] = "비늘\n없음"
L["Overlay.NoLink"] = "공생\n없음"
L["Overlay.NoWeyrnstone"] = "웨이른\n없음"
L["Overlay.NoTimeless"] = "무궁\n없음"
L["Overlay.NoAttune"] = "조율\n없음"
L["Overlay.NoFamiliar"] = "전령\n없음"
L["Overlay.DropWell"] = "영혼샘\n깔기"
L["Overlay.NoGrim"] = "흑마법서\n없음"
L["Overlay.BurningRush"] = "불돌"
L["Overlay.NoRite"] = "의식\n없음"
L["Overlay.ApplyPoison"] = "독\n바르기"
L["Overlay.NoForm"] = "형상\n없음"
L["Overlay.NoEL"] = "대지생명\n없음"
L["Overlay.NoFT"] = "불꽃\n없음"
L["Overlay.NoTG"] = "수호\n없음"
L["Overlay.NoWF"] = "질풍\n없음"
L["Overlay.NoSelfES"] = "내 대보\n없음"
L["Overlay.NoShield"] = "보호막\n없음"
L["Overlay.NoPet"] = "소환수\n없음"
L["Overlay.PassivePet"] = "수동적\n소환수"
L["Overlay.WrongPet"] = "잘못된\n소환수"
L["Overlay.WrongStance"] = "잘못된\n태세"
L["Overlay.WrongForm"] = "잘못된\n형상"
L["Overlay.NoRune"] = "증강\n없음"
L["Overlay.DKWrongRune"] = "잘못된\n룬"
L["Overlay.DKWrongRuneOH"] = "잘못된\n보조\n룬"
L["Overlay.NoFlask"] = "영약\n없음"
L["Overlay.NoFood"] = "음식\n없음"
L["Overlay.NoWeaponBuff"] = "무기 버프\n없음"
L["Overlay.Buff"] = "버프!"
L["Overlay.MinutesFormat"] = "%d분"
L["Overlay.LessThanOneMinute"] = "<1분"
L["Overlay.SecondsFormat"] = "%d초"

-- ============================================================================
-- CONSUMABLE STAT LABELS (icon overlays, keep very short)
-- ============================================================================
L["Label.Crit"] = "치명타"
L["Label.Haste"] = "가속"
L["Label.Versatility"] = "유연성"
L["Label.Mastery"] = "특화"
L["Label.Stamina"] = "체력"
L["Label.Healing"] = "치유"
L["Label.Random"] = "무작위"
L["Label.Speed"] = "이속"
L["Label.PvP"] = "PvP"
L["Label.Feast"] = "잔칫상"
L["Label.HasteShort"] = "가"
L["Label.VersatilityShort"] = "유"
L["Label.MasteryShort"] = "특"
L["Label.CritVers"] = "치/유"
L["Label.MasteryCrit"] = "특/치"
L["Label.MasteryVers"] = "특/유"
L["Label.MasteryHaste"] = "특/가"
L["Label.HasteCrit"] = "가/치"
L["Label.HasteVers"] = "가/유"
L["Label.StaminaStr"] = "체/힘"
L["Label.StaminaAgi"] = "체/민"
L["Label.StaminaInt"] = "체/지"
L["Label.HighPrimary"] = "상급 1차"
L["Label.HighSecondary"] = "상급 2차"
L["Label.MidPrimary"] = "중급 1차"
L["Label.LowPrimary"] = "하급 1차"
L["Label.LowSecondary"] = "하급 2차"
L["Label.RevivePet"] = "야수 되살리기"
L["Label.Felguard"] = "지옥수호병"
L["Badge.Hearty"] = "든"
L["Badge.Fleeting"] = "덧"

-- ============================================================================
-- BUFF NAMES (used in Options panel checkboxes and sound notification list)
-- ============================================================================
-- Raid
L["Buff.ArcaneIntellect"] = "신비한 지능"
L["Buff.BattleShout"] = "전투의 외침"
L["Buff.BlessingOfTheBronze"] = "청동용군단의 축복"
L["Buff.MarkOfTheWild"] = "야생의 징표"
L["Buff.PowerWordFortitude"] = "신의 권능: 인내"
L["Buff.Skyfury"] = "하늘의 격노"
-- Presence
L["Buff.AtrophicNumbingPoison"] = "위축/마취 독"
L["Buff.DevotionAura"] = "헌신의 오라"
L["Buff.Soulstone"] = "영혼석"
-- Targeted
L["Buff.BeaconOfFaith"] = "신념의 봉화"
L["Buff.BeaconOfLight"] = "빛의 봉화"
L["Buff.BlisteringScales"] = "끓어오르는 비늘"
L["Buff.EarthShield"] = "대지의 보호막"
L["Buff.SourceOfMagic"] = "마법의 원천"
L["Buff.SymbioticRelationship"] = "공생관계"
L["Buff.Timelessness"] = "무궁"
L["Buff.Weyrnstone"] = "웨이른석"
-- Self
L["Buff.ArcaneFamiliar"] = "비전 전령"
L["Buff.Attunement"] = "조율"
L["Buff.CreateSoulwell"] = "영혼의 샘 창조"
L["Buff.DruidForm"] = "드루이드 변신"
L["Buff.GrimoireOfSacrifice"] = "흑마법서: 희생"
L["Buff.BurningRush"] = "불타는 돌진"
L["Buff.RiteOfAdjuration"] = "서원의 의식"
L["Buff.RiteOfSanctification"] = "축성의 의식"
L["Buff.RoguePoisons"] = "도적 독"
L["Buff.RuneforgeMH"] = "룬벼리기 (주장비)"
L["Buff.RuneforgeOH"] = "룬벼리기 (보조장비)"
L["Buff.Shadowform"] = "어둠의 형상"
L["Buff.EarthlivingWeapon"] = "대지생명의 무기"
L["Buff.FlametongueWeapon"] = "불꽃혓바닥 무기"
L["Buff.TidecallersGuard"] = "파도소환사의 수호"
L["Buff.WindfuryWeapon"] = "질풍의 무기"
L["Buff.EarthShieldSelf"] = "대지의 보호막 (자신)"
L["Buff.WaterLightningShield"] = "물/번개 보호막"
L["Buff.ShieldNoTalent"] = "보호막 (특성 없음)"
-- Pet
L["Buff.PetPassive"] = "수동적 소환수"
L["Buff.HunterPet"] = "사냥꾼 야수"
L["Buff.UnholyGhoul"] = "부죽 구울"
L["Buff.WarlockDemon"] = "흑마법사 악마"
L["Buff.WaterElemental"] = "물의 정령"
L["Buff.WrongDemon"] = "잘못된 악마"
L["Buff.WarriorStance"] = "전사 태세"
-- Consumable
L["Buff.AugmentRune"] = "증강 룬"
L["Buff.Flask"] = "영약"
L["Buff.DelveFood"] = "구렁 음식"
L["Buff.Food"] = "음식"
L["Buff.Healthstone"] = "생명석"
L["Buff.Weapon"] = "무기"
L["Buff.WeaponOH"] = "무기 (보조장비)"

-- ============================================================================
-- BUFF GROUP DISPLAY NAMES
-- ============================================================================
L["Group.Beacons"] = "봉화"
L["Group.DKRunes"] = "룬벼리기"
L["Group.ShamanImbues"] = "주술사 무기 강화"
L["Group.PaladinRites"] = "성기사 의식"
L["Group.Pets"] = "소환수"
L["Group.ShamanShields"] = "주술사 보호막"
L["Group.Flask"] = "영약"
L["Group.Food"] = "음식"
L["Group.DelveFood"] = "구렁 음식"
L["Group.Healthstone"] = "생명석"
L["Group.AugmentRune"] = "증강 룬"
L["Group.WeaponBuff"] = "무기 버프"

-- ============================================================================
-- BUFF INFO TOOLTIPS
-- ============================================================================
L["Tooltip.MayShowExtraIcon"] = "추가 아이콘이 표시될 수 있음"
L["Tooltip.MayShowExtraIcon.Desc"] =
    "이 주문을 시전하기 전까진 이 알림과 물/번개 보호막 알림이 동시에 표시될 수 있습니다. 대지의 보호막을 자신에게 걸려는 건지 아군에게 걸고 자신은 물/번개 보호막을 걸려는 건지 구분이 불가능하기 때문입니다."
L["Tooltip.InstanceEntryReminder"] = "인스턴스 입장 알림"
L["Tooltip.InstanceEntryReminder.Desc"] =
    "던전 입장 시 영혼의 샘을 깔라는 알림이 잠시 표시됩니다. 시전하거나 30초가 지나면 사라집니다."
L["BuffTooltip.ProvidedBy"] = "%s|1이;가; 걸어줌"

-- ============================================================================
-- GLOW TYPE NAMES
-- ============================================================================
L["Glow.Pixel"] = "픽셀"
L["Glow.AutoCast"] = "자동 시전"
L["Glow.Border"] = "테두리"
L["Glow.Proc"] = "발동"

-- ============================================================================
-- CORE
-- ============================================================================
L["Core.Any"] = "모두"

-- ============================================================================
-- PROFILES
-- ============================================================================
L["Profile.SwitchQueued"] = "전투 종료 후 프로필이 전환됩니다."
L["Profile.Switched"] = "'%s' 프로필로 전환했습니다."

-- ============================================================================
-- MOVERS
-- ============================================================================
L["Mover.SetPosition"] = "위치 설정"
L["Mover.AnchorFrame"] = "앵커 프레임"
L["Mover.AnchorPoint"] = "앵커 지점"
L["Mover.NoneScreenCenter"] = "없음 (화면 중앙)"
L["Mover.Apply"] = "적용"
L["Mover.BuffAnchor"] = "버프 앵커"
L["Mover.DragTooltip"] = "드래그로 위치 조정\n클릭으로 좌표 편집기 열기/닫기"
L["Mover.MainEmpty"] = "메인 (비어있음)"
L["Mover.MainAll"] = "메인 (전체)"
L["Mover.Detached"] = "분리됨"

-- ============================================================================
-- DISPLAY
-- ============================================================================
L["Display.FramesLocked"] = "프레임 위치를 고정했습니다."
L["Display.FramesUnlocked"] = "프레임의 고정이 해제됐습니다."
L["Display.MinimapHidden"] = "미니맵 아이콘이 숨겨졌습니다."
L["Display.MinimapShown"] = "미니맵 아이콘이 표시됩니다."
L["Display.DebugEnabled"] =
    "디버그 모드가 활성화됐습니다. |cFFFFD100/br debug|r를 다시 실행하면 꺼집니다."
L["Display.DebugDisabled"] = "디버그 모드가 비활성화됐습니다."
L["Display.Description"] = "누락된 버프를 한꺼번에 확인하세요."
L["Display.OpenOptions"] = "옵션 열기"
L["Display.SlashCommands"] = "슬래시 명령어: /br, /br lock, /br unlock, /br test, /br minimap"
L["Display.MinimapLeftClick"] = "|cFFCFCFCF왼쪽 클릭|r: 옵션"
L["Display.MinimapRightClick"] = "|cFFCFCFCF오른쪽 클릭|r: 테스트 모드"
L["Display.DismissConsumables"] = "다음 로딩 화면 전까지 소모품 알림 숨기기"
L["Display.DismissConsumablesChat"] = "소모품 알림이 다음 로딩 화면까지 숨겨집니다."
L["Display.LoginFirstInstall"] =
    "설치해 주셔서 감사합니다! |cFFFFD100/br unlock|r을 입력하여 버프 표시를 이동하거나, |cFFFFD100/br|r 옵션 패널 하단의 버튼을 사용하세요."
L["Display.LoginLoadout"] =
    "신 기능: 구성 알림! |cFFFFD100/br|r의 장비 및 특성 페이지에서 설정해 보세요."
L["Display.LoginGlowDefaultChanged"] =
    "CPU 사용량을 줄이기 위해 버프 반짝임은 꺼짐이 기본값이 되었습니다. |cFFFFD100/br|r의 기본값 페이지에서 언제든 다시 활성화할 수 있습니다."

-- ============================================================================
-- OPTIONS: NAVIGATION LABELS
-- ============================================================================
L["Tab.DisplayBehavior"] = "표시/동작"

-- Sidebar groups
L["Sidebar.General"] = "일반"
L["Sidebar.Profiles"] = "프로필"

-- Page titles
L["Page.General"] = "일반"
L["Page.Defaults"] = "기본값"
L["Page.Visibility"] = "표시 설정"
L["Page.ChatRequests"] = "채팅 요청"
L["Page.Profiles"] = "프로필"
L["Page.AllBuffs"] = "모든 버프"

-- Per-category page section headers
L["Section.Tracking"] = "추적"
L["Section.TrackingOverrides"] = "추적 무시"
L["Section.TrackingOverrides.Desc"] =
    "지정된 상황일 때 추적 모드의 범위를 좁힙니다. 위의 모드를 사용하려면 상황 설정을 기본값으로 두세요. 여러가지 상황(렙업 중 전투중 같은)을 한번에 적용할 경우 가장 제한이 심한 사항이 우선합니다."

-- ============================================================================
-- OPTIONS: SOUND ALERTS
-- ============================================================================
L["Options.Sound.Preview"] = "미리듣기"
L["Options.Preview"] = "미리보기"

-- ============================================================================
-- OPTIONS: GLOBAL DEFAULTS
-- ============================================================================
L["Options.GlobalDefaults"] = "전체 기본값"
L["Options.GlobalDefaults.Note"] =
    "(사용자 지정 외형으로 덮어쓰지 않는 한 모든 카테고리에 적용됨)"
L["Options.Default"] = "기본값"
L["Options.Font"] = "글꼴"
L["Options.TextOutline"] = "외곽선"
L["Options.TextOutline.None"] = "없음"
L["Options.TextOutline.Outline"] = "외곽선"
L["Options.TextOutline.Thick"] = "두꺼운 외곽선"
L["Options.TextOutline.Monochrome"] = "모노크롬"
L["Options.TextOutline.OutlineMono"] = "외곽선 + 모노크롬"
L["Options.TextOutline.ThickMono"] = "두꺼움 + 모노크롬"

-- ============================================================================
-- OPTIONS: GLOW SETTINGS
-- ============================================================================
L["Options.GlowReminderIcons.Title"] = "알림 아이콘 반짝임"
L["Options.GlowReminderIcons.CpuWarning"] =
    "화면의 각 아이콘에 매 프레임 반짝임 효과를 주며 CPU를 보다 많이 사용합니다. 아이콘이 오래 떠있을 경우(전투 도중 버프를 걸지 않았을 때 처럼) 자원 소비도 그만큼 지속됩니다. 이러한 이유로 기본값은 비활성화입니다."
L["Options.GlowKind.Expiring"] = "만료 임박"
L["Options.GlowKind.Missing"] = "누락"
L["Options.GlowSettings.Expiring"] = "반짝임 설정 - 만료 임박"
L["Options.GlowSettings.Missing"] = "반짝임 설정 - 누락"
L["Options.Glow.Enabled"] = "활성화"
L["Options.Threshold"] = "기준값"
L["Options.GlowMissingPets"] = "소환수 없음 반짝임"
L["Options.Expiration"] = "만료 임박"
L["Options.Glow"] = "반짝임"
L["Options.UseCustomColor"] = "사용자 지정 색상 사용"
L["Options.UseCustomColor.Desc"] =
    "활성화하면 발동 반짝임의 채도가 내려가고 색상이 변경됩니다.\n기본 발동 반짝임보다 덜 선명하게 보일 수 있습니다."
L["Options.ExpirationReminder"] = "만료 임박 알림"
L["Options.PreKeyThreshold"] = "쐐기 전 기준값"
L["Options.PreKeyThreshold.Desc"] =
    "신화 던전(M0)에서 쐐기돌을 넣기 전에는 더 긴 만료 임박 기준값을 사용합니다.\n쐐기를 시작하기 전 버프 작업할 때 도움이 됩니다."

-- Glow params
L["Options.Glow.Type"] = "유형:"
L["Options.Glow.Size"] = "크기:"
L["Options.Glow.Duration"] = "지속시간"
L["Options.Glow.Frequency"] = "빈도"
L["Options.Glow.Length"] = "길이"
L["Options.Glow.Lines"] = "선"
L["Options.Glow.Particles"] = "입자"
L["Options.Glow.Scale"] = "크기 비율"
L["Options.Glow.Speed"] = "속도"
L["Options.Glow.StartAnimation"] = "시작 애니메이션"
L["Options.Glow.XOffset"] = "X 조정"
L["Options.Glow.YOffset"] = "Y 조정"

-- ============================================================================
-- OPTIONS: CONTENT VISIBILITY
-- ============================================================================
L["Options.HidePvPMatchStart"] = "PvP 경기 시작 시 숨기기"
L["Options.HidePvPMatchStart.Title"] = "PvP 경기 시작 시 숨기기"
L["Options.HidePvPMatchStart.Desc"] =
    "PvP 경기가 시작되면 (준비 단계 종료 후) 이 카테고리를 숨깁니다."
L["Options.ReadyCheckOnly"] = "전투 준비 시에만 표시"
L["Options.ReadyCheckOnly.Desc"] = "전투 준비 후 15초 동안만 이 카테고리의 버프를 표시합니다."
L["Options.Visibility"] = "표시 설정"

-- ============================================================================
-- OPTIONS: HEALTHSTONE
-- ============================================================================
L["Options.Healthstone.LowStock"] = "부족 시 경고"
L["Options.Healthstone.LowStock.Desc"] =
    "생명석이 있지만 부족할 때 경고를 표시합니다. 생명석이 없는 경우(0개)는 이 설정과 관계없이 항상 추적됩니다."
L["Options.Healthstone.Threshold"] = "경고 기준 수량"
L["Options.Healthstone.Threshold.Desc"] =
    "생명석이 이 수량 이하일 때 부족 경고를 표시합니다.\n\n|cffffcc001:|r 정확히 1개일 때 경고.\n|cffffcc002:|r 1개나 2개일 때 경고합니다."

-- ============================================================================
-- OPTIONS: SOULSTONE
-- ============================================================================
L["Options.Soulstone.HideCooldown"] = "쿨타임일 때 숨기기 (흑마법사)"
L["Options.Soulstone.HideCooldown.Desc"] =
    "활성화하면 주문이 쿨타임일 때 흑마법사에게 영혼석 알림을 표시하지 않습니다. 흑마법사에게만 적용됩니다."

-- ============================================================================
-- OPTIONS: FREE CONSUMABLES
-- ============================================================================
L["Options.FreeConsumables"] = "무료 소모품"
L["Options.FreeConsumables.Note"] = "(생명석, 영구 증강 룬)"
L["Options.FreeConsumables.Override"] = "콘텐츠 필터 적용"
L["Options.FreeConsumables.Override.Desc"] =
    "체크 시, 무료 소모품은 아래의 콘텐츠 유형 설정을 사용합니다.\n\n체크 해제 시, 다른 소모품과 동일한 콘텐츠 필터를 따릅니다."

-- ============================================================================
-- OPTIONS: ICONS
-- ============================================================================
L["Options.Icons"] = "아이콘"
L["Options.ShowText"] = "아이콘에 텍스트 표시"
L["Options.ShowText.Desc"] =
    "이 카테고리의 버프 아이콘에 버프 개수나 누락 텍스트 오버레이를 표시합니다."
L["Options.ShowMissingCountOnly"] = "누락 수량만 표시"
L["Options.ShowMissingCountOnly.Desc"] =
    '전체 숫자(예: "19/20") 대신 누락된 버프 수(예: "1")만 표시합니다.'
L["Options.ShowBuffReminderText"] = '"버프!" 알림 텍스트 표시'
L["Options.Size"] = "크기"

-- ============================================================================
-- OPTIONS: TEXT POSITIONS
-- ============================================================================
L["Options.TextPositions"] = "텍스트"
L["Options.TextPositions.Zone"] = "위치"
L["Options.TextPositions.OffsetX.Short"] = "X"
L["Options.TextPositions.OffsetY.Short"] = "Y"
L["Options.TextPositions.StackCount"] = "중첩 수"
L["Options.TextPositions.StatLabel"] = "능력치 라벨"
L["Options.TextPositions.Badge"] = "표시 (든 / 덧)"
L["Options.TextPositions.Vertical.Above"] = "위쪽"
L["Options.TextPositions.Vertical.InsideTop"] = "상단"
L["Options.TextPositions.Vertical.InsideMiddle"] = "중앙"
L["Options.TextPositions.Vertical.InsideBottom"] = "하단"
L["Options.TextPositions.Vertical.Below"] = "아래쪽"
L["Options.TextPositions.Align.Left"] = "왼쪽"
L["Options.TextPositions.Align.Center"] = "중앙"
L["Options.TextPositions.Align.Right"] = "오른쪽"

-- ============================================================================
-- OPTIONS: CLICK TO CAST
-- ============================================================================
L["Options.ClickToCast"] = "클릭으로 시전"
L["Options.ClickToCast.DescFull"] =
    "버프 아이콘을 클릭해 해당 주문을 시전할 수 있습니다.(비전투 시에만) 내 캐릭터가 시전 가능한 주문에만 작동합니다."
L["Options.HoverHighlight"] = "마우스오버 강조"
L["Options.HoverHighlight.Desc"] =
    "클릭 가능한 버프 아이콘에 마우스를 올리면 희미한 강조 효과가 표시됩니다."
L["Options.RequestBuffInChat"] = "없는 버프를 채팅으로 요청"
L["Options.RequestBuffInChat.Desc"] =
    "내 직업이 걸 수 없는 누락된 버프를 클릭하면 채팅으로 요청합니다. 채널(인스턴스/공격대/파티/일반)을 자동으로 감지합니다. 버프당 30초의 쿨타임이 있습니다."
L["Options.ChatRequest.ResetAll"] = "모두 초기화"
L["ChatRequests.PerBuffMessages"] = "버프별 메시지"
-- Chat request messages (keyed by buff.key, sent as-is via SendChatMessage)
-- EU/US translators: leave untranslated so chat messages stay in English.
-- Asian translators: translate these so chat messages match your locale.
L["ChatRequest.intellect"] = "신비한 지능 버프 주세요"
L["ChatRequest.attackPower"] = "전투의 함성 버프 주세요"
L["ChatRequest.bronze"] = "청동용군단의 축복 버프 주세요"
L["ChatRequest.versatility"] = "야생의 징표 버프 주세요"
L["ChatRequest.stamina"] = "신의 권능: 인내 버프 주세요"
L["ChatRequest.skyfury"] = "하늘의 격노 버프 주세요"
L["ChatRequest.atrophicNumbingPoison"] = "위축/마취 독 발라주세요"
L["ChatRequest.devotionAura"] = "헌신의 오라 켜주세요"
L["ChatRequest.soulstone"] = "영혼석 걸어주세요"
L["ChatRequest.healthstone"] = "생명석 주세요"

-- ============================================================================
-- OPTIONS: PET
-- ============================================================================
L["Options.PetSpecIcon"] = "마우스를 올렸을 때 사냥꾼 소환수 특성 아이콘 표시"
L["Options.PetSpecIcon.Title"] = "마우스를 올리면 소환수 특성 아이콘으로"
L["Options.PetSpecIcon.Desc"] =
    "마우스를 올리면 소환수 아이콘이 특성 능력(교활, 야성, 끈기)으로 바뀝니다."
L["Options.ShowItemTooltips"] = "아이템 툴팁 표시"
L["Options.ShowItemTooltips.Desc"] =
    "소모품 아이콘에 마우스를 올리면 아이템 툴팁이 표시됩니다."
L["Options.ShowBuffTooltips"] = "버프 툴팁 표시"
L["Options.ShowBuffTooltips.Desc"] =
    "공격대 또는 특수 버프 아이콘에 마우스 커서를 올리면 주문 툴팁과 걸어준 직업이 표시됩니다."
L["Options.Behavior"] = "동작"
L["Options.PetPassiveCombat"] = "전투 중에만 수동적 소환수 알림"
L["Options.PetPassiveCombat.Desc"] =
    "전투 중에만 수동적 소환수 알림을 표시합니다. 비활성화 시 항상 표시됩니다."
L["Options.FelDomination"] = "소환 전 지옥 지배 사용"
L["Options.FelDomination.Title"] = "지옥 지배"
L["Options.FelDomination.Desc"] =
    "클릭 시전으로 악마를 소환하기 전에 자동으로 지옥 지배를 시전합니다. 지옥 지배가 쿨타임일 땐 소환은 일반 방식대로 진행됩니다. 지옥 지배 특성이 필요합니다."

-- ============================================================================
-- OPTIONS: PET DISPLAY
-- ============================================================================
L["Options.PetDisplay"] = "소환수 표시"
L["Options.PetDisplay.Generic"] = "기본 아이콘"
L["Options.PetDisplay.GenericDesc"] = "기본 '소환수 없음' 아이콘 1개"
L["Options.PetDisplay.Summon"] = "소환 주문"
L["Options.PetDisplay.SummonDesc"] = "각 소환수 주문을 개별 아이콘으로 표시"
L["Options.PetDisplay.Mode"] = "소환수 표시 모드"
L["Options.PetDisplay.Mode.Desc"] = "소환수 없음 알림의 표시 방식을 설정합니다."
L["Options.PetLabels"] = "소환수 라벨"
L["Options.PetLabels.Desc"] = "각 아이콘 아래에 소환수 이름과 특성을 표시합니다."
L["Options.PetLabels.SizePct"] = "크기 %"

-- ============================================================================
-- OPTIONS: CONSUMABLE DISPLAY
-- ============================================================================
L["Options.ConsumableTextScale"] = "텍스트 크기"
L["Options.ConsumableTextScale.Title"] = "소모품 텍스트 크기"
L["Options.ConsumableTextScale.Desc"] =
    "아이콘 크기 대비 아이템 수량 및 등급(R1/R2/R3) 라벨의 폰트 크기 비율입니다."
L["Options.HideConsumableLabels"] = "능력치 라벨 숨기기"
L["Options.HideConsumableLabels.Title"] = "소모품 능력치 라벨 숨기기"
L["Options.HideConsumableLabels.Desc"] =
    '소모품 아이콘 왼쪽 상단에 표시되는 작은 능력치 라벨(예: "상급 1차", "하급 2차")을 숨깁니다.'
L["Options.ItemDisplay"] = "아이템 표시"
L["Options.ItemDisplay.IconOnly"] = "아이콘만 표시"
L["Options.ItemDisplay.IconOnlyDesc"] = "수량이 가장 많은 아이템 표시"
L["Options.ItemDisplay.SubIcons"] = "하위 아이콘"
L["Options.ItemDisplay.SubIconsDesc"] =
    "각 아이콘 아래에 클릭되는 다른 등급의 작은 아이템을 표시합니다"
L["Options.ItemDisplay.Expanded"] = "확장"
L["Options.ItemDisplay.ExpandedDesc"] = "다른 등급 아이템 아이콘을 원래 크기로 확장합니다"
L["Options.ItemDisplay.Mode"] = "소모품 아이템 표시"
L["Options.ItemDisplay.Mode.Desc"] =
    "복수의 등급이 있는 소모품 아이템(예: 다양한 영약 등급)의 표시 방식을 설정합니다."
L["Options.SubIconSide"] = "방향"
L["Options.SubIconSide.Bottom"] = "아래"
L["Options.SubIconSide.Top"] = "위"
L["Options.SubIconSide.Left"] = "왼쪽"
L["Options.SubIconSide.Right"] = "오른쪽"
L["Options.ShowWithoutItems"] = "소지품에 없을 때도 표시"
L["Options.ShowWithoutItems.Title"] = "가지고 있지 않은 소모품 표시"
L["Options.ShowWithoutItems.Desc"] =
    "활성화 시, 소지품에 아이템이 없어도 소모품 알림이 표시됩니다. 비활성화 시, 실제 보유한 소모품만 표시됩니다."
L["Options.ShowWithoutItemsReadyCheckOnly"] = "전투 준비 시에만"
L["Options.ShowWithoutItemsReadyCheckOnly.Title"] = "전투 준비 시 없는 아이템 표시"
L["Options.ShowWithoutItemsReadyCheckOnly.Desc"] =
    "활성화하면 가방에 없는 소모품은 전투 준비 시에만 표시됩니다. 풀링 전 보충을 위한 빠른 알림으로 유용합니다."
L["Options.DelveFoodOnly"] = "구렁에선 구렁 음식만 표시"
L["Options.DelveFoodOnly.Desc"] = "구렁에선 구렁 음식을 제외한 모든 소모품 알림을 숨깁니다."
L["Options.HideLegacyConsumables"] = "구 확장팩 소모품 숨기기"
L["Options.HideLegacyConsumables.Title"] = "구 확장팩 소모품 숨기기"
L["Options.HideLegacyConsumables.Desc"] =
    "활성화하면 구 확장팩의 음식, 영약, 증강 룬이 액션 버튼에서 제외됩니다. 시간여행, 구 레이드 파밍, 부캐 육성에 예전 소모품을 쓰고 있다면 비활성화하세요."

-- ============================================================================
-- OPTIONS: DK RUNEFORGE PREFERENCES
-- ============================================================================
L["Options.RuneMainHand"] = "주장비"
L["Options.RuneOffHand"] = "보조장비"
L["Options.RuneTwoHanded"] = "양손 무기"
L["Options.RuneDualWield"] = "쌍수 무기"

-- ============================================================================
-- OPTIONS: ROGUE POISON PREFERENCES
-- ============================================================================
L["Options.RoguePoisonNote"] =
    "바를 독과 우선순위(맨 위 = 제일 높음)를 선택하세요. 비활성화된 독은 시전되지 않으며 알림도 발생하지 않습니다."
L["Options.PoisonLethal"] = "살상용"
L["Options.PoisonNonLethal"] = "비살상용"
L["Options.PoisonMoveUp"] = "우선순위 위로"
L["Options.PoisonMoveDown"] = "우선순위 아래로"
L["Options.PoisonReset"] = "기본값으로 초기화"

-- ============================================================================
-- OPTIONS: BUFF SETTINGS GEAR ICONS
-- ============================================================================
L["Options.BronzeHideInCombat"] = "전투 중 숨기기"
L["Options.BronzeHideInCombat.Desc"] =
    "전투 중에 청동용군단의 축복 알림을 숨깁니다. 이 버프는 덜 중요하기 때문에 전투 중에 다시 걸고 싶지 않을 수 있습니다."
L["Options.DruidIgnoreTravelForm"] = "날쌘 동물 변신일땐 무시"
L["Options.DruidIgnoreTravelForm.Desc"] =
    "날쌘 동물 변신(지상, 수중, 비행, 탈것 변신)이나 탈것 탑승중엔 잘못된 변신 알림을 숨겨서 날쌘 동물 변신을 의도했을 때 알림이 귀찮게 하지 않습니다."
L["Options.DelveFoodTimer"] = "30초 후 자동 숨김"
L["Options.DelveFoodTimer.Desc"] =
    "활성화하면 구렁 입장 후 30초 동안만 알림이 표시되고 자동으로 숨겨집니다. 비활성화하면 구렁에서 버프가 없는 동안 계속 알림이 표시됩니다."

-- ============================================================================
-- OPTIONS: LAYOUT
-- ============================================================================
L["Options.Layout"] = "레이아웃"
L["Options.SplitFrame"] = "개별 프레임으로 분리"
L["Options.SplitFrame.Desc"] =
    "이 카테고리의 버프를 독립적으로 이동 가능한 별도의 프레임에 표시합니다."

-- Display Order section (Defaults page) - drives the same priority field the
-- old per-category slider wrote, but as a single ordered list across all
-- non-split categories.
L["Options.DisplayOrder.Note"] =
    "조합된 프레임 내에서 카테고리들이 위에서 아래로 쌓이는 순서를 설정합니다. 분리한 카테고리는 별도의 프레임에 있으므로 여기엔 나오지 않습니다."

-- Detached Icons page (search-driven dual-list manager).

-- ============================================================================
-- OPTIONS: APPEARANCE
-- ============================================================================
L["Options.Customize"] = "사용자 지정"
L["Options.ResetPosition"] = "위치 초기화"
L["Options.MasqueNote"] = "확대 및 테두리 설정은 Masque에서 관리합니다."

-- ============================================================================
-- OPTIONS: SETTINGS TAB
-- ============================================================================
L["Options.ShowLoginMessages"] = "로그인 메시지 표시"
L["Options.ShowMinimapButton"] = "미니맵 버튼 표시"

-- Hide when section
L["Options.HideWhen"] = "숨김 조건:"
L["Options.HideWhen.Alone"] = "1인"
L["Options.HideWhen.Alone.Title"] = "혼자일 때 숨김"
L["Options.HideWhen.Alone.Desc"] = "파티나 공격대 그룹에 없을 때 모든 버프 알림을 숨깁니다"
L["Options.HideWhen.Resting"] = "휴식 중"
L["Options.HideWhen.Resting.Title"] = "휴식 중 숨김"
L["Options.HideWhen.Resting.Desc"] = "여관이나 대도시에 있을 때 버프 알림을 숨깁니다."
L["Options.HideWhen.Combat"] = "전투 중"
L["Options.HideWhen.Expiring"] = "전투 중에는 만료 임박 버프만"
L["Options.HideWhen.Expiring.Title"] = "전투 중 만료 임박 버프 숨기기"
L["Options.HideWhen.Expiring.Desc"] =
    "전투 중에는 곧 만료될 버프를 숨기고 완전히 사라진 버프만 표시합니다."
L["Options.HideWhen.Vehicle"] = "차량 이용 중"
L["Options.HideWhen.Vehicle.Title"] = "차량 이용 중에 숨기기"
L["Options.HideWhen.Vehicle.Desc"] =
    "퀘스트 차량을 이용 중일 때 모든 버프 알림을 숨깁니다. 비활성화 시에도 공격대 및 특수 버프는 표시됩니다."
L["Options.HideWhen.Mounted"] = "탈것 탔을 때"
L["Options.HideWhen.Mounted.Title"] = "탈것 타는 중에 숨기기"
L["Options.HideWhen.Mounted.Desc"] =
    "탈것을 탔을 때 모든 버프 알림을 숨깁니다. 카테고리별 소환수 탈것 숨기기 설정보다 우선 적용됩니다."
L["Options.HideWhen.Legacy"] = "구 인스턴스"
L["Options.HideWhen.Legacy.Title"] = "구 인스턴스에서 숨기기"
L["Options.HideWhen.Legacy.Desc"] =
    "구 인스턴스(유산 전리품이 활성화된 곳)에서 모든 버프 알림을 숨깁니다."
L["Options.HideWhen.Leveling"] = "레벨링"
L["Options.HideWhen.Leveling.Title"] = "레벨링 중에 숨기기"
L["Options.HideWhen.Leveling.Desc"] = "만렙이 안됐을 때 모든 버프 알림을 숨깁니다."

-- ============================================================================
-- OPTIONS: BUFF TRACKING MODE
-- ============================================================================
L["Options.BuffTracking"] = "버프 추적"
L["Options.BuffTracking.All"] = "모든 버프, 모든 사람에게"
L["Options.BuffTracking.All.Desc"] =
    "모든 직업의 공격대 및 특수 버프를 표시하고 그룹 전체 적용 여부를 추적합니다."
L["Options.BuffTracking.MyBuffs"] = "내 버프만, 모든 사람에게"
L["Options.BuffTracking.MyBuffs.Desc"] =
    "내 직업이 걸 수 있는 버프만 표시하되, 그룹 전체 적용 여부는 추적합니다."
L["Options.BuffTracking.OnlyMine"] = "모든 버프, 나한테만"
L["Options.BuffTracking.OnlyMine.Desc"] =
    "모든 버프 유형을 표시하지만 나한테 있는지만을 확인합니다. 그룹은 세지 않습니다."
L["Options.BuffTracking.SelfOnly"] = "내 버프만, 나한테만"
L["Options.BuffTracking.SelfOnly.Desc"] =
    "내 직업이 걸 수 있는 버프만 표시하고 나한테 있는지만 확인합니다. 그룹 및 다른 사람에게 건 버프 수는 세지 않습니다."
L["Options.BuffTracking.Smart"] = "스마트"
L["Options.BuffTracking.Smart.Desc"] =
    "내 직업이 걸 수 있는 버프가 그룹에 몇이나 걸려있는지 추적합니다. 다른 직업 버프는 나한테 있는지만 확인합니다."
L["Options.BuffTracking.Mode"] = "버프 추적 모드"
L["Options.BuffTracking.Mode.Desc"] =
    "표시할 공격대 및 특수 버프를 설정하고 그룹 전체 또는 자신만 추적할지 설정합니다."
L["Options.BuffTracking.Override.Default"] = "기본값 (위의 모드 사용)"
L["Options.BuffTracking.Override.OutsideInstances"] = "던전 및 공격대 아님"
L["Options.BuffTracking.Override.OutsideInstances.Desc"] =
    "필드에서 사용하는 추적 모드입니다. 위에서 선택한 모드는 던전, 공격대, 시나리오, PvP에서 여전히 사용됩니다."
L["Options.BuffTracking.Override.Combat"] = "전투 중"
L["Options.BuffTracking.Override.Combat.Desc"] =
    "전투 중에 사용하는 추적 모드입니다. 예를 들면 '내 버프만'으로 범위를 좁히면 전투 중이 아닐땐 다른 직업의 버프 리마인더가 표시되지만 전투가 시작되면 사라집니다."
L["Options.BuffTracking.Override.Leveling"] = "레벨링"
L["Options.BuffTracking.Override.Leveling.Desc"] =
    "만렙이 아닐 때 사용하는 추적 모드입니다. 만렙이 되면 위에 선택한 모드가 사용됩니다."

-- ============================================================================
-- OPTIONS: PROFILES TAB
-- ============================================================================
L["Options.ActiveProfile"] = "활성 프로필"
L["Options.ActiveProfile.Desc"] =
    "저장된 설정 간에 전환합니다. 각 캐릭터마다 다른 프로필을 사용할 수 있습니다."
L["Options.SelectProfile"] = "프로필 선택"
L["Options.Profile"] = "프로필"
L["Options.CopyFrom"] = "다음에서 복사"
L["Options.Delete"] = "삭제"
L["Options.PerSpecProfiles"] = "전문화별 프로필"
L["Options.PerSpecProfiles.Desc"] = "전문화 변경 시 자동으로 프로필을 전환합니다."
L["Options.PerSpecProfiles.Enable"] = "전문화별 프로필 활성화"

-- ============================================================================
-- OPTIONS: IMPORT/EXPORT
-- ============================================================================
L["Options.ExportSettings"] = "설정 내보내기"
L["Options.ExportSettings.Desc"] = "아래 문자열을 복사해서 설정을 공유하세요."
L["Options.ImportSettings"] = "설정 가져오기"
L["Options.ImportSettings.DescPlain"] = "아래에 설정 문자열을 붙여넣으세요."
L["Options.ImportSettings.Overwrite"] = "활성 프로필을 덮어씁니다."
L["Options.Export"] = "내보내기"
L["Options.Import"] = "가져오기"
L["Options.ImportSuccess"] = "설정을 성공적으로 가져왔습니다!"
L["Options.FailedExport"] = "내보내기 실패"
L["Options.UnknownError"] = "알 수 없는 오류"

-- ============================================================================
-- OPTIONS: DIALOGS
-- ============================================================================
L["Dialog.Cancel"] = "취소"
L["Dialog.DeleteCustomBuff"] = '사용자 지정 버프 "%s"|1을;를; 삭제할까요?'
L["Dialog.DeleteLoadout"] = '구성 알림 "%s"|1을;를; 삭제할까요?'
L["Dialog.ResetProfile"] =
    "활성 프로필을 기본값으로 초기화할까요?\n\n현재 프로필의 모든 사용자 지정\n설정이 삭제되고 UI가 재시작됩니다."
L["Dialog.Reset"] = "초기화"
L["Dialog.ReloadPrompt"] =
    "설정을 성공적으로 가져왔습니다!\nUI를 재시작해서 변경 사항을 적용할까요?"
L["Dialog.Reload"] = "재시작"
L["Dialog.NewProfilePrompt"] = "새 프로필의 이름을 입력하세요:"
L["Dialog.Create"] = "생성"
L["Dialog.DiscordPrompt"] = "BuffReminders Discord에 참여하세요!\n아래 URL을 복사하세요 (Ctrl+C):"
L["Dialog.KofiPrompt"] =
    "BuffReminders의 후원을 지원해 주셔서 감사합니다!\n아래의 URL을 복사하세요 (Ctrl+C):"
L["Dialog.Close"] = "닫기"

-- ============================================================================
-- OPTIONS: TEST / LOCK
-- ============================================================================
L["Options.LockUnlock"] = "잠금 / 해제"
L["Options.LockUnlock.Desc"] =
    "잠금을 해제하면 버프 프레임 위치를 조정할 수 있는 앵커 핸들이 표시됩니다."
L["Options.TestAppearance"] = "아이콘 외형 테스트"
L["Options.TestAppearance.Desc"] =
    "가짜 값으로 선택한 버프를 표시해서 외형을 미리 볼 수 있습니다."
L["Options.Test"] = "테스트"
L["Options.StopTest"] = "테스트 중지"
L["Options.AnchorHint"] = "앵커를 클릭하면 앵커 지점이나 좌표값을 업데이트합니다."
L["Options.Lock"] = "잠금"
L["Options.Unlock"] = "잠금 해제"

-- ============================================================================
-- OPTIONS: CUSTOM BUFF DIALOG
-- ============================================================================
L["CustomBuff.Edit"] = "사용자 지정 버프 편집"
L["CustomBuff.EditShort"] = "편집"
L["CustomBuff.Add"] = "사용자 지정 버프 추가"
L["CustomBuff.AddButton"] = "+ 사용자 지정 버프 추가"
L["CustomBuff.SpellIDs"] = "주문 ID:"
L["CustomBuff.Lookup"] = "검색"
L["CustomBuff.AddSpellID"] = "+ 주문 ID 추가"
L["CustomBuff.Name"] = "이름:"
L["CustomBuff.Text"] = "텍스트:"
L["CustomBuff.LineBreakHint"] = "(\\n을 사용해서 줄바꿈)"
L["CustomBuff.Appearance"] = "외형"
L["CustomBuff.BuffTracking"] = "버프 추적"
L["CustomBuff.Requirements"] = "필요 조건"
L["CustomBuff.ShowIn"] = "표시 위치"
L["CustomBuff.ClickAction"] = "클릭 동작"

-- Custom buff mode toggles
L["CustomBuff.WhenActive"] = "있을 때"
L["CustomBuff.WhenMissing"] = "없을 때"
L["CustomBuff.OnlyIfSpellKnown"] = "주문을 배웠을 때만"

-- Custom buff class dropdown
L["Class.Any"] = "모두"
L["Class.DeathKnight"] = "죽음의 기사"
L["Class.DemonHunter"] = "악마사냥꾼"
L["Class.Druid"] = "드루이드"
L["Class.Evoker"] = "기원사"
L["Class.Hunter"] = "사냥꾼"
L["Class.Mage"] = "마법사"
L["Class.Monk"] = "수도사"
L["Class.Paladin"] = "성기사"
L["Class.Priest"] = "사제"
L["Class.Rogue"] = "도적"
L["Class.Shaman"] = "주술사"
L["Class.Warlock"] = "흑마법사"
L["Class.Warrior"] = "전사"

-- Custom buff fields
L["CustomBuff.Spec"] = "전문화:"
L["CustomBuff.Class"] = "직업:"
L["CustomBuff.RequireItem"] = "아이템 필요:"
L["CustomBuff.RequireItem.EquippedBags"] = "착용 중/소지품"
L["CustomBuff.RequireItem.Equipped"] = "착용 중"
L["CustomBuff.RequireItem.InBags"] = "소지품"
L["CustomBuff.RequireItem.Hint"] = "아이템 ID - 없으면 숨김"
L["CustomBuff.ItemCooldown"] = "쿨타임:"
L["CustomBuff.ItemCooldown.Any"] = "모두"
L["CustomBuff.ItemCooldown.OffCooldown"] = "쿨타임 아님"
L["CustomBuff.ItemCooldown.OnCooldown"] = "쿨타임 상태"

-- Bar glow options
L["CustomBuff.BarGlow.WhenGlowing"] = "반짝일 때 감지"
L["CustomBuff.BarGlow.WhenNotGlowing"] = "반짝이지 않을 때 감지"
L["CustomBuff.BarGlow.Disabled"] = "비활성화"
L["CustomBuff.BarGlow"] = "액션 바 반짝임:"
L["CustomBuff.BarGlow.Title"] = "액션 바 반짝임을 대신 사용"
L["CustomBuff.BarGlow.Desc"] =
    "버프 API가 제한되는 신화+/PvP/전투 중에는 대신 액션 바 주문 반짝임을 사용해서 감지합니다. 버프 유무만 추적하고 싶다면 비활성화하세요."

-- Ready check / level
L["CustomBuff.ReadyCheckOnly"] = "전투 준비 시에만"
L["CustomBuff.Level"] = "레벨:"
L["CustomBuff.Level.Any"] = "모든 레벨"
L["CustomBuff.Level.Max"] = "만렙만"
L["CustomBuff.Level.BelowMax"] = "만렙이 아닐 때"

-- Click action
L["CustomBuff.Action.None"] = "없음"
L["CustomBuff.Action.Spell"] = "주문"
L["CustomBuff.Action.Item"] = "아이템"
L["CustomBuff.Action.Macro"] = "매크로"
L["CustomBuff.Action.OnClick"] = "클릭 시:"
L["CustomBuff.Action.Title"] = "클릭 동작"
L["CustomBuff.Action.Desc"] =
    "이 버프 아이콘을 클릭했을 때의 동작을 설정합니다. 주문은 주문 시전, 아이템은 아이템 사용, 매크로는 매크로를 실행합니다."
L["CustomBuff.Action.MacroHint"] = "예: /사용 item:12345\n/사용 13"

-- Save/Cancel/Delete
L["CustomBuff.Save"] = "저장"
L["CustomBuff.ValidateError"] = "유효한 주문 ID가 1개 이상 필요합니다"

-- Custom buff status
L["CustomBuff.InvalidID"] = "잘못된 ID"
L["CustomBuff.NotFound"] = "찾을 수 없음"
L["CustomBuff.NotFoundRetry"] = "찾을 수 없음 (다시 시도)"
L["CustomBuff.Error"] = "오류:"

-- ============================================================================
-- OPTIONS: DISCORD
-- ============================================================================
L["Options.JoinDiscord"] = "Discord 참여"
L["Options.JoinDiscord.Title"] = "클릭하면 초대 링크 표시"
L["Options.JoinDiscord.Desc"] = "피드백, 기능 요청, 버그 신고를 하려면?\nDiscord에 참여하세요!"

-- ============================================================================
-- OPTIONS: KO-FI
-- ============================================================================
L["Options.SupportKofi"] = "Ko-fi에서 후원하기"
L["Options.SupportKofi.Title"] = "링크를 클릭"
L["Options.SupportKofi.Desc"] =
    "BuffReminders를 잘 쓰고 계시나요?\nKo-fi에서 개발 작업을 후원해 주세요!"

-- ============================================================================
-- OPTIONS: CUSTOM ANCHOR FRAMES
-- ============================================================================
L["Options.CustomAnchorFrames.Desc"] =
    "앵커 드롭다운에 전역 프레임 이름을 추가합니다. (예: MyAddon_PlayerFrame)\n게임 내에 존재하지 않는 프레임은 자동으로 건너뜁니다."
L["Options.Add"] = "추가"
L["Options.New"] = "새로 제작"
L["Options.ResetToDefaults"] = "기본값으로 초기화"

-- ============================================================================
-- OPTIONS: MISC
-- ============================================================================
L["Options.Off"] = "끄기"
L["Options.Always"] = "항상"
L["Options.ReadyCheck"] = "전투 준비"
L["Options.Min"] = "분"

-- ============================================================================
-- COMPONENTS (UI/Components.lua)
-- ============================================================================
-- Content filter tooltip
L["Content.ClickToFilter"] = "클릭하면 %s 난이도별로 필터 설정을 합니다"

-- Mover labels
L["Mover.AnchorGrowth"] = "앵커 · 방향 %s"
L["Mover.AnchorGrowthFrame"] = "앵커 · 방향 %s · > %s"

-- Pet labels
L["Pet.SpiritBeast"] = "야수 정령"

-- Appearance grid labels
L["Appearance.Width"] = "너비"
L["Appearance.Height"] = "높이"
L["Appearance.Zoom"] = "확대"
L["Appearance.Border"] = "테두리"
L["Appearance.Spacing"] = "간격"
L["Appearance.Alpha"] = "불투명도"
L["Appearance.Text"] = "텍스트"

-- Slider tooltip
L["Component.AdjustValue"] = "값 조정"
L["Component.AdjustValue.Desc"] = "클릭해서 입력하거나 마우스 휠을 사용하세요."
L["Component.AdjustValue.ClickHint"] = "숫자를 클릭하면 직접 값을 입력할 수 있습니다."

-- Direction labels
L["Direction.Left"] = "왼쪽"
L["Direction.Center"] = "가운데"
L["Direction.Right"] = "오른쪽"
L["Direction.Up"] = "위"
L["Direction.Down"] = "아래"
L["Direction.Label"] = "방향"

-- Content visibility
L["Content.ShowIn"] = "표시 조건:"

-- Content toggle definitions
L["Content.OpenWorld"] = "야외"
L["Content.Housing"] = "하우징"
L["Content.Scenarios"] = "시나리오 (구렁, 토르가스트 등)"
L["Content.Dungeons"] = "던전 (신화+ 포함)"
L["Content.Raids"] = "공격대"
L["Content.PvP"] = "PvP (투기장과 전장)"

-- Scenario difficulty
L["Content.Delves"] = "구렁"
L["Content.OtherScenarios"] = "기타 시나리오 (토르가스트 등)"

-- Dungeon difficulty
L["Content.NormalDungeons"] = "일반 던전"
L["Content.HeroicDungeons"] = "영웅 던전"
L["Content.MythicDungeons"] = "신화 던전"
L["Content.MythicPlus"] = "신화+ 쐐기돌"
L["Content.TimewalkingDungeons"] = "시간여행 던전"
L["Content.FollowerDungeons"] = "추종자 던전"

-- Raid difficulty
L["Content.LFR"] = "공격대 찾기"
L["Content.NormalRaids"] = "일반 공격대"
L["Content.HeroicRaids"] = "영웅 공격대"
L["Content.MythicRaids"] = "신화 공격대"

-- PvP types
L["Content.Arena"] = "투기장"
L["Content.Battlegrounds"] = "전장"
