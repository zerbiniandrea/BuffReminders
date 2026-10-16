---@class BR
local _, BR = ...

-- Fonts for the display layer. Options panel text uses the stock GameFont objects,
-- except for the font previews.
--
-- At login the client can report a successful SetFont without a real apply,
-- and can revert a verified apply when the async load of the font file
-- completes. TrySetFont therefore verifies every apply with a GetFont
-- read-back. A ticker re-verifies the shared Font objects after login.

local LSM = LibStub("LibSharedMedia-3.0")
local abs = math.abs
local floor = math.floor

-- The stock client font, captured at file load, before any addon can
-- reassign the STANDARD_TEXT_FONT global at login. The client preloads this
-- file for its own UI, so a fallback to it always applies.
local CLIENT_FONT = STANDARD_TEXT_FONT

-- Resolved from saved settings by Resolve().
local fontPath = STANDARD_TEXT_FONT

-- "NONE" in saved settings maps to "" at the WoW API level.
local outlineFlag = "OUTLINE"

---One verified font apply on any FontInstance. The return value of SetFont
---is ignored: fontstrings can return `true` without a real apply, and Font
---objects return nothing. Only a GetFont read-back that matches the request
---counts as success. Outline flags are not compared - the client reformats
---the flags string.
---@param target FontInstance any Font object, fontstring, or edit box
---@param path string
---@param size number
---@param outline string
---@return boolean applied true when the face and size are on the target
local function TrySetFont(target, path, size, outline)
    if not pcall(target.SetFont, target, path, size, outline) then
        return false
    end
    local okRead, appliedPath, appliedSize = pcall(target.GetFont, target)
    return okRead and appliedPath == path and appliedSize ~= nil and abs(appliedSize - size) < 0.5
end

-- Shared Font objects, keyed by (outline, size). Each size gets its own
-- object because SetTextScale sizing snaps to discrete steps. Sizes come
-- from integer sliders, so the set stays small.
-- healthy = the configured face passed a verified apply on the object.
local fontObjects = {} ---@type table<string, Font>
local objectSize = {} ---@type table<string, number>
local objectOutline = {} ---@type table<string, string>
local objectHealthy = {} ---@type table<string, boolean>
local objectCount = 0

local ScheduleReassert

---Apply the configured face to one Font object, with fallbacks. The object
---must always carry a font: SetText on a fontstring linked to a font-less
---object raises an error.
---@param key string
local function AssertObject(key)
    local obj = fontObjects[key]
    local size = objectSize[key]
    local outline = objectOutline[key]
    if TrySetFont(obj, fontPath, size, outline) then
        objectHealthy[key] = true
        return
    end
    objectHealthy[key] = false
    -- Fallback chain: the live STANDARD_TEXT_FONT (another addon can swap
    -- it game-wide), then the stock client font.
    if fontPath == STANDARD_TEXT_FONT or not TrySetFont(obj, STANDARD_TEXT_FONT, size, outline) then
        pcall(obj.SetFont, obj, CLIENT_FONT, size, outline)
    end
    ScheduleReassert()
end

---Re-apply every object that the client reverted or never accepted.
local function ReassertObjects()
    for key, obj in pairs(fontObjects) do
        local okRead, path, size = pcall(obj.GetFont, obj)
        local intact = okRead and path == fontPath and size ~= nil and abs(size - objectSize[key]) < 0.5
        if not intact then
            AssertObject(key)
        else
            objectHealthy[key] = true
        end
    end
end

---@param outline string
---@param size number integer pixel size
---@return Font obj
---@return string key
local function GetObject(outline, size)
    local key = outline .. "@" .. size
    local obj = fontObjects[key]
    if not obj then
        objectCount = objectCount + 1
        obj = CreateFont("BuffRemindersDisplayFont" .. objectCount)
        fontObjects[key] = obj
        objectSize[key] = size
        objectOutline[key] = outline
        AssertObject(key)
    end
    return obj, key
end

-- Retry timer for objects that failed a verified apply (for example, the
-- face file is not loadable yet). The cap stops the timer for a face that
-- never loads. Resolve resets the budget when the face changes.
local reassertScheduled = false
local reassertCount = 0
local MAX_REASSERTS = 10

