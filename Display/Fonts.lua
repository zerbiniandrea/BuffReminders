---@class BR
local _, BR = ...

-- Shared font handling for the display layer: reminder icons, movers, secure
-- overlays, and the externals tracker (the options panel typeface is a
-- separate system, see UI/Fonts.lua).
--
-- Architecture: a few shared Font OBJECTS, not per-fontstring SetFont. Each
-- outline variant in use gets one Font object, built once at BASE_HEIGHT with
-- a verified apply. Fontstrings link to it with SetFontObject (a pointer
-- assignment) and get their pixel size from SetTextScale. A face change is
-- then one SetFont per object, and every linked fontstring follows without
-- per-string work.
--
-- Why the apply must be verified and re-asserted: on a cold client start,
-- SetFont can report success while the target keeps its previous font spec,
-- and the client can also REVERT a verified apply when the async load of the
-- font file completes (both confirmed live, 2026-08-13/14, with SetFont /
-- SetFontObject hooks proving that no Lua code wrote to the fontstring).
-- With shared objects the exposure shrinks to the objects themselves: a
-- short ticker after login and reload re-verifies each object with a GetFont
-- read and re-applies when the client reverted it.

local LSM = LibStub("LibSharedMedia-3.0")
local abs = math.abs

-- The stock client font, captured at file load - BEFORE any addon can
-- reassign the STANDARD_TEXT_FONT global at login. Last-resort fallback:
-- the client preloads this file for its own UI, so it always applies.
local CLIENT_FONT = STANDARD_TEXT_FONT

-- Cached font path - resolved once on load and updated when the setting changes (via VisualsRefresh).
-- All applies read this local directly instead of calling LSM:Fetch() every time.
local fontPath = STANDARD_TEXT_FONT

-- Cached outline flag - resolved on load and updated when the setting changes (via VisualsRefresh).
-- "NONE" in saved settings is translated to "" at the WoW API level.
local outlineFlag = "OUTLINE"

-- All Font objects are built at this height. Per-fontstring sizes are text
-- scales (size / BASE_HEIGHT), so a size change never touches the font API.
local BASE_HEIGHT = 20

---One guarded and verified font apply on any FontInstance (Font objects,
---fontstrings, edit boxes). The pcall catches paths that raise a hard error.
---The return value of SetFont is ignored completely: fontstrings can return
---`true` without a real apply (see the module header), and Font objects
---return nothing at all. Only a GetFont read-back that matches the request
---counts as success. Outline flags are not compared - the client can
---reformat the flags string.
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

-- Shared Font objects, one per outline variant in use (2-3 in practice).
-- healthy = the configured face passed a verified apply on the object.
local fontObjects = {} ---@type table<string, Font>
local objectHealthy = {} ---@type table<string, boolean>
local objectCount = 0

local ScheduleReassert -- defined below

---Apply the configured face to one Font object, with the client font as the
---legible fallback. A fontstring linked to an object without a font raises
---an error on SetText, so the object must always carry SOME font.
---@param outline string
local function AssertObject(outline)
    local obj = fontObjects[outline]
    if TrySetFont(obj, fontPath, BASE_HEIGHT, outline) then
        objectHealthy[outline] = true
        return
    end
    objectHealthy[outline] = false
    -- Fallback chain: the live STANDARD_TEXT_FONT (the user's game-wide
    -- face when another addon swapped it), then the stock client font.
    if fontPath == STANDARD_TEXT_FONT or not TrySetFont(obj, STANDARD_TEXT_FONT, BASE_HEIGHT, outline) then
        pcall(obj.SetFont, obj, CLIENT_FONT, BASE_HEIGHT, outline)
    end
    ScheduleReassert()
end

---Verify every object against a live GetFont read and re-apply the ones the
---client reverted or never accepted. Runs from Resolve, from the retry
---timer, and from the post-login ticker.
local function ReassertObjects()
    for outline, obj in pairs(fontObjects) do
        local okRead, path, size = pcall(obj.GetFont, obj)
        local intact = okRead and path == fontPath and size ~= nil and abs(size - BASE_HEIGHT) < 0.5
        if not intact then
            AssertObject(outline)
        else
            objectHealthy[outline] = true
        end
    end
end

---Get (or create) the shared Font object for an outline variant.
---@param outline string
---@return Font
local function GetObject(outline)
    local obj = fontObjects[outline]
    if not obj then
        objectCount = objectCount + 1
        obj = CreateFont("BuffRemindersDisplayFont" .. objectCount)
        fontObjects[outline] = obj
        AssertObject(outline)
    end
    return obj
end

-- Retry timer for objects that failed a verified apply (for example, the
-- face file is not loadable yet). Capped so a face that never loads stops
-- the timer; Resolve resets the budget when the face changes.
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

---Report whether the WoW client can load a font file path (the options font
---picker filters the LSM list through this).
---The cache keeps successes only. A failure can be the first-use transient,
---so the next call probes the path again.
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

---Resolve the font path and outline flag from saved settings, then bring
---every Font object in line. No loadability probe gates the result: a probe
---at login can fail for a face that loads a moment later, and AssertObject
---degrades to the client font and retries on its own.
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

    if path ~= fontPath then
        -- A new face gets a fresh retry budget.
        reassertCount = 0
    end
    fontPath = path
    outlineFlag = outline
    ReassertObjects()
end

---Link a fontstring to the shared font and set its pixel size as a text
---scale. Cheap and idempotent: a pointer compare and a number compare, so
---render paths can call it freely. Face and outline changes propagate
---through the shared object; no caller has to re-apply anything.
---Edit boxes have no SetTextScale, so they get a direct verified apply with
---fallback instead (rare, options-adjacent widgets).
---@param fs FontString|EditBox any FontInstance
---@param size number pixel size
---@param outline? string overrides the shared outlineFlag (e.g. "" for edit boxes)
---@return boolean healthy true when the configured face is on the shared object
local function Apply(fs, size, outline)
    outline = outline or outlineFlag
    if fs.SetTextScale then
        local obj = GetObject(outline)
        if fs:GetFontObject() ~= obj then
            fs:SetFontObject(obj)
        end
        local scale = size / BASE_HEIGHT
        if abs(fs:GetTextScale() - scale) > 0.001 then
            fs:SetTextScale(scale)
        end
        return objectHealthy[outline] == true
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
    ---Measured size of a fontstring's current text, in its parent's
    ---coordinate space. GetStringWidth/Height do not include the text
    ---scale, so it is multiplied back in here - the one place to correct
    ---if a client ever changes that.
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
-- return the override). Re-resolve on both signals; linked fontstrings
-- follow the objects, so no display refresh is needed.
local function OnMediaChanged(_, mediatype)
    if mediatype == "font" then
        Resolve()
    end
end
LSM.RegisterCallback(BR.DisplayFonts, "LibSharedMedia_Registered", OnMediaChanged)
LSM.RegisterCallback(BR.DisplayFonts, "LibSharedMedia_SetGlobal", OnMediaChanged)

-- The client-revert window after login and reload (see the module header).
-- Re-verify the objects a few times; reverted objects are re-applied and
-- every linked fontstring follows. Zone-change loading screens pass neither
-- flag and stay excluded.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
    if not (isInitialLogin or isReloadingUi) then
        return
    end
    C_Timer.NewTicker(5, ReassertObjects, 6)
end)
