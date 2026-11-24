---@meta
-- Type definitions for LuaLS (lua-language-server)
-- This file is NOT loaded by WoW - it's only used for type checking during development

-- WoW API types (stubs with commonly used methods)
---@class Frame
---@field Show fun(self: Frame)
---@field Hide fun(self: Frame)
---@field IsShown fun(self: Frame): boolean
---@field SetPoint fun(self: Frame, point: string, relativeTo?: any, relativePoint?: string|number, x?: number, y?: number)
---@field GetParent fun(self: Frame): Frame?
---@field GetWidth fun(self: Frame): number
---@field GetHeight fun(self: Frame): number
---@field CreateFontString fun(self: Frame, name?: string, layer?: string, inherits?: string): FontString

---@class Button: Frame

-- Anything that carries a font: Font objects, FontStrings, EditBoxes.
-- The SetFont return value can lie at login - Display/Fonts.lua owns the
-- verified-apply logic.
---@class FontInstance
---@field SetFont fun(self: FontInstance, font: string, size: number, flags?: string): boolean
---@field GetFont fun(self: FontInstance): string?, number?, string?
---@field SetFontObject fun(self: FontInstance, fontObject: Font|string)
---@field GetFontObject fun(self: FontInstance): Font?
---@field SetTextScale? fun(self: FontInstance, scale: number) -- FontString only
---@field GetTextScale? fun(self: FontInstance): number -- FontString only

-- A shared font object from CreateFont()
---@class Font: FontInstance

---@class EditBox: Frame, FontInstance

---@class Texture
---@field SetAllPoints fun(self: Texture, target?: any)
---@field SetTexCoord fun(self: Texture, left: number, right: number, top: number, bottom: number)
---@field SetTexture fun(self: Texture, texture: number|string)
---@field SetAtlas fun(self: Texture, atlas: string)
---@field SetSize fun(self: Texture, width: number, height: number)
---@field Show fun(self: Texture)
---@field Hide fun(self: Texture)

---@class FontString: FontInstance
---@field SetText fun(self: FontString, text: string)
---@field GetStringWidth fun(self: FontString): number
---@field GetStringHeight fun(self: FontString): number
---@field SetTextColor fun(self: FontString, r: number, g: number, b: number, a?: number)
---@field ClearAllPoints fun(self: FontString)
---@field SetPoint fun(self: FontString, point: string, relativeTo?: any, relativePoint?: string, x?: number, y?: number)
---@field GetParent fun(self: FontString): Frame?
---@field Show fun(self: FontString)
---@field Hide fun(self: FontString)

---@class AnimationGroup

---@alias TooltipText {title: string, desc?: (string|fun(): string), atlas?: string}
---@alias SpellID number|number[]
---@alias ClassName "WARRIOR"|"PALADIN"|"HUNTER"|"ROGUE"|"PRIEST"|"DEATHKNIGHT"|"SHAMAN"|"MAGE"|"WARLOCK"|"MONK"|"DRUID"|"DEMONHUNTER"|"EVOKER"
---@alias RoleType "TANK"|"HEALER"|"DAMAGER"
-- What one cast of the buff covers: the caster's party, or the whole raid.
---@alias BuffReach "party"|"raid"
-- Who receives the buff. The category gives the default.
--   group: every member who benefits needs a copy (raid default)
--   anyone: one copy on any member covers the group (presence default)
--   self: only the player
--   ally: one unit that the caster picks. Needs a group (targeted default). "Just on me" modes hide it
--   allyOrSelf: one unit that the caster picks, the player included. Also shown solo
--   tankOrSelf: each tank (TANK role or Main Tank mark), one cast at a time. With no tank, the player
---@alias BuffTarget "group"|"anyone"|"self"|"ally"|"allyOrSelf"|"tankOrSelf"
-- Which copies satisfy the caster: any caster's copy, or only the player's own.
-- A viewer of another class always counts any copy. The category gives the default.
---@alias BuffCopies "any"|"own"
---@alias SpecID number
---@alias BuffBeneficiaries table<string, table<ClassName, boolean>>
---@alias SpecBeneficiaries table<string, table<SpecID, boolean>>

---@class LoadConditions
---@field openWorld? boolean
---@field dungeon? boolean
---@field scenario? boolean
---@field raid? boolean
---@field housing? boolean
---@field pvp? boolean
---@field readyCheckOnly? boolean
---@field levelFilter? "maxLevel"|"belowMaxLevel"
---@field scenarioDifficulty? table<string, boolean>
---@field dungeonDifficulty? table<string, boolean>
---@field raidDifficulty? table<string, boolean>
