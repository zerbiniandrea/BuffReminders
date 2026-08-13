---@class BR
local _, BR = ...

-- Shared font handling for the display layer: reminder icons, movers, secure
-- overlays, and the externals tracker (the options panel typeface is a
-- separate system, see UI/Fonts.lua). The module resolves the configured LSM
-- face when the setting changes, applies it with fallback, and memoizes per
-- fontstring. Every apply is verified through GetFont, because SetFont can
-- report success without a real apply during the login window (confirmed
-- live on 2026-08-13: return value true, GetFont unchanged). A failed apply
-- schedules a deferred VisualsRefresh, so static labels heal too.

local LSM = LibStub("LibSharedMedia-3.0")
local abs = math.abs

-- Cached font path - resolved once on load and updated when the setting changes (via VisualsRefresh).
-- All SetFont calls read this local directly instead of calling LSM:Fetch() every time.
local fontPath = STANDARD_TEXT_FONT

-- Cached outline flag - resolved on load and updated when the setting changes (via VisualsRefresh).
-- "NONE" in saved settings is translated to "" at the WoW API level.
local outlineFlag = "OUTLINE"

---One guarded and verified SetFont attempt. The pcall catches paths that
---raise a hard error (for example, a missing TTF that another addon
---registered in LSM). The return value of SetFont is NOT sufficient: during
---the login window it can be `true` while the fontstring keeps its previous
---face and size. Only a GetFont read-back that matches the request counts
---as success. Outline flags are not compared - the client can reformat the
---flags string, and a wrong outline is not worth a retry loop.
---@param fs FontString|EditBox any FontInstance
---@param path string
---@param size number
---@param outline string
---@return boolean applied true when the face and size are on the font instance
local function TrySetFont(fs, path, size, outline)
    local ok, valid = pcall(fs.SetFont, fs, path, size, outline)
    if not ok or valid ~= true then
        return false
    end
    -- pcall again: GetFont on a forbidden subtree (externals) can throw.
    ---@diagnostic disable-next-line: undefined-field
    local okRead, appliedPath, appliedSize = pcall(fs.GetFont, fs)
    return okRead and appliedPath == path and appliedSize ~= nil and abs(appliedSize - size) < 0.5
end

-- Deferred self-heal: when a verified apply fails, one VisualsRefresh is
-- scheduled. Its handler re-resolves and re-applies every display font, which
-- reaches static labels that no render path touches again ("NO PET" text
-- never changes, so nothing else re-calls SetFontCached on it). The counter
-- caps the pump for a face that never loads; Resolve resets it when the
-- configured face changes.
local retryScheduled = false
local retryCount = 0
local MAX_FONT_RETRIES = 10

local function ScheduleRetry()
    if retryScheduled or retryCount >= MAX_FONT_RETRIES then
        return
    end
    retryScheduled = true
    retryCount = retryCount + 1
    C_Timer.After(1.5, function()
        retryScheduled = false
        BR.CallbackRegistry:TriggerEvent("VisualsRefresh")
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

---Resolve the font path and outline flag from saved settings and update the
---caches. This function does not probe the path. ApplyFont handles unloadable
---faces at apply time. A probe at login can fail for a face that loads a
---moment later, and the fallback then stays until the next resolve.
local function Resolve()
    local defaults = BR.profile and BR.profile.defaults
    local fontName = defaults and defaults.fontFace
    local path = fontName and LSM:Fetch("font", fontName)
    if path ~= fontPath and path ~= nil then
        -- A new face gets a fresh retry budget.
        retryCount = 0
    end
    fontPath = path or STANDARD_TEXT_FONT

    local outline = defaults and defaults.textOutline
    if outline == "NONE" then
        outlineFlag = ""
    else
        outlineFlag = outline or "OUTLINE"
    end
end

---@class BRFontString: FontString
---@field _br_font_size number?   -- last font size applied via SetFontCached
---@field _br_font_path string?   -- the path that SetFontCached applied (fallback, or nil on failure)
---@field _br_font_outline string? -- last outline flag applied via SetFontCached

---Apply the shared font face at the given size, with fallback. If the face
---fails to load, the client font keeps the text at the correct size. Callers
---that memoize must record the applied path and retry while it differs from
---fontPath. Then a load failure at login corrects itself on a later pass.
---@param fs FontString|EditBox any FontInstance
---@param size number
---@param outline? string overrides the shared outlineFlag
---@return string? appliedPath the path now on the font instance, nil if no call landed
local function ApplyFont(fs, size, outline)
    outline = outline or outlineFlag
    if TrySetFont(fs, fontPath, size, outline) then
        return fontPath
    end
    ScheduleRetry()
    if fontPath ~= STANDARD_TEXT_FONT and TrySetFont(fs, STANDARD_TEXT_FONT, size, outline) then
        return STANDARD_TEXT_FONT
    end
    return nil
end

---Apply the shared font (fontPath/outlineFlag) to a fontstring only when
---something changed. SetFont forces a full fontstring re-layout, and render
---paths re-apply fonts up to twice per second with unchanged values. The
---memo stores the applied path. After a fallback or a failed call, each
---later call retries the desired face until it lands.
---@param fs BRFontString|FontString|EditBox any FontInstance (edit boxes included)
---@param size number
---@param outline? string overrides the shared outlineFlag (e.g. "" for edit boxes)
---@return boolean applied true when the desired face is on the fontstring
local function SetFontCached(fs, size, outline)
    outline = outline or outlineFlag
    if fs._br_font_size == size and fs._br_font_path == fontPath and fs._br_font_outline == outline then
        return true
    end
    local applied
    if TrySetFont(fs, fontPath, size, outline) then
        applied = fontPath
    elseif fs._br_font_size == size and fs._br_font_path == STANDARD_TEXT_FONT and fs._br_font_outline == outline then
        -- The fontstring already has the fallback at this size, so skip the re-layout.
        applied = STANDARD_TEXT_FONT
    elseif fontPath ~= STANDARD_TEXT_FONT and TrySetFont(fs, STANDARD_TEXT_FONT, size, outline) then
        applied = STANDARD_TEXT_FONT
    end
    fs._br_font_size = size
    fs._br_font_path = applied
    fs._br_font_outline = outline
    if applied ~= fontPath then
        ScheduleRetry()
    end
    return applied == fontPath
end

BR.FontCache = {
    Resolve = Resolve,
    GetFontPath = function()
        return fontPath
    end,
    GetOutline = function()
        return outlineFlag
    end,
    IsFontPathValid = IsFontPathValid,
    ApplyFont = ApplyFont,
    SetFontCached = SetFontCached,
}

-- LSM can change what Fetch returns after login: a late registration of the
-- configured face, or a global override (LSM 12 SetGlobal makes every Fetch
-- return the override). Re-resolve on both signals and refresh only when the
-- resolved values changed. A trigger before Display registers its handler is
-- a safe no-op.
local function OnMediaChanged(_, mediatype)
    if mediatype ~= "font" then
        return
    end
    local oldPath, oldOutline = fontPath, outlineFlag
    Resolve()
    if fontPath ~= oldPath or outlineFlag ~= oldOutline then
        BR.CallbackRegistry:TriggerEvent("VisualsRefresh")
    end
end
LSM.RegisterCallback(BR.FontCache, "LibSharedMedia_Registered", OnMediaChanged)
LSM.RegisterCallback(BR.FontCache, "LibSharedMedia_SetGlobal", OnMediaChanged)
