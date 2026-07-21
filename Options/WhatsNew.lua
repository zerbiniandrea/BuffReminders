local _, BR = ...

-- ============================================================================
-- WHAT'S-NEW NOTIFICATION DOTS
-- ============================================================================
-- A mobile-style "there's something new here" badge that guides the user to
-- addon features shipped in a release they haven't acknowledged yet. Fully
-- dynamic and generic: it tracks opaque `cohort` labels (a version string,
-- set once and never removed), and `BR.aceDB.global.seenVersions` is the set of
-- cohorts the user has acknowledged. Something is "new" purely by set
-- membership - no version comparison, so it is robust against the
-- @project-version@ package token and prerelease suffixes.
--
-- Sources declare what's new by registering entries:
--   { cohort = "6.4.0", pageId = "visibility", key? = "someControl" }
-- `pageId` drives the sidebar bubble-up (page button + its group header);
-- optional `key` drives a dot on a specific row/control. Static entries go
-- through Register(); dynamic sources (e.g. the buff list, whose tables finish
-- populating at ADDON_LOADED) register a provider whose function is evaluated
-- fresh on every Refresh.
--
-- This module owns only state/lifecycle. Dots are drawn where their UI lives:
-- the sidebar in Options/Frame.lua, per-row dots in the buff row factory. The
-- panel acknowledges the current cohorts when it closes; fresh-install seeding
-- is in Core/Bootstrap.lua.

BR.Options = BR.Options or {}
BR.Options.WhatsNew = {}
local WhatsNew = BR.Options.WhatsNew

local staticEntries = {} -- registered { cohort, pageId, key? } literals
local providers = {} -- functions returning entry lists, evaluated per Refresh

-- Session snapshot, recomputed from the persisted seen-set on panel build/hide.
local unseenItems = {} -- key -> true
local unseenPages = {} -- pageId -> true
local pending = false

---Register a static what's-new entry. `cohort` is required; `pageId` enables
---the sidebar bubble-up; `key` enables a per-row/control dot.
function WhatsNew.Register(entry)
    staticEntries[#staticEntries + 1] = entry
end

---Register a source whose entries are computed lazily (called on each Refresh),
---for data that isn't final at load time.
function WhatsNew.RegisterProvider(fn)
    providers[#providers + 1] = fn
end

local function ForEachEntry(fn)
    for _, entry in ipairs(staticEntries) do
        fn(entry)
    end
    for _, provider in ipairs(providers) do
        local list = provider()
        if list then
            for _, entry in ipairs(list) do
                fn(entry)
            end
        end
    end
end

-- Recompute the session snapshot from the persisted seen-set. Called at panel
-- build and on hide, so each open reflects the latest acknowledged cohorts.
function WhatsNew.Refresh()
    wipe(unseenItems)
    wipe(unseenPages)
    pending = false
    local seen = BR.aceDB and BR.aceDB.global and BR.aceDB.global.seenVersions or {}
    ForEachEntry(function(entry)
        if not seen[entry.cohort] then
            if entry.key then
                unseenItems[entry.key] = true
            end
            if entry.pageId then
                unseenPages[entry.pageId] = true
            end
            pending = true
        end
    end)
end

function WhatsNew.IsItemNew(key)
    return unseenItems[key] == true
end

function WhatsNew.IsPageNew(pageId)
    return unseenPages[pageId] == true
end

---True if any page in the given sidebar group (`{ pages = { id, ... } }`) is new.
function WhatsNew.IsGroupNew(group)
    for _, pageId in ipairs(group.pages) do
        if unseenPages[pageId] then
            return true
        end
    end
    return false
end

function WhatsNew.HasPending()
    return pending
end

-- Acknowledge every cohort currently present across all sources. Writes to the
-- persisted set so the dots don't return next open, but leaves the session
-- snapshot intact so anything the user is looking at right now keeps its dot.
function WhatsNew.MarkSeen()
    if not (BR.aceDB and BR.aceDB.global) then
        return
    end
    local g = BR.aceDB.global
    g.seenVersions = g.seenVersions or {}
    ForEachEntry(function(entry)
        g.seenVersions[entry.cohort] = true
    end)
    pending = false
end

-- Testing helper (see /br shownew). Cohort labels accumulate across releases and
-- never leave the data, so clearing the whole seen-set would resurface every
-- cohort at once; Unsee targets a single one so re-testing stays clean forever.
function WhatsNew.GetCohorts()
    local counts = {}
    ForEachEntry(function(entry)
        counts[entry.cohort] = (counts[entry.cohort] or 0) + 1
    end)
    return counts
end

function WhatsNew.Unsee(cohort)
    local g = BR.aceDB and BR.aceDB.global
    if g and g.seenVersions then
        g.seenVersions[cohort] = nil
    end
    WhatsNew.Refresh()
end
