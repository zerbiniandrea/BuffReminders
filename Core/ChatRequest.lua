local _, ns = ...
---@class BR
local BR = ns
local L = BR.L

-- ============================================================================
-- CHAT REQUEST (definition + resolution)
-- ============================================================================
-- Single source of truth for "request this buff in chat". A buff is requestable
-- only when its definition in BR.BUFF_TABLES carries `chatRequestable = true`.

local ChatRequest = {}

-- The scan order fixes the order of the results. The virtual categories
-- (custom/loadout) are absent: no UI can flag them, so they never carry
-- `chatRequestable`.
local CATEGORY_ORDER = BR.STATIC_CATEGORIES

---@type table<string, table[]>
local buffsByCategory
local categoryList
local categorySet
---@type table<string, table>
local defsByKey

-- BR.BUFF_TABLES is static after load (custom buffs are not scanned), so one
-- build is safe to cache for the session.
local function build()
    buffsByCategory = {}
    categoryList = {}
    categorySet = {}
    defsByKey = {}
    for _, cat in ipairs(CATEGORY_ORDER) do
        local tbl = BR.BUFF_TABLES[cat]
        if tbl then
            for _, def in ipairs(tbl) do
                if def.chatRequestable then
                    if not categorySet[cat] then
                        categorySet[cat] = true
                        categoryList[#categoryList + 1] = cat
                        buffsByCategory[cat] = {}
                    end
                    local list = buffsByCategory[cat]
                    list[#list + 1] = def
                    defsByKey[def.key] = def
                end
            end
        end
    end
end

--- Ordered list of the buff defs of a category flagged `chatRequestable`.
---@param category string
---@return table[] defs
function ChatRequest.BuffsIn(category)
    if not buffsByCategory then
        build()
    end
    return buffsByCategory[category] or {}
end

--- Ordered list of categories that host at least one requestable buff.
---@return string[] categories
function ChatRequest.Categories()
    if not categoryList then
        build()
    end
    return categoryList
end

--- True when the category can produce a chat request for the current profile.
--- The click-to-cast setting of the category does not gate a request: the player
--- asked for one on the Chat Requests page, so the wiring paths that skip a
--- non-clickable category must still visit this one.
---@param category string
---@return boolean
function ChatRequest.WantsCategory(category)
    if BR.profile.requestBuffInChat ~= true then
        return false
    end
    if not categorySet then
        build()
    end
    return categorySet[category] == true
end

--- Slash-command prefix for the current group context (instance > raid > party > say).
---@return string prefix trailing space included, ready to prepend to the message
function ChatRequest.GetPrefix()
    if IsInGroup(2) then -- instance group
        return "/instance "
    elseif IsInRaid() then
        return "/raid "
    elseif IsInGroup() then
        return "/party "
    end
    return "/say "
end

--- The message of a buff key when the profile has no custom message.
--- A buff with chatRequestSpell puts the spell name into the %s of the localized text.
---@param key string
---@param fallbackName string? used only when no locale entry exists
---@return string?
function ChatRequest.DefaultMessage(key, fallbackName)
    if not defsByKey then
        build()
    end
    local text = L["ChatRequest." .. key]
    local def = defsByKey[key]
    if text and def and def.chatRequestSpell then
        local spellID = def.chatRequestSpell()
        -- A translation with another format sequence must not throw.
        local ok, formatted = pcall(string.format, text, spellID and BR.GetSpellName(spellID) or def.name)
        return ok and formatted or text
    end
    return text or fallbackName
end

--- Resolve the message for a buff key: custom (profile) > default message.
---@param key string buff key (matches BR.profile.chatRequestMessages keys)
---@param fallbackName string? used only when no custom message and no locale entry exist
---@return string?
function ChatRequest.ResolveMessage(key, fallbackName)
    local custom = (BR.profile.chatRequestMessages or {})[key]
    -- The chat server rejects a message with an escape sequence.
    custom = custom and custom:gsub("|", "")
    if custom and custom ~= "" then
        return custom
    end
    return ChatRequest.DefaultMessage(key, fallbackName)
end

BR.ChatRequest = ChatRequest
