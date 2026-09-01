# Secret Values - Findings & Handling

> **AI-maintained document.** This is kept up to date by an AI assistant as PTR patches,
> patch notes, and in-game verification of WoW's secret-value behavior are tracked. Entries
> are added, amended, and pruned across sessions - treat it as a living log, not a
> hand-authored spec. When updating by hand, keep the verified/patch-notes/unverified
> tagging and dates intact so provenance stays clear.

Single source of truth for how WoW's **secret value** system affects BuffReminders and how
to handle it correctly. Living document - prune or amend freely as behavior is verified.
Every claim here should say whether it's **verified in-game**, **from patch notes/docs**,
or **unverified/assumed**, with a date where relevant.

---

## 1. The mental model

Secret values are opaque Lua values returned by combat-related WoW APIs (12.0 Midnight+).
They implement Blizzard's "addon disarmament" philosophy: **addons may display combat
data but may not perform logic on it.**

A secret value is _not_ nil - it is a real, truthy value that carries a taint tag. When
your (tainted) addon code performs a forbidden operation on it, the operation **throws**;
it does not return nil or false.

The exact op set below was **verified in-game on the 12.1 PTR (2026-07-15)** with the
SecretProbe tool - it corrects the community reference, which was wrong about string ops.

**Tainted (addon) code CANNOT, on a secret value (confirmed to THROW):**

- Arithmetic (`+ - * / % ^`)
- Value comparison (`== ~= < > <= >=`) - _comparing the secret against another value_
- Using a secret **as a table key** (`t[secret] = v`)
- Structural ops - **`ipairs`, `#` (length)**
- **Boolean-test a secret BOOLEAN** - `if secretBool then`, `secretBool and/or ...`. Its
  truthiness _is_ the protected value, so branching on it would leak the secret. (This is
  type-specific: see the CAN list - a secret number/table is safe to `if` on.)

**Tainted code CAN (confirmed OK - do NOT over-guard these):**

- Store secrets in variables, pass them around
- **Branch on the truthiness of a secret NUMBER or TABLE**: `if secretNumber then`,
  `if secretTable then` - they're always truthy (non-nil, non-false), so the branch leaks
  nothing. **Not** true for a secret _boolean_ (see CANNOT). `secret ~= nil` / `== nil` is
  fine for any type (nil comparison, not value comparison).
- **String ops**: `tostring(secret)`, `"x" .. secret`, `string.format("%d", secret)`,
  `type(secret)` - all OK (the community doc was wrong here)
- Pass them to whitelisted native APIs (`StatusBar:SetValue`, `Curve:Evaluate`, ...)
- Call `issecretvalue(v)` on them (safe on any value, including nil) - and `Plain()` /
  `AuraField()` build on it, so reading a secret boolean _through_ them is always safe

