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

A secret value is *not* nil - it is a real, truthy value that carries a taint tag. When
your (tainted) addon code performs a forbidden operation on it, the operation **throws**;
it does not return nil or false.

The exact op set below was **verified in-game on the 12.1 PTR (2026-07-15)** with the
SecretProbe tool - it corrects the community reference, which was wrong about string ops.

**Tainted (addon) code CANNOT, on a secret value (confirmed to THROW):**
- Arithmetic (`+ - * / % ^`)
- Value comparison (`== ~= < > <= >=`) - *comparing the secret against another value*
- Using a secret **as a table key** (`t[secret] = v`)
- Structural ops - **`ipairs`, `#` (length)**
- **Boolean-test a secret BOOLEAN** - `if secretBool then`, `secretBool and/or ...`. Its
  truthiness *is* the protected value, so branching on it would leak the secret. (This is
  type-specific: see the CAN list - a secret number/table is safe to `if` on.)

**Tainted code CAN (confirmed OK - do NOT over-guard these):**
- Store secrets in variables, pass them around
- **Branch on the truthiness of a secret NUMBER or TABLE**: `if secretNumber then`,
  `if secretTable then` - they're always truthy (non-nil, non-false), so the branch leaks
  nothing. **Not** true for a secret *boolean* (see CANNOT). `secret ~= nil` / `== nil` is
  fine for any type (nil comparison, not value comparison).
- **String ops**: `tostring(secret)`, `"x" .. secret`, `string.format("%d", secret)`,
  `type(secret)` - all OK (the community doc was wrong here)
- Pass them to whitelisted native APIs (`StatusBar:SetValue`, `Curve:Evaluate`, ...)
- Call `issecretvalue(v)` on them (safe on any value, including nil) - and `Plain()` /
  `AuraField()` build on it, so reading a secret boolean *through* them is always safe

> **A separate failure mode - THROWING CALLS.** Aura *enumeration* APIs
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
is *logic on plain values*, which is exactly what the secret system forbids:

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
returns a **plain, readable struct (spellId + expirationTime)** in combat *and* in M+,
exactly like live; non-whitelisted spells return `nil`. So the addon's core
restricted-context counting is safe on 12.1.

What 12.1 *does* change is **aura enumeration**: `GetAuraDataByIndex` now **throws** in
restricted contexts (it used to return data). That only affects the three icon/source scans
that can't use a targeted query (see #3.5); they're guarded with `AuraByIndex` and degrade
to the 3s ticker. No strategy-level rework is needed.

### Restricted contexts

Three contexts restrict the aura API identically (see also CLAUDE.md -> *Aura API
Restrictions*): **combat lockdown**, **boss encounters** (ENCOUNTER_START->END), and
**M+ keystones** (always, even out of combat). State.lua owns a single `inCombat` flag
covering all three; the encounter-start gap (ENCOUNTER_START fires before
`InCombatLockdown()` flips) is why `InCombatLockdown()` is never called in the refresh path.

---

## 3. Verified behavior (dated findings)

### 3.1 Secret returns from unit-identity / stat APIs - *verified, 12.0.5*

Unit-identity APIs (`UnitCreatureID`, `UnitCreatureFamily`, `UnitIsUnit`, stat APIs while
auras are secret, etc.) return values tagged secret when unit identity isn't publicly
resolved. Comparing one from addon code throws:

```
attempt to compare local 'X' (a secret number value, while execution tainted by 'BuffReminders')
```

- **`pcall` around the API call does NOT catch this** - the error fires on the *operator*,
  not the call. The guard must wrap the value *before* the compare.
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

### 3.2 UNIT_AURA payload follows the aura whitelist - *verified in-game 2026-07-12*

Tested in follower-dungeon combat **and** a battleground (both restriction paths - combat
lockdown and restricted-while-out-of-combat):

- `UNIT_AURA` `updateInfo.addedAuras` entries for **whitelisted** spells have **readable**
  `spellId` and `auraInstanceID`; non-whitelisted auras come back secret (guarded reads
  fail). Confirmed spells: Battle Shout 6673, Mark of the Wild 1126, Renewing Mist 119611.
- This scoped `BuffState.GroupAuraUpdateMatters`' *per-entry* handling: a secret entry
  ("secret spellId ⇒ not whitelisted ⇒ not displayable here") is safe to skip.
- **This finding was about individual *entries*. It did NOT establish that the list
  *container* stays readable - and 3.4 shows it does not.** The per-entry guarantee still
  appears to hold; the container-level guarantee never existed and must not be assumed.

