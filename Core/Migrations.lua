local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- Versioned SavedVariables migrations. They run on raw profile tables before
-- AceDB:New, so a key with a default reads nil and a nested table can be absent.
--
-- The runner runs each migration in (profile.dbVersion, DB_VERSION] in order,
-- then stamps DB_VERSION. A profile below MIN_DB_VERSION resets to empty.
-- Add a migration as a new numbered entry at the end and increase DB_VERSION.
-- Never renumber an entry. To raise the floor, set MIN_DB_VERSION and delete
-- the migrations at or below it.
-- ============================================================================

BR.Migrations = {}

BR.Migrations.DB_VERSION = 69
BR.Migrations.MIN_DB_VERSION = 48

---Move a category's growth direction from growDirection, read only under the
---appearance override, to layoutDirection, which inherits on its own. The
---effective direction stays the same: an override with no stored direction
---resolved to CENTER, and a direction stored without the override was ignored.
---The main frame has no override and always followed Defaults, so a stale main
---growDirection goes too.
---@param categorySettings table|nil One profile's categorySettings
function BR.Migrations.MoveCategoryDirection(categorySettings)
    if type(categorySettings) ~= "table" then
        return
    end
    for category, catSettings in pairs(categorySettings) do
        if type(catSettings) == "table" then
            if category ~= "main" and catSettings.useCustomAppearance and catSettings.layoutDirection == nil then
                catSettings.layoutDirection = catSettings.growDirection or "CENTER"
            end
            catSettings.growDirection = nil
        end
    end
end

---Move the shared buff tooltip toggle (defaults.showBuffTooltips, read by raid
---and presence) to a per-category key on both, so each keeps what it showed.
---@param profile table One profile
function BR.Migrations.SplitBuffTooltips(profile)
    local profileDefaults = type(profile.defaults) == "table" and profile.defaults
    if not profileDefaults then
        return
    end
    if profileDefaults.showBuffTooltips == true then
        if type(profile.categorySettings) ~= "table" then
            profile.categorySettings = {}
        end
        for _, category in ipairs({ "raid", "presence" }) do
            if type(profile.categorySettings[category]) ~= "table" then
                profile.categorySettings[category] = {}
            end
            profile.categorySettings[category].showBuffTooltips = true
        end
    end
    profileDefaults.showBuffTooltips = nil
end

local VERTICAL_DIRECTIONS = { UP = true, DOWN = true }

---Convert one appearance scope's spacing from a fraction of the icon size to whole pixels.
---The pixel value is the gap that the display drew: the fraction times the icon dimension
---along the growth direction, rounded down.
---@param scope table defaults, or a category's settings
---@param direction string Effective growth direction of the scope
---@param keepNil boolean Leave a nil spacing as nil (it inherits)
local function SpacingScopeToPixels(scope, direction, keepNil)
    local fraction = scope.spacing
    if type(fraction) ~= "number" then
        if keepNil then
            scope.spacing = nil
            return
        end
        fraction = 0.2
    end
    local height = tonumber(scope.iconSize) or 64
    local width = tonumber(scope.iconWidth) or height
    local mainDim = VERTICAL_DIRECTIONS[direction] and height or width
    scope.spacing = math.floor(fraction * mainDim)
end

---Spacing changes from a fraction of the icon size to whole pixels. Each stored value
---converts with the icon size of its own scope, so the gaps on screen stay the same.
---A category under the appearance override with no stored spacing drew 20% of its own
---size, so it gets that value in pixels. The main frame reads the Defaults spacing, so
---its own key has no reader.
---@param profile table One profile
function BR.Migrations.SpacingToPixels(profile)
    local profileDefaults = type(profile.defaults) == "table" and profile.defaults or nil
    local globalDirection = profileDefaults and profileDefaults.growDirection or "CENTER"
    if profileDefaults then
        SpacingScopeToPixels(profileDefaults, globalDirection, false)
    end
    local categorySettings = profile.categorySettings
    if type(categorySettings) ~= "table" then
        return
    end
    for category, catSettings in pairs(categorySettings) do
        if category == "main" and type(catSettings) == "table" then
            catSettings.spacing = nil
        elseif type(catSettings) == "table" then
            local direction = globalDirection
            if catSettings.split and catSettings.layoutDirection then
                direction = catSettings.layoutDirection
            end
            SpacingScopeToPixels(catSettings, direction, not catSettings.useCustomAppearance)
        end
    end