> **A separate failure mode - THROWING CALLS.** Aura _enumeration_ APIs
> (`C_UnitAuras.GetAuraDataByIndex`, `GetAuraDataByAuraInstanceID`) do not return a secret
> in restricted contexts on 12.1 - **the call itself throws** (verified: combat, and M+ even
> out of combat). That is a call-error, not a secret-value op, so `issecretvalue` can't help
> (there's no return value to inspect) - `pcall` is the right guard. `GetUnitAuraBySpellID`
> does **not** throw; it returns nil / readable / secret and is read through `AuraField`.

When execution is **not** tainted (Blizzard/secure code), secret values behave as normal.

### The two escape hatches, and why only one applies here

Blizzard provides two distinct ways to cope with secrets. They solve different problems:

1. **Display primitives** - `C_CurveUtil` (`Curve`, `ColorCurve`), `C_DurationUtil`
   (`Duration`), `C_Secrets` (`IsLessThan`/`IsEqual`/`Select`), `UnitHealPredictionCalculator`.
   Every one of these **returns another secret value** and is meant to be piped straight
   into a Blizzard widget for rendering (health bars, cooldown swipes, gradients). You
   never get a plain value back.

2. **The aura whitelist** (`Data/AuraWhitelist.lua`) - Blizzard returns **plain**
   (non-secret) values for a fixed set of whitelisted aura spell IDs, even in restricted
   contexts. This is orthogonal to the display primitives above and is **the only
   mechanism that yields plain values the addon can do logic on.**

---

## 2. What this means for BuffReminders

**The display primitives (Curve/ColorCurve/Duration/C_Secrets) do not apply to this
addon**, and it's important to understand why, so nobody reaches for them. The addon's job
is _logic on plain values_, which is exactly what the secret system forbids:

- count how many of N benefiting group members lack a buff -> a plain **integer**
- decide whether an icon shows at all -> a plain **boolean** driving `:Show()`/`:Hide()`
- render the `"17/20"` overlay -> `string.format` on plain numbers

A secret StatusBar health value works for Blizzard's own frames because Blizzard renders
it. A secret buff count is useless here because BuffReminders draws its own frames and text
and must branch/count/format - none of which is legal on a secret. There is no API that
turns a secret aura into a countable integer or a branchable boolean.

**The addon's lifeline is therefore the aura whitelist, not the display helpers.**
Whitelisted spell IDs read back plain in restricted contexts; that is the sole reason group
buff counting works during combat/encounters/M+ today.

**The whitelist SURVIVES on 12.1 - verified on the PTR (2026-07-15).** The patch notes
("AuraData structs are now always fully secret") read like the hatch was being removed. It
is not, for the path that matters: `GetUnitAuraBySpellID` for a **whitelisted** spell
returns a **plain, readable struct (spellId + expirationTime)** in combat _and_ in M+,
exactly like live; non-whitelisted spells return `nil`. So the addon's core
restricted-context counting is safe on 12.1.

What 12.1 _does_ change is **aura enumeration**: `GetAuraDataByIndex` now **throws** in
restricted contexts (it used to return data). That only affects the three icon/source scans
that can't use a targeted query (see #3.5); they're guarded with `AuraByIndex` and degrade
to the 3s ticker. No strategy-level rework is needed.

### Restricted contexts

Four contexts restrict the aura API identically (see also CLAUDE.md -> _Aura API
Restrictions_): **combat lockdown**, **boss encounters** (ENCOUNTER_START->END),
**M+ keystones** (always, even out of combat), and **PvP instances** (always, prep phase
included - verified live, see #3.11). `BuffState.IsRestricted()` is the single source of
truth. State.lua owns one `inCombat` flag for the first two, and adds the difficulty key
and content type as separate terms for the other two. The encounter-start gap
(ENCOUNTER_START fires before `InCombatLockdown()` flips) is why `InCombatLockdown()` is
never called in the refresh path.

---

## 3. Verified behavior (dated findings)

### 3.1 Secret returns from unit-identity / stat APIs - _verified, 12.0.5_

Unit-identity APIs (`UnitCreatureID`, `UnitCreatureFamily`, `UnitIsUnit`, stat APIs while
auras are secret, etc.) return values tagged secret when unit identity isn't publicly
resolved. Comparing one from addon code throws:

```
attempt to compare local 'X' (a secret number value, while execution tainted by 'BuffReminders')
```

- **`pcall` around the API call does NOT catch this** - the error fires on the _operator_,
  not the call. The guard must wrap the value _before_ the compare.
- Debug locals render secret values as `<no value>` / blank - a useful triage fingerprint.
- Confirmed offender historically: the wrong-pet check comparing
  `UnitCreatureFamily("pet") ~= 29`. Pet identity is nominally on the allow-list, but
  transient pets (Wild Imps, Dreadstalkers), mind-control, and instance transitions can
  still produce secret returns.
- **Handling:** route unit-identity returns through `BR.Secret.Plain` (#4.1) before any
  compare - `local fam = Plain(UnitCreatureFamily("pet")); if fam and fam ~= 29 then`. The
  known sites are converted: `BuffState.IsWrongDemonPet` and the `UnitIsUnit(..., "player")`
  checks in the targeted-buff path (`Plain(UnitIsUnit(...))` reads a secret as falsy, which
  routes to the explicit player-cast scan - the correct fallback).

### 3.2 UNIT_AURA payload follows the aura whitelist - _verified in-game 2026-07-12_

Tested in follower-dungeon combat **and** a battleground (both restriction paths - combat
lockdown and restricted-while-out-of-combat):

- `UNIT_AURA` `updateInfo.addedAuras` entries for **whitelisted** spells have **readable**
  `spellId` and `auraInstanceID`; non-whitelisted auras come back secret (guarded reads
  fail). Confirmed spells: Battle Shout 6673, Mark of the Wild 1126, Renewing Mist 119611.
- This scoped `BuffState.GroupAuraUpdateMatters`' _per-entry_ handling: a secret entry
  ("secret spellId ⇒ not whitelisted ⇒ not displayable here") is safe to skip.
- **This finding was about individual _entries_. It did NOT establish that the list
  _container_ stays readable - and 3.4 shows it does not.** The per-entry guarantee still
  appears to hold; the container-level guarantee never existed and must not be assumed.

### 3.3 Payload container secrecy - _patch notes, 12.1.0 PTR 4 (partly SUPERSEDED by 3.6)_

12.1.0 PTR notes state: _"The UNIT_AURA event now delivers a fully secret payload while
auras are secret. AuraData structs are now always fully secret."_ Read literally, this
sounded like _everything_ (targeted queries included) goes secret in restricted contexts.
**PTR testing (3.6) disproved the literal reading for `GetUnitAuraBySpellID`** - whitelisted
targeted queries still return plain structs. The "fully secret" wording applies to the
_enumeration_ path and the event payload container, not to whitelisted targeted lookups.

### 3.4 Whole-container secrecy is happening on LIVE - _confirmed live, v6.2.2-alpha2_

A user crash on live (not PTR) proved a **UNIT_AURA list container itself can be secret**,
independent of the 12.1.0 PTR notes:

```
bad argument #1 to 'ipairs' (table expected, got secret)   -- UpdateEatingState, player payload
```

`updateInfo.addedAuras` was truthy (so `if updateInfo.addedAuras then` passed) but was a
secret value, so `ipairs`/`#`/indexing on it threw. This is the concrete failure mode
behind the container-secrecy concern in 3.3 - and it is **already live**, at least for the
**player** `UNIT_AURA` payload.

**Scope still to verify:** this was observed on the _player_ payload. Whether _group-unit_
payload containers are equally affected (which would change how often
`GroupAuraUpdateMatters` fails open) has not been separately confirmed in-game since this
crash. The 2026-07-12 group-payload verification (3.2) predates it.

**Handling:** never gate a list container on truthiness alone - route it through
`AuraList` (secret container -> empty). Both callers now fail **closed**: `UpdateEatingState`
skips (re-syncs on combat end) and `GroupAuraUpdateMatters` skips (3s-ticker backstop). See
#3.6 (group-container secrecy confirmed on PTR) and #4.4 for why fail-closed won.

### 3.5 Frame-API overhaul does not affect the reminder pipeline - _patch notes, 12.1.0 PTR 4/6_

> Scope: this section is about the **existing** reminder display, which the rework leaves
> untouched. The same APIs _do_ enable a new present-based tracker - see #3.9.

The AuraContainer/AuraGroup/AuraSlot rework, `AddAuraFrame` removal,
`SecureAuraHeaderTemplate` removal, and `AddPrivateAuraAppliedSound` -> `AddAuraAppliedSound`
rename **do not touch BuffReminders** (grep-confirmed zero usage). The addon draws its own
icon frames and uses no secure aura headers or private-aura sounds.

PTR 6 continues to build that surface out - `GetAuraGroupFrame`, `ApplicationBar`,
`SetAuraGroupFilterString`, `SetAuraBorder` color curves/maps, aura-group `layoutIndex`,
`AddAuraAppliedSound` -> `AddAuraSound` (+ `RemoveAuraSound`), the reparent ban,
temp-weapon-enchant click-to-cancel, `HasAccessConstraints` / `CanBeAccessedInContext`,
`IsRolesetFiltered`, `C_Roleset.GetActiveAllowedRolesets` / `GetActiveBlockedRolesets`, the
`alwaysBlocked` roleset, and boolean-filter negation (`isStealable = false`). **All still
zero-usage here.** Two are worth knowing about anyway:

- _"Auras flagged as non-secret can now be filtered using `excludeSpellIDs`/`includeSpellIDs`
  without restrictions on any unit."_ This is the container path Blizzard is steering aura
  addons toward - and it is why the never-secret list is shrinking (#3.7). It renders
  Blizzard-side, so it still yields no countable integer; §2 stands.
- `HasAccessConstraints` / `CanBeAccessedInContext` are ask-before-you-touch predicates for
  _script objects_, not values. They don't replace `issecretvalue` for our data reads.

One PTR 6 fix does touch our model: _"Fixed a bug where calling some APIs (like
`FormatNumber`) with secrets would cause objects to be marked as secret incorrectly (and
result in Lua Errors)."_ So the "string ops on secrets are safe" finding in #1 was
build-dependent for _some_ formatting APIs - the taint could spread to the receiving object.
We only `string.format` plain counts, so no live exposure, but don't generalize "any
formatting API accepts a secret" from #1.

### 3.6 12.1 PTR behavior - _verified in-game, 12.1.0 PTR, 2026-07-15_

Tested with SecretProbe out of combat, in combat (open world), and in an M+ key
(difficultyID 8, restricted even out of combat). Definitive:

- **Targeted query survives.** `GetUnitAuraBySpellID("player", 6673)` (Battle Shout,
  whitelisted) returned a **plain struct with readable `spellId` and `expirationTime` in
  combat AND M+**. Non-whitelisted spells returned `nil`. The whitelist is intact on 12.1
  for the targeted path - same behavior as live. The core detection is safe.
- **Enumeration throws.** `GetAuraDataByIndex` (and by extension
  `GetAuraDataByAuraInstanceID`) **raises an error** at index 1 in combat and in M+ (it
  returned data fine out of combat). This is a _call-error_, not a secret return. Handled by
  `BR.Secret.AuraByIndex` / `AuraByInstanceID` (pcall -> nil-on-throw); the three
  icon/source scans degrade to the 3s ticker in restricted contexts.
- **Operation legality is TYPE-SPECIFIC** (see #1): `~= nil` / `tostring` / `string.format`
  / `type` are OK on any secret; value comparison, arithmetic, `#`, `ipairs`, and
  secret-as-table-key throw. **Boolean test (`if x`) depends on the secret's type:** a secret
  _number/table_ is always-truthy so `if` on it is fine (confirms group-B `if auraData then`
  is safe), but a secret _boolean_ THROWS - branching leaks its value. Discovered the hard
  way: `if updateInfo.isFullUpdate` crashed on a secret-boolean field (fixed with `Plain`).
- **Container secrecy in combat - CONFIRMED (follower dungeon, `/sprobe watch`).** In
  combat, `UNIT_AURA` `addedAuras` came back `SECRET container` for **both `player` and
  every `party*` unit**. Payload containers go secret in restricted contexts for group units
  too, so `GroupAuraUpdateMatters` hits its secret-container path on ~every group payload in
  combat - which is why it fails **closed** (#4.4).
- **Group-unit targeted queries WORK - CONFIRMED (section C, follower-dungeon combat).**
  `GetUnitAuraBySpellID(party1..4, 6673)` all returned `plain (callable + readable)`, and
  multiple whitelisted spells on the player (6673, 1126, 1459) read plain while
  non-whitelisted returned `nil`. **The group buff-counting path is fully intact on 12.1.**
  Nothing left unverified.

### 3.7 The never-secret list SHRANK - healer buffs/HoTs removed - _patch notes, 12.1.0 PTR 6_

PTR 6 removes every healer buff and HoT from the "never secret" list, with the stated reason
that custom aura containers can now filter and position helpful auras on raid members
(#3.5). Removed set = **exactly** the `HEALER BUFFS AND HOTs` block in
`Data/AuraWhitelist.lua`: Preservation/Augmentation Evoker (Dream Breath, Dream Flight, Echo,
Reversion, Echo Reversion, Lifebind, Echo Dream Breath, Blistering Scales, Ebon Might,
Prescience, Inferno's Blessing, Symbiotic Bloom, Shifting Sands), Resto Druid (Rejuv,
Regrowth, Lifebloom, Wild Growth, Germination, Symbiotic Blooms 439530), Disc Priest (PW:S,
Atonement, Void Shield + the two Unfolding Vision variants 1300008/1300009), Holy Priest
(Renew, Prayer of Mending, Echo of Light), Mistweaver (Soothing Mist, Renewing Mist,
Enveloping Mist, Aspect of Harmony, Coalescence 1292922), Resto Shaman (Earth Shield 974 /
383648, Riptide, Earthliving Weapon 382024, Ancestral Vigor, Hydrobubble), Holy Paladin
(Beacon of Light, Eternal Flame, Beacon of Faith, Beacon of the Savior, Beacon of Virtue,
Dawnlight).

**The raid-buff block is untouched** - Mark of the Wild, Arcane Intellect, Battle Shout, PW:
Fortitude, Source of Magic, Skyfury, Symbiotic Relationship, Blessing of the Bronze, poisons,
shaman imbues all stay whitelisted. So group _coverage counting_, the addon's core, is
unaffected.

**Impact is on five user-facing buffs** whose queried IDs sit in the removed block. With the
IDs still in our whitelist, `IsAuraTrackable` says "trackable", the restricted-context query
comes back `nil`, and the addon reports a **false "missing"** - the exact failure the
whitelist exists to prevent:

| Buff (key)          | Queried ID                | Restricted-context behavior once removed          |
| ------------------- | ------------------------- | ------------------------------------------------- |
| `beaconOfLight`     | 53563                     | `glowDetectable` fallback (spell-activation glow) |
| `beaconOfFaith`     | 156910                    | `glowDetectable` fallback                         |
| `blisteringScales`  | 360827                    | hidden (no fallback)                              |
| `earthShieldOthers` | 974                       | hidden (no fallback)                              |
| `earthShieldSelfEO` | 383648 (`buffIdOverride`) | hidden (no fallback)                              |

`waterLightningShieldEO` / `shamanShieldBasic` already fail `ComputeAuraTrackable` (192106 /
52127 were never whitelisted), so they are unchanged.

**Handled (done):** the healer block is deleted from `AuraWhitelist.lua`, so
`IsAuraTrackable` returns false for those buffs and they take the existing
hide-in-restricted-contexts path. No build gate - this branch targets 12.1 and ships on patch
day, so there is no window where both whitelists need to be live. A file comment records the
five affected buffs so nobody re-adds the IDs.

### 3.8 PTR 7 preview: unit-identity APIs go secret - _patch notes, 12.1.0 PTR 7 (preview)_

Announced, not yet on a PTR build: a batch of Unit APIs will **return secret values when the
unit's identity is secret**, to stop addons combining them to compare secret units. This is
#3.1 generalized from creature/`UnitIsUnit` to the whole identity surface.

Announced list: `UnitClass`, `UnitClassBase`, `UnitIsOwnerOrControllerOfUnit`, `UnitSex`,
`UnitSexBase`, `UnitPhaseReason`, `UnitGroupRolesAssigned`, `UnitGroupRolesAssignedEnum`,
`UnitIsRaidOfficer`, `UnitInRaid`, `UnitIsPVP`, `UnitRace`, `UnitIsGroupLeader`,
`UnitIsGroupAssistant`, `UnitLeadsAnyGroup`, `UnitGetAvailableRoles`,
`GetInspectSpecialization`. Plus: `GetGuildInfo` stops accepting compound unit tokens, and
`UnitIsCharmed` / `UnitIsPossessed` go secret while auras are secret.

Not used anywhere in the addon: `UnitSex`, `UnitIsRaidOfficer`, `UnitIsPVP`,
`UnitIsGroupLeader`/`Assistant`, `UnitLeadsAnyGroup`, `UnitGetAvailableRoles`,
`GetInspectSpecialization` (we get ally specs from LibSpecialization addon comms - **plain
values, immune to this whole change**), `GetGuildInfo`, `UnitIsCharmed`/`UnitIsPossessed`,
`UnitIsOwnerOrControllerOfUnit`. `UnitClass("player")` / `UnitRace("player")` /
`UnitClassBase("player")` (Bootstrap, Loadouts, Buffs, SecureButtons, Display, AceDB,
LibDualSpec) read the _local player_, whose identity is never secret - assumed safe, worth a
sanity check on the first PTR 7 build.

Four call sites read these on **group units** and would break:

1. **`State.lua` `BuildValidUnitCache`** - `local _, class = UnitClass(unit)` feeds
   `AcquireUnitEntry`, then `beneficiaries[class]`, `perClass[class]`, and
   `classMaxLevels[class]`. **Secret-as-table-key throws** (#1) -> hard error every refresh in
   combat. Needs `Plain`.
2. **`State.lua` `IsPlayerBuffActive`** - `UnitGroupRolesAssigned(data.unit) == role`. Secret
   string **value comparison throws**. Hit by role-filtered targeted buffs (Source of Magic,
   `beneficiaryRole = "HEALER"`). Needs `Plain`.
3. **`Data/Buffs.lua` Soulstone `clickMacro`** - the first-living-healer scan does
   `UnitGroupRolesAssigned(unitId) == "HEALER"`. This runs in the secure button's **PreClick
   at click time**, i.e. in combat -> throws inside a secure handler. Needs `Plain`.
4. **`State.lua` `IsUnitPhased`** - `UnitPhaseReason(unit) ~= nil`. `~= nil` is a legal op, so
   no throw; but a secret return is non-nil, so **every group member reads as phased** and
   phased+missing members are dropped from the counts -> reminders silently stop. Route
   through `Plain` and fail **open** (secret -> not phased): false-phased suppresses
   reminders, and phasing mid-group is rare.
   `State.lua` `HasHealerInGroup` is a fifth, currently unreachable in restricted contexts
   (its only caller returns on an `isRestricted` guard) - guard it anyway, it's one call.

**`Plain` alone stops the crashes but degrades accuracy**, so it isn't the whole fix. With a
nil class, `UnitBenefitsFromBuff` returns `beneficiaries[nil] -> false`, so a class-filtered
member is excluded from _both_ `missing` and `total`; raid entries only show when
`missing > 0`, so class-filtered raid buffs would collapse to player-only counts in combat
("0/1", or hidden). Same shape for roles: `IsPlayerBuffActive` returns "active" when no
beneficiary with the role is found, so Source of Magic would silently stop reminding.

**Handled (done):**

- All four sites read through `Plain`, plus `HasHealerInGroup` defensively.
- **`allyClassCache` / `allyRoleCache`** (State.lua, beside `allySpecCache`): name -> last
  value seen _plain_. `BuildValidUnitCache` writes the class cache on every refresh where the
  read comes back plain and reads from it when it doesn't; `GetUnitRole` does the same lazily,
  so role is only queried where a buff actually filters on it. No new event wiring - the
  refresh path already runs unrestricted often enough to prime both - and both are pruned
  alongside `allySpecCache` on `GROUP_ROSTER_UPDATE`. Worst case is a member who joins
  mid-combat and has no cached class until the restriction lifts.
- **Spec beats class anyway.** `UnitBenefitsFromBuff` prefers `SpecBeneficiaries[specId]` via
  `allySpecCache[name]` (LibSpecialization comms, plain). Both filters that exist
  (`intellect`, `attackPower`) have spec tables, so any ally broadcasting a spec never needs
  class. That's also why a static specId -> class map was **not** added: the only consumers
  left for a derived class are per-class spell variants (which fall back to the full ID list -
  Blessing of the Bronze still detects, just queries all 13) and `classMaxLevels`, which the
  cache already covers.

`RAID_CLASS_COLORS[class]` in `SecureButtons`' last-target tooltip takes its class from
`TargetMemory`, which is fed from these same entries - so the `Plain` at the source fixes that
secret-as-table-key throw too, and nothing downstream needs its own guard.

### 3.9 AuraContainers display auras we cannot read - _verified in-game, 12.1.0 PTR_

**An `AuraSlot` renders a buff in combat that the addon has no ability to read.** Verified by
casting Power Infusion (10060, not whitelisted) on self: the icon **and its duration
countdown** both appeared while in combat. This is the one capability the secret system does
_not_ take away, because Blizzard does the rendering and the addon never touches the aura.

It does **not** rescue the reminder pipeline (§2 stands - still no countable integer, still no
branchable boolean). What it enables is a **separate, present-based display**: "show me PI /
Bloodlust / an external buff while it's up", which today is impossible in restricted contexts.

Mechanics confirmed by reading `Blizzard_AuraContainer/` source at tag `12.1.0`:

- **Legality.** `ValidateCandidateFilters`: _"Spell ID matching is only permitted for helpful
  buffs on assistable units, and harmful buffs on non-assistable units."_ The player is
  assistable, so `"HELPFUL"` + `includeSpellIDs` on `"player"` is allowed. A **debuff on
  yourself is not** - which is why this can never become a debuff-reminder path.
- **Assistability is re-checked at RUNTIME, and the check fails OPEN.** The rule above is not
  only a declaration-time validation.
  `AuraContainerUtil.CanApplyIdentityCandidateFilters` + `DoesAuraPassCandidateFilters` apply
  `includeSpellIDs` to a helpful aura **only while `UnitCanAssist("player", unit)` holds**. When
  that fails, the spell-ID filter is **skipped entirely** and the aura passes on its filter
  string alone - so a group asking for one spell renders **every buff on the player**, wearing
  the tracked buffs' styling.

  Assistability drops in three states, none of them obvious:

  | State | Window |
  | --- | --- |
  | Vehicle ride | The whole ride, starting at the **boarding** transition |
  | Cinematic (in-world cutscenes included) | Start to end |
  | Faction flip (Pandaren choice) | The transition |

  **`UNIT_FACTION` on the player is the only edge a cinematic fires.** `UNIT_FLAGS` does not.
  `CINEMATIC_STOP` / `STOP_MOVIE` cover the skip paths only, whose faction restore can order
  ahead of the edge. So `UNIT_FACTION` is mandatory, and the movie events are a safety net -
  not the reverse.

  Two traps in the recovery:

  1. **Membership is cached per aura instance**, and `UNIT_AURA` re-parses only what changed. So
     the degraded parse **outlives** the state that caused it, with no aura edge guaranteed to
     follow. Something must force a full rebuild.
  2. **A rebuild taken while still degraded re-bakes the wrong set.** The restore lands a
     measurable moment _after_ the event, so a probe read on the event still says degraded.
     Nothing announces the restore, so recovery needs a **settle watch**: probe on a short
     ticker, act on the first clean read, give up after a couple of seconds and leave the
     display hidden for the next edge to re-arm.

  The handling is: **suppress, don't render**. Hide the display for the degraded window rather
  than show the full buff set, then rebuild once assistability is verified back. `UnitCanAssist`
  reads the local player, whose identity is never secret, but guard it anyway - and fail **open**
  here (#4.4), against the addon's usual direction: this display exists to run in combat, so an
  unreadable probe must not blank it for a whole fight. The vehicle branch of the probe uses
  `UnitUsingVehicle`, not `UnitInVehicle` - it also reads true across the boarding and exiting
  transitions, where the filters are already degraded.
- **A live group does not re-parse present auras when its filters change.**
  `SetAuraGroupCandidateFilters` on an existing group stores the payload, but the auras already
  on the unit keep the membership they were parsed with (same per-instance cache as above). So
  ticking a buff that is **already active** shows nothing until that aura is reapplied.
  `AuraContainerPrivateMixin:OnShow_Intrinsic` calls `UpdateAllAuras`, so wrapping the whole
  reconfigure in a container `Hide()` / `Show()` pair forces the reparse - and costs nothing,
  because the container is hidden only for the duration of the config writes. Do this on **every**
  reconfigure, not only on filter edits.
- **Empty slots hide themselves.** `CustomAuraButtonPrivateMixin:ApplyVisibility` is
  `self:SetShown(secretwrap(auraData ~= nil))`. No occlusion trick needed, and the shown state
  is secret-wrapped so it can't be read back.
- **`initializeFrame` is the creation window, and styling does NOT stay open** (confirmed
  in-game). The frame provider calls it via
  `securecallfunction(initializeFrame, auraFrame:GetObjectTable())` and only then applies the
  `DenyTaintedAccessWhenAurasAreSecret` access restriction. Crucially, **that restriction reaches
  our own regions, not just the button**: restyling a texture we created via
  `button:CreateTexture()` fails in combat with

  ```
  calling 'ClearAllPoints' on bad self (Attempt to access forbidden object from code
  tainted by an AddOn)
  ```

  The texture _itself_ is a forbidden object. **The boundary is the button's whole subtree**, and
  there is no host-frame escape hatch - all four probe levels were denied in combat:

  | Probe (in combat)                       | Result |
  | --------------------------------------- | ------ |
  | recolor a texture **on** the button     | DENY   |
  | reanchor a texture **on** the button    | DENY   |
  | resize a child **Frame** of the button  | DENY   |
  | recolor a texture on that child frame   | DENY   |

  So decoration must be built in the creation window, and any live restyle must **tolerate
  denial**: attempt it, catch the failure, queue it, and retry when the restriction lifts
  (`PLAYER_REGEN_ENABLED`, `ENCOUNTER_END`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`).
  Never assume a style application landed.
- **Corollary: dynamic chrome belongs OUTSIDE the button subtree.** Anything we animate or
  toggle at runtime - glow being the obvious one - cannot live on the button or its children,
  because starting/stopping it in combat would be denied. Put it on a **sibling frame we own**
  (e.g. the container's plain parent). That is viable precisely because we anchor the slot
  ourselves and take size from config, so a sibling overlay can track the button without ever
  reading its geometry. Keep the button subtree limited to what Blizzard drives: `SetIcon`,
  `SetDurationText`, and static decoration set once at creation.
- **Skinning is available, and our existing icon treatment transfers** (confirmed in-game).
  Create regions/child frames in the creation window and style those. Verified: a border texture
  at `BACKGROUND` anchored with a **negative inset** - `SetPoint("TOPLEFT", -size, size)`, i.e.
  protruding **past** the button's bounds, exactly as `UpdateIconStyling` does it - renders
  correctly. So regions must be **children of the button**, but they are _not_ confined to its
  bounds; the fontstring anchored below the button's bottom edge renders for the same reason. No
  restructuring of our border math is needed. Per-button state still belongs in an **external
  weak-keyed table**, never written onto the button itself.
- **`button:SetSize` is denied on the same terms**, and an unsized button renders nothing - so
  sizing has to land in the creation window or ride the same deferred-retry path.
- **Our icon styling survives the per-aura update.** `AuraContainerUtil.SetIconTextureForAura`
  only calls `texture:SetTexture(secretwrap(icon))` - it never touches texcoords, vertex color,
  desaturation, size, or anchors. So `UpdateIconStyling`'s zoom + aspect-ratio crop
  (`SetTexCoord`) applies once and holds while Blizzard swaps the texture file underneath.
- **Duration text is rendered, never read** (confirmed in-game). `SetDurationText` stamps
  `SecretAspect.Text/Alpha/VertexColor` onto the fontstring we pass in. Blizzard writes it and
  counts it down; we must never read it back. So a tracker gets a live timer **for free**, on a
  buff whose remaining duration we could not otherwise obtain in a restricted context.
- **`AddAuraSlot` returns the button**, and slots are exempt from the container's flow layout,
  so we anchor them ourselves. Anchor the container to a plain parent frame - a frame anchored
  _to_ a container inherits its layout restrictions.
- **Container-level flow layout is public and live-settable**:
  `SetFlowLayoutGrowthDirection(growthH, growthV)`,
  `SetFlowLayoutAnchorPoint`, `SetFlowLayoutAxis`, `SetFlowLayoutMaximumLineSize`,
  `SetFlowLayoutPadding` - 68914+ names; older builds spell them `SetAuraLayout*`, so resolve
  per call with the old name as fallback. Direction values are `AnchorUtil.FlowDirection`
  members (Left=-1, Right=1, Up=1, Down=-1), **not strings**, and there is no centered growth.
  Two traps: (1) the flow layout places buttons from its INTERNAL anchor point (default
  `TOPLEFT`), independent of the container's own anchor - derive ONE corner from the direction
  and feed it to both the container `SetPoint` and `SetFlowLayoutAnchorPoint`, or the first
  icon lands on the wrong side. (2) a group's `elementWidth`/`elementHeight` in
  `SetAuraGroupLayout` feed the flow math only and **never resize the button** - the visible
  size is `button:SetSize` in the creation window (or the deferred-retry path), and the two
  must agree.

These findings are implemented in `Display/AuraTracker.lua` (the throwaway `/brpi` harness that
produced them has been removed). That module is the reference for the shape: one AuraGroup whose
filters get reconfigured rather than rebuilt, styling applied in `initializeFrame`, every
button-touching call `pcall`ed with a lift watcher to retry what a restricted context denied.

**Masque cannot skin an AuraButton - confirmed in-game, and not for the reason expected.**
`Group:AddButton` fails with:

```
Masque/Core/Core.lua:119: attempt to perform arithmetic on a secret number value
(execution tainted by 'Masque')
```

This is **not** an access-restriction denial - it is #3.1's failure mode. **An AuraButton's
dimensions read back as secret numbers**, and Masque does arithmetic on them while sizing a
skin. Two consequences:

- **Not fixable from our side.** Deferring, or calling `AddButton` inside the creation window,
  changes nothing: the read returns a secret regardless of when it happens. Masque would have to
  guard its own arithmetic. A tracked-buff display must therefore skin itself - which costs
  nothing, since the icon treatment transfers (above).
- **Never read geometry off an AuraButton.** Any `GetWidth`/`GetHeight`/`GetSize` on one feeds a
  secret into arithmetic or a comparison and throws. This directly implicates `UI/Glow.lua`,
  which gates on `host:GetWidth() < 1`; a glow for a tracked buff must attach to a plain host
  frame we own, never to the button. Size must come from **config**, as `UpdateIconStyling`
  already does (`catSettings.iconSize`, never a live read).

**Implied shape for a tracker:** decoration created in the window as child frames, per-button
state in an external weak-keyed table, and a restyle path that tolerates denial - queue the
button-level calls that failed and retry them when the restriction lifts, rather than assuming
a style application always lands.

**Restriction detection can be measured, not derived.** Two probes answer it directly:
`C_Secrets.ShouldAurasBeSecret()`, and `pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1,
"HELPFUL")`, which throws in restricted contexts (#3.6). #3.11 ran both live. Each one agrees
with `BuffState.IsRestricted()`, so the derived model is correct and the probes are available
as a replacement.

### 3.10 Widget getters return secrets - `IsVisible()` included - _confirmed live, v6.4_

A sweep over every frame in the game (`EnumerateFrames`, for the anchor picker) threw on the
first aura-owned frame it reached:

```
attempt to perform boolean test on a secret boolean value (execution tainted by 'BuffReminders')
frame = Frame <AuraKit.lua:928>
(*temporary) = <secret boolean>
```

The call was `frame:IsVisible()`, inside `if ... and frame:IsVisible() and ...`. So the secret
tag reaches **widget getters**, not only the aura and unit-identity APIs of #3.1-#3.8:

- `Frame:IsVisible()` returns a **secret boolean** for a frame that an aura owns. The call
  itself is fine; the `and` that tests the result is what throws.
- The same applies to geometry (`GetLeft`, `GetWidth`, `GetEffectiveScale`, ...), which #3.9
  already found on aura buttons. A sweep hits those frames without asking for them.

**Rule:** every widget read on a frame the addon does not own must go through `Plain()`, and
must branch on `== true` / `== false` rather than on truthiness. An unknown answer is a third
state:

```lua
local function FrameVisibility(frame)          -- true, false, or nil when secret
    if frame.IsVisible == nil then return nil end
    return Plain(frame:IsVisible())
end
```

Skip a frame whose state reads back secret. It cannot be measured, so it cannot be an anchor,
and reporting it as hidden would be a guess. `IsForbidden()` gets the same treatment, with
unknown counted as forbidden - a frame the sweep cannot ask about is one it must not touch.

This is the first case where the secret system reached an API with **no aura in its
signature**. Treat any getter on a frame of unknown origin as capable of returning a secret.

### 3.11 PvP prep phase is restricted, and `C_Secrets` is real - _confirmed live, 2026-09-01_

A user reported that shaman shield reminders stay hidden in the arena prep room, before the
gates open, while Skyfury shows. The report is correct behavior. Two samples from a temporary
`/br probe` command settle both open questions.

Open world, out of combat:

```
zone: none | combat: false
IsRestricted() = false
enumerate player: OK spellId=72286
C_Secrets.ShouldAurasBeSecret = false
72286 Invincible | read: FOUND | -- | shouldBeSecret: false
```

Arena prep phase, out of combat, before the gates open:

```
zone: arena | combat: false
IsRestricted() = true
enumerate player: THREW
C_Secrets.ShouldAurasBeSecret = true
C_Secrets.ShouldUnitIdentityBeSecret = false
```

Four conclusions:

- **A PvP instance restricts auras for its whole duration, prep phase included.** Combat is
  not necessary. The blanket PvP term in `IsRestricted()` is correct, and a prep-phase
  exemption is wrong. This closes the PvP question that #3.9 raised.
- **`C_Secrets` exists on live and its answers match the derived model.**
  `ShouldAurasBeSecret()` returned `false` in the open world and `true` in the arena, exactly
  as `IsRestricted()` did. It can replace the whole derivation.
- **`ShouldSpellAuraBeSecret(spellID)` returns real booleans**, not `nil`. It can replace
  the hand-maintained `Data/AuraWhitelist.lua`. One measurement is still missing: its answer
  for a non-whitelisted spell inside a restricted context.
- **Unit identity stays plain while auras are secret.** `ShouldUnitIdentityBeSecret("player")`
  returned `false` in the arena prep phase. The identity guards of #3.8 can ask instead of
  assume, which matters for the `UnitIsUnit(sourceUnit, "player")` reads that now fail closed.

The reminder that a whitelisted buff stays readable holds: Skyfury (462854) shows in the prep
room, and the shields (974, 192106, 52127, 383648) do not. Silence there is the correct
result, because a non-whitelisted read cannot tell "not buffed" from "cannot see".

---

## 4. How to handle secrets correctly

### 4.1 Read through the boundary helpers, don't hand-roll pcalls

`pcall` is the **wrong tool** for secret-guarding: it sets up a protected frame every
call and _throws + unwinds_ when the value is secret (exactly the common case in restricted
contexts), it swallows unrelated bugs, and it guards a _body_ rather than the _operation_ -
which is how the original `UpdateEatingState` crash happened (the `pcall` was on the
per-entry read; the throwing `ipairs` on the container sat outside it).

`issecretvalue()` inverts all three - check-then-branch, no throw, precise. `Core.lua`
centralizes it into a small **secret-safe read layer** exposed as `BR.Secret` (each file
aliases the helpers to file-scope locals). Read combat data through these and downstream
code stays plain Lua:

```lua
local function Plain(v)                       -- v, or nil if secret
    if issecretvalue(v) then return nil end
    return v
end

local EMPTY_AURA_LIST = {}
local function AuraList(container)            -- real iterable, or empty if the container is secret
    if container == nil or issecretvalue(container) then return EMPTY_AURA_LIST end
    return container
end

local function AuraField(aura, key)          -- field value, or nil if the entry OR field is secret
    if aura == nil or issecretvalue(aura) then return nil end
    return Plain(aura[key])
end
```

Payload loops and aura reads then carry no guards of their own:

```lua
for _, aura in ipairs(AuraList(updateInfo.addedAuras)) do
    if AuraField(aura, "icon") == EATING_AURA_ICON then     -- nil == icon is a safe compare
        eatingAuraInstanceID = AuraField(aura, "auraInstanceID")
        break
    end
end

local exp = AuraField(auraData, "expirationTime")
if exp and exp > 0 then remaining = exp - GetTime() end     -- exp is guaranteed plain here
```

Keep the helpers as module-level functions (no per-aura closure allocation) and return
scalars, not per-aura snapshot tables, so the hot group-scan loop stays allocation-free.

**Reserve raw `pcall` for calls that can genuinely error for non-secret reasons.** That's a
real category, distinct from secret-guarding: on 12.1 the enumeration APIs
(`GetAuraDataByIndex`, `GetAuraDataByAuraInstanceID`) **throw** in restricted contexts (#3.6).
`issecretvalue` can't help - the call raises before returning a value to inspect - so those
go through `BR.Secret.AuraByIndex` / `AuraByInstanceID`, which `pcall` the call and return
nil on throw. `GetUnitAuraBySpellID` does _not_ throw, so it stays a direct call read via
`AuraField`. Rule of thumb: **`issecretvalue` guards a value you hold; `pcall` guards a call
that might not return.**

### 4.2 The helpers fail _closed_ - and that's the right default everywhere

`AuraList`/`AuraField` bake in fail-closed (a secret reads as absent/empty). Every aura
caller uses them, including `GroupAuraUpdateMatters`: a secret payload container reads as an
empty list, contributes no match, and the payload is skipped (ticker-backstopped). There is
**no fail-open secret-container exception** - an earlier version had one, but the PTR data
(#3.6: group containers are secret on ~every combat payload) showed fail-open would just
rescan on every combat payload and undo the event-filter's whole purpose. The only fail-open
left is for _no-info_ payloads (`nil` / `isFullUpdate`), which is a different case - see #4.4.

### 4.3 Prefer detection that never compares secrets

Where possible, sidestep the problem entirely: spell-known checks, whitelist membership,
enchant IDs, instance/content gates. A comparison you never make can't throw.

### 4.4 Fail direction is a deliberate choice

- **Fail-open** only on _no-info_ payloads - `nil` updateInfo or `isFullUpdate` - where
  there is literally nothing to filter on, so `GroupAuraUpdateMatters` returns `true` and a
  rescan runs. This is not the secret case; it's the "we got no incremental data" case.
- **Fail-closed** on everything secret: a secret container / entry / spellId reads as
  absent (via `AuraList`/`AuraField`), so it contributes no match and the payload is
  skipped. Rationale (verified on PTR, #3.6): in combat these containers are secret on
  ~every payload, so failing open would rescan constantly and defeat the event filter; the
  3s ticker is the accepted backstop for anything skipped.
- Historically the bias was "hard against stale, prefer rescan." The PTR data flipped the
  balance for restricted-context group payloads specifically: rescanning _every_ combat
  payload costs more than a ≤3s ticker lag on a group buff _count_ is worth (raid buffs are
  applied pre-pull; mid-combat changes are rare and low-stakes).

### 4.5 issecretvalue is safe on anything

You can call `issecretvalue(v)` on nil or any value without a taint concern - use it
liberally as the first line of any branch that touches combat data.

---

## 5. Watch list / open questions

- **PTR 6 healer de-whitelisting - CODE LANDED, VERIFY IN-GAME (#3.7).** Our whitelist is a
  _derived_ copy of Blizzard's never-secret list, so confirm on a PTR 6+ build that
  `GetUnitAuraBySpellID("party1", 53563)` really does return `nil`/secret in combat. If it
  still reads plain, the five buffs are being hidden in combat for nothing.
- **PTR 7 unit-identity secrecy - CODE LANDED, VERIFY ON PTR 7 (#3.8).** The guards and caches
  are in; they are written against announced behavior, not tested behavior. Open questions for
  the first PTR 7 build:
  (a) is `UnitClass("player")` genuinely never secret (Bootstrap/Buffs/Display all assume it);
  (b) does `UnitPhaseReason` return a _secret_ or plain `nil` when there is no phase reason -
  decides how often `IsUnitPhased` fails open;
  (c) is _reading_ `t[secret]` as fatal as writing it (assumed yes - both need the hash);
  (d) do `GetRaidRosterInfo` (class token + `combatRole`) and `UnitIsPlayer` / `UnitLevel`
  survive as plain sources, or are they the obvious next batch? Don't build on them without
  checking - a plain class/role source would make the caches unnecessary.
- **~~12.1 whitelist reversion~~ - RESOLVED (2026-07-15).** Feared the whitelist was being
  removed; PTR testing (#3.6) shows it **survives** for `GetUnitAuraBySpellID`. No
  strategy-level rework needed. The real 12.1 change is enumeration-throws, already handled
  (`AuraByIndex`). Left here as a record of the corrected assumption.
- **Group-unit behavior on PTR (open).** #3.6 tested the _player_. Confirm in a live
  group / boss pull: (a) `GetUnitAuraBySpellID(party*/raid*, whitelistedID)` still readable
  in restricted contexts; (b) UNIT_AURA **container** secrecy for group units
  (`/sprobe watch`) - this decides how often `GroupAuraUpdateMatters` fails open.
- **`GroupAuraUpdateMatters` fail-open cost.** With the secret-container guard it fails
  open (rescans) whenever a group payload container is secret. If that turns out to be
  _every_ combat payload (i.e. group containers are as secret as the player's per 3.4), the
  event filter is effectively bypassed in combat and the committed CPU optimization is lost
  there - state stays correct but the raid-combat savings from "perf(events): ⚡️ cut aura
  update CPU usage in groups and combat" (2026-07-12) are gone. If raid CPU regresses,
  the lever is an `C_RestrictedActions.IsRestricted()` / `IsRestricted()` early-return at
  the top of `GroupAuraUpdateMatters` (fall back to the 3s ticker in restricted contexts).
  That commit squashed the old gate-removal, so there's no standalone commit to revert.
- **`C_Secrets` / `C_CurveUtil` / `C_DurationUtil` / `C_RestrictedActions` signatures** -
  sourced from a community-reconstructed reference (April 2026). `issecretvalue()` and the
  general model are solid. The exact namespace signatures stay **verify-before-use**, except
  the four `C_Secrets` members that #3.11 confirmed. The display primitives are likely never
  needed (see #2), but `C_RestrictedActions.IsRestricted` is worth a look as a second answer
  for the restriction gate.
- **`C_Secrets` - VERIFIED LIVE, NOT ADOPTED (#3.11).** The namespace exists on live.
  `ShouldAurasBeSecret()` agreed with `IsRestricted()` in the open world and in an arena prep
  phase, so it can retire the whole derivation. `ShouldSpellAuraBeSecret(spellID)` returns
  real booleans and can retire `Data/AuraWhitelist.lua`. `HasSecretRestrictions` and
  `ShouldUnitIdentityBeSecret` also answer. Neither replacement is adopted yet. One
  measurement is still missing before the whitelist swap: the answer of
  `ShouldSpellAuraBeSecret` for a **non-whitelisted** spell inside a restricted context. A
  wrong answer there turns every buff into a false "missing".
- **~~PvP matches are a restricted context we do not model~~ - RESOLVED (2026-09-01, #3.11).**
  A PvP instance restricts auras for its whole duration, prep phase included, with no combat
  needed. The blanket PvP term in `IsRestricted()` is correct. A prep-phase exemption shipped
  once (commit `6e7f4bb`). Commit `53f3d99` removed it, and that removal is now confirmed.
  Left here as a record, because the visible result - a shield reminder that stays silent in
  the arena while Skyfury shows - reads like a bug and gets reported as one.
- **Aura struct secrecy scope - partly RESOLVED (#3.6).** Out of combat everything reads
  plain; in restricted contexts enumeration throws while whitelisted targeted queries stay
  plain. So "always fully secret" is not literally true for the targeted path. Remaining
  unknown: whether a _non-whitelisted_ targeted query can return a secret struct (vs `nil`)
  on some build - currently it returns `nil`, which `UnitHasBuff` treats as missing.
