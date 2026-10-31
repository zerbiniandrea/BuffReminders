local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- GENERAL PAGE
-- ============================================================================
-- Addon-meta settings that are not tied to a buff or a category: language,
-- login messages and the minimap launcher icon.

local L = BR.L
local Components = BR.Components

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local LANGUAGE_AUTO = "auto"

local LANGUAGE_OPTIONS = {
    { value = LANGUAGE_AUTO, label = L["Options.Language.Auto"] },
    { value = "enUS", label = L["Language.enUS"] .. " (enUS)" },
}
do
    local codes = {}
    for code in pairs(BR.translatedLocales) do
        codes[#codes + 1] = code
    end
    table.sort(codes)
    for _, code in ipairs(codes) do
        LANGUAGE_OPTIONS[#LANGUAGE_OPTIONS + 1] =
            { value = code, label = BR.translatedLocales[code] .. " (" .. code .. ")" }
    end
end

StaticPopupDialogs["BUFFREMINDERS_RELOAD_LANGUAGE"] = {
    text = L["Dialog.ReloadLanguage"],
    button1 = L["Dialog.Reload"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Build(content)
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    local languageHolder = Components.Dropdown(content, {
        label = L["Options.Language"],
        options = LANGUAGE_OPTIONS,
        width = 140,
        tooltip = { title = L["Options.Language"], desc = L["Options.Language.Desc"] },
        get = function()
            return BR.aceDB.global.language or LANGUAGE_AUTO
        end,
        onChange = function(value)
            local language = value ~= LANGUAGE_AUTO and value or nil
            BR.aceDB.global.language = language
            -- BR.locale holds the language that loaded this session.
            if (language or GetLocale()) ~= BR.locale then
                StaticPopup_Show("BUFFREMINDERS_RELOAD_LANGUAGE")
            end
        end,
    })
    layout:Add(languageHolder, nil, COMPONENT_GAP)

    local loginMsgHolder = Components.Checkbox(content, {
        label = L["Options.ShowLoginMessages"],
        get = function()
            return BR.profile.showLoginMessages ~= false
        end,
        onChange = function(checked)
            BR.profile.showLoginMessages = checked
        end,
    })
    layout:Add(loginMsgHolder, nil, COMPONENT_GAP)

    local minimapHolder = Components.Checkbox(content, {
        label = L["Options.ShowMinimapButton"],
        get = function()
            return not BR.aceDB.global.minimap.hide
        end,
        onChange = function(checked)
            BR.aceDB.global.minimap.hide = not checked
            if BR.MinimapButton then
                if checked then
                    BR.MinimapButton.Icon:Show("BuffReminders")
                else
                    BR.MinimapButton.Icon:Hide("BuffReminders")
                end
            end
        end,
    })
    layout:Add(minimapHolder, nil, COMPONENT_GAP)

    content:SetHeight(math.abs(layout:GetY()) + 20)
end

BR.Options.Pages.general = {
    title = L["Page.General"],
    Build = Build,
}
