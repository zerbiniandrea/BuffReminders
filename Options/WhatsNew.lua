local _, BR = ...

-- ============================================================================
-- WHAT'S-NEW NOTIFICATION DOTS
-- ============================================================================
-- Dots that point the user at features from a release that the user did not
-- acknowledge yet. A `cohort` is an opaque label. `BR.aceDB.global.seenVersions`
-- is the set of acknowledged cohorts. A cohort is new only when that set does
-- not hold it. No code compares versions, so the @project-version@ package token
-- and prerelease suffixes stay safe.
--
-- This module owns state and lifecycle only. Each dot is drawn where its UI lives.

BR.Options.WhatsNew = {}
local WhatsNew = BR.Options.WhatsNew

---@class WhatsNewEntry
---@field cohort string Opaque release label; membership in the seen-set decides "new"
---@field pageId? string Sidebar page that gets a dot, and its group header
---@field key? string Row or control that gets a dot

---@type WhatsNewEntry[]
local staticEntries = {}
local providers = {}

local unseenItems = {} -- key -> true
local unseenPages = {} -- pageId -> true
local pending = false

---Register a static what's-new entry.
---@param entry WhatsNewEntry
function WhatsNew.Register(entry)
    staticEntries[#staticEntries + 1] = entry
end

---Register a source of entries. Refresh calls the function each time, for data
---that is not final at load time.
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

-- Recompute the session snapshot from the persisted seen-set. Call it at panel
-- build and at panel hide, so each open shows the latest acknowledged cohorts.
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

---True if any page in the given sidebar group is new.
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

-- Acknowledge every cohort that the sources report now. The write to the
-- persisted set stops the dots at the next open. The session snapshot stays
-- intact, so a dot that the user sees now stays.
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

-- Testing helper for /br shownew. Cohort labels stay in the data forever. A
-- clear of the full seen-set brings back every cohort at once, so Unsee removes
-- one cohort only.
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
