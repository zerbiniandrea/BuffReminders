local _, BR = ...

-- ============================================================================
-- IMPORT/EXPORT FUNCTIONS
-- ============================================================================

local LibDeflate = LibStub:GetLibrary("LibDeflate")

-- Prefix scheme: !BR_<TAG>_<payload> where TAG is one or more letters.
-- Legacy strings (!BR_<base64>) have no tag; standard base64 never contains '_',
-- so the tagged-pattern match is unambiguous. Neither does the print encoding
-- (a-z A-Z 0-9 and parentheses), so a tag of more than one letter stays
-- unambiguous too: the payload holds no second '_' for the greedy match to eat.
local LEGACY_PREFIX = "!BR_"
local COMPRESSED_PREFIX = "!BR_C_"
local CUSTOM_BUFF_PREFIX = "!BR_CB_"
local TAG_PATTERN = "^!BR_(%a+)_(.*)$"
local DEFLATE_CONFIG = { level = 9 }

-- A tag names both the payload encoding and the kind of data it carries, so an
-- import entry point can refuse a string meant for a different one.
local TAGS = {
    [""] = { encoding = "base64", kind = "profile" },
    C = { encoding = "deflate", kind = "profile" },
    CB = { encoding = "deflate", kind = "custombuff" },
}

local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Detect the format of a prefixed import string.
-- Returns (payload, tag) or (nil, nil) if the prefix is missing. The caller
-- resolves the tag through TAGS; "" is the legacy untagged form.
local function StripPrefix(str)
    local tag, payload = str:match(TAG_PATTERN)
    if tag then
        return payload, tag
    end
    if str:sub(1, #LEGACY_PREFIX) == LEGACY_PREFIX then
        return str:sub(#LEGACY_PREFIX + 1), ""
    end
    return nil, nil
end

-- Serialize a Lua table to a deflate-compressed, print-encoded payload (no prefix).
local function SerializeTable(tbl)
    local success, cbor = pcall(C_EncodingUtil.SerializeCBOR, tbl)
    if not success then
        return nil
    end
    local compressed = LibDeflate:CompressDeflate(cbor, DEFLATE_CONFIG)
    if not compressed then
        return nil
    end
    return LibDeflate:EncodeForPrint(compressed)
end

-- Deserialize a prefixed import string back to a Lua table.
-- expectedKind rejects a valid string that carries the wrong kind of data.
local function DeserializeTable(str, expectedKind)
    if not str or str:trim() == "" then
        return nil, "Empty input"
    end

    local payload, tag = StripPrefix(str)
    if not payload then
        return nil, "Invalid import string (missing prefix)"
    end

    local spec = TAGS[tag]
    if not spec then
        return nil, "Invalid format: unknown tag '" .. tag .. "'"
    end
    if expectedKind and spec.kind ~= expectedKind then
        return nil, "Wrong string type: expected " .. expectedKind .. ", got " .. spec.kind
    end

    local cbor
    if spec.encoding == "base64" then
        local ok, decoded = pcall(C_EncodingUtil.DecodeBase64, payload)
        if not ok or not decoded then
            return nil, "Invalid format: not valid base64"
        end
        cbor = decoded
    else
        local decoded = LibDeflate:DecodeForPrint(payload)
        if not decoded then
            return nil, "Invalid format: not valid print encoding"
        end
        local decompressed = LibDeflate:DecompressDeflate(decoded)
        if not decompressed then
            return nil, "Invalid format: failed to decompress"
        end
        cbor = decompressed
    end

    local ok, data = pcall(C_EncodingUtil.DeserializeCBOR, cbor)
    if not ok or type(data) ~= "table" then
        return nil, "Invalid data: failed to deserialize"
    end

    return data
end

-- If sourceProfile is provided, exports from that table instead of the active profile.
local function ExportSettings(sourceProfile)
    local defaults = BR.defaults
    local prof = sourceProfile or BR.profile
    local export = {}

    for key in pairs(defaults) do
        if prof[key] ~= nil then
            export[key] = DeepCopy(prof[key])
        end
    end

    if prof.customBuffs then
        export.customBuffs = DeepCopy(prof.customBuffs)
    end

    if prof.detachedIcons then
        export.detachedIcons = DeepCopy(prof.detachedIcons)
    end

    local result = SerializeTable(export)
    if not result then
        return nil, "Failed to serialize settings"
    end
    return COMPRESSED_PREFIX .. result
end

local function ImportSettings(prefixedStr)
    local defaults = BR.defaults
    local data, err = DeserializeTable(prefixedStr, "profile")
    if not data then
        return false, err
    end

    -- Wipe all exportable keys first so import is a full replacement, not a merge.
    -- This ensures keys present in the current profile but absent from the import
    -- string are cleared (e.g. old customBuffs, disabled enabledBuffs entries).
    for key in pairs(defaults) do
        if key ~= "minimap" then
            BR.profile[key] = nil
        end
    end
    BR.profile.customBuffs = nil
    BR.profile.detachedIcons = nil

    for k, v in pairs(data) do
        BR.profile[k] = DeepCopy(v)
    end

    -- Back-compat: pre-v44 export strings carry the legacy boolean tracking
    -- overrides instead of the per-context mode enums. Migrations do not re-run on
    -- import, so map them here (mirrors migration [44]) and clear the stale keys.
    -- Guard on the OLD key only: the new mode keys already hold a value in the
    -- profile (AceDB defaults), so a `p.outsideInstancesMode == nil` check never
    -- fires and drops the legacy boolean without conversion.
    local p = BR.profile
    if p.selfOnlyOutsideInstances ~= nil then
        p.outsideInstancesMode = p.selfOnlyOutsideInstances and "self_only" or "default"
    end
    if p.hideOthersInCombat ~= nil then
        p.combatMode = p.hideOthersInCombat and "my_buffs" or "default"
    end
    if p.myBuffsOnlyWhileLeveling ~= nil then
        p.levelingMode = p.myBuffsOnlyWhileLeveling and "my_buffs" or "default"
    end
    p.selfOnlyOutsideInstances = nil
    p.hideOthersInCombat = nil
    p.myBuffsOnlyWhileLeveling = nil

    -- Pre-v52 strings carry the panel zoom as a raw frame scale (migration [52]).
    if type(p.optionsPanelScale) == "number" then
        p.optionsPanelZoom = BR.ZoomFromLegacyScale(p.optionsPanelScale)
    end
    p.optionsPanelScale = nil

    -- Ensure defaults sub-table exists and has the metatable (DeepCopy produces
    -- a plain table, and old export strings can omit the defaults key).
    if not BR.profile.defaults then
        BR.profile.defaults = {}
    end
    setmetatable(BR.profile.defaults, { __index = defaults.defaults })

    return true
end

-- ============================================================================
-- SINGLE CUSTOM BUFF
-- ============================================================================
-- A custom buff is self-contained, so one entry travels on its own. The stored
-- key never travels with it: an import assigns a fresh key, which keeps the
-- imported entry separate from whatever the profile already holds.
--
-- An import string is untrusted input. Only the fields listed here reach the
-- profile, each one checked against the value domain its editor writes. That
-- matters most for castMacro: a click action runs what the string carries.

local floor = math.floor
local strtrim = strtrim

local NAME_LIMIT = 100
local OVERLAY_LIMIT = 100
local MACRO_LIMIT = 1024
local MAX_EXPIRATION = 600
-- Each tracked ID costs an aura read on every refresh.
local SPELL_LIMIT = 64

-- The editor stores its default choice as nil, so these sets leave the default
-- out. An imported default then reads back as nil, the same as a locally saved
-- one.
local GLOW_MODES = { whenGlowing = true, whenNotGlowing = true }
local ITEM_MODES = { equipped = true, bags = true }
local ITEM_COOLDOWNS = { offCooldown = true, onCooldown = true }
local LEVEL_FILTERS = { maxLevel = true, belowMaxLevel = true }

-- Content and difficulty keys come from the toggle defs the editor renders.
local CONTENT_KEYS, DIFFICULTY_KEYS = {}, {}
for _, def in ipairs(BR.Components.ContentToggleDefs) do
    CONTENT_KEYS[def.key] = true
    if def.diffDbKey then
        local allowed = {}
        for _, diff in ipairs(def.diffDefs) do
            allowed[diff.key] = true
        end
        DIFFICULTY_KEYS[def.diffDbKey] = allowed
    end
end

local function PositiveInt(value)
    if type(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
        return nil
    end
    return floor(value)
end

local function BoundedString(value, limit)
    if type(value) ~= "string" then
        return nil
    end
    local text = strtrim(value)
    if text == "" then
        return nil
    end
    return text:sub(1, limit)
end

---@return SpellID?
local function SanitizeSpellID(value)
    local single = PositiveInt(value)
    if single then
        return single
    end
    if type(value) ~= "table" then
        return nil
    end
    local ids = {}
    for _, entry in ipairs(value) do
        local id = PositiveInt(entry)
        if id then
            ids[#ids + 1] = id
            if #ids == SPELL_LIMIT then
                break
            end
        end
    end
    if #ids == 0 then
        return nil
    end
    return #ids == 1 and ids[1] or ids
end

-- A visibility table stores only the turned-off keys, so an entry that is not
-- false carries no meaning and is dropped.
local function SanitizeLoadConditions(source)
    if type(source) ~= "table" then
        return nil
    end
    local conditions, any = {}, false
    for key, value in pairs(source) do
        if CONTENT_KEYS[key] then
            if value == false then
                conditions[key] = false
                any = true
            end
        elseif DIFFICULTY_KEYS[key] then
            if type(value) == "table" then
                local allowed, difficulties, anyDifficulty = DIFFICULTY_KEYS[key], {}, false
                for diffKey, diffValue in pairs(value) do
                    if allowed[diffKey] and diffValue == false then
                        difficulties[diffKey] = false
                        anyDifficulty = true
                    end
                end
                if anyDifficulty then
                    conditions[key] = difficulties
                    any = true
                end
            end
        elseif key == "levelFilter" then
            if LEVEL_FILTERS[value] then
                conditions.levelFilter = value
                any = true
            end
        elseif key == "readyCheckOnly" then
            if value == true then
                conditions.readyCheckOnly = true
                any = true
            end
        end
    end
    return any and conditions or nil
end

---Copy the known fields of a decoded custom buff.
---@param data table
---@return CustomBuff?
local function SanitizeCustomBuff(data)
    if type(data) ~= "table" then
        return nil
    end
    local spellID = SanitizeSpellID(data.spellID)
    if not spellID then
        return nil
    end

    local showWhenPresent = data.showWhenPresent == true or nil
    local expiration = tonumber(data.expirationThreshold) or 0
    if showWhenPresent or expiration < 0 or expiration > MAX_EXPIRATION then
        expiration = 0
    end

    local requireItemID = PositiveInt(data.requireItemID)

    return {
        spellID = spellID,
        name = BoundedString(data.name, NAME_LIMIT),
        overlayText = BoundedString(data.overlayText, OVERLAY_LIMIT),
        class = BR.CLASS_SPEC_OPTIONS[data.class] and data.class or nil,
        requireSpecId = PositiveInt(data.requireSpecId),
        showWhenPresent = showWhenPresent,
        requireSpellKnown = data.requireSpellKnown == true or nil,
        glowMode = GLOW_MODES[data.glowMode] and data.glowMode or nil,
        expirationThreshold = expiration,
        castSpellID = PositiveInt(data.castSpellID),
        castItemID = PositiveInt(data.castItemID),
        castMacro = BoundedString(data.castMacro, MACRO_LIMIT),
        requireItemID = requireItemID,
        requireItemMode = requireItemID and ITEM_MODES[data.requireItemMode] and data.requireItemMode or nil,
        itemCooldownCondition = requireItemID
                and ITEM_COOLDOWNS[data.itemCooldownCondition]
                and data.itemCooldownCondition
            or nil,
        loadConditions = SanitizeLoadConditions(data.loadConditions),
    }
end

---Serialize one custom buff to a shareable string.
---@param key string
---@return string|nil
---@return string|nil error
local function ExportCustomBuff(key)
    local buffs = BR.profile.customBuffs
    local buff = buffs and buffs[key]
    if not buff then
        return nil, "Unknown custom buff"
    end

    local payload = DeepCopy(buff)
    payload.key = nil

    local result = SerializeTable(payload)
    if not result then
        return nil, "Failed to serialize custom buff"
    end
    return CUSTOM_BUFF_PREFIX .. result
end

---Decode a custom-buff string without applying it.
---@param str string
---@return CustomBuff|nil
---@return string|nil error
local function DecodeCustomBuff(str)
    if type(str) ~= "string" then
        return nil, "Invalid import string"
    end
    local data, err = DeserializeTable(str, "custombuff")
    if not data then
        return nil, err
    end
    local buff = SanitizeCustomBuff(data)
    if not buff then
        return nil, "Invalid custom buff data"
    end
    return buff
end

---Add a custom-buff string to the active profile as a new entry.
---@param str string
---@return string|nil key of the created entry
---@return string|nil error
local function ImportCustomBuff(str)
    local buff, err = DecodeCustomBuff(str)
    if not buff then
        return nil, err
    end

    local db = BR.profile
    if not db.customBuffs then
        db.customBuffs = {}
    end

    local key = BR.Helpers.GenerateCustomBuffKey(buff.spellID)
    buff.key = key
    db.customBuffs[key] = buff
    db.enabledBuffs[key] = true

    BR.CustomBuffs.CreateRuntime(buff)
    -- requireItemMode decides how ownership is read, so the cached answer for a
    -- shared item ID can be wrong for the new entry.
    BR.BuffState.InvalidateItemCache()
    return key
end

-- ============================================================================
-- PUBLIC API (for external addon integration)
-- ============================================================================

--- PUBLIC API - used by Wago UI and other external addons. Do not remove or rename.
--- Export settings to a prefixed string that can be imported by other addons.
--- If profileKey is nil or matches the active profile, exports the active profile.
--- Otherwise reads from AceDB's raw saved variables.
--- @param profileKey string|nil Optional profile name to export
--- @return string|nil Encoded settings string with !BR_C_ prefix, or nil on error
--- @return string|nil Error message if export failed
function BuffReminders:Export(profileKey)
    local sourceProfile
    if profileKey and BR.aceDB and profileKey ~= BR.aceDB:GetCurrentProfile() then
        local rawProfile = BR.aceDB.sv and BR.aceDB.sv.profiles and BR.aceDB.sv.profiles[profileKey]
        if rawProfile then
            -- Wrap raw SV table with defaults so unset keys resolve the same as the active profile
            local profileDefaults = BR.aceDB.defaults and BR.aceDB.defaults.profile
            if profileDefaults then
                sourceProfile = setmetatable({}, {
                    __index = function(_, k)
                        local v = rawProfile[k]
                        if v ~= nil then
                            return v
                        end
                        return profileDefaults[k]
                    end,
                })
            else
                sourceProfile = rawProfile
            end
        end
        -- If rawProfile is nil, sourceProfile stays nil -> exports active profile (backward compat)
    end

    return ExportSettings(sourceProfile)
end

--- PUBLIC API - used by Wago UI and other external addons. Do not remove or rename.
--- Import settings from a prefixed string. Accepts both legacy (!BR_) and compressed
--- (!BR_C_) formats; the format is detected from the prefix tag.
--- If profileKey is provided, creates or switches to that profile before applying.
--- @param importString string The encoded settings string
--- @param profileKey string|nil Optional profile name to import into
--- @return boolean success Whether the import succeeded
--- @return string|nil error Error message if import failed
function BuffReminders:Import(importString, profileKey)
    if not importString or type(importString) ~= "string" then
        return false, "Invalid import string"
    end

    -- Validate the prefix before any profile mutation so a malformed string, or
    -- one that carries a single custom buff, cannot create or switch profiles as
    -- a side effect.
    local _, tag = StripPrefix(importString)
    local spec = tag and TAGS[tag]
    if not spec then
        return false, "Invalid import string (missing prefix)"
    end
    if spec.kind ~= "profile" then
        return false, "Wrong string type: expected profile, got " .. spec.kind
    end

    -- BatchOperation suppresses the intermediate refresh from SetProfile, so one
    -- RefreshAfterProfileChange runs after the data is applied.
    local importSuccess, importErr
    BR.Profiles.BatchOperation(function()
        -- AceDB:SetProfile creates the profile if it does not exist.
        if profileKey and type(profileKey) == "string" and BR.aceDB then
            BR.aceDB:SetProfile(profileKey)
        end
        importSuccess, importErr = ImportSettings(importString)
    end)

    if not importSuccess then
        return false, importErr
    end
    return true
end

--- PUBLIC API - Decode an import string without applying it.
--- Accepts both legacy (!BR_) and compressed (!BR_C_) formats.
--- @param importString string The encoded settings string
--- @return table|nil data Decoded settings table, or nil on error
--- @return string|nil error Error message if decode failed
function BuffReminders:DecodeProfileString(importString)
    if not importString or type(importString) ~= "string" then
        return nil, "Invalid import string"
    end
    return DeserializeTable(importString, "profile")
end

--- PUBLIC API - Export one custom buff of the active profile to a string with
--- the !BR_CB_ prefix.
--- @param key string Custom buff key
--- @return string|nil
--- @return string|nil error
function BuffReminders:ExportCustomBuff(key)
    if type(key) ~= "string" then
        return nil, "Invalid custom buff key"
    end
    return ExportCustomBuff(key)
end

--- PUBLIC API - Add a custom-buff string to the active profile as a new entry.
--- @param importString string
--- @return string|nil key of the created entry
--- @return string|nil error
function BuffReminders:ImportCustomBuff(importString)
    if type(importString) ~= "string" then
        return nil, "Invalid import string"
    end
    return ImportCustomBuff(importString)
end

--- PUBLIC API - Return all existing profile keys in { [key] = true } format.
--- @return table<string, boolean>
function BuffReminders:GetProfileKeys()
    local result = {}
    for _, name in ipairs(BR.Profiles.ListProfiles()) do
        result[name] = true
    end
    return result
end

--- PUBLIC API - Return the key of the currently active profile.
--- @return string
function BuffReminders:GetCurrentProfileKey()
    return BR.Profiles.GetActiveProfileName()
end

--- PUBLIC API - Switch to an existing or new profile by key.
--- @param profileKey string
function BuffReminders:SetProfile(profileKey)
    if type(profileKey) ~= "string" then
        return
    end
    BR.Profiles.SwitchProfile(profileKey)
end

-- ============================================================================
-- WagoUI Pack API (thin wrappers matching expected method names)
-- ============================================================================

function BuffReminders:ExportProfile(profileKey)
    return self:Export(profileKey)
end

function BuffReminders:ImportProfile(profileString, profileKey)
    return self:Import(profileString, profileKey)
end

function BuffReminders:OpenConfig()
    BR.Options.Show()
end

function BuffReminders:CloseConfig()
    BR.Options.Hide()
end

BuffRemindersAPI = BuffReminders

BR.ImportExport = {
    DeepCopy = DeepCopy,
    Export = ExportSettings,
    Import = ImportSettings,
    ExportCustomBuff = ExportCustomBuff,
    ImportCustomBuff = ImportCustomBuff,
    DecodeCustomBuff = DecodeCustomBuff,
}