### 3.3 Payload container secrecy - *patch notes, 12.1.0 PTR 4 (partly SUPERSEDED by 3.6)*

12.1.0 PTR notes state: *"The UNIT_AURA event now delivers a fully secret payload while
auras are secret. AuraData structs are now always fully secret."* Read literally, this
sounded like *everything* (targeted queries included) goes secret in restricted contexts.
**PTR testing (3.6) disproved the literal reading for `GetUnitAuraBySpellID`** - whitelisted
targeted queries still return plain structs. The "fully secret" wording applies to the
*enumeration* path and the event payload container, not to whitelisted targeted lookups.

### 3.4 Whole-container secrecy is happening on LIVE - *confirmed live, v6.2.2-alpha2*

A user crash on live (not PTR) proved a **UNIT_AURA list container itself can be secret**,
independent of the 12.1.0 PTR notes:

```
bad argument #1 to 'ipairs' (table expected, got secret)   -- UpdateEatingState, player payload
```

`updateInfo.addedAuras` was truthy (so `if updateInfo.addedAuras then` passed) but was a
secret value, so `ipairs`/`#`/indexing on it threw. This is the concrete failure mode
behind the container-secrecy concern in 3.3 - and it is **already live**, at least for the
**player** `UNIT_AURA` payload.

**Scope still to verify:** this was observed on the *player* payload. Whether *group-unit*
payload containers are equally affected (which would change how often
`GroupAuraUpdateMatters` fails open) has not been separately confirmed in-game since this
crash. The 2026-07-12 group-payload verification (3.2) predates it.

**Handling:** never gate a list container on truthiness alone - route it through
`AuraList` (secret container -> empty). Both callers now fail **closed**: `UpdateEatingState`
skips (re-syncs on combat end) and `GroupAuraUpdateMatters` skips (3s-ticker backstop). See
#3.6 (group-container secrecy confirmed on PTR) and #4.4 for why fail-closed won.

### 3.5 Frame-API overhaul does not affect BuffReminders - *patch notes, 12.1.0 PTR 4*

The AuraContainer/AuraGroup/AuraSlot rework, `AddAuraFrame` removal,
`SecureAuraHeaderTemplate` removal, and `AddPrivateAuraAppliedSound` -> `AddAuraAppliedSound`
rename **do not touch BuffReminders** (grep-confirmed zero usage). The addon draws its own
icon frames and uses no secure aura headers or private-aura sounds.

### 3.6 12.1 PTR behavior - *verified in-game, 12.1.0 PTR, 2026-07-15*

Tested with SecretProbe out of combat, in combat (open world), and in an M+ key
(difficultyID 8, restricted even out of combat). Definitive:

- **Targeted query survives.** `GetUnitAuraBySpellID("player", 6673)` (Battle Shout,
  whitelisted) returned a **plain struct with readable `spellId` and `expirationTime` in
  combat AND M+**. Non-whitelisted spells returned `nil`. The whitelist is intact on 12.1
  for the targeted path - same behavior as live. The core detection is safe.
- **Enumeration throws.** `GetAuraDataByIndex` (and by extension
  `GetAuraDataByAuraInstanceID`) **raises an error** at index 1 in combat and in M+ (it
  returned data fine out of combat). This is a *call-error*, not a secret return. Handled by
  `BR.Secret.AuraByIndex` / `AuraByInstanceID` (pcall -> nil-on-throw); the three
  icon/source scans degrade to the 3s ticker in restricted contexts.
