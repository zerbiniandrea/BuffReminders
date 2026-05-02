local _, BR = ...

-- ============================================================================
-- SOUNDS PAGE
-- ============================================================================
-- Single global home for buff sound alerts. Renders one alphabetized list of
-- every buff that currently has a sound assigned (across all categories +
-- custom buffs), with preview / edit / remove controls per row and a single
-- "Add Sound Alert" button that opens the SoundAlert dialog scoped to the full
-- buff catalog.
--
-- Sound alerts are a cross-cutting notification feature, not a per-category
-- display knob - keeping them on one page preserves discoverability and lets
-- users audit their full alert configuration in one glance.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local BUFF_TABLES = BR.BUFF_TABLES
local BuffGroups = BR.BuffGroups

local GetBuffTexture = BR.Helpers.GetBuffTexture
local SetBuffSound = BR.Helpers.SetBuffSound

local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local TEXCOORD_INSET = BR.TEXCOORD_INSET
local LSM = BR.LSM
local PlaySoundFile = PlaySoundFile

local COL_PADDING = BR.Options.Constants.COL_PADDING
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local tinsert = table.insert
local tsort = table.sort
local abs = math.abs

local SOUND_ROW_HEIGHT = 24
local SOUND_ICON_SIZE = 20
local ADD_BTN_HEIGHT = 22
local LIST_TOP_GAP = 6

-- Build a {key -> {name, spellID}} lookup spanning every static buff array
-- plus the user's custom buffs. Static portion is cached at file scope; custom
-- buffs are merged on each call since they can be added/removed at runtime.
local cachedStaticInfo = nil
local function GetAllBuffInfo()
    if not cachedStaticInfo then
        cachedStaticInfo = {}
        local seenGroups = {}
        local arrays = {
            BUFF_TABLES.raid,
            BUFF_TABLES.presence,
            BUFF_TABLES.targeted,
            BUFF_TABLES.self,
            BUFF_TABLES.pet,
            BUFF_TABLES.consumable,
        }
        for _, buffArray in ipairs(arrays) do
            for _, buff in ipairs(buffArray) do
                if buff.groupId then
                    if not seenGroups[buff.groupId] then
                        seenGroups[buff.groupId] = true
                        local groupInfo = BuffGroups[buff.groupId]
                        cachedStaticInfo[buff.groupId] = {
                            name = groupInfo and groupInfo.displayName or buff.name,
                            spellID = buff.displaySpells or buff.spellID,
                        }
                    end
                else
                    cachedStaticInfo[buff.key] = {
                        name = buff.name,
                        spellID = buff.displaySpells or buff.spellID,
                    }
                end
            end
        end
    end

    local info = {}
    for k, v in pairs(cachedStaticInfo) do
        info[k] = v
    end

    local db = BR.profile
    if db.customBuffs then
        for key, customBuff in pairs(db.customBuffs) do
            info[key] = {
                name = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID)),
                spellID = customBuff.spellID,
            }
        end
    end
    return info
end