end

---Grow one appearance scope by its border, so the icon art and the visible gap stay the same.
---@param scope table defaults, a category's settings, or externals
---@param fallbackBorder number Border width when the scope stores none
---@param fill boolean Write the code defaults for keys the scope does not store
---@param sizeDefault number Code default of iconSize
---@param spacingDefault number Code default of spacing
local function GrowScopeByBorder(scope, fallbackBorder, fill, sizeDefault, spacingDefault)
    local border = tonumber(scope.borderSize) or fallbackBorder
    if border <= 0 then
        return
    end
    local iconSize = tonumber(scope.iconSize) or (fill and sizeDefault or nil)
    if iconSize then
        scope.iconSize = iconSize + 2 * border
    end
    if type(scope.iconWidth) == "number" then
        scope.iconWidth = scope.iconWidth + 2 * border
    end
    local spacing = tonumber(scope.spacing) or (fill and spacingDefault or nil)
    if spacing then
        scope.spacing = math.max(0, spacing - 2 * border)
    end
end

---The native border moves from outside the icon frame to inside it. Each scope that drew
---the border grows by it, so the icon art and the visible gaps stay the same. The
---Blizzard icon style and a Masque skin draw no native border on the reminder icons. The
---Masque check is an estimate: a disabled Masque group still counts as a skin.
---@param profile table One profile
function BR.Migrations.BorderInside(profile)
    local profileDefaults = type(profile.defaults) == "table" and profile.defaults or nil
    local iconStyle = profileDefaults and profileDefaults.iconStyle
        or (BR.CLIENT == BR.ClientType.Forever and "blizzard" or "modern")
    local masqueLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Masque")
    if iconStyle ~= "blizzard" and not masqueLoaded then
        if not profileDefaults then
            profileDefaults = {}
            profile.defaults = profileDefaults
        end
        local defaultBorder = tonumber(profileDefaults.borderSize) or 2
        GrowScopeByBorder(profileDefaults, 2, true, 64, 12)
        if type(profile.categorySettings) == "table" then
            for category, catSettings in pairs(profile.categorySettings) do
                if category ~= "main" and type(catSettings) == "table" then
                    if catSettings.useCustomAppearance then
                        GrowScopeByBorder(catSettings, 2, true, 64, 12)
                    else
                        GrowScopeByBorder(catSettings, defaultBorder, false, 64, 12)
                    end
                end
            end
        end
    end
    -- The externals draw the native border under every icon style and skin.
    local externals = profile.externals
    if type(externals) == "table" and externals.useCustomAppearance then
        GrowScopeByBorder(externals, 2, true, 40, 4)
    end
end

-- The categories that had each interaction control, and the global default of the control.
local INTERACTION_FOLD = {
    {
        key = "clickable",
        default = true,
        categories = { "raid", "presence", "targeted", "self", "pet", "consumable", "utility" },
    },
    {
        key = "clickableHighlight",
        default = true,
        categories = { "raid", "presence", "targeted", "self", "pet", "consumable", "utility" },
    },
    {
        key = "showDescriptionTooltips",
        default = false,
        categories = { "raid", "presence", "targeted", "self", "consumable" },
    },
}

-- The saved key that each interaction key replaces.
local OLD_KEYS = { showDescriptionTooltips = "showBuffTooltips" }

