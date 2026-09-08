# Secret Values

> **AI-maintained document.** Statements are verified in-game on a 12.1 client unless a
> line says otherwise. Git history holds the dated findings.

Secret values are opaque Lua values that combat-related WoW APIs return (12.0+). They
enforce Blizzard's rule: addons can display combat data, but cannot do logic on it. A
secret value is not `nil`. It is a real, truthy value with a taint tag. When tainted
(addon) code performs a forbidden operation on it, the operation throws. In untainted
(Blizzard) code, a secret behaves as a normal value. Debug locals render a secret as
`<no value>`.

Whether a query returns secrets depends on the current context (the client decides), on
the API domain (auras, cooldowns, unit identity are separate), and for auras also on the
spell's secrecy classification.

## 1. Operation legality

Forbidden on a secret from tainted code (the operation throws):

- Arithmetic (`+ - * / % ^`)
- Value comparison (`== ~= < > <= >=`) against another value
- Use as a table key (`t[secret] = v`)
- `ipairs`, `#` (length)
- Boolean test of a secret **boolean** (`if secretBool then`, `secretBool and ...`)

Legal:

- Store in variables, pass as arguments and returns
- Boolean test of a secret **number or table** (always truthy, so the branch leaks
  nothing)
- `secret ~= nil` / `secret == nil` for any type (a nil comparison, not a value
  comparison)
- `tostring(secret)`, `"x" .. secret`, `string.format("%d", secret)`, `type(secret)`.
  This does not extend to every formatting API: `FormatNumber` spread taint on one PTR
  build.
- Pass to whitelisted native APIs (`StatusBar:SetValue`, `Curve:Evaluate`, ...)
- `issecretvalue(v)` on any value, `nil` included

Two guard tools exist, and they cover different failures. `issecretvalue(v)` tests a
value you hold, without a throw. `pcall` catches a call that throws. `pcall` around a
call does **not** catch a later operator throw on the returned value - the error fires on
the operator.

## 2. The C_Secrets API

| Member                             | Answer                                                                   |
| ---------------------------------- | ------------------------------------------------------------------------ |
| `ShouldAurasBeSecret()`            | Aura queries return secrets in the current context                       |
| `ShouldCooldownsBeSecret()`        | Cooldown queries return secrets in the current context (separate domain) |
| `GetSpellAuraSecrecy(spellID)`     | The spell's `Enum.SecrecyLevel` - context-free                           |
| `ShouldSpellAuraBeSecret(spellID)` | This spell's aura reads secret in the current context                    |
| `ShouldUnitIdentityBeSecret(unit)` | Identity queries on this unit return secrets                             |
| `HasSecretRestrictions()`          | The build enforces secrets at all (`true` on every 12.1 client)          |

`Enum.SecrecyLevel`: `NeverSecret` (0), `AlwaysSecret` (1), `ContextuallySecret` (2).

The context predicates answer for every restricted context at once. Which contexts
restrict which domain is the client's decision - never encode "PvP is restricted" or
"M+ is restricted" anywhere. A secrecy query's own answer can in principle be secret,
so test it with `issecretvalue` before use.

The members in the table are verified live. Treat every other `C_Secrets` member, and
the display primitives (`C_CurveUtil`, `C_DurationUtil`), as verify-before-use: their
signatures come from a community-reconstructed reference.

## 3. API behavior in restricted contexts

**Targeted aura queries.** `C_UnitAuras.GetUnitAuraBySpellID` never throws. For a
`NeverSecret` spell it returns a plain struct, for the player and for group units. For
every other spell it returns plain `nil`, even when the aura is present (measured - no
secret struct). That `nil` is indistinguishable from "aura not present". A non-nil aura
table proves presence: table identity is never secret.

**Aura enumeration.** `GetAuraDataByIndex` and `GetAuraDataByAuraInstanceID` throw while
`ShouldAurasBeSecret()` is true. This is a call error, not a secret return, so
`issecretvalue` cannot guard it - only `pcall` can.

**`UNIT_AURA` payloads.** Entries for `NeverSecret` spells stay readable. The list
containers themselves (`addedAuras`, ...) are secret in restricted contexts, for the
player and for group units - a truthy container can still throw on `ipairs` / `#`.
The `isFullUpdate` field can be a secret boolean.

**Display primitives.** `C_CurveUtil`, `C_DurationUtil`, and the `C_Secrets` comparators
(`IsLessThan`, `Select`, ...) accept secrets and return other secrets, for piping into
Blizzard widgets. No API converts a secret into a plain value. The only plain data in a
restricted context comes from the `NeverSecret` spell set.

**Unit identity.** Identity APIs (`UnitClass`, `UnitGroupRolesAssigned`,
`UnitPhaseReason`, `UnitCreatureFamily`, `UnitIsUnit`, stat APIs, ...) can return secrets
on units whose identity is secret. Measured so far: `ShouldUnitIdentityBeSecret` read
`false` in every sampled context, for the player and for allies (NPC follower included),
while auras were secret. Transient pets and mind-control historically produced secret
identity returns.

**Widget getters.** A frame that an aura owns returns secrets from its getters:
`IsVisible()` returns a secret boolean, geometry getters (`GetWidth`, `GetLeft`, ...)
return secret numbers. This reaches APIs with no aura in their signature, so any getter
on a frame of unknown origin can return a secret.

**Cooldowns.** `C_Spell.GetSpellCooldown` returns secrets while
`ShouldCooldownsBeSecret()` is true. `C_Item.GetItemCooldown` throws instead.