local function CreateSoundRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(SOUND_ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(SOUND_ICON_SIZE, SOUND_ICON_SIZE)
    row.icon:SetPoint("LEFT", 0, 0)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

    row.soundText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.soundText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)

    row.previewBtn = CreateFrame("Button", nil, row)
    row.previewBtn:SetSize(14, 14)
    row.previewBtn:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    row.previewTex = row.previewBtn:CreateTexture(nil, "ARTWORK")
    row.previewTex:SetAllPoints()
    row.previewTex:SetAtlas("chatframe-button-icon-voicechat")
    row.previewTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
    row.previewBtn:SetScript("OnEnter", function()
        row.previewTex:SetVertexColor(1, 1, 1, 1)
    end)
    row.previewBtn:SetScript("OnLeave", function()
        row.previewTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
    end)

    row.editBtn = CreateFrame("Button", nil, row)
    row.editBtn:SetSize(14, 14)
    row.editBtn:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    row.editTex = row.editBtn:CreateTexture(nil, "ARTWORK")
    row.editTex:SetAllPoints()
    row.editTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    row.editTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
    row.editBtn:SetScript("OnEnter", function()
        row.editTex:SetVertexColor(1, 1, 1, 1)
    end)
    row.editBtn:SetScript("OnLeave", function()
        row.editTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
    end)

    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(14, 14)
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.removeTex = row.removeBtn:CreateTexture(nil, "ARTWORK")
    row.removeTex:SetAllPoints()
    row.removeTex:SetAtlas("common-icon-redx")
    row.removeTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
    row.removeBtn:SetScript("OnEnter", function()
        row.removeTex:SetVertexColor(1, 0.3, 0.3, 1)
    end)
    row.removeBtn:SetScript("OnLeave", function()
        row.removeTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
    end)

    return row
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -10 })

    LayoutSectionNote(layout, content, L["Page.Sounds.Desc"])

    -- Anchor the list host directly (not via layout:Add) so the host can grow
    -- on re-render without leaving the rest of the page misaligned.
    local listTopY = layout:GetY() - LIST_TOP_GAP
    local listHost = CreateFrame("Frame", nil, content)
    listHost:SetPoint("TOPLEFT", content, "TOPLEFT", COL_PADDING, listTopY)
    listHost:SetWidth(contentWidth - COL_PADDING * 2)
    listHost:SetHeight(1)

    local emptyText
    local addBtn
    local rowPool = {}
    local rowCount = 0

    local Render -- forward decl

    local function AcquireRow(index)
        local row = rowPool[index]
        if not row then
            row = CreateSoundRow(listHost)
            rowPool[index] = row
        end
        row:SetWidth(listHost:GetWidth())
        row:Show()
        return row
    end

    Render = function()
        for i = 1, rowCount do
            rowPool[i]:Hide()
        end
        rowCount = 0

        local db = BR.profile
        local buffSounds = db.buffSounds or {}
        local buffInfo = GetAllBuffInfo()

        local sortedKeys = {}
        for key in pairs(buffSounds) do
            tinsert(sortedKeys, key)
        end
        tsort(sortedKeys, function(a, b)
            local infoA = buffInfo[a]
            local infoB = buffInfo[b]
            local nameA = infoA and infoA.name or a
            local nameB = infoB and infoB.name or b
            return nameA < nameB
        end)

        local y = 0
        if #sortedKeys == 0 then
            if not emptyText then
                emptyText = listHost:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                emptyText:SetPoint("TOPLEFT", 0, 0)
                emptyText:SetJustifyH("LEFT")
            end
            emptyText:SetText(L["Options.Sound.NoAlerts"])
            emptyText:Show()
            y = -SOUND_ROW_HEIGHT
        else
            if emptyText then
                emptyText:Hide()
            end

            for _, key in ipairs(sortedKeys) do
                local soundName = buffSounds[key]
                local info = buffInfo[key]
                local displayName = info and info.name or key

                rowCount = rowCount + 1
                local row = AcquireRow(rowCount)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, y)

                local spellID = info and info.spellID
                if type(spellID) == "table" then
                    spellID = spellID[1]
                end
                local texture = spellID and GetBuffTexture(spellID)
                if texture then
                    row.icon:SetTexture(texture)
                    row.icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
                else
                    row.icon:SetTexture(134400)
                    row.icon:SetTexCoord(0, 1, 0, 1)
                end

                row.nameText:SetText(displayName)
                row.soundText:SetText("|cff888888" .. soundName .. "|r")

                row.previewBtn:SetScript("OnClick", function()
                    local soundFile = LSM:Fetch("sound", soundName)
                    if soundFile then
                        PlaySoundFile(soundFile, "Master")
                    end
                end)
                row.editBtn:SetScript("OnClick", function()
                    BR.Options.Dialogs.SoundAlert.Show(Render, key, soundName, displayName)
                end)
                row.removeBtn:SetScript("OnClick", function()
                    SetBuffSound(key, nil)
                    Render()
                end)

                y = y - SOUND_ROW_HEIGHT
            end
        end

        if not addBtn then
            addBtn = CreateButton(listHost, L["Options.Sound.AddAlert"], function()
                BR.Options.Dialogs.SoundAlert.Show(Render)
            end)
            addBtn:SetSize(160, ADD_BTN_HEIGHT)
        end
        addBtn:ClearAllPoints()
        addBtn:SetPoint("TOPLEFT", 0, y - 8)

        local listHeight = -y + 8 + ADD_BTN_HEIGHT
        listHost:SetHeight(listHeight)
        content:SetHeight(abs(listTopY) + listHeight + 30)
    end

    Render()

    -- Re-render when the page becomes active so add/remove that happened
    -- elsewhere (e.g. via the dialog opening from another page) is reflected.
    local refreshHook = CreateFrame("Frame", nil, listHost)
    refreshHook:SetSize(1, 1)
    function refreshHook:Refresh()
        Render()
    end
    tinsert(BR.RefreshableComponents, refreshHook)

    local _ = COMPONENT_GAP
end

BR.Options.Pages.sounds = {
    title = L["Page.Sounds"],
    Build = Build,
}