---Fold the per-category interaction keys into global defaults with an override per
---category (useCustomInteraction). A key whose categories all agree becomes that
---global value, else the global takes its default. A category that differs from a
---global keeps its values under an override. A category without a control follows
---the global. The category key showBuffTooltips becomes showDescriptionTooltips.
---@param profile table One profile
function BR.Migrations.FoldInteraction(profile)
    if type(profile.defaults) ~= "table" then
        profile.defaults = {}
    end
    local profileDefaults = profile.defaults
    if type(profile.categorySettings) ~= "table" then
        profile.categorySettings = {}
    end
    local categorySettings = profile.categorySettings

    -- The old effective value: clickable and clickableHighlight defaulted to on, and
    -- the consumable tooltip toggle was defaults.showConsumableTooltips.
    local function oldValue(category, key)
        if key == "showDescriptionTooltips" and category == "consumable" then
            return profileDefaults.showConsumableTooltips == true
        end
        local cs = categorySettings[category]
        local raw
        if type(cs) == "table" then
            raw = cs[OLD_KEYS[key] or key]
        end
        if key == "showDescriptionTooltips" then
            return raw == true
        end
        return raw ~= false
    end

    local globals = {}
    local controls = {}
    for _, fold in ipairs(INTERACTION_FOLD) do
        local first = oldValue(fold.categories[1], fold.key)
        local agree = true
        for _, category in ipairs(fold.categories) do
            controls[category] = controls[category] or {}
            controls[category][fold.key] = true
            if oldValue(category, fold.key) ~= first then
                agree = false
            end
        end
        if agree then
            globals[fold.key] = first
        else
            globals[fold.key] = fold.default
        end
    end

    local overrides = {}
    for category, keys in pairs(controls) do
        for key in pairs(keys) do
            if oldValue(category, key) ~= globals[key] then
                local values = {}
                for _, fold in ipairs(INTERACTION_FOLD) do
                    if keys[fold.key] then
                        values[fold.key] = oldValue(category, fold.key)
                    else
                        values[fold.key] = globals[fold.key]
                    end
                end
                overrides[category] = values
                break
            end
        end
    end

    for _, fold in ipairs(INTERACTION_FOLD) do
        profileDefaults[fold.key] = globals[fold.key]
    end
    for _, cs in pairs(categorySettings) do
        if type(cs) == "table" then
            for _, fold in ipairs(INTERACTION_FOLD) do
                cs[fold.key] = nil
            end
            cs.showBuffTooltips = nil
        end
    end
    for category, values in pairs(overrides) do
        if type(categorySettings[category]) ~= "table" then
            categorySettings[category] = {}
        end
        local cs = categorySettings[category]
        cs.useCustomInteraction = true
        for key, value in pairs(values) do
            cs[key] = value
        end
    end
    profileDefaults.showConsumableTooltips = nil
end

---Move defaults.feastAtPlayer to defaults.placeAtPlayer. The setting also places cauldrons.
---@param profile table One profile
function BR.Migrations.RenameFeastAtPlayer(profile)
    local profileDefaults = type(profile.defaults) == "table" and profile.defaults
    if not profileDefaults then
        return
    end
    if profileDefaults.feastAtPlayer ~= nil then
        profileDefaults.placeAtPlayer = profileDefaults.feastAtPlayer
    end
    profileDefaults.feastAtPlayer = nil
end

---Move a tracked Guardian of the Forgotten Queen from the curated externals list to
---a custom entry, sound override included. labelSpellID, not a stored name: aura
---228050 reads as "Divine Shield", and the granting ability localizes on every client.
---@param profile table One profile
function BR.Migrations.KeepForgottenQueen(profile)
    local externals = profile.externals
    if type(externals) ~= "table" then
        return
    end
    local entries = externals.entries
    if type(entries) ~= "table" or not entries.forgottenQueen then
        return
    end

    externals.custom = externals.custom or {}
    local key = BR.NewExternalKey(228050)
    externals.custom[key] = { spellIDs = { 228050 }, labelSpellID = 228049 }
    entries[key] = true
    entries.forgottenQueen = nil

    local sounds = externals.sounds
    if type(sounds) == "table" and sounds.forgottenQueen ~= nil then
        sounds[key] = sounds.forgottenQueen
        sounds.forgottenQueen = nil
    end
end

---Clear the saved entry and sound of curated externals that left the list.
---@param profile table One profile
---@param keys string[] Curated external keys
function BR.Migrations.ClearExternals(profile, keys)
    local externals = type(profile.externals) == "table" and profile.externals
    if not externals then
        return
    end
    local entries = type(externals.entries) == "table" and externals.entries
    local sounds = type(externals.sounds) == "table" and externals.sounds
    for _, key in ipairs(keys) do
        if entries then
            entries[key] = nil
        end
        if sounds then
            sounds[key] = nil
        end
    end
