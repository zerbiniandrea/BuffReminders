local _, BR = ...

-- ============================================================================
-- BUFF ROW FACTORY (shared)
-- ============================================================================
-- One row per tracked buff, at a single fixed height (ITEM_HEIGHT):
--
--   [x] icon(s)  Buff Name .............. [sound][pin]  <trailing link>
--
-- Buffs that share a `groupId` collapse into one row. Its spell list and icon
-- set are the union of the group members.

local L = BR.L
local Components = BR.Components

local BuffGroups = BR.BuffGroups

local GetBuffIcons = BR.Helpers.GetBuffIcons
local IsIconDetached = BR.Helpers.IsIconDetached

local UpdateDisplay = BR.Display.Update

local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

local tinsert = table.insert

-- Clickable-link affordance on the trailing link. Plain ASCII ">" renders in
-- every client font - the U+203A chevron is tofu in the CJK/Cyrillic bundled
-- fonts. It stays in code, not in the locale strings, so translators never
-- carry a stray marker.
local CHEVRON = " >"

-- Trailing link colors by state. Gold when the buff has its own options, orange
-- when that option still needs setup, gray for the generic "Settings".
local LINK_IDLE = { 0.55, 0.55, 0.58 }
local LINK_HOVER = BR.Colors.Accent
local GOLD_IDLE = { 0.82, 0.68, 0.24 }
local GOLD_HOVER = BR.Colors.Accent
local WARN_IDLE = { 0.95, 0.48, 0.32 }
local WARN_HOVER = { 1, 0.6, 0.42 }

local GLYPH_IDLE = { 0.62, 0.70, 0.75 }
local GLYPH_HOVER = { 0.85, 0.92, 0.97 }

-- Mirrors the Checkbox factory's info-icon trailing space (INFO_ICON_GAP + INFO_ICON_W).
local INFO_ICON_TRAILING = 18
-- Gap reserved between the label zone and the trailing cluster (link + glyphs).
local LINK_GAP = 8
local GLYPH_SIZE = 13
local GLYPH_GAP = 5
local GLYPH_TO_LINK_GAP = 7
-- Space the label clamp reserves for glyphs so a row with every glyph shown can
-- never overlap the buff name, regardless of how glyph visibility changes later.
-- Three slots: new-buff dot, detached pin, sound.
local GLYPH_RESERVE = 3 * (GLYPH_SIZE + GLYPH_GAP)

-- The bundled dot and pin textures are white. The vertex color sets the hue.
local NOTIFY_DOT_TEXTURE = "Interface\\AddOns\\BuffReminders\\Media\\dot.tga"
local NOTIFY_DOT_COLOR = { 0.88, 0.42, 0.40 }

local SOUND_ATLAS = "chatframe-button-icon-voicechat"
local PIN_TEXTURE = "Interface\\AddOns\\BuffReminders\\Media\\detach.tga"

local function OpenPanel(key, displayName, icons, readyCheckOnly, freeConsumable, anchor)
    BR.Options.Dialogs.BuffPanel.Show({
        key = key,
        displayName = displayName,
        icons = icons,
        readyCheckOnly = readyCheckOnly,
        freeConsumable = freeConsumable,
    }, anchor)
end

-- One state glyph in the trailing cluster. It starts hidden; the sync pass shows it.
local function CreateGlyph(parent, applyTexture, tooltipTitle, tooltipDesc)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    btn:SetFrameLevel(parent:GetFrameLevel() + 5)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    applyTexture(tex)
    tex:SetVertexColor(unpack(GLYPH_IDLE))
    btn.tex = tex
    btn:SetScript("OnEnter", function(self)
        tex:SetVertexColor(unpack(GLYPH_HOVER))
        BR.ShowTooltip(self, tooltipTitle, self.dynamicDesc or tooltipDesc, "ANCHOR_RIGHT")
    end)
    btn:SetScript("OnLeave", function()
        tex:SetVertexColor(unpack(GLYPH_IDLE))
        BR.HideTooltip()
    end)
    btn:Hide()
    return btn
