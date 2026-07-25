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

---@class Texture
---@field SetAllPoints fun(self: Texture, target?: any)
---@field SetTexCoord fun(self: Texture, left: number, right: number, top: number, bottom: number)
---@field SetTexture fun(self: Texture, texture: number|string)
---@field SetAtlas fun(self: Texture, atlas: string)
---@field SetSize fun(self: Texture, width: number, height: number)
---@field Show fun(self: Texture)
---@field Hide fun(self: Texture)

---@class FontString
---@field SetFont fun(self: FontString, font: string, size: number, flags?: string): boolean? # false when the font file isn't loaded/usable yet
---@field SetText fun(self: FontString, text: string)
---@field SetTextColor fun(self: FontString, r: number, g: number, b: number, a?: number)
---@field ClearAllPoints fun(self: FontString)
---@field SetPoint fun(self: FontString, point: string, relativeTo?: any, relativePoint?: string, x?: number, y?: number)
---@field GetParent fun(self: FontString): Frame?
---@field Show fun(self: FontString)
---@field Hide fun(self: FontString)

---@class AnimationGroup

---@alias TooltipText {title: string, desc?: string, atlas?: string}
---@alias SpellID number|number[]
---@alias ClassName "WARRIOR"|"PALADIN"|"HUNTER"|"ROGUE"|"PRIEST"|"DEATHKNIGHT"|"SHAMAN"|"MAGE"|"WARLOCK"|"MONK"|"DRUID"|"DEMONHUNTER"|"EVOKER"
---@alias RoleType "TANK"|"HEALER"|"DAMAGER"
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