end

local WARLOCK_DEMON_KEYS = { [688] = "imp", [697] = "voidwalker", [691] = "felhunter", [366222] = "sayaad" }

---Move defaults.warlockDemon (one summon spell ID per row) to defaults.warlockDemons
---(a set of allowed demons per row). Every key is written, because a missing key
---follows the default, which allows Felhunter.
---@param profile table One profile
function BR.Migrations.ConvertWarlockDemons(profile)
    local profileDefaults = type(profile.defaults) == "table" and profile.defaults
    if not profileDefaults then
        return
    end
    local old = rawget(profileDefaults, "warlockDemon")
    if type(old) == "table" then
        local new = rawget(profileDefaults, "warlockDemons")
        if type(new) ~= "table" then
            new = {}
            profileDefaults.warlockDemons = new
        end
        for row, spellID in pairs(old) do
            if type(row) == "string" and WARLOCK_DEMON_KEYS[spellID] then
                local accepted = {}
                for id, key in pairs(WARLOCK_DEMON_KEYS) do
                    accepted[key] = id == spellID
                end
                new[row] = accepted
            end
        end
    end
    profileDefaults.warlockDemon = nil
end

-- Versioning predates multiple profiles, so an unversioned profile comes from a build
-- that did not stamp a new profile. Its data is current, and a reset deletes player
-- choices. 60 is the last DB_VERSION of such a build, so the later migrations still apply.
local UNVERSIONED_PROFILE_STAMP = 60

---Stamp each unversioned raw profile, before AceDB:New. Safe on every login: this
---build stamps a profile when it is created, so only an older build leaves one unversioned.
---@param profiles table? Raw BuffRemindersDB.profiles
function BR.Migrations.StampUnversionedProfiles(profiles)
    if not profiles then
        return
    end
    for _, profile in pairs(profiles) do
        if type(profile) == "table" and profile.dbVersion == nil then
            profile.dbVersion = UNVERSIONED_PROFILE_STAMP
        end
    end
end