end

local function CreateBuffRow(
    parent,
    x,
    y,
    icons,
    key,
    displayName,
    infoTooltip,
    readyCheckOnly,
    freeConsumable,
    rowWidth
)
    local holder = Components.Checkbox(parent, {
        label = displayName,
        icons = icons,
        infoTooltip = infoTooltip,
        -- Span the full column so the trailing link (and glyphs) right-align at
        -- the column edge instead of clustering 200px in from the left.
        holderWidth = rowWidth,
        get = function()
            return BR.StateHelpers.IsBuffEnabled(key)
        end,
        onChange = function(checked)
            BR.profile.enabledBuffs[key] = checked
            UpdateDisplay()
            Components.RefreshAll()
        end,
    })
    holder:SetPoint("TOPLEFT", x, y)

    -- Right-aligned at the holder edge, so every row's link sits in one column.
    -- Declared before openPanel, because the drawer anchors to it.
    local settingsBtn = CreateFrame("Button", nil, holder)

    local function openPanel()
        OpenPanel(key, displayName, icons, readyCheckOnly, freeConsumable, settingsBtn)
    end

    settingsBtn:SetFrameLevel(holder:GetFrameLevel() + 5)
    local settingsText = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    settingsText:SetPoint("RIGHT", 0, 0)
    settingsBtn:SetPoint("RIGHT", holder, "RIGHT", 0, 0)

    local pinGlyph = CreateGlyph(holder, function(t)
        t:SetTexture(PIN_TEXTURE)
    end, L["BuffRow.Glyph.Detached"], L["BuffRow.Glyph.Detached.Desc"])
    local soundGlyph = CreateGlyph(holder, function(t)
        t:SetAtlas(SOUND_ATLAS)
    end, L["BuffRow.Glyph.Sound"], nil)

    local newDot = CreateFrame("Button", nil, holder)
    newDot:SetSize(GLYPH_SIZE, GLYPH_SIZE)
    newDot:SetFrameLevel(holder:GetFrameLevel() + 5)
    local newDotTex = newDot:CreateTexture(nil, "ARTWORK")
    newDotTex:SetPoint("CENTER")
    newDotTex:SetSize(GLYPH_SIZE - 2, GLYPH_SIZE - 2)
    newDotTex:SetTexture(NOTIFY_DOT_TEXTURE)
    newDotTex:SetVertexColor(NOTIFY_DOT_COLOR[1], NOTIFY_DOT_COLOR[2], NOTIFY_DOT_COLOR[3])
    newDot:SetScript("OnEnter", function(self)
        BR.ShowTooltip(self, L["BuffRow.Glyph.New"], L["BuffRow.Glyph.New.Desc"], "ANCHOR_RIGHT")
    end)
    newDot:SetScript("OnLeave", function()
        BR.HideTooltip()
    end)
    newDot:Hide()

    -- Repaints the trailing cluster from the buff's live state. Registered as a
    -- refreshable below, because the drawer edits these values and calls RefreshAll.
    local function syncTrailing()
        local isSpecial, warn = BR.Options.Dialogs.BuffPanel.GetSpecialState(key)
        local idle, hover
        if isSpecial then
            idle = warn and WARN_IDLE or GOLD_IDLE
            hover = warn and WARN_HOVER or GOLD_HOVER
            settingsText:SetText(L["BuffRow.Extras"] .. CHEVRON)
        else
            idle = LINK_IDLE
            hover = LINK_HOVER
            settingsText:SetText(L["BuffPanel.SettingsLink"] .. CHEVRON)
        end
        settingsBtn.idleColor = idle
        settingsBtn.hoverColor = hover
        settingsText:SetTextColor(unpack(idle))
        settingsBtn:SetSize(settingsText:GetStringWidth() + 4, 16)

        -- Lay visible glyphs out right-to-left: [sound][pin][new] <link>.
        local sounds = BR.profile.buffSounds
        local hasSound = sounds and sounds[key] ~= nil
        local hasPin = IsIconDetached(key)
        local isRowNew = BR.Options.WhatsNew.IsItemNew(key)
        soundGlyph.dynamicDesc = hasSound and BR.Sounds.Label(sounds[key]) or nil

        local anchor, anchorGap = settingsBtn, GLYPH_TO_LINK_GAP
        for _, g in ipairs({ { newDot, isRowNew }, { pinGlyph, hasPin }, { soundGlyph, hasSound } }) do
            local glyph, active = g[1], g[2]
            if active then
                glyph:ClearAllPoints()
                glyph:SetPoint("RIGHT", anchor, "LEFT", -anchorGap, 0)
                glyph:Show()
                anchor, anchorGap = glyph, GLYPH_GAP
            else
                glyph:Hide()
            end
        end
    end
    syncTrailing()
    tinsert(BR.RefreshableComponents, { Refresh = syncTrailing })

    -- Clamp the label so it (and its trailing info icon) can never run under the
    -- trailing cluster, whatever the buff name's length or which glyphs show.
    local infoTrailing = holder.infoIcon and INFO_ICON_TRAILING or 0
    local maxLabelW = holder:GetWidth()
        - holder.labelOffset
        - infoTrailing
        - settingsBtn:GetWidth()
        - GLYPH_RESERVE
        - LINK_GAP
    if holder.label:GetStringWidth() > maxLabelW then
        holder.label:SetWidth(math.min(maxLabelW, holder.label:GetStringWidth()))
        holder.label:SetJustifyH("LEFT")
    end

    settingsBtn:SetScript("OnEnter", function(self)
        settingsText:SetTextColor(unpack(self.hoverColor or LINK_HOVER))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(displayName, 1, 0.82, 0)
        GameTooltip:AddLine(L["BuffRow.SettingsLink.Tooltip"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        settingsText:SetTextColor(unpack(self.idleColor or LINK_IDLE))
        GameTooltip:Hide()
    end)
    settingsBtn:SetScript("OnClick", openPanel)

    return y - ITEM_HEIGHT
end

-- Merge per-buff icon lists from every member of a group, deduped, in declared order.
local function MergeGroupIcons(group)
    local merged = {}
    local seen = {}
    for _, buff in ipairs(group) do
        for _, icon in ipairs(GetBuffIcons(buff)) do
            if not seen[icon] then
                seen[icon] = true
                tinsert(merged, icon)
            end
        end
    end
    return merged
end

local function RenderBuffArray(parent, x, y, buffArray, rowWidth)
    -- Bucket grouped buffs so the row factory sees one logical entry per groupId.
    local groupMembers = {}
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            groupMembers[buff.groupId] = groupMembers[buff.groupId] or {}
            tinsert(groupMembers[buff.groupId], buff)
        end
    end

    local seenGroups = {}
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            if not seenGroups[buff.groupId] then
                seenGroups[buff.groupId] = true
                local members = groupMembers[buff.groupId]
                local groupInfo = BuffGroups[buff.groupId]
                local readyCheckOnly = false
                local freeConsumable = false
                for _, m in ipairs(members) do
                    if m.readyCheckOnly then
                        readyCheckOnly = true
                    end
                    if m.freeConsumable then
                        freeConsumable = true
                    end
                end
                y = CreateBuffRow(
                    parent,
                    x,
                    y,
                    MergeGroupIcons(members),
                    buff.groupId,
                    groupInfo and groupInfo.displayName or buff.name,
                    buff.infoTooltip,
                    readyCheckOnly,
                    freeConsumable,
                    rowWidth
                )
            end
        else
            y = CreateBuffRow(
                parent,
                x,
                y,
                GetBuffIcons(buff),
                buff.key,
                buff.name,
                buff.infoTooltip,
                buff.readyCheckOnly,
                buff.freeConsumable,
                rowWidth
            )
        end
    end

    return y
end

BR.Options.BuffRow.Render = RenderBuffArray
BR.Options.BuffRow.CreateRow = CreateBuffRow
