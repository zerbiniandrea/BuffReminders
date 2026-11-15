local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- Versioned SavedVariables migrations.
--
-- Each entry runs exactly once, gated by db.dbVersion: on login the runner
-- executes every migration with an index in (db.dbVersion, DB_VERSION] in
-- order, then stamps db.dbVersion = DB_VERSION.
--
-- NEVER delete or renumber an existing migration: WoW has no forced upgrade,
-- so a profile can return from any historical dbVersion. An old profile then
-- skips the schema reshaping it still needs. Append new migrations at the end
-- and bump DB_VERSION.
-- ============================================================================

BR.Migrations = {}

BR.Migrations.DB_VERSION = 61
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

-- Versioning predates multiple profiles, and the single profile converted from the
-- flat layout was the active one at its first login. So an unversioned profile was
-- created in a session, in a version that did not stamp new profiles. Its data is
-- current, and a replay from 1 overwrites player choices. 60 is the last released
-- DB_VERSION, so the migrations after it still convert these profiles.
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
---@param db table Raw profile table
function BR.Migrations.Run(db)
    local version = db.dbVersion or 0
    if version > BR.Migrations.DB_VERSION then
        return
    end
    if version < BR.Migrations.MIN_DB_VERSION then
        wipe(db)
        db.dbVersion = BR.Migrations.DB_VERSION
        return
    end

    local migrations = {
        -- [48] (no-op, retired: repairGear/mageFood now ship off-by-default via the
        -- buff def's `defaultEnabled = false`, resolved at read time by
        -- StateHelpers.IsBuffEnabled - no per-profile seeding needed)
        [48] = function() end,

        -- [49] Frame lock is now session-only (starts locked every login), so the
        -- persisted `locked` field is dead - drop it.
        [49] = function()
            db.locked = nil
        end,

        -- [50] The entry set is the externals switch: a ticked buff is a tracked
        -- buff, so the separate enable flag is gone. A profile that kept ticks
        -- while that flag was off starts drawing them, which is what the ticks
        -- always asked for.
        [50] = function()
            if db.externals then
                db.externals.enabled = nil
            end
        end,
        -- [51] Guardian of the Forgotten Queen leaves the curated externals list:
        -- it is a PvP talent, too niche to offer everyone
        -- (BR.Migrations.KeepForgottenQueen).
        [51] = function()
            BR.Migrations.KeepForgottenQueen(db)
        end,
        -- [52] The options panel zoom replaces a raw frame scale that held
        -- PANEL_DENSITY at 100%. This pass covers every profile, not only `db`:
        -- migrations never run against an inactive profile, so a stale profile
        -- keeps the dead key and falls back to 100%.
        [52] = function()
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            for _, profile in pairs(profiles) do
                if type(profile) == "table" then
                    if type(profile.optionsPanelScale) == "number" then
                        profile.optionsPanelZoom = BR.ZoomFromLegacyScale(profile.optionsPanelScale)
                    end
                    profile.optionsPanelScale = nil
                end
            end
        end,
        -- [53] Aura Mastery leaves the curated externals list: aura 31821 lands on
        -- the paladin who casts it, not on the group, so the entry can never fire
        -- for the player it was offered to. Nothing walks a tracked key without a
        -- matching entry, so this pass only clears the dead saved keys.
        [53] = function()
            BR.Migrations.ClearExternals(db, { "auraMastery" })
        end,
        -- [54] Luminous Barrier and Earthen Wall Totem leave the curated externals
        -- list: the game removed both abilities, so auras 271466 and 201633 can never
        -- apply. Nothing walks a tracked key without a matching entry, so this pass
        -- only clears the dead saved keys.
        [54] = function()
            BR.Migrations.ClearExternals(db, { "luminousBarrier", "earthenWall" })
        end,
        -- [55] The icon cache leaves the custom buff entries. The display code
        -- wrote `_iconsCache` onto each entry, so SavedVariables and profile
        -- exports carried it. This pass covers every profile, not only `db`:
        -- an inactive profile keeps the dead key and exports it.
        [55] = function()
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            for _, profile in pairs(profiles) do
                local customBuffs = type(profile) == "table" and profile.customBuffs
                if type(customBuffs) == "table" then
                    for _, buff in pairs(customBuffs) do
                        if type(buff) == "table" then
                            buff._iconsCache = nil
                        end
                    end
                end
            end
        end,

        -- [56] defaults.warlockDemon becomes defaults.warlockDemons
        -- (BR.Migrations.ConvertWarlockDemons).
        [56] = function()
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            for _, profile in pairs(profiles) do
                if type(profile) == "table" then
                    BR.Migrations.ConvertWarlockDemons(profile)
                end
            end
        end,

        -- [57] Ancestral Protection Totem leaves the curated externals list: the game
        -- removed the ability, so aura 207498 can never apply. Nothing walks a tracked
        -- key without a matching entry, so this pass only clears the dead saved keys.
        -- It covers every profile, because an inactive profile keeps them otherwise.
        [57] = function()
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            local keys = { "ancestralProtection" }
            for _, profile in pairs(profiles) do
                if type(profile) == "table" then
                    BR.Migrations.ClearExternals(profile, keys)
                end
            end
        end,

        -- [58] /br debug leaves: no code reads debugMode, so this pass clears the
        -- dead flag in every profile.
        [58] = function()
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            for _, profile in pairs(profiles) do
                if type(profile) == "table" then
                    profile.debugMode = nil
                end
            end
        end,

        -- [59] A category's direction moves from growDirection to layoutDirection
        -- (BR.Migrations.MoveCategoryDirection). This pass covers every inactive
        -- profile too, because an inactive profile otherwise keeps the old key. An
        -- inactive profile below v58 is skipped: older migrations still read its
        -- growDirection, and its own run reaches this step in order.
        [59] = function()
            BR.Migrations.MoveCategoryDirection(db.categorySettings)
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            local active = BR.aceDB.profile
            for _, profile in pairs(profiles) do
                if type(profile) == "table" and profile ~= active and (profile.dbVersion or 0) >= 58 then
                    BR.Migrations.MoveCategoryDirection(profile.categorySettings)
                end
            end
        end,
        -- [60] The buff tooltip toggle becomes per category
        -- (BR.Migrations.SplitBuffTooltips). It covers inactive profiles by the
        -- rule of [59].
        [60] = function()
            BR.Migrations.SplitBuffTooltips(db)
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            local active = BR.aceDB.profile
            for _, profile in pairs(profiles) do
                if type(profile) == "table" and profile ~= active and (profile.dbVersion or 0) >= 58 then
                    BR.Migrations.SplitBuffTooltips(profile)
                end
            end
        end,
        -- [61] defaults.feastAtPlayer becomes defaults.placeAtPlayer
        -- (BR.Migrations.RenameFeastAtPlayer). No older migration reads the old key,
        -- so every inactive profile converts, whatever its version.
        [61] = function()
            BR.Migrations.RenameFeastAtPlayer(db)
            local profiles = BR.aceDB and BR.aceDB.sv and BR.aceDB.sv.profiles
            if not profiles then
                return
            end
            local active = BR.aceDB.profile
            for _, profile in pairs(profiles) do
                if type(profile) == "table" and profile ~= active then
                    BR.Migrations.RenameFeastAtPlayer(profile)
                end
            end
        end,
    }

    for step = version + 1, BR.Migrations.DB_VERSION do
        if migrations[step] then
            migrations[step]()
        end
    end
    db.dbVersion = BR.Migrations.DB_VERSION
end