---Run the pending migrations on one raw profile table and stamp it. A profile below
---MIN_DB_VERSION resets to empty. A profile above DB_VERSION comes from a newer build
---and stays untouched.
---@param profile table Raw profile table
---@param isImport? boolean The profile comes from an import string
function BR.Migrations.RunProfile(profile, isImport)
    local version = tonumber(profile.dbVersion) or 0
    if version > BR.Migrations.DB_VERSION then
        return
    end
    if version < BR.Migrations.MIN_DB_VERSION then
        wipe(profile)
        profile.dbVersion = BR.Migrations.DB_VERSION
        return
    end

    local migrations = {
        -- [49] The frame lock is session-only and starts locked at every login, so
        -- no code reads the saved `locked` field.
        [49] = function()
            profile.locked = nil
        end,

        -- [50] The entry set is the externals switch: a ticked buff is a tracked
        -- buff, so no code reads the enable flag. A profile with ticks under a
        -- disabled flag then shows those buffs.
        [50] = function()
            if profile.externals then
                profile.externals.enabled = nil
            end
        end,
        -- [51] Guardian of the Forgotten Queen leaves the curated externals list:
        -- it is a PvP talent, too niche to offer everyone
        -- (BR.Migrations.KeepForgottenQueen).
        [51] = function()
            BR.Migrations.KeepForgottenQueen(profile)
        end,
        -- [52] The options panel zoom replaces a raw frame scale that held
        -- PANEL_DENSITY at 100%.
        [52] = function()
            if type(profile.optionsPanelScale) == "number" then
                profile.optionsPanelZoom = BR.ZoomFromLegacyScale(profile.optionsPanelScale)
            end
            profile.optionsPanelScale = nil
        end,
        -- [53] Aura Mastery leaves the curated externals list: aura 31821 lands on
        -- the paladin who casts it, not on the group, so the entry can never fire
        -- for the player it was offered to. Nothing walks a tracked key without a
        -- matching entry, so this pass only clears the dead saved keys.
        [53] = function()
            BR.Migrations.ClearExternals(profile, { "auraMastery" })
        end,
        -- [54] Luminous Barrier and Earthen Wall Totem leave the curated externals
        -- list: the game removed both abilities, so auras 271466 and 201633 can never
        -- apply. Nothing walks a tracked key without a matching entry, so this pass
        -- only clears the dead saved keys.
        [54] = function()
            BR.Migrations.ClearExternals(profile, { "luminousBarrier", "earthenWall" })
        end,
        -- [55] The icon cache leaves the custom buff entries. The display code
        -- wrote `_iconsCache` onto each entry, so SavedVariables and profile
        -- exports carried it.
        [55] = function()
            local customBuffs = profile.customBuffs
            if type(customBuffs) == "table" then
                for _, buff in pairs(customBuffs) do
                    if type(buff) == "table" then
                        buff._iconsCache = nil
                    end
                end
            end
        end,

        -- [56] defaults.warlockDemon becomes defaults.warlockDemons
        -- (BR.Migrations.ConvertWarlockDemons).
        [56] = function()
            BR.Migrations.ConvertWarlockDemons(profile)
        end,

        -- [57] Ancestral Protection Totem leaves the curated externals list: the game
        -- removed the ability, so aura 207498 can never apply. Nothing walks a tracked
        -- key without a matching entry, so this pass only clears the dead saved keys.
        [57] = function()
            BR.Migrations.ClearExternals(profile, { "ancestralProtection" })
        end,

        -- [58] /br debug leaves: no code reads debugMode, so this pass clears the
        -- dead flag.
        [58] = function()
            profile.debugMode = nil
        end,

        -- [59] A category's direction moves from growDirection to layoutDirection
        -- (BR.Migrations.MoveCategoryDirection).
        [59] = function()
            BR.Migrations.MoveCategoryDirection(profile.categorySettings)
        end,
        -- [60] The buff tooltip toggle becomes per category
        -- (BR.Migrations.SplitBuffTooltips).
        [60] = function()
            BR.Migrations.SplitBuffTooltips(profile)
        end,
        -- [61] defaults.feastAtPlayer becomes defaults.placeAtPlayer
        -- (BR.Migrations.RenameFeastAtPlayer).
        [61] = function()
            BR.Migrations.RenameFeastAtPlayer(profile)
        end,
        -- [62] The paladin blessings move to a priority list per class
        -- (defaults.paladinBlessingsByClass). No code reads the blessing of each
        -- content row or the global blessing priority, so this pass clears them.
        [62] = function()
            local profileDefaults = profile.defaults
            if type(profileDefaults) == "table" then
                profileDefaults.paladinBlessings = nil
                profileDefaults.paladinBlessingPriority = nil
            end
        end,
        -- [63] The four choice-row keys become defaults.subIconReveal: one "always"
        -- keeps every row on screen. defaults.rightClickSnooze = false becomes
        -- defaults.rightClickMenu = false.
        [63] = function()
            local profileDefaults = profile.defaults
            if type(profileDefaults) ~= "table" then
                return
            end
            for _, key in ipairs({ "blessingSubIcons", "driveBySubIcons", "trackingSubIcons", "campSubIcons" }) do
                if profileDefaults[key] == "always" then
                    profileDefaults.subIconReveal = "always"
                end
                profileDefaults[key] = nil
            end
            if profileDefaults.rightClickSnooze == false then
                profileDefaults.rightClickMenu = false
            end
            profileDefaults.rightClickSnooze = nil
        end,
        -- [64] The paladin aura of each content row becomes a list with a backup
        -- (defaults.paladinAuraOrder). No code reads the single choice, so this pass clears it.
        [64] = function()
            local profileDefaults = profile.defaults
            if type(profileDefaults) == "table" then
                profileDefaults.paladinAuras = nil
            end
        end,
        -- [65] The expiring state below max level follows the duration share, so the
        -- levelingExpiring choice has no reader. This pass clears it.
        [65] = function()
            profile.levelingExpiring = nil
        end,
        -- [66] Consumable sub-icons follow defaults.subIconReveal. A local retail profile
        -- keeps them always on screen, as before. WoW Forever and an import start on the
        -- default. The sub-icon side becomes the global defaults.subIconSide.
        [66] = function()
            local profileDefaults = type(profile.defaults) == "table" and profile.defaults or nil
            local mode = profileDefaults and profileDefaults.consumableDisplayMode
            local reveal = profileDefaults and profileDefaults.subIconReveal
            if
                BR.CLIENT == BR.ClientType.Retail
                and not isImport
                and reveal == nil
                and (mode == nil or mode == "sub_icons")
            then
                profileDefaults = profileDefaults or {}
                profile.defaults = profileDefaults
                profileDefaults.subIconReveal = "always"
            end
            local categorySettings = profile.categorySettings
            if type(categorySettings) ~= "table" then
                return
            end
            local consumable = categorySettings.consumable
            local side = type(consumable) == "table" and consumable.subIconSide or nil
            if side ~= nil then
                profileDefaults = profileDefaults or {}
                profile.defaults = profileDefaults
                profileDefaults.subIconSide = side
            end
            for _, catSettings in pairs(categorySettings) do
                if type(catSettings) == "table" then
                    catSettings.subIconSide = nil
                end
            end
        end,
        -- [67] Click to cast, the hover highlight and the tooltips become global
        -- defaults with an Interaction override per category
        -- (BR.Migrations.FoldInteraction).
        [67] = function()
            BR.Migrations.FoldInteraction(profile)
        end,
        -- [68] Spacing becomes whole pixels, not a fraction of the icon size
        -- (BR.Migrations.SpacingToPixels).
        [68] = function()
            BR.Migrations.SpacingToPixels(profile)
        end,
        -- [69] The icon border moves inside the icon frame (BR.Migrations.BorderInside).
        [69] = function()
            BR.Migrations.BorderInside(profile)
        end,
    }

    for step = version + 1, BR.Migrations.DB_VERSION do
        if migrations[step] then
            migrations[step]()
        end
    end
    profile.dbVersion = BR.Migrations.DB_VERSION