ScheduleReassert = function()
    if reassertScheduled or reassertCount >= MAX_REASSERTS then
        return
    end
    reassertScheduled = true
    reassertCount = reassertCount + 1
    C_Timer.After(1.5, function()
        reassertScheduled = false
        ReassertObjects()
    end)
end

local fontProbe = UIParent:CreateFontString(nil, "BACKGROUND")
fontProbe:Hide()
local fontPathValidCache = {}

---Report whether the WoW client can load a font file path. The cache keeps
---successes only: a failure can be a first-use transient, so the next call
---probes the path again.
---@param path string? LSM-resolved font file path
---@return boolean valid true if path is non-nil and SetFont succeeds
local function IsFontPathValid(path)
    if not path then
        return false
    end
    if fontPathValidCache[path] then
        return true
    end
    local valid = TrySetFont(fontProbe, path, 12, "")
    if valid then
        fontPathValidCache[path] = true
    end
    return valid
end

---A loadability probe must not gate the result: a probe at login can fail
---for a face that loads a moment later.
local function Resolve()
    local defaults = BR.profile and BR.profile.defaults
    local fontName = defaults and defaults.fontFace
    local path = fontName and LSM:Fetch("font", fontName)
    path = path or STANDARD_TEXT_FONT

    local outline = defaults and defaults.textOutline
    if outline == "NONE" then
        outline = ""
    else
        outline = outline or "OUTLINE"
    end
    -- Plain outlines render through the client's Slug text path. MONOCHROME
    -- combinations keep the classic rasterized outline.
    if outline == "OUTLINE" or outline == "THICKOUTLINE" then
        outline = outline .. ", SLUG"
    end

    if path ~= fontPath then
        reassertCount = 0
    end
    fontPath = path
    outlineFlag = outline
    ReassertObjects()
end

---Link a fontstring to the shared Font object for its (outline, size).
---Safe to call from render paths on every pass. Edit boxes have no
---SetTextScale marker method, so they get a direct verified apply with
---fallback.
---@param fs FontString|EditBox any FontInstance
---@param size number pixel size, rounded to an integer here
---@param outline? string overrides the shared outlineFlag (e.g. "" for edit boxes)
---@return boolean healthy true when the configured face is on the shared object
local function Apply(fs, size, outline)
    outline = outline or outlineFlag
    size = floor(size + 0.5)
    if fs.SetTextScale then
        local obj, key = GetObject(outline, size)
        if fs:GetFontObject() ~= obj then
            fs:SetFontObject(obj)
        end
        return objectHealthy[key] == true
    end
    if TrySetFont(fs, fontPath, size, outline) then
        return true
    end
    if fontPath ~= STANDARD_TEXT_FONT then
        TrySetFont(fs, STANDARD_TEXT_FONT, size, outline)
    end
    return false
end

BR.DisplayFonts = {
    Resolve = Resolve,
    GetFontPath = function()
        return fontPath
    end,
    GetOutline = function()
        return outlineFlag
    end,
    IsFontPathValid = IsFontPathValid,
    Apply = Apply,
    ---Measured size of a fontstring's current text. GetStringWidth/Height
    ---do not include the text scale, so it is multiplied back in here.
    ---@param fs FontString
    ---@return number width
    ---@return number height
    GetStringSize = function(fs)
        local scale = (fs.GetTextScale and fs:GetTextScale()) or 1
        return fs:GetStringWidth() * scale, fs:GetStringHeight() * scale
    end,
}

-- LSM can change what Fetch returns after login: a late registration of the
-- configured face, or a global override (LSM 12 SetGlobal makes every Fetch
-- return the override).
local function OnMediaChanged(_, mediatype)
    if mediatype == "font" then
        Resolve()
    end
end
LSM.RegisterCallback(BR.DisplayFonts, "LibSharedMedia_Registered", OnMediaChanged)
LSM.RegisterCallback(BR.DisplayFonts, "LibSharedMedia_SetGlobal", OnMediaChanged)

-- Zone-change loading screens pass neither flag and stay excluded.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
    if not (isInitialLogin or isReloadingUi) then
        return
    end
    C_Timer.NewTicker(5, ReassertObjects, 6)
end)