- **Operation legality is TYPE-SPECIFIC** (see #1): `~= nil` / `tostring` / `string.format`
  / `type` are OK on any secret; value comparison, arithmetic, `#`, `ipairs`, and
  secret-as-table-key throw. **Boolean test (`if x`) depends on the secret's type:** a secret
  *number/table* is always-truthy so `if` on it is fine (confirms group-B `if auraData then`
  is safe), but a secret *boolean* THROWS - branching leaks its value. Discovered the hard
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

---

## 4. How to handle secrets correctly

### 4.1 Read through the boundary helpers, don't hand-roll pcalls

`pcall` is the **wrong tool** for secret-guarding: it sets up a protected frame every
call and *throws + unwinds* when the value is secret (exactly the common case in restricted
contexts), it swallows unrelated bugs, and it guards a *body* rather than the *operation* -
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
nil on throw. `GetUnitAuraBySpellID` does *not* throw, so it stays a direct call read via
`AuraField`. Rule of thumb: **`issecretvalue` guards a value you hold; `pcall` guards a call
that might not return.**

### 4.2 The helpers fail *closed* - and that's the right default everywhere

`AuraList`/`AuraField` bake in fail-closed (a secret reads as absent/empty). Every aura
caller uses them, including `GroupAuraUpdateMatters`: a secret payload container reads as an
empty list, contributes no match, and the payload is skipped (ticker-backstopped). There is
**no fail-open secret-container exception** - an earlier version had one, but the PTR data
(#3.6: group containers are secret on ~every combat payload) showed fail-open would just
rescan on every combat payload and undo the event-filter's whole purpose. The only fail-open
left is for *no-info* payloads (`nil` / `isFullUpdate`), which is a different case - see #4.4.

### 4.3 Prefer detection that never compares secrets

Where possible, sidestep the problem entirely: spell-known checks, whitelist membership,
enchant IDs, instance/content gates. A comparison you never make can't throw.

### 4.4 Fail direction is a deliberate choice

- **Fail-open** only on *no-info* payloads - `nil` updateInfo or `isFullUpdate` - where
  there is literally nothing to filter on, so `GroupAuraUpdateMatters` returns `true` and a
  rescan runs. This is not the secret case; it's the "we got no incremental data" case.
- **Fail-closed** on everything secret: a secret container / entry / spellId reads as
  absent (via `AuraList`/`AuraField`), so it contributes no match and the payload is
  skipped. Rationale (verified on PTR, #3.6): in combat these containers are secret on
  ~every payload, so failing open would rescan constantly and defeat the event filter; the
  3s ticker is the accepted backstop for anything skipped.
- Historically the bias was "hard against stale, prefer rescan." The PTR data flipped the
  balance for restricted-context group payloads specifically: rescanning *every* combat
  payload costs more than a ≤3s ticker lag on a group buff *count* is worth (raid buffs are
  applied pre-pull; mid-combat changes are rare and low-stakes).

### 4.5 issecretvalue is safe on anything

You can call `issecretvalue(v)` on nil or any value without a taint concern - use it
liberally as the first line of any branch that touches combat data.

---

## 5. Watch list / open questions

- **~~12.1 whitelist reversion~~ - RESOLVED (2026-07-15).** Feared the whitelist was being
  removed; PTR testing (#3.6) shows it **survives** for `GetUnitAuraBySpellID`. No
  strategy-level rework needed. The real 12.1 change is enumeration-throws, already handled
  (`AuraByIndex`). Left here as a record of the corrected assumption.
- **Group-unit behavior on PTR (open).** #3.6 tested the *player*. Confirm in a live
  group / boss pull: (a) `GetUnitAuraBySpellID(party*/raid*, whitelistedID)` still readable
  in restricted contexts; (b) UNIT_AURA **container** secrecy for group units
  (`/sprobe watch`) - this decides how often `GroupAuraUpdateMatters` fails open.
- **`GroupAuraUpdateMatters` fail-open cost.** With the secret-container guard it fails
  open (rescans) whenever a group payload container is secret. If that turns out to be
  *every* combat payload (i.e. group containers are as secret as the player's per 3.4), the
  event filter is effectively bypassed in combat and the committed CPU optimization is lost
  there - state stays correct but the raid-combat savings from "perf(events): ⚡️ cut aura
  update CPU usage in groups and combat" (2026-07-12) are gone. If raid CPU regresses,
  the lever is an `C_RestrictedActions.IsRestricted()` / `IsRestricted()` early-return at
  the top of `GroupAuraUpdateMatters` (fall back to the 3s ticker in restricted contexts).
  That commit squashed the old gate-removal, so there's no standalone commit to revert.
- **`C_Secrets` / `C_CurveUtil` / `C_DurationUtil` / `C_RestrictedActions` signatures** -
  sourced from a community-reconstructed reference (April 2026). `issecretvalue()` and the
  general model are solid; the exact namespace signatures are **verify-before-use**. The
  display primitives are likely never needed (see #2), but `C_RestrictedActions.IsRestricted`
  is worth confirming as a cleaner replacement for the combat/encounter/M+ gating.
- **Aura struct secrecy scope - partly RESOLVED (#3.6).** Out of combat everything reads
  plain; in restricted contexts enumeration throws while whitelisted targeted queries stay
  plain. So "always fully secret" is not literally true for the targeted path. Remaining
  unknown: whether a *non-whitelisted* targeted query can return a secret struct (vs `nil`)
  on some build - currently it returns `nil`, which `UnitHasBuff` treats as missing.
