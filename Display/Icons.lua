local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- ICON / TEXTURE RESOLUTION
-- ============================================================================
-- Single source of truth for "given a buff def, what texture(s) represent it".
-- Resolution and caching only. This module never touches a frame.

local tinsert = table.insert

local GetPlayerRole = BR.BuffState.GetPlayerRole

local spellTextureCache = {}

-- Weak keys: custom buff defs are SavedVariables tables, so the cache must not be a field on them.
local buffIconsCache = setmetatable({}, { __mode = "k" })

---Resolve a spell ID to its texture, with caching. Returns nil if the API cannot resolve it yet.
---A miss stays cached until a spell data event clears the misses.
---@param id number
---@return number? textureID
local function GetSpellTextureCached(id)
    local cached = spellTextureCache[id]
    if cached ~= nil then
        return cached or nil
    end
    local texture
    pcall(function()
        texture = C_Spell.GetSpellTexture(id)
    end)
    spellTextureCache[id] = texture or false
    return texture
end

local function ClearSpellTextureMisses()
    local cleared = false
    for id, texture in pairs(spellTextureCache) do
        if texture == false then
            spellTextureCache[id] = nil
            cleared = true
        end
    end
    -- A cached icon list can lack the texture of a cleared miss.
    if cleared then
        wipe(buffIconsCache)
    end
end
BR.GameContext.RegisterCache("spellTextureMisses", ClearSpellTextureMisses)

---Get spell texture from a single spell ID. For a buff def use GetBuffIcons(buff)[1]
---instead, so that buff.icons takes priority over the raw spellID lookup.
---@param spellID SpellID?
---@return number? textureID
local function GetBuffTexture(spellID)
    if type(spellID) == "table" then
        spellID = spellID[1]
    end
    if not spellID then
        return nil
    end
    return GetSpellTextureCached(spellID)
end

---Resolve the static portion of an `icons` spec into a list of texture IDs.
---Caller owns dedup.
---@param icons IconSpec?
---@param add fun(t: number?)
local function ResolveStaticIcons(icons, add)
    if not icons then
        return
    end
    if icons.spells then
        for _, id in ipairs(icons.spells) do
            add(GetSpellTextureCached(id))
        end
    elseif icons.textures then
        for _, t in ipairs(icons.textures) do
            add(t)
        end
    end
end

---Resolve the static icon list for a buff, cached per buff def. Spell textures
---can return nil during early load, before spell data settles. An empty result stays
---uncached, so the first read after a spell data event resolves it again.
---@param buff table Any buff def (RaidBuff, SelfBuff, ConsumableBuff, CustomBuff, ...)
---@return number[] textures (may be empty)
local function GetBuffIcons(buff)
    local cached = buffIconsCache[buff]
    if cached then
        return cached
    end
    local out = {}
    local seen = {}
    local function add(t)
        if t and not seen[t] then
            seen[t] = true
            tinsert(out, t)
        end
    end

    local icons = buff.icons
    if icons and (icons.textures or icons.spells) then
        ResolveStaticIcons(icons, add)
    elseif buff.spellID then
        local list = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
        for _, id in ipairs(list) do
            add(GetSpellTextureCached(id))
        end
    end

    if #out > 0 then
        buffIconsCache[buff] = out
    end
    return out
end

---`byRole` has no entry field: ResolveFrameTexture resolves it at render time.
---@param entry table
---@param buff table
local function ApplyDynamicIcon(entry, buff)
    local icons = buff.icons
    if icons and icons.dynamic then
        entry.dynamicIcon = icons.dynamic()
    end
end

---Pre-fill the icon cache for every static buff. The caller must wait until spell data
---settles.
local function PreFillIconCaches()
    for _, buffArray in pairs(BR.BuffData.buffTables) do
        for _, buff in ipairs(buffArray) do
            GetBuffIcons(buff)
        end
    end
end

---Resolve the role-dependent texture for a buff at render time. Caller has already
---verified `def.icons.byRole` is present.
---@param def table buff def
---@return number? textureID
local function ResolveRoleTexture(def)
    local role = GetPlayerRole()
    local id = role and def.icons.byRole[role]
    if id then
        return GetSpellTextureCached(id)
    end
    return GetBuffIcons(def)[1]
end

---Resolve the display texture for a buff frame from its buffDef.
---@param frame BuffFrame
---@return number? textureID
local function ResolveFrameTexture(frame)
    local def = frame.buffDef
    if not def then
        return nil
    end
    if def.icons and def.icons.byRole then
        return ResolveRoleTexture(def)
    end
    return GetBuffIcons(def)[1]
end

BR.Icons = {
    GetBuffTexture = GetBuffTexture,
    GetBuffIcons = GetBuffIcons,
    ApplyDynamicIcon = ApplyDynamicIcon,
    PreFillIconCaches = PreFillIconCaches,
    ResolveFrameTexture = ResolveFrameTexture,
    ---Invalidate one spell ID's cached texture so the next resolve re-queries the API.
    ---@param spellID number
    InvalidateSpell = function(spellID)
        spellTextureCache[spellID] = nil
    end,
    ---Drop one buff def's cached icon list so the next GetBuffIcons resolves it again.
    ---@param buff table
    InvalidateBuffIcons = function(buff)
        buffIconsCache[buff] = nil
    end,
}