end

-- Export strings carry exportVersion from this DB_VERSION on.
local FIRST_STAMPED_EXPORT = 59

---Migrate decoded profile import data and stamp it, as RunProfile does. An unstamped
---string comes from a DB_VERSION below 59 and runs every migration above the floor:
---[49]-[58] only clear or convert keys that a newer string does not carry.
---@param data table Decoded import data
---@param exportVersion number exportVersion of the string, 0 if absent
function BR.Migrations.RunImport(data, exportVersion)
    -- A NaN or infinite version comes only from a crafted string.
    if exportVersion ~= exportVersion or exportVersion == math.huge then
        exportVersion = 0
    end
    if exportVersion < FIRST_STAMPED_EXPORT then
        data.dbVersion = BR.Migrations.MIN_DB_VERSION
    else
        data.dbVersion = math.floor(exportVersion)
    end
    BR.Migrations.RunProfile(data, true)
end

local function CopyTable(source)
    local copy = {}
    for k, v in pairs(source) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end

---Migrate every raw profile below DB_VERSION, before AceDB:New. Each profile migrates
---on a copy, so an error keeps the saved original and the other profiles still migrate.
---@param profiles table? Raw BuffRemindersDB.profiles
function BR.Migrations.RunAllProfiles(profiles)
    if type(profiles) ~= "table" then
        return
    end
    for name, profile in pairs(profiles) do
        if type(profile) == "table" and (tonumber(profile.dbVersion) or 0) < BR.Migrations.DB_VERSION then
            -- The handler runs at the error, so the error handler records the migration stack.
            local ok, result = xpcall(function()
                local copy = CopyTable(profile)
                BR.Migrations.RunProfile(copy)
                return copy
            end, function(err)
                geterrorhandler()(("BuffReminders: migration of profile %q failed: %s"):format(name, tostring(err)))
            end)
            if ok then
                profiles[name] = result
            end
        end
    end
end
